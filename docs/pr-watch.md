# PR watch

An optional watcher for the pull requests an agent session opens. It tells the
owning session when CI turns red, when a review bot leaves an unresolved
thread, or when GitHub reports a merge conflict. The agent no longer has to
keep polling its PRs, which it rarely does without gaps.

Off by default. Nothing runs until you switch it on (DECISIONS 2026-11-14
"PR watch ships inside ytstack as an optional, opt-in tool").

## What it reports, and what not

Reported to the session that created the PR, once per occurrence:

- a failed check run or commit status on the current head (checks of the review bots named in the policy excluded)
- an unresolved review thread whose first comment is from a bot (or a reviewer login from the policy), outdated threads included
- a merge conflict, when GitHub returns `mergeable: false`

Not reported: general bot comments and review summaries, quota notices, human
threads, waiting, ready and closed states. Those stay visible in
`bin/ytstack-pr-watch status`, which also shows a readiness verdict per PR
(`ready`, `waiting`, `action_required`, `unavailable`) with the missing evidence.

PR watch never comments, reacts, reruns, approves or merges. A notice does not
authorize a merge; repository rules still apply. GitHub comment bodies never
reach the agent as instructions: notices are fixed templates with a link.

## Switch it on

```bash
bin/ytstack-pr-watch enable           # writes pr_watch=on to ~/.ytstack/config
bin/ytstack-pr-watch install-worker   # prints what it would install
bin/ytstack-pr-watch install-worker --yes
```

`bin/` is relative to the installed plugin; inside a session the SessionStart
context names the absolute path. The switch is per user and covers all projects.
With it off, every PR watch hook exits after one `grep` on `~/.ytstack/config`,
without starting Python and without output.

Requirements: `python3` 3.9 or newer (the macOS system Python works), `gh`
signed in to GitHub, and for the worker macOS (launchd).

State lives in `~/.ytstack/pr-watch/state/` (`watch.sqlite3`, `policy.json`,
worker logs), or under `$YTSTACK_PR_WATCH_HOME/state`. It is shared by Claude
Code, Codex and the worker, and stays the same across plugin updates.

## How a PR gets watched

- `gh pr create` in a Bash tool call, or an MCP `create_pull_request` tool: the
  PostToolUse hook records the PR URL from the output; the worker confirms it on
  GitHub and registers it to the session.
- SessionStart and PreToolUse record which session works on which branch in
  which worktree. A PR that appears later on that branch is adopted by the
  worker even if the post-tool hook was missed. `main`, `master` and `develop`
  are never adopted. Two sessions on one branch produce an ambiguity entry in
  `status`; nothing is adopted silently.
- Explicitly, for PRs created elsewhere:

```bash
bin/ytstack-pr-watch create --repo OWNER/REPO --session SESSION_ID --cwd WORKTREE -- --title "..." --body-file body.md
bin/ytstack-pr-watch register --repo OWNER/REPO --pr 123 --session SESSION_ID --cwd WORKTREE
bin/ytstack-pr-watch pause --repo OWNER/REPO --pr 123     # and resume
bin/ytstack-pr-watch inspect --repo OWNER/REPO --pr 123   # read only, registers nothing
bin/ytstack-pr-watch status
```

Inside a session `--session` defaults to the current one (`CODEX_THREAD_ID`, or
`claude:$CLAUDE_CODE_SESSION_ID`).

## Delivery: Claude Code pulls, Codex is woken

**Claude Code.** Sessions are stored as `claude:<session_id>` and are never
woken. With each user prompt the UserPromptSubmit hook adds a one-line status
per PR the session owns and any pending notice; a notice is shown once. The
hook reads local state only, never GitHub, so the evidence is at most one
worker tick old and the agent re-reads GitHub before acting. A session that
owns no open watch gets no output. A red check therefore reaches the agent with
the next prompt, not on its own.

**Codex.** The worker talks to the running Codex app server over its local
socket and starts a turn in the owning thread when that thread is idle, after a
fresh GitHub read and a second idle check. Busy or unloaded threads keep the
notice in the outbox. A lost start receipt is marked uncertain in `status` and
never sent twice. Codex runs plugin hooks only after you trust them in `/hooks`.

## The worker

`install-worker --yes` writes:

- `~/.ytstack/pr-watch/bin/pr-watch`, a launcher that runs the engine of the
  ytstack version Claude Code has installed (`installPath` in
  `~/.claude/plugins/installed_plugins.json`, so a rolled-back version is not
  used); without that entry, the highest cached version that carries no
  `.orphaned_at` marker (Claude Code and Codex plugin caches); last, the
  plugin that ran `install-worker`
- `~/Library/LaunchAgents/com.ytstack.pr-watch.plist`: `tick` every 60 seconds
  and at login, logs in the state directory, a `PATH` with the directories of
  `gh` and `python3` found at install time

It refuses when another `*pr-watch*.plist` exists in `~/Library/LaunchAgents`:
two workers would poll and deliver twice. On Linux it prints a systemd user
timer instead and writes nothing. `uninstall-worker --yes` unloads and removes
the LaunchAgent and the launcher and keeps the state.

`status` shows `health.heartbeat` (the last finished tick), discovery and
delivery errors.

## GitHub quota

GitHub allows 5,000 REST calls an hour per account, shared by everything that
runs under your login: the worker, every `gh` call of your agents, scripts. One
PR snapshot costs about eight calls, so a worker that read ten PRs every minute
would use nearly the whole hour on its own. The worker therefore:

- reads a PR every minute only while something moves (`registered`,
  `waiting`); a PR that is `ready`, blocked (`action_required`) or
  `unavailable` every 5 minutes; a closed one every 30 minutes (it can be
  reopened); a merged one never again;
- asks GitHub for the remaining quota before each tick (`gh api rate_limit`,
  which GitHub does not count) and keeps a reserve for your agents: 30% of the
  hourly quota by default, `rate_limit_reserve` (0 to 0.9) in the `defaults` of
  `policy.json`. At or below the reserve the tick reads nothing and `status`
  shows `health.rate_limited` with the reset time; above it, each snapshot is
  paid from what is left and the least recently read PRs go first.

## Policy

`policy.json` in the state directory says per repository which review bots must
finish before a PR counts as ready. Start from
[`tools/pr-watch/policy.example.json`](../tools/pr-watch/policy.example.json):

```json
{
  "defaults": {"review_policy_configured": false, "reviewers": []},
  "repositories": {
    "owner/repo": {
      "review_policy_configured": true,
      "reviewers": [
        {"login": "cursor", "app": "cursor", "check": "Cursor Bugbot"},
        {"login": "greptile-apps", "completion": "review"}
      ],
      "optional_skipped_checks": ["browser-tests"],
      "label_required_checks": [{"label": "preview", "name": "Build preview"}]
    }
  }
}
```

- A reviewer with `check` and `app` is done when that check run succeeded on the current head.
- A reviewer with `completion: "review"` is done when it submitted a review on the current head that is not a quota or failure notice.
- `optional_skipped_checks`: a skipped check that is not required does not block.
- `label_required_checks`: with the label set, the check must exist and pass.

Without a policy entry a repository still gets notices, but its PRs stay
`waiting` ("Expected review bots not configured"). An explicit empty
`reviewers` list with `review_policy_configured: true` means no bot review.
Neutral results, quota notices, missing checks and API errors never count as
green.

## Migrating from a local install

If you ran the watcher as a local tool before, copy its state once:

```bash
bin/ytstack-pr-watch migrate --from /path/to/old-install          # prints the plan
bin/ytstack-pr-watch migrate --from /path/to/old-install --yes
```

`--from` is the old install directory (with `state/watch.sqlite3`) or the state
directory itself. SQLite never opens the source: the database file and its
`-wal` are copied byte for byte into a scratch directory, the copy is checked
with `integrity_check` and written to the target with SQLite's backup API. The
source files stay untouched (even a read-only SQLite connection can create or
remove a database's `-wal` and `-shm` files). Stop the old worker first (step
1): a copy taken while it writes can be inconsistent, and the command then
refuses. `policy.json` is copied when the target has none. The command refuses
when the target database exists. It changes nothing else and prints the
remaining steps, which are yours to run:

1. Unload the old LaunchAgent (`launchctl bootout gui/$(id -u)/<label>`) and remove its plist. Do this first: what the old worker writes after the copy stays behind.
2. Remove the old `pr-watch hook --host claude` entries from `~/.claude/settings.json` (back the file up first). Otherwise both hook sets run.
3. Disable or remove the old Codex plugin `pr-watch@local-pr-watch`.
4. `bin/ytstack-pr-watch enable`, then `bin/ytstack-pr-watch install-worker --yes`.

## Limits

- Only the hook surfaces and the `create` command bind a PR to a session.
  Browser or hosted tools and untrusted or disabled hooks bypass them; register
  such PRs explicitly. This is no enforcement boundary against code that
  deliberately avoids the tooling.
- The worker runs while you are logged in. After sleep, logout or network loss
  it resumes with the next tick. 24/7 coverage needs a host that is always on.
- A closed PR stays watched: the worker looks at it again every 30 minutes and
  picks it up when it was reopened; registering it again does the same at
  once. A merged PR is not checked again.
- A settled PR is read every 5 minutes, so a red check on it can take that
  long to show up; below the quota reserve nothing is read until the reset.
- GitHub and the agent cannot be read atomically. A finding can resolve right
  after the last read; the agent re-reads before acting.
- Codex delivery uses the Codex app server's local API. An unsupported API
  version fails closed: the notice stays in the outbox.
- `delivered` means the host accepted the notice (Codex: turn started; Claude
  Code: shown with a prompt), not that the agent acted on it.
- No model polls. Model usage starts when a session processes a notice.
- `gh` authentication is reused; no token is copied into the database, the
  plist or the logs.

## Switch it off

```bash
bin/ytstack-pr-watch disable                 # hooks exit at once again
bin/ytstack-pr-watch uninstall-worker --yes  # stop polling
```

State stays in `~/.ytstack/pr-watch/`; delete it yourself once no watch is
needed. `bin/ytstack-watch` is unrelated and unchanged: it reads PR state on
demand while an agent keeps it running.

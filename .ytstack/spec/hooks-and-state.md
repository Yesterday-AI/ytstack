---
area: hooks-and-state
status: implemented
paths:
  - hooks/**
  - bin/ytstack-status
  - bin/ytstack-pr-watch
  - tools/pr-watch/**
sources:
  - docs/statusline.md
  - docs/pr-watch.md
  - docs/kimi.md
verified_at: db07481
---

# hooks-and-state

## Purpose

The lifecycle hooks under `hooks/` and the shared library `hooks/lib/git-ctx.sh`. The hooks inject project state when a session starts, keep volatile session state outside the repository, and tie commits and team tasks to task summaries. The library answers one question for every hook, skill preamble and `bin/` script: which checkout and which `.ytstack` directory does this call belong to. The status line segment `bin/ytstack-status` is described in `docs/statusline.md`. Skills that source the library belong to their own area.

## Behavior

### Resolver (`hooks/lib/git-ctx.sh`)

- The library is sourced, never executed. It targets macOS bash 3.2 and Linux bash 5.
- `yt_read_stdin` reads the hook payload once and extracts the common fields. It uses `jq`, else `python3`. With neither, every field stays empty. A `cwd` that is not an existing directory is discarded.
- `yt_git_ctx` resolves the directory the agent works in: the payload `cwd`, else `$PWD`. It never reads `CLAUDE_PROJECT_DIR`. Git detection is `git rev-parse --is-inside-work-tree`, so a linked worktree (where `.git` is a file) counts as Git.
- A checkout is a linked worktree when its git dir differs from the common git dir.
- The repo key is a 16-character digest of the canonical common git dir. All worktrees of one repository share it. Outside Git it is a digest of the directory. The worktree key is a digest of the canonical toplevel.
- `yt_resolve_yt_dir` finds the `.ytstack` directory: `<toplevel>/.ytstack` first (scope `project`), else `~/.ytstack/projects/<repo-key>` (scope `user`), else none. A linked worktree uses its own copy, not the main checkout's.
- Volatile state lives outside the tree under `<base>/repos/<repo-key>/worktrees/<worktree-key>/sessions/<session-id>/`. `yt_state_base` defines the order of candidate bases. A missing session id becomes `nosession`.
- If the base cannot be created, the state directory falls back to `<toplevel>/.ytstack/.local` when the checkout has a `.ytstack`, else to a per-user temp directory. `yt_ensure_gitignore` adds the ignore line for that fallback. Skills call it, hooks do not.
- `yt_pref` reads one key from `PREFERENCES.md` (`key: value` or `key=value`; quotes and a trailing comment are stripped). `yt_prefs` reads the ceremony dials and sets `YT_PREF_MERGE_BY` (default `risk`) and `YT_PREF_EVIDENCE_DIR` (default `.ytstack/evidence`). An invalid value is replaced by its default and reported in `YT_PREF_WARNINGS`; an invalid `merge_by` is replaced by `human`, so that a typo never merges without a person. `YT_PREF_ESCALATE` is the comma separated escalation list (default and fallback for an invalid item: all five of `violation, deviation, irreversible, secret, spend`), so that a typo never takes a class away from the person. `yt_upstream_feedback` (called by `yt_prefs`) sets `YT_PREF_UPSTREAM_FEEDBACK` from `PREFERENCES.md`, else from the last `upstream_feedback=` line of `~/.ytstack/config`, else `suggest`, and `YT_PREF_UPSTREAM_FEEDBACK_FROM` (`preferences`, `config`, `default`); an invalid value reads as `suggest`, so that a typo never publishes. `hooks/session-start` injects nothing for it; the injected `using-ytstack` names the channel.
- `yt_epoch` turns an ISO time into seconds with BSD `date -j`, GNU `date -d`, or, for BusyBox, `date -d` on the form `YYYY-MM-DD HH:MM:SS`.
- `yt_brownfield_signals` counts up to six signs of an existing codebase and names which file would feed which artifact. The comment above the function lists the counted signals and the hint-only ones.
- `yt_commit_ref_pattern` renders a task's commit pattern from `commit_ref_pattern` in `PREFERENCES.md`, or from the default. `yt_task_commits` lists commits whose subject matches it. When none match, it falls back to the commits on the current branch after the merge-base with the default branch, and reports which source it used.
- `yt_find_artifacts` lists artifacts newest first from the flat layout and from the alternative layouts named in its comment. Reading tolerates those layouts. `yt_artifact_dir` and `yt_artifact_path` say where a milestone's files live and where its new ones go: the directory that already holds its roadmap or files, else flat ([artifacts.md](artifacts.md), "Location and scope"). `post-tool-use-bash`, `task-completed`, `stop`, `pre-tool-use-edit` and `session-start` find the milestone's files through them; `task-created` and `teammate-idle` list its slice plans in every layout through `yt_find_artifacts`, one per name, so a plan that landed flat before the milestone moved counts too.
- `yt_factory_notices` returns one line per factory tool that is off although the project would use it, from local files only: risk routing (`spec/` without `REVIEW.md` or without an area whose frontmatter allows `auto_merge: low|normal`, quotes allowed, read with `yt_fm`, the reader `bin/ytstack-risk` uses; while `merge_by` is `risk`), the PR watch on a GitHub `origin` (no line in `~/.ytstack/config` that turns the hook on, read as `hooks/pr-watch` does: any `pr_watch=on` line; or `on` with a heartbeat missing or 10 minutes old; `yt_pr_watch_heartbeat` reads `watch.sqlite3`, else the time of `worker.lock`), and `RUNTIME.md` without "Release" or "Signals" while deploy or signal evidence exists (`ytstack-runtime sections`). `merge_by: human|coordinator` and `pr_watch=off` are choices and stay silent. `yt_read_stdin` also sets `YT_SOURCE`.
- `yt_standing` lists the standing instructions in force from `.ytstack/standing/` (name, `given`, `scope`, tab separated), newest first by the time in the name (missing seconds count as `00`), without the entries another entry names in `supersedes`, without entries of `kind: end` and without entries whose `until` has passed. It prints nothing without the directory; `STANDING.md` is read by the skills themselves. `yt_standing_fields` prints the same entries with every key, the first sentence of the body, `active` or `expired`, the source and the whole body on one line (`-` for an empty value); with `pending` as third argument also the entries of `yt_standing_pending` (on a local `standing/*` branch or the upstream it tracks, not in the working tree, not on `yt_standing_default_ref`), read with `git show`, source `pending:<branch>`. `yt_standing_default_ref` is `origin/HEAD`, else `origin/main`, `origin/master`, `main`, `master`. `yt_standing_lines <dir> <role> [max] [full]` prints the active ones for a role (with `full` the whole body, for briefs) (`docs/ux/coordinator-format.md`, "Scope and roles"), pending ones included and marked, as `- <name> (<scope>): <sentence>`, with a pointer line past `max`. None of them runs a command of an entry. `yt_latest_handoff` (for skill preambles) finds the newest `latest-handoff` of the worktree under every base a hook may have used: `CLAUDE_PLUGIN_DATA`, `PLUGIN_DATA`, each `~/.claude/plugins/data/ytstack*` and the XDG base. `coordinate` and `resume-session` use it; before, they looked under `yt_state_base` only, which in the Bash tool is not where the hook wrote. `yt_session_home` is `${XDG_STATE_HOME:-~/.local/state}/ytstack/sessions`: per-session state that a hook and the Bash tool of the same session both find (`CLAUDE_PLUGIN_DATA` reaches hooks only). It holds the coordinate marker (the resolved `.ytstack` on line 1, the repository key on line 2, which keys the lint counter also in user scope), the prompt counter and the standing flags of a session. `yt_behind_origin <toplevel> <yt_dir>` (issue #82) says whether the checkout is on the default branch (`yt_standing_default_ref`, only when that is an `origin` ref) and behind it, from local refs only, never a fetch (an `origin/<default>` that was never fetched counts as current), and only for a `.ytstack` inside the checkout whose `STATE.md` that ref has (else all 0 and empty: user scope, an untracked `STATE.md`): `YT_BEHIND_N`, `YT_AHEAD_N`, `YT_BEHIND_REF` (`origin/<branch>`), `YT_BEHIND_CHANGED` (`yes` when origin changed `STATE.md` since the merge base) and `YT_BEHIND_STATE`, origin's `STATE.md` only when it is the one to read: strictly behind (not diverged), changed, and the working tree's `STATE.md` is HEAD's (PR #94 review).

### STATE lint and progress block

`yt_state_lint` is read-only and returns one line per finding.

| Finding | Condition |
|---|---|
| missing | `STATE.md` does not exist in the resolved directory |
| W1 | `current_milestone`, `active_slice`, `active_task` or `last_updated` has a malformed value |
| W2 | the pointer is behind the newest `M###-CONTEXT.md` or `M###-ROADMAP.md` on disk |
| W3 | the active task already has a summary that is not a draft |
| W4 | a slice or task is set while the milestone is `none` |
| W5 | `last_updated` is older than the newest commit touching the `.ytstack` directory, beyond a slack set in the function |
| W6 | the current milestone's roadmap has `status: done` while a slice is still active |
| W7 | the `progress` block is malformed, one finding per problem |
| W8 | `STATE.md` is larger than `YT_STATE_MAX_BYTES` (set beside the function): it is a pointer, not a ledger |
| W9 | `STATE.md` carries status paragraphs beside the current one (`**Previous ...**`, `**Prior ...**`, a second `**Status ...**`) |
| W10 | an active task is set and `last_updated` is older than `YT_POINTER_STALE_DAYS` days (default 3) |

W8 and W9 are prompts for `ytstack:reconcile`, which moves history out with consent. No skill stops on them, nor on W10: `hooks/stop` leaves such a pointer to this line instead of a message at every stop. W10 reads `last_updated`, not the time the pointer itself last changed; an edit that bumps `last_updated` without moving the pointer resets it.

`yt_progress_parse` is the only parser of the optional `progress` block in the `STATE.md` frontmatter. It reports `none`, `ok` or `bad`. The lint and `bin/ytstack-status` both call it, so they agree on what is malformed.

### Hooks

Every hook except `pr-watch` sources the library and resolves from the payload `cwd`. Every hook except `session-start` and `pr-watch` exits 0 silently when no `.ytstack` directory resolves.

`pr-watch` (SessionStart, UserPromptSubmit, PreToolUse and PostToolUse on `Bash|mcp__.*create_pull_request.*`; for Codex also Stop, via `bin/ytstack-codex hook pr-watch`) is the opt-in PR watch: it exits 0 with no output and without starting Python unless `~/.ytstack/config` has `pr_watch=on`, then hands the payload to `tools/pr-watch/pr-watch.py hook`. It works for any repository, with or without `.ytstack`, and fails open (an engine error is one stderr line, exit 0). Engine, state (`~/.ytstack/pr-watch/`), worker and migration are described in `docs/pr-watch.md`; `bin/ytstack-check` exempts this hook from the resolver rule by name. For Claude Code the UserPromptSubmit output is injected only when a status line changed since the last injection in that session (one fingerprint per PR line in `meta` key `surface:<session>`, reset on SessionStart) or a notice is pending, and it lists only the changed lines plus `- N unchanged`, and one `closed (merged)` / `closed` line for a watch of the last block that closed since; an `action_required` watch that is not paused and whose `changed_at` is 24 h old or NULL gets one `pause` suggestion per stretch (`meta` key `pause-hint:<session>`, PR to `changed_at`, not reset on SessionStart) (`tests/pr_watch/test_scope.py`); before 24 h, an `action_required` watch that is not paused and whose `changed_at` is `stall_minutes` old (policy, default 15, 0 off) gets `STALL 1` first, and `STALL 2` a full window after `STALL 1` was shown (`meta` key `stall:<session>`, PR to `changed_at`, step and time shown), each part of the fingerprint so it shows once, with the line of `bin/ytstack-frontier owner --pr N,...`, one call per `cwd` whose `origin` is the PR's repository, only for lines that are shown, all within `OWNER_BUDGET` (3 s), resolved before the fingerprints are saved and never failing the block; a watch with `focus=1` (`register --pr N --focus`, `--no-focus`) is read on every tick and listed first under `Focus (read every tick):`, the rest under `Others:`; the focus and stall marks enter a fingerprint only when set (`tests/pr_watch/test_focus_stall.py`); a `git push` the PostToolUse hook sees in a bound worktree sets `pushed_at` on that branch's watch when `refs/remotes/origin/<branch>` (without one, `refs/heads/<branch>`) then differs from the watched head, which shows `head moved` and makes the worker read it next tick (`tests/pr_watch/test_under_load.py`). A merge the worker observes queues one notice per PR when the watch saw a bot finding on it (outbox key `merged:<repo>:<n>`, a fixed template that names `ytstack:review-lessons`); it is delivered without the fresh GitHub read other notices get and is never cancelled by a later read (`tests/pr_watch/test_merge_notice.py`). `handover --from <session> [--to <session>]` moves a session's watches, its undelivered notices (not a Codex notice with a `dispatch_id`), bindings and candidates to its successor and writes `meta` key `handover:<from>`; `register` follows that chain, so a PR a subagent of the old session opens later goes to the successor, and discovery counts a binding of the old session as its successor (no "Multiple sessions" ambiguity). A bare `--from`/`--to` id is qualified to `claude:<id>` when only that is stored, and a bare `--to` naming nothing follows a Claude `--from` (`tests/pr_watch/test_handover.py`). `register --all-open` takes only PRs whose author is the `gh` login or a login of `--author` (case-insensitive, a `[bot]` suffix ignored; without a readable login only `--author`, else an error), and skips drafts and labels that contain the words "do not merge" or `dnm` after `-_/:.` read as spaces unless `--include-drafts` / `--include-labelled` (which, like `--author`, need `--all-open`), naming each skipped PR with its reason and pausing a skipped PR this session already watches (`tests/pr_watch/test_register_all.py`). `status` is scoped to the current session and the `origin` repository of the working directory (`--session`, `--repo` compared without case; `--all` for everything; what does not resolve does not narrow) and prints the `scope` it used; `health` stays whole.

| Hook | Event | Reads from the payload | Effect | Exit |
|---|---|---|---|---|
| `session-start` | SessionStart | `cwd`, `source` | prints the injection as JSON on stdout, writes nothing | 0 |
| `version-notice` | UserPromptSubmit (first entry) | `session_id` | records the plugin version of the session's first prompt in `<base>/sessions/<session-id>/plugin-version`; when the installed version (`installed_plugins.json` entries of this root's marketplace with scope `user`, or `project`/`local` whose `projectPath` is the session's project; else the newest cache sibling without `.orphaned_at`) is newer, prints once per installed version "ytstack X installed, this session loaded A: reload the skills you use" and the CHANGELOG entry titles in between (cut at 600 characters), and writes `notified-<X>` after the notice was printed | 0 |
| `standing-prompt` | UserPromptSubmit (second entry) | `session_id`, `prompt` | only with the coordinate marker `<session home>/<session-id>/coordinate`: appends the epoch of every human prompt (not one that starts with `<`) to `prompts`; a prompt that reads like a standing instruction (instruction phrases in the script, English and German; a prompt that is only one question never) goes into `standing-flags` and gets one line of `additionalContext`: record it with `ytstack-standing add` before the next dispatch | 0 |
| `pre-compact` | PreCompact | `cwd`, `session_id`, `trigger` | writes `HANDOFF.auto.md` into the session state directory, renames a fresh `latest-handoff` symlink into the worktree state directory, prints compaction guidance on stdout; with the coordinate marker appends the epoch to `compactions` beside it, also without a `.ytstack` (issue #83) | 0 |
| `session-end` | SessionEnd | `cwd`, `session_id`, `reason` | appends one JSON line to `session.jsonl` in the session state directory | 0 |
| `stop` | Stop | `cwd`, `session_id`, `stop_hook_active` | prints a `systemMessage` when the active task has no summary or only a draft, once per session and pointer (`stop-said`), not with the coordinate marker and not for a pointer the lint reports as W10; when `yt_behind_origin` gives origin's `STATE.md` instead one message per origin head with the count and its pointer (issue #82); when a new session dir is made, dirs of sessions untouched for 14 days that only hold `stop-said` are removed; with the coordinate marker from the second compaction one reminder per compaction to rotate (Step 12, `rotate-said`; issue #83); with the coordinate marker and flagged prompts not handled yet, `decision: block` once when no standing entry exists since the first of them (working tree, or added on any ref after it), then writes `standing-stop`; with the marker also the coordinate lints: a `systemMessage` once per session when `LANES.md` lags the session's dispatches and reports by more than five minutes or the STATE pointer is behind (W2), and a block once when the same lint came in `YT_LINT_STREAK_N` (3) sessions in a row, a session counting once when the lint was there at any of its stops, overlapping sessions once each (counter `<state base>/repos/<repo-key>/coordinate-lints`) | 0 |
| `pre-tool-use-agent` | PreToolUse on `Agent`, `Task`, `SendMessage`, `Bash` | `session_id`, `tool_name`, the prompt or message, `subagent_type`, `isolation`, the command | only with the coordinate marker: appends every `Agent` call to `dispatches` except a lookup type (`Explore`, `Plan`, `claude-code-guide`, `statusline-setup`, a type naming search or explore) without a brief; a prompt without a line starting with `# Brief: ` (a `SendMessage` only above 400 characters) gets one line of `additionalContext` naming claim, render, dispatch; an `Agent` call that is no lookup and has no `isolation` one line naming `isolation: "worktree"`; a `Bash` command that runs `gh pr merge` or `gh pr close` as a command (per line and segment, after assignments, `if`/`then`/`!`, wrappers, `env`, `xargs` and `gh -R`; not in quotes or after `#`) one line naming `ytstack-finish-lane merge`, or `parked` and `gh run rerun` (issue #83); never a permission decision | 0 |
| `pre-tool-use-edit` | PreToolUse on `Edit`, `Write`, `MultiEdit` | `cwd`, target path | prints a drift warning on stderr | 0 |
| `post-tool-use-bash` | PostToolUse on `Bash` | `cwd`, command, exit code, `tool_response.stdout` | creates a draft task summary once; with the coordinate marker, a `gh run list --branch <default>` (or `-b`) whose output has a failed run (tab-separated `completed`/`failure`, `timed_out` or `startup_failure`, or a JSON array with `conclusion` and `workflowName`), counting only the newest run of each workflow and, with `--repo`/`-R`, only the repository of `origin`, gets one `additionalContext` note to run `ytstack:lesson`, once per distinct set of those runs (`red-main-said`; issue #83) | 0 |
| `task-created` | TaskCreated | `cwd`, subject, description | prints a scope warning on stderr | 2 on drift, else 0 |
| `task-completed` | TaskCompleted | `cwd`, subject | writes an auto summary, ticks the slice plan checkbox | 0 |
| `teammate-idle` | TeammateIdle | `cwd` | prints the open task count on stderr | 2 while tasks are open, else 0 |

- `pre-tool-use-edit` skips paths under `.ytstack/` and the artifact file names listed in the script. Scope drift means: the active task has a plan, and neither the checkout-relative path nor its basename occurs anywhere in that plan. Schema drift means: the target matches a model or schema pattern from the script and the plan names no migration path.
- `post-tool-use-bash` acts only when all of this holds: the call succeeded, the command contains a real `git commit` (after a command separator, optionally behind the wrapper tokens the script lists), `STATE.md` names an active slice and task, HEAD's subject matches the task's commit pattern, and no summary file exists. The stub carries `closed: draft`.
- `task-created` runs only with an active milestone. It extracts file-like paths from subject and description. Drift is a path that occurs in no slice plan of the current milestone and not in its roadmap.
- `task-completed` needs an `M###-S##-T##` id in the task subject. It never overwrites an existing summary. `teammate-idle` counts unchecked `T##` checkboxes across the slice plans of the current milestone.
- `stop` speaks only when milestone, slice and task are all set and the task's summary is missing or a draft (once per session and pointer, not in a coordinate session, not for a W10 pointer), when the checkout is behind origin, when a coordinator should rotate, or when the standing check or a coordinate lint speaks. It stays silent when `stop_hook_active` is true. The standing check counts an entry whose name time is in or after the minute of the first unhandled flagged prompt, in the working tree's `standing/` or in `git log --all --since=<that prompt> --diff-filter=A` of the repository; local git only, no host call.

### SessionStart injection

- Always: the full text of `skills/using-ytstack/SKILL.md` in an `<EXTREMELY_IMPORTANT>` envelope. If that file is missing, the hook prints nothing. If `YTSTACK_HOST_CONTEXT` is set, its text goes in front of the skill text.
- No `.ytstack`: a greenfield block that routes build intent to `office-hours`. With two or more brownfield signals it routes to `adopt-brownfield` and names the signals.
- `.ytstack` without `STATE.md`: a one-line repair notice.
- Otherwise a state block, in this order: scope, project, pointer, last update, working tree with the linked-worktree flag, `.ytstack` path, when `yt_behind_origin` gives origin's `STATE.md` a line with the count and `git merge --ff-only` (pointer and Next action are then read from it and the STATE lint is left out; issue #82), when origin changed `STATE.md` but the checkout diverged or edited it locally a line with ahead and behind and the local file read, in a coordinate session after a compaction `Compaction N of this coordinator: ytstack:coordinate Step 12, rotate now` (N from `compactions`, at least 1; issue #83), a Next action excerpt, the three newest summary names, a notice when more than one milestone roadmap is `in-progress`, in a coordinate session the operating checklist of `docs/ux/coordinator-format.md` (in place of the minimal-code line), the standing instructions in force for the session's role (coordinator with the coordinate marker, else lane; pending ones too, also before the checkout has `standing/`; at most six lines from `yt_standing_lines`, files only, and a line naming `STANDING.md` when it exists), the manual and the latest automatic handoff (a manual one whose `timestamp` is older than the automatic one's is listed after it as "Older manual handoff"), a lifecycle hint for a finished slice or a finished milestone without retro, up to five STATE lint findings, the minimal-code line when `minimal_code` is on, a "Factory tools" block with the lines of `yt_factory_notices` (only when the payload `source` is `startup` or `clear`, or absent on a SessionStart, so it is said once per session without a file), and a closing line that names the files as the source of truth. When `spec/SPEC.md` exists, the closing line names it as the place for what applies now.
- Cap: the hook measures the injection without the host context. Above the guard threshold in the script, which sits just under the host's 10,000-character limit, it first cuts the standing lines to the three newest, then the Factory tools block shrinks to one line that counts them and names `bin/ytstack-upkeep`, then the minimal-code line to its short pointer, then the closing line to its short form, then the standing lines to one line that counts them, names the role and `bin/ytstack-standing list`; last the `using-ytstack` body is cut to what fits, at a line end, with the line `(cut for the 10,000-char cap: read the rest in <the file>)` (issue #82: the Next action comes before that body). The Next action excerpt (at most five lines of 600 characters), the operating checklist and the lines about the checkout and a compaction are never cut. If the text is still above the threshold, it warns on stderr and emits the text anyway. Nothing else is dropped. Last, with a state block and on every source (also resume and compaction): one line `YT_BIN=<the running plugin's bin/, canonical>`, the directory skills run ytstack's bins from as `"$YT_BIN/ytstack-<name>"` (issue #85). It is added only when it still fits under the guard and the `using-ytstack` body was not cut, so it never costs the Next action excerpt or the directive; the `coordinate` preamble prints it too.
- Output is the existing Claude-compatible JSON envelope by default. `YTSTACK_HOOK_FORMAT=plain` emits the raw context instead. Kimi's helper uses this mode only to prepare pending context, not as a claim that SessionStart stdout is consumed.

### Kimi pending bridge

Kimi's native `sessionStart.skill` supplies the static directive. `bin/ytstack-kimi` stores the generated context atomically as `pending-context.md` in the session state directory on SessionStart and PostCompact. UserPromptSubmit renames it before emitting it, so parallel prompts consume it at most once and an absent file produces no output. PreCompact still writes the shared automatic handoff and SessionEnd the shared journal. The host contract and close limits are in `docs/kimi.md` and the `host-adapters` area.

### Status line segment

See `docs/statusline.md`. It was read against `bin/ytstack-status` at `verified_at` and matches.

`ytstack-status --phases [--json]` (issue #81) prints done, in review and total per milestone roadmap that is not dropped or backlog (a done or shipped-informally one counts all its slices), the phases that joined or left, and the total, from the checkout's files. A text report keeps the slice ids and a log of every change with its cause under `<base>/repos/<repo key>/phases/` (`snapshot`, `denominator.log`), outside the tree, under a noclobber lock with a `mktemp` file; `--json` reads them and writes nothing; a run that cannot create that directory prints `log none` and writes nothing.

## Interfaces and contracts

- `hooks/hooks.json` registers the nine lifecycle hooks, `version-notice`, `standing-prompt`, `pre-tool-use-agent` and `pr-watch` for Claude Code: event, matcher, timeout. The Codex and Kimi registrations are in the `host-adapters` area.
- The `YT_*` globals each function sets are named in the comment above that function. Consumers are every hook, the skill preambles and `bin/ytstack-status`.
- Files other parts read: `HANDOFF.auto.md` and `latest-handoff` (read by `hooks/session-start` and `skills/resume-session/SKILL.md`), draft and auto summaries (replaced by `summarize-task`, listed by `reconcile`). Kimi also reads and removes `pending-context.md` through its helper.
- The `progress` block and the segment's exit codes: `docs/statusline.md`.

## Invariants and security boundaries

- No hook resolves its target from `CLAUDE_PROJECT_DIR`. `bin/ytstack-check` fails on that name in a hook script, on `[ -d .git ]` and on a basename slug.
- Volatile state (automatic handoff, journal, Kimi pending context, the session's plugin version, the phase snapshot and denominator log of `ytstack-status --phases`, the first time `ytstack-frontier check` saw a lane ready) is written outside the tree. `version-notice` writes only `plugin-version` and `notified-<version>` under `<base>/sessions/<session-id>/`, keyed by the session and not by the checkout, and only for a session id of letters, digits, `.`, `_` and `-`. The only in-tree location is the `.ytstack/.local` fallback.
- No hook creates or changes `.ytstack/HANDOFF.md` or `STATE.md`.
- Two hooks write deliberate artifacts into the resolved `.ytstack`: `post-tool-use-bash` (the draft stub) and `task-completed` (auto summary, checkbox). Both write into the checkout the payload names, so a session that works in a linked worktree leaves the main checkout unchanged.
- `standing-prompt` writes only `prompts`, `reports` and `standing-flags`, `pre-tool-use-agent` only `dispatches`, `pre-compact` there only `compactions`, `post-tool-use-bash` there only `red-main-said`, and `stop` only `standing-stop`, `rotate-said`, `lint-warned-<kind>` and `lint-blocked-<kind>` under `<session home>/<session-id>/` plus the `coordinate-lints` counter under the state base, and only when the coordinate marker is there; the one exception is `stop-said`, which `stop` keeps for every session (what it said once, issue #82); a session id with other characters than letters, digits, `.`, `_` and `-` is ignored. No hook runs the `until-check` or `check` command of a standing entry (`docs/ux/coordinator-format.md`, "Where the commands of an entry run"). `session-start`, `pre-tool-use-edit`, `task-created` and `teammate-idle` write no files. Plain mode does not change this; the Kimi helper owns the pending write.
- Files under `sessions/<session-id>/` have one writer. There is no locking. Kimi's consume-by-rename is atomic even when two prompt hooks race.
- The payload is trusted as coming from the host. Its fields are shell-quoted before evaluation, but `session_id` is used as a directory name without sanitising.

## Error behavior

- No entry in `hooks/hooks.json` sets `onFailure: block`. The scripts run without `set -e`, report write errors on stderr and still exit 0.
- Without `jq`, the common fields come from `python3`. The fields that single hooks read themselves (target path, task subject, `stop_hook_active`) stay empty, so `pre-tool-use-edit`, `task-created` and `task-completed` do nothing.
- Without `jq` and `python3`, `session-start` prints unescaped JSON as a last resort.

## Runtime and deployment assumptions

- Bash, Git and either `jq` or `python3`.
- The host passes a JSON payload with `cwd` on stdin and honours the timeouts in `hooks/hooks.json`.

## Known limits

- `pre-tool-use-edit` warns on stderr and exits 0. The Claude Code hooks reference says the agent never sees stderr of a hook that exits 0. Who sees the warning: Unknown -- not reproduced in a live session.
- `task-created` exits 2 on drift and its message says the task is still created. The Claude Code hooks reference says exit 2 on TaskCreated rolls the creation back. Actual effect: Unknown -- not reproduced in a live session.
- The injection shares the 10,000-character cap with `using-ytstack` (about 7,400 characters). A project with two handoffs and long paths is near the cap already: there the standing list is cut to its pointer line, in a coordinate session after the checklist, and a long Next action cuts the end of the `using-ytstack` body, which the agent then reads from the file the pointer names.- `session-start` looks for `latest-handoff` only under the state base. An automatic handoff written to a fallback location is not announced.
- `yt_resolve_yt_dir` looks only at the toplevel. Outside Git, a subdirectory does not find its parent's `.ytstack`.
- `post-tool-use-bash` attributes a commit to the payload `cwd`, also when the command changed directory first.
- The scope check in `pre-tool-use-edit` is a substring match over the whole task plan, not over its Files section.
- `session.jsonl` has no reader in this repository.
- Codex and Kimi do not register `version-notice`; their sessions get no version notice. The standing hooks are Claude Code only too: Codex registers no ytstack UserPromptSubmit hook, and a Kimi shell has no session id for the coordinate marker. So are the hints of issue #83 (isolation, `gh pr merge`, `gh pr close`, compactions, the red-main note): Codex runs only the PR watch on `Bash` and has no ytstack hook on its subagent tools; there the skill text carries the rules. `standing-prompt` matches phrases (also a hold with until/bis and a time or condition, "hold merges until 12:37", "bis 12:37 keine Merges"), so an instruction in other words is not flagged, and a phrase in an ordinary sentence is; the stop block comes once per flagged batch and the agent may answer that none was a standing instruction. Whether Claude Code sends a task notification through UserPromptSubmit is not verified; without it the `reports` file stays empty and the LANES check sees dispatches only. `pre-tool-use-agent` tells a lookup from a lane only by the agent type and therefore never denies. With several ytstack entries in `installed_plugins.json` that count the highest version counts. The PR watch notice keys on a GitHub `origin`, not on open pull requests (that needs a host call).
- The key digest depends on the tool `yt_sha16` finds first, so keys can differ between machines.

## Where implemented

- `hooks/lib/git-ctx.sh` -- resolver, state directories, preferences, lint, progress parser, brownfield signals, commit discovery
- `hooks/hooks.json` -- registration
- `hooks/session-start`, `hooks/version-notice`, `hooks/standing-prompt`, `hooks/pre-tool-use-agent`, `hooks/pre-compact`, `hooks/session-end`, `hooks/stop`, `hooks/pre-tool-use-edit`, `hooks/post-tool-use-bash`, `hooks/task-created`, `hooks/task-completed`, `hooks/teammate-idle`
- `bin/ytstack-status` -- status line segment, and progress per phase (`--phases`)
- `bin/ytstack-check` (`check_resolver_contract`) -- banned patterns
- Tests: `tests/git-ctx.test.sh`, `tests/hooks-json.test.sh`, `tests/hooks-readonly.test.sh`, `tests/hooks-stop.test.sh`, `tests/hooks-standing.test.sh`, `tests/hooks-coordinate.test.sh`, `tests/hooks-worktree.test.sh`, `tests/hooks-concurrency.test.sh`, `tests/post-tool-use-bash.test.sh`, `tests/pre-compact.test.sh`, `tests/session-end.test.sh`, `tests/session-notices.test.sh`, `tests/ytstack-status.test.sh`, `tests/kimi_lifecycle_test.py`

## How to verify

Run from the repository root. Each shell suite ends with a line `<n> passed, 0 failed` and exits 0.

```bash
bash tests/git-ctx.test.sh
bash tests/hooks-json.test.sh
bash tests/hooks-readonly.test.sh
bash tests/hooks-stop.test.sh
bash tests/hooks-standing.test.sh
bash tests/hooks-coordinate.test.sh
bash tests/hooks-worktree.test.sh
bash tests/hooks-concurrency.test.sh
bash tests/post-tool-use-bash.test.sh
bash tests/pre-compact.test.sh
bash tests/session-end.test.sh
bash tests/session-notices.test.sh
bash tests/ytstack-status.test.sh
python3 -m unittest discover -s tests -p 'kimi_lifecycle_test.py' -v
```

`tests/hooks-worktree.test.sh` is the acceptance for the write rule: it fires every hook for three session shapes and compares the checkouts before and after. At `verified_at`, the nine Kimi lifecycle tests passed; native installation, real-prompt context and interactive close are verified by the live suite in the `host-adapters` area.

## Decisions that apply now

- DECISIONS.md -- "2026-11-15: Coordinate mode is a session marker the coordinate preamble writes; the standing hooks act only with it (issue #72)"; "2026-11-15: In coordinate mode the operating path is injected and checked by hooks that warn; a lint repeated in three sessions blocks once (issue #76)"; "2026-11-15: Standing entries end by `until`, `until-condition` or `until-check` and are closed by an entry of `kind: end`; their commands run only in `ytstack-standing list` (issues #73, #74)", narrowed by "2026-11-15: A standing entry's command runs only when the entry is merged; pending means this machine's standing branches (review of PR #87)"; extended by "2026-11-15: Hooks read a stale checkout from origin, say a reminder once per session and pointer, and keep a coordinator on its path with hints, not denies (issues #82, #83)" (the behind check, the once-per-pointer reminder, the cap order, the hints and the compaction count), narrowed by "2026-11-15: The open-PR cap limits opening, never a merge; origin's STATE.md is read only when the checkout is strictly behind and unedited (review of PR #94)"
- DECISIONS.md -- "2026-11-15: SessionStart stays read-only; factory-tool notices are said on startup only, the plugin version is recorded by a prompt hook (M031-S03)"
- DECISIONS.md -- "2026-11-15: PR watch bulk registration takes only your own ready PRs; bins are called through `YT_BIN` (issue #85)", extended by "2026-11-15: STALL detection lives in both watchers, owner liveness in `ytstack-frontier owner`; focus PRs are read every tick (issue #91)" (focus watches and STALL marks of the PR watch)
- DECISIONS.md -- "2026-11-14: Kimi uses native plugin bootstrap and pending lifecycle context (M020)" (plain output is explicit, the helper owns pending context and consumes it once)
- DECISIONS.md -- "2026-11-13: Whether a person looks at a change is decided per change: a floor from the diff, the class an independent reviewer states, a ceiling per area, lenses per kind of change (M025)" (`merge_by` and `evidence_dir` in `yt_prefs`)
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree"
- DECISIONS.md -- "2026-05-31: post-tool-use-bash is stub-once; summarize-task owns commit-to-task linking (M015 / issue #22)". The 2026-11-07 entry above narrows it: the stub appears only in the committing checkout and only for a commit that carries the task ref.
- DECISIONS.md -- "2026-04-24: Add `using-ytstack` skill + SessionStart-hook-injected directive for agent-driven skill selection". Only the injection pattern is in force; "2026-04-24: Skill selection is semantic (description-based), not keyword-based" retired its trigger map.
- DECISIONS.md -- "2026-04-23: `.ytstack/` location is user-chosen (project vs user vs both)". The 2026-11-07 hooks entry narrows it: user scope is keyed by the repo key, not by a slug.
- DECISIONS.md -- "2026-11-07: Ceremony scales with the change -- granularity, autonomy, quick lane and minimal-code guard are project preferences with loud defaults"
- DECISIONS.md -- "2026-11-07: Brownfield adoption is a reference-first distillation, never a pitch"
- DECISIONS.md -- "2026-11-11: Status line progress is one optional `progress` block in STATE.md, read by a plugin script (M021, issue #31)"
- DECISIONS.md -- "2026-11-15: Progress per phase counts slices of each roadmap; the denominator log lives outside the tree (issue #81)"
- DECISIONS.md -- "2026-11-13: `STATE.md` is a pointer with a size bound; history leaves it through `reconcile`, a closed milestone is folded into the spec (M022-S03)" (lint W8 and W9, the cut excerpt in the injection)
- DECISIONS.md -- "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)" (the closing line of the injection names `spec/SPEC.md`)
- DECISIONS.md -- "2026-11-14: The six gstack skills become ytstack's own adaptations, synced with upstream; no gstack install" (the library has no gstack functions)

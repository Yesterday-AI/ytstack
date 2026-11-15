# Upstream feedback

How an agent feeds what it learned about ytstack back to https://github.com/Yesterday-AI/ytstack/issues. One channel, one setting, rules a machine checks before anything is posted. Pointed at from `skills/using-ytstack/SKILL.md` ("Feeding ytstack upstream"); used at the end of `retro`, `lane-retro` and `lesson`. Source: issue #55.

## Why

Without a channel, what an agent learns about ytstack dies with the session. A coordinator builds its own PR babysitter because nothing pointed at the PR watch (#54); a day of incidents shows that a whole loop is missing (#53). Those reports exist only because a person told every session to write them. The setting carries that instruction forward.

## What goes upstream

Only what concerns ytstack itself: a skill, a hook, a script under `bin/`, an artifact format, a doc of the plugin. Never the project's own bugs.

| Kind (`--kind`) | What | Example |
|---|---|---|
| `bug` | A skill, hook or script did the wrong thing: the wrong skill fired, a hook errored, a script refused valid input, an artifact got mangled. | `ytstack-signals lesson new` refused a target that the format allows. |
| `gap` | A tool existed and was not used because nothing pointed at it, or a tool was missing and the agent built a workaround. | The coordinator polled pull requests by hand while `ytstack-pr-watch` was installed. |
| `proposal` | A change that came out of real runs: from `retro`, `lane-retro`, `review-lessons` or `lesson`, when the lesson concerns ytstack and not the project. | Three lanes repeated the same mistake that a check in `bin/ytstack-brief` would catch. |
| `evidence` | The first run of a tool against a real host, a real repository or a real session, where the README or a spec area says it has not run yet. | `bin/ytstack-finish-lane merge` against GitHub with a merge queue: what happened, with counts. |

## When

- **At the moment it happens.** A ytstack bug or a workaround is reported when it is found, not at the end of the day. Work on the person's task goes on; the report is one step.
- **At the end of `retro` and `lane-retro`.** Both end with an "Upstream" section: what of this milestone's or these lanes' experience concerns ytstack itself, handled per the setting.
- **In `lesson`.** A lesson whose class is a ytstack behaviour (a skill that misled, a script that let a mistake through) is recorded in the project as usual and also goes upstream.
- **In `review-lessons`.** A missed class that comes from a ytstack reviewer brief or format, not from the project's own role file, is a `proposal`.

## The setting

`upstream_feedback` in `.ytstack/PREFERENCES.md` (`upstream_feedback: file`). Without it, the last `upstream_feedback=` line of `~/.ytstack/config` (for all of a person's projects). Without both, `suggest`. A value outside the three reads as `suggest`.

| Value | What the agent does |
|---|---|
| `suggest` (default) | Drafts the issue, runs the check, and shows the person the title and the draft path with one line: "this concerns ytstack itself; file it at Yesterday-AI/ytstack?" It posts only after a yes. |
| `file` | Searches, drafts, checks, then posts (`gh issue create`) or comments on the issue it found (`gh issue comment`), and tells the person the link in one line. |
| `off` | Nothing goes upstream and nothing is suggested. A ytstack bug is still named to the person in the conversation. |

`file` is opt-in because it publishes text to a public repository under the person's GitHub account. `bin/ytstack-upstream mode` prints the effective value; for `file` it asks `gh auth status`, and without `gh` or a login it prints `mode: suggest` with a note. The agent follows the `mode:` line, not the file.

## The steps

```bash
ytstack-upstream mode                                   # mode: suggest | file | off
gh issue list --repo Yesterday-AI/ytstack --state all --search "<three to five words>" --limit 10
ytstack-upstream draft --kind gap --title "<what, in a few words>"   # prints path: and title:
# fill the draft with the Edit tool: every TODO line, the Searched: line
ytstack-upstream check --title "<title>" <path>         # draft ok, or one line per problem
gh issue create --repo Yesterday-AI/ytstack --title "<title>" --body-file <path>   # file mode, the checked title
gh issue comment <n> --repo Yesterday-AI/ytstack --body-file <path>               # a match was found
```

In a skill, the script is `${CLAUDE_SKILL_DIR}/../../bin/ytstack-upstream`; elsewhere `ytstack-upstream` is on the `PATH` of a session that loaded the plugin.

## The rules

1. **Search first, comment instead of duplicating.** One `gh issue list --search` with the words of the observation, open and closed issues. A match that describes the same behaviour gets a comment with the new evidence; a closed match whose fix did not hold gets a comment that says so, with the version. The `Searched:` line records the query and the result. `check` fails without it.
2. **One observation per issue, with evidence.** One behaviour, one issue. Evidence is what someone else can check: the ytstack version and host (the draft's footer), the commands with their output, counts ("7 pull requests, 41 `gh pr view` calls in one day"), not impressions. `check` fails on an empty "Evidence".
3. **No personal or customer data, no secrets.** No names or email addresses of people, no customer or product names of the project, no tokens, no internal hostnames, no home directory paths (they name a person). Private repository names only when the person allowed it in this conversation. `check` fails on a placeholder line of the draft left (a `TODO:` at the start of a line outside fenced code, or as the `Searched:` value; a `TODO:` quoted from elsewhere is evidence), on an email address (a bare `noreply@` excepted; a `<id>+<login>@users.noreply.github.com` address names the person; a `git@host:org/repo` remote or a `user@host:path` target is no address), a secret of a known shape (AWS key id and secret, GitHub, `sk-`, Slack, GitLab and npm tokens, a PEM private key) or a token-looking string (a commit SHA up to 40 hex digits is fine), and a home directory path (`/Users/<name>`, `/home/<name>`, `C:\Users\<name>`), in the body and in the `--title`; the title that is posted is the one that was checked. The rest is the agent's reading. When in doubt, describe the shape ("a private monorepo with 40 packages") instead of the name.
4. **Tell the person the link in one line.** After posting: "Filed Yesterday-AI/ytstack#61: <title>" or "Commented on #54". Under `suggest`: the title, the draft path, the question. Nothing longer.
5. **Without `gh` auth, `suggest`.** `mode` already says so. The draft is ready; the person files it or signs in.

## What stays out

- The project's own bugs and lessons: they go into its ledger, its `KNOWLEDGE.md` or its tracker.
- Work in the ytstack repository itself: its own `.ytstack/` artifacts are the place, and an issue is opened there as part of the work, not through this channel.
- Taste and wishes without a run behind them ("my agent might want X"): no evidence, no issue (`AGENTS.md`, "Speculative features").
- Anything from a dispatched worker on its own: a worker puts the observation into its report (`Not checked:` or a deviation), and the session that owns the person's conversation decides. A worker never posts.
- A second report of the same run: one observation is reported once, by the session that saw it.

## Checked mechanically

`bin/ytstack-upstream` (suite `tests/ytstack-upstream.test.sh`): the effective setting and the `gh` fallback (`mode`), the body with version, host and the parts to fill (`draft`, never posts), the rules a machine can see (`check`). The setting itself is read by `yt_upstream_feedback` in `hooks/lib/git-ctx.sh` (suite `tests/git-ctx.test.sh`). Whether an observation concerns ytstack, whether a search match is the same behaviour and whether a name is private stay the agent's judgement.

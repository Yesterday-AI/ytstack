---
area: hooks-and-state
status: implemented
paths:
  - hooks/**
  - bin/ytstack-status
sources:
  - docs/statusline.md
verified_at: 4d1ac7a
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
- `yt_pref` reads one key from `PREFERENCES.md` (`key: value` or `key=value`; quotes and a trailing comment are stripped). `yt_prefs` reads the ceremony dials and sets `YT_PREF_MERGE_BY` (default `risk`) and `YT_PREF_EVIDENCE_DIR` (default `.ytstack/evidence`). An invalid value is replaced by its default and reported in `YT_PREF_WARNINGS`; an invalid `merge_by` is replaced by `human`, so that a typo never merges without a person.
- `yt_epoch` turns an ISO time into seconds with BSD `date -j`, GNU `date -d`, or, for BusyBox, `date -d` on the form `YYYY-MM-DD HH:MM:SS`.
- `yt_brownfield_signals` counts up to six signs of an existing codebase and names which file would feed which artifact. The comment above the function lists the counted signals and the hint-only ones.
- `yt_commit_ref_pattern` renders a task's commit pattern from `commit_ref_pattern` in `PREFERENCES.md`, or from the default. `yt_task_commits` lists commits whose subject matches it. When none match, it falls back to the commits on the current branch after the merge-base with the default branch, and reports which source it used.
- `yt_find_artifacts` lists artifacts newest first from the flat layout and from the alternative layouts named in its comment. Reading tolerates those layouts. Writing stays flat.
- `yt_gstack_ctx` reports whether the gstack install and bun meet the pin and the minimum, both constants in the library.

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

W8 and W9 are prompts for `ytstack:reconcile`, which moves history out with consent. No skill stops on them.

`yt_progress_parse` is the only parser of the optional `progress` block in the `STATE.md` frontmatter. It reports `none`, `ok` or `bad`. The lint and `bin/ytstack-status` both call it, so they agree on what is malformed.

### Hooks

Every hook sources the library and resolves from the payload `cwd`. Every hook except `session-start` exits 0 silently when no `.ytstack` directory resolves.

| Hook | Event | Reads from the payload | Effect | Exit |
|---|---|---|---|---|
| `session-start` | SessionStart | `cwd` | prints the injection as JSON on stdout, writes nothing | 0 |
| `pre-compact` | PreCompact | `cwd`, `session_id`, `trigger` | writes `HANDOFF.auto.md` into the session state directory, renames a fresh `latest-handoff` symlink into the worktree state directory, prints compaction guidance on stdout | 0 |
| `session-end` | SessionEnd | `cwd`, `session_id`, `reason` | appends one JSON line to `session.jsonl` in the session state directory | 0 |
| `stop` | Stop | `cwd`, `stop_hook_active` | prints a `systemMessage` when the active task has no summary or only a draft | 0 |
| `pre-tool-use-edit` | PreToolUse on `Edit`, `Write`, `MultiEdit` | `cwd`, target path | prints a drift warning on stderr | 0 |
| `post-tool-use-bash` | PostToolUse on `Bash` | `cwd`, command, exit code | creates a draft task summary once | 0 |
| `task-created` | TaskCreated | `cwd`, subject, description | prints a scope warning on stderr | 2 on drift, else 0 |
| `task-completed` | TaskCompleted | `cwd`, subject | writes an auto summary, ticks the slice plan checkbox | 0 |
| `teammate-idle` | TeammateIdle | `cwd` | prints the open task count on stderr | 2 while tasks are open, else 0 |

- `pre-tool-use-edit` skips paths under `.ytstack/` and the artifact file names listed in the script. Scope drift means: the active task has a plan, and neither the checkout-relative path nor its basename occurs anywhere in that plan. Schema drift means: the target matches a model or schema pattern from the script and the plan names no migration path.
- `post-tool-use-bash` acts only when all of this holds: the call succeeded, the command contains a real `git commit` (after a command separator, optionally behind the wrapper tokens the script lists), `STATE.md` names an active slice and task, HEAD's subject matches the task's commit pattern, and no summary file exists. The stub carries `closed: draft`.
- `task-created` runs only with an active milestone. It extracts file-like paths from subject and description. Drift is a path that occurs in no slice plan of the current milestone and not in its roadmap.
- `task-completed` needs an `M###-S##-T##` id in the task subject. It never overwrites an existing summary.
- `teammate-idle` counts unchecked `T##` checkboxes across the slice plans of the current milestone.
- `stop` speaks only when milestone, slice and task are all set and the task's summary is missing or a draft. It stays silent when `stop_hook_active` is true.

### SessionStart injection

- Always: the full text of `skills/using-ytstack/SKILL.md` in an `<EXTREMELY_IMPORTANT>` envelope. If that file is missing, the hook prints nothing. If `YTSTACK_HOST_CONTEXT` is set, its text goes in front of the skill text.
- No `.ytstack`: a greenfield block that routes build intent to `office-hours`. With two or more brownfield signals it routes to `adopt-brownfield` and names the signals.
- `.ytstack` without `STATE.md`: a one-line repair notice.
- Otherwise a state block, in this order: scope, project, pointer, last update, working tree with the linked-worktree flag, `.ytstack` path, a Next action excerpt, the three newest summary names, a notice when more than one milestone roadmap is `in-progress`, the manual and the latest automatic handoff, a lifecycle hint for a finished slice or a finished milestone without retro, up to five STATE lint findings, the minimal-code line when `minimal_code` is on, and a closing line that names the files as the source of truth. When `spec/SPEC.md` exists, the closing line names it as the place for what applies now.
- Cap: the hook measures the injection without the host context. Above the guard threshold in the script, which sits just under the host's 10,000-character limit, it cuts the Next action excerpt to what still fits and marks the cut; when less than a useful rest would remain, it replaces the excerpt with a one-line note. If the text is still above the threshold, it warns on stderr and emits the text anyway. Nothing else is dropped.

### Status line segment

See `docs/statusline.md`. It was read against `bin/ytstack-status` at `verified_at` and matches.

## Interfaces and contracts

- `hooks/hooks.json` registers the nine hooks for Claude Code: event, matcher, timeout. The Codex registration is in the `host-adapters` area.
- The `YT_*` globals each function sets are named in the comment above that function. Consumers are every hook, the skill preambles and `bin/ytstack-status`.
- Files other parts read: `HANDOFF.auto.md` and `latest-handoff` (read by `hooks/session-start` and `skills/resume-session/SKILL.md`), draft and auto summaries (replaced by `summarize-task`, listed by `reconcile`).
- The `progress` block and the segment's exit codes: `docs/statusline.md`.

## Invariants and security boundaries

- No hook resolves its target from `CLAUDE_PROJECT_DIR`. `bin/ytstack-check` fails on that name in a hook script, on `[ -d .git ]` and on a basename slug.
- Volatile state (automatic handoff, journal) is written outside the tree. The only in-tree location is the `.ytstack/.local` fallback.
- No hook creates or changes `.ytstack/HANDOFF.md` or `STATE.md`.
- Two hooks write deliberate artifacts into the resolved `.ytstack`: `post-tool-use-bash` (the draft stub) and `task-completed` (auto summary, checkbox). Both write into the checkout the payload names, so a session that works in a linked worktree leaves the main checkout unchanged.
- `session-start`, `stop`, `pre-tool-use-edit`, `task-created` and `teammate-idle` write no files.
- Files under `sessions/<session-id>/` have one writer. There is no locking.
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
- `session-start` looks for `latest-handoff` only under the state base. An automatic handoff written to a fallback location is not announced.
- `yt_resolve_yt_dir` looks only at the toplevel. Outside Git, a subdirectory does not find its parent's `.ytstack`.
- `post-tool-use-bash` attributes a commit to the payload `cwd`, also when the command changed directory first.
- The scope check in `pre-tool-use-edit` is a substring match over the whole task plan, not over its Files section.
- `session.jsonl` has no reader in this repository.
- The key digest depends on the tool `yt_sha16` finds first, so keys can differ between machines.

## Where implemented

- `hooks/lib/git-ctx.sh` -- resolver, state directories, preferences, lint, progress parser, brownfield signals, commit discovery
- `hooks/hooks.json` -- registration
- `hooks/session-start`, `hooks/pre-compact`, `hooks/session-end`, `hooks/stop`, `hooks/pre-tool-use-edit`, `hooks/post-tool-use-bash`, `hooks/task-created`, `hooks/task-completed`, `hooks/teammate-idle`
- `bin/ytstack-status` -- status line segment
- `bin/ytstack-check` (`check_resolver_contract`) -- banned patterns
- Tests: `tests/git-ctx.test.sh`, `tests/hooks-json.test.sh`, `tests/hooks-readonly.test.sh`, `tests/hooks-stop.test.sh`, `tests/hooks-worktree.test.sh`, `tests/hooks-concurrency.test.sh`, `tests/post-tool-use-bash.test.sh`, `tests/pre-compact.test.sh`, `tests/session-end.test.sh`, `tests/ytstack-status.test.sh`

## How to verify

Run from the repository root. Each suite ends with a line `<n> passed, 0 failed` and exits 0.

```bash
bash tests/git-ctx.test.sh
bash tests/hooks-json.test.sh
bash tests/hooks-readonly.test.sh
bash tests/hooks-stop.test.sh
bash tests/hooks-worktree.test.sh
bash tests/hooks-concurrency.test.sh
bash tests/post-tool-use-bash.test.sh
bash tests/pre-compact.test.sh
bash tests/session-end.test.sh
bash tests/ytstack-status.test.sh
```

`tests/hooks-worktree.test.sh` is the acceptance for the write rule: it fires every hook for three session shapes and compares the checkouts before and after.

## Decisions that apply now

- DECISIONS.md -- "2026-11-13: Whether a person looks at a change is decided per change: a floor from the diff, the class an independent reviewer states, a ceiling per area, lenses per kind of change (M025)" (`merge_by` and `evidence_dir` in `yt_prefs`)
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree"
- DECISIONS.md -- "2026-05-31: post-tool-use-bash is stub-once; summarize-task owns commit-to-task linking (M015 / issue #22)". The 2026-11-07 entry above narrows it: the stub appears only in the committing checkout and only for a commit that carries the task ref.
- DECISIONS.md -- "2026-04-24: Add `using-ytstack` skill + SessionStart-hook-injected directive for agent-driven skill selection". Only the injection pattern is in force; "2026-04-24: Skill selection is semantic (description-based), not keyword-based" retired its trigger map.
- DECISIONS.md -- "2026-04-23: `.ytstack/` location is user-chosen (project vs user vs both)". The 2026-11-07 hooks entry narrows it: user scope is keyed by the repo key, not by a slug.
- DECISIONS.md -- "2026-11-07: Ceremony scales with the change -- granularity, autonomy, quick lane and minimal-code guard are project preferences with loud defaults"
- DECISIONS.md -- "2026-11-07: Brownfield adoption is a reference-first distillation, never a pitch"
- DECISIONS.md -- "2026-11-11: Status line progress is one optional `progress` block in STATE.md, read by a plugin script (M021, issue #31)"
- DECISIONS.md -- "2026-11-13: `STATE.md` is a pointer with a size bound; history leaves it through `reconcile`, a closed milestone is folded into the spec (M022-S03)" (lint W8 and W9, the cut excerpt in the injection)
- DECISIONS.md -- "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)" (the closing line of the injection names `spec/SPEC.md`)
- DECISIONS.md -- "2026-11-07: Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency" (for `yt_gstack_ctx` and its pin)

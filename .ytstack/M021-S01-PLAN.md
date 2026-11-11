---
milestone: M021
slice: S01
project: ytstack
created: 2026-11-11T10:25:52Z
status: planned
task_count: 2
completed_tasks: 0
---

# M021-S01 -- Slice Plan

**Goal:** `bin/ytstack-status` prints the progress segment for any directory, from one shared parser that the STATE lint also uses.

## Tasks

- [ ] T01 -- `yt_progress_parse` in `hooks/lib/git-ctx.sh` (reads STATE content on stdin; sets state none / ok / bad plus label, done, total, waiting_on) and lint finding W7 in `yt_state_lint` for a malformed block; cases in `tests/git-ctx.test.sh`.
- [ ] T02 -- `bin/ytstack-status`: cwd from the status line JSON (`workspace.current_dir`, `cwd`, else `$PWD`), plan progress from the default branch outside it, task pointer from the local `STATE.md`, slice checkbox fallback, `waiting_on` truncation, `NO_COLOR` / `--no-color`, silent non-zero exit outside a project or on a malformed block; new `tests/ytstack-status.test.sh`.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Claude Code documents no stable path to plugin files for a `statusLine` command: `bin/` is on PATH for the Bash tool only, and `CLAUDE_PLUGIN_ROOT` changes on every update (statusline and plugin manifest reference, read 2026-11-11).
- Considered and dropped: SessionStart maintaining a `~/.ytstack/bin/ytstack-status` link. The hook is read-only by contract and every suite that fires it would need an isolated HOME. The integration snippet in `docs/statusline.md` (S02-T02) resolves the newest installed version itself instead.

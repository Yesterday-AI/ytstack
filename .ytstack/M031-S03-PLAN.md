---
milestone: M031
slice: S03
project: ytstack
created: 2026-11-15T09:00:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M031-S03 -- Slice Plan

**Goal:** SessionStart and `bin/ytstack-upkeep` say, once per session and only when it applies, which factory tool is off, and a session learns when the installed plugin is newer than the one it loaded (issue #54 points 3 and 4, issue #61 "a session keeps the skill text it loaded").

## Tasks

- [x] T01 -- Factory-tool notices: `yt_factory_notices` in `hooks/lib/git-ctx.sh` (risk routing with `.ytstack/spec/` but no `REVIEW.md` or no area with `auto_merge: low|normal`; PR watch not enabled or without a fresh worker heartbeat on a GitHub origin; `RUNTIME.md` without "Release" or "Signals" while deploy or signal evidence exists), `ytstack-runtime sections`, the lines in the `session-start` injection on `startup` and `clear` only, a "factory tools" section in `bin/ytstack-upkeep` that is not counted. Tests: `tests/session-notices.test.sh`, `tests/ytstack-upkeep.test.sh`, `tests/ytstack-runtime.test.sh`.
- [x] T02 -- Version notice: `hooks/version-notice` on UserPromptSubmit records the plugin version a session first ran with (out of tree, per session) and says once per installed version "ytstack X installed, this session loaded A: reload the skills you use" with the CHANGELOG entry titles in between (bounded). Installed version from `installed_plugins.json`, else the newest non-orphaned sibling in the plugin cache. Tests: `tests/session-notices.test.sh`, `tests/hooks-json.test.sh`.
- [x] T03 -- Docs and spec: `hooks-and-state` and `checks-and-evals` areas, `docs/ux/runtime-format.md`, `docs/recipes/recurring-upkeep.md`, `docs/pr-watch.md`, DECISIONS entry (SessionStart stays read-only, the prompt hook owns the version record).

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- No GitHub call in a hook: the PR watch notice reads `~/.ytstack/config`, the origin URL and the worker's heartbeat from its local state (`sqlite3 -readonly`, else the mtime of `worker.lock`).
- `STATE.md`, `ROADMAP.md`, `M031-ROADMAP.md` and `CHANGELOG.md` stay with the coordinating session.

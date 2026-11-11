---
milestone: M021
slice: S02
project: ytstack
created: 2026-11-11T10:25:52Z
status: done
task_count: 3
completed_tasks: 3
---

# M021-S02 -- Slice Plan

**Goal:** The block stays current without hand upkeep and a user can wire the segment into their status line from the documentation.

## Tasks

- [x] T01 -- `summarize-task` and `quick-task` update the `progress` block when they advance STATE and re-run the lint; skill versions bumped; `bin/ytstack-check` clean.
- [x] T02 -- `docs/statusline.md` (block reference, output forms, two-line integration for Claude Code, other hosts, colour switch); pointers in README, `docs/concept.md` and `docs/codex.md`; CHANGELOG `[Unreleased]` entry.
- [x] T03 -- Verification and close: `bash tests/run-all.sh`, `bash tests/run-all.sh --linux`, `bin/ytstack-check`, live run against this repository and a linked worktree; M021 roadmap, global ROADMAP, DECISIONS and STATE closed.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Push, release tag and issue closing are operator actions (standing instruction).

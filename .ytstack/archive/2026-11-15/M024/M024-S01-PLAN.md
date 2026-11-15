---
milestone: M024
slice: S01
project: ytstack
created: 2026-11-13T16:40:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M024-S01 -- Slice Plan

**Goal:** Who works on what and what may start next are on disk.

**Blocked by:** none

## Tasks

- [x] T01 -- The formats in `docs/ux/coordinator-format.md`: `LANES.md`, blocking edges and the frontier, lane kinds, the report, `questions/`, `STANDING.md`, what is checked mechanically; the DECISIONS entry.
- [x] T02 -- `bin/ytstack-frontier` (`list`, `claim`, `set`, `release`, `check`) with its suite; `**Blocked by:**` in the slice plan and task plan templates; `spawn-milestone-team` claims before it dispatches and dispatches again when the frontier changes.
- [x] T03 -- Lane kinds in `bin/ytstack-brief render --kind`; the report gains `Status:`, `Uncommitted:` and `Next:` and the checker validates them; the adapter, the implementer and the verifier follow.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

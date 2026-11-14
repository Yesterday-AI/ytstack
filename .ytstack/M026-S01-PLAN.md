---
milestone: M026
slice: S01
project: ytstack
created: 2026-11-13T18:09:00Z
status: done
task_count: 2
completed_tasks: 2
---

# M026-S01 -- Slice Plan

**Goal:** After a merge somebody watches whether the target serves the commit and stays healthy, and it is not the person.

**Blocked by:** none

## Tasks

- [x] T01 -- `bin/ytstack-watch release --commit <sha>`: reads "Release" through `bin/ytstack-runtime get`, waits for the commit, asks `healthy` for the settle time, prints one receipt; with its suite.
- [x] T02 -- `finish-lane` runs the watch after a merge and puts the receipt into its report; `coordinate` names it.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

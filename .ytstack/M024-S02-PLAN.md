---
milestone: M024
slice: S02
project: ytstack
created: 2026-11-13T16:40:00Z
status: done
task_count: 2
completed_tasks: 2
---

# M024-S02 -- Slice Plan

**Goal:** A reported lane becomes a merged pull request through gates read from the host.

**Blocked by:** S01

## Tasks

- [x] T01 -- `bin/ytstack-finish-lane` (`leftovers`, `commit`, `push`, `open-pr`, `wait-head`, `body-check`, `gates`, `merge`) with a suite on a fake `gh` and a local bare remote.
- [x] T02 -- The skill `finish-lane`: the order of the steps, the pre-review checklist, the delta brief, the reviewed head and round in the lane's row, `merge_by` as the project's decision who merges.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Gates

- [ ] G01 -- The pipeline works against a real pull request host | decides: the operator | how: the first lane of a consumer project finished with it, receipt in that project | lapses: never

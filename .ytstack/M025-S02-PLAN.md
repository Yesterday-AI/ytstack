---
milestone: M025
slice: S02
project: ytstack
created: 2026-11-13T18:09:00Z
status: planned
task_count: 5
completed_tasks: 0
---

# M025-S02 -- Slice Plan

**Goal:** The class of a change, the ceiling of its areas and the records of its review decide the route.

**Blocked by:** none

## Tasks

- [ ] T01 -- `auto_merge` in the area frontmatter and `REVIEW.md` beside the area files: `docs/ux/spec-format.md`, `bin/ytstack-spec lint`, its suite.
- [ ] T02 -- `bin/ytstack-risk floor` and `check` with the suite: rule documents, invariant sections, checks, uncovered paths, never-low patterns, size.
- [ ] T03 -- `bin/ytstack-risk route`: round lines with risk, invariants and reviewer, validity for a head, ceilings.
- [ ] T04 -- `merge_by: risk` as the default in `yt_prefs`; `finish-lane` and `bin/ytstack-finish-lane` apply the route; `coordinate` and `spawn-milestone-team` name it.
- [ ] T05 -- `code-review` and the review step of `finish-lane`: the four labels, the reading against invariants and decisions, the extended round line.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

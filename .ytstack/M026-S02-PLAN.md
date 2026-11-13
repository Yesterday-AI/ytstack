---
milestone: M026
slice: S02
project: ytstack
created: 2026-11-13T18:09:00Z
status: in-progress
task_count: 3
completed_tasks: 2
---

# M026-S02 -- Slice Plan

**Goal:** The upkeep of `.ytstack/` can run without a person starting it and leaves one report.

**Blocked by:** none

## Tasks

- [x] T01 -- `bin/ytstack-upkeep`: one run over spec drift, the STATE lint, open and lapsed gates, questions never asked and lanes without movement; one report, exit 0 when nothing needs a look; with its suite.
- [x] T02 -- `docs/recipes/recurring-upkeep.md`: how to schedule the run on each supported host, and what it may leave behind.
- [ ] T03 -- README, CHANGELOG, the area files, DECISIONS; close M026.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

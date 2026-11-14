---
milestone: M031
slice: S05
project: ytstack
created: 2026-11-15T09:00:00Z
status: in-progress
task_count: 3
completed_tasks: 1
---

# M031-S05 -- Slice Plan

**Goal:** `reconcile` (and `adopt-brownfield` on such a repo) detects a large plan outside `.ytstack/` and offers to map its open rows into milestones and slices, so `ytstack-frontier` sees it. The external plan is never edited.

**Blocked by:** none

## Tasks

- [x] T01 -- `bin/ytstack-plans`: `scan` finds plan directories (`plans/`, `plan/`, `planning/`, `roadmap/` and the same under `docs/`), counts work rows (task-list items and rows of tables with a status or checkbox column) as open, done or dropped, applies the thresholds and reads a recorded answer from `PREFERENCES.md`; `rows` prints one line per work row with `path:line`, state, id, section and title. `tests/ytstack-plans.test.sh` first.
- [ ] T02 -- The question and the mapping: `docs/ux/external-plans.md` (thresholds, mapping rules, pointer format, answer record); `reconcile` gets the class "External plan" (preamble line, one AskUserQuestion, the mapping after a yes); `adopt-brownfield` asks the same question after its artifacts exist. Preamble suite covers the new line.
- [ ] T03 -- Docs and checks: spec areas (`artifacts`, `checks-and-evals`), README tools list, the eval case `evals/external-plan/` with its README row, a `DECISIONS.md` entry for "script detects, agent maps".

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Source: issue #54 point 5. Real example (read only, never written): `meinkontext/plans/`, 80 files, tables `| Done | ID | Deliverable | Gate | Can start | State |` with `[x]`/`[ ]` and task lists of several hundred items; frontier saw nothing and lanes were tracked by hand.
- The slice does not touch `hooks/lib/git-ctx.sh` (S03 works in the hooks); the detection lives in its own script that both skills call.

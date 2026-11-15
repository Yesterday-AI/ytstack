---
milestone: M022
slice: S02
project: ytstack
created: 2026-11-13T15:10:00Z
status: done
task_count: 6
completed_tasks: 6
---

# M022-S02 -- Slice Plan

**Goal:** The loop keeps the spec true.

## Tasks

- [x] T01 -- `plan-task` determines the "Spec impact" of a task (area and section, or `none` with a reason) and writes it into the plan; `quick-task` carries the rule in one paragraph.
- [x] T02 -- `summarize-task` runs `ytstack-spec impact` in its preamble and does not close a task whose named area was not updated; the summary gets a `## Spec` section.
- [x] T03 -- `code-review` and the verifier read the area files that cover the changed paths against the change, and nothing beyond them; a reversed decision moves in the area's "Decisions that apply now".
- [x] T04 -- `reassess-roadmap` answers the drift report once per area at the slice boundary; `resume-session`, `handoff-session` and the closing sentence of the SessionStart injection point at `spec/SPEC.md`.
- [x] T05 -- Eval graders for the new plan section and the closure record; README, QUICKSTART, CHANGELOG and `evals/README.md`; ytstack's own area files updated for what this milestone changed.
- [x] T06 -- Verification of S01 and S02 against the exit criteria and close on paper.

## Done when

All tasks marked `[x]` and verified.

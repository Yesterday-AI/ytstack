---
milestone: M030
slice: S03
project: ytstack
created: 2026-11-14T15:30:00Z
status: planned
task_count: 4
completed_tasks: 0
---

# M030-S03 -- Slice Plan

**Goal:** The `review-lessons` skill turns recurring or severe escapes into role-file proposals, runs after merges, and `retro` reports escape rates.

## Tasks

- [ ] T01 -- Skill `review-lessons`: runs `bin/ytstack-review-escapes` for a merged PR (or a range of merged PRs), assigns each escape its owning role (by the role files' checklists) and a class slug, records it with `bin/ytstack-signals` (`kind: review`). Threshold: second sighting of a class, or the first at critical/high (threshold fixed from the S01 measurement).
- [ ] T02 -- Proposal at the threshold: the exact checklist or rule line, the role file and section it goes to, the escaped threads as evidence; written as a question under `.ytstack/questions/` for a person. The skill never edits the role file; after approval the change goes through the normal task loop and `bin/ytstack-signals set <F> --state planned --ref <task>`.
- [ ] T03 -- Trigger after every merge, whoever merges: most merges are done by a person after `ship` or `finish-lane` stopped, so no skill is running at that moment. The intake therefore keys on the host's merged state, not on a skill step: `bin/ytstack-upkeep` lists merged PRs since the last intake that have no escape check yet (a marker in the signals ledger per PR), and with the PR watch on, a merge it observes queues a notice to the owning session to run `review-lessons`. `finish-lane` calls it directly when it merges itself. `retro` adds escapes per role (caught vs escaped bot findings) for the milestone window.
- [ ] T04 -- Docs and close: QUICKSTART section, README, CHANGELOG; verification; a pilot run on a real project's merged PRs, recorded in the summary.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

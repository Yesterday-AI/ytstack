---
milestone: M031
slice: S05
task: T02
project: ytstack
closed: 2026-11-15T10:20:00Z
verification: passed
---

# M031-S05-T02 -- Summary

## Commits

- The commit that carries this file (`M031-S05-T02: reconcile and adopt-brownfield offer to map a large external plan`).

## Outcome

`docs/ux/external-plans.md` fixes what counts as an external plan, the two thresholds and why, how the answer is recorded (`external_plans: <dir> mapped|declined <date>` in `PREFERENCES.md`), the question's three options and its recommendation rule, and the mapping: one milestone per plan file with open rows (per section above 12 slices), one slice per open board row or per section, at most 7 tasks, `status: planned`, done rows only counted, `**Blocked by:**` only for a dependency on another mapped open row, and a pointer back on every slice (`**Source:** path:line (row id, read date)`) and every task line. The plan is read only.

`reconcile` 0.3.0 prints `EXTERNAL_PLAN_OFFER` and the `scan` lines in its preamble, asks the class "External plan" last, and its Step 4 allows the new milestone files, `ROADMAP.md` rows and one `PREFERENCES.md` line. `adopt-brownfield` 0.3.0 prints the same lines and asks the same question in a new Step 6b, after the artifacts exist; its backlog question skips a directory that 6b covers, the Adoption table and the report get a row.

## Deviations from plan

- The recommendation is conditional (A up to five plan files with open rows, B above). The real example has 23 plan files and 1467 open rows, most of them unticked checklists under finished packages; recommending "map all" there would flood the frontier.
- The re-ask footer of `adopt-brownfield` points at `reconcile`, because `adopt-brownfield` stops on an initialized project.
- `reconcile`'s preamble now prints `BRANCH` and `PROJECT_SLUG`, which the Re-ground of the new question needs.

## Follow-ups

- The mapping is prose the agent follows. Its quality on a real plan (board plus checklists) is graded only by the eval case of T03, which has not run.

## Spec

- artifacts: updated in T03 (`reconcile` writes for the external plan class)

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh` -- exit 0, `549 passed, 0 failed` (541 before; 8 new: per skill no plan -> `EXTERNAL_PLAN_OFFER: no`, ten open rows -> `yes` and the dir line, a recorded answer -> `no`). `python3 bin/ytstack-check` -- exit 2, no `[fail]`; the only warning on this branch's files is the spec drift note for `checks-and-evals` (closed in T03).

By hand, once: a fixture plan (`/tmp/s05map/plans/v2.md`, a board with 1 done and 11 open rows, AV-03 depending on AV-02, AV-02 on the done AV-01) mapped by the document's rules into `M001` with 11 slices; `ytstack-frontier list --milestone M001` printed S01 ready, S02 `blocked S01`, S03-S11 ready; without `--milestone` the frontier picked M001 (STATE names none); `ytstack-plans scan` then reported `answer=mapped` and exited 1.

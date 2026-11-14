---
milestone: M025
slice: S03
task: T04
project: ytstack
closed: 2026-11-13T19:28:38Z
verification: passed
---

# M025-S03-T04 -- Summary

## Commits

- The commit that carries this file (`M025-S03-T04: code-review and finish-lane dispatch the required lenses and record them`).

## Outcome

`code-review` got the paragraph "Lenses": for every name after `lenses:` of the floor it renders the lens brief, dispatches one separate fresh reviewer (`<lens>-<task>`), checks the report and records one lens line under `## Review`. `finish-lane` got the step "Dispatch the required lenses" between the recorded round and the route, with the same four moves for a lane (`<lens>-<lane>`), a table for the three verdicts, and the lens verdicts in its report and in the line about an unattended merge. Both say that `fail` goes back like a blocking finding, that `not run` is recorded as it is and never rewritten, that a lens whose brief the script refuses is `not run` without a reviewer, and that the session hands a visual lens no screenshots. `coordinate` and `spawn-milestone-team` say that a lens reviewer is a lane of kind `review`.

`bin/ytstack-finish-lane leftovers` and `commit` left the evidence directory out: `evidence_dir` of `PREFERENCES.md`, default `.ytstack/evidence`. Before, an untracked evidence directory in the lane's worktree was listed as out of scope and `commit` refused. The suite pins that, and that `route` gives `unattended` for a visual lens only when the images lie in the main checkout: from a linked worktree it did not read the same images under the worktree.

## Deviations from plan

- The lenses run for every lane whose change requires them, also when the floor is `person` or `merge_by` is `human`: the person who merges reads the lens verdict. A lens whose line `route` still accepts is not run again.
- A lens is no round. A lens that fails again after a fix goes to the human with the diagnosis of a third round.
- The steps of `finish-lane` are renumbered: 8 lenses, 9 route, 10 gates, 11 merge or hand over, 12 report.

## Follow-ups

- The evidence directory is left out of `commit` also in a project that wants it committed. It lies in the main checkout, not in the lane's worktree; a project that commits it does so with its own step.
- `docs/ux/coordinator-format.md` ("Lane kinds") says that a `review` lane reads only. A lens with visual evidence writes its evidence directory. The sentence is in the report for the coordinator.
- Nothing mechanical keeps a session from writing `pass` into a lens line whose reviewer said `not run`. For a visual lens the manifest check of `route` catches it; for `evidence: none` only the hard gate of the skill does.

## Spec

- skills: area file updated by the coordinator in the closing task
- checks-and-evals: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-finish-lane.test.sh && /bin/bash tests/skill-preambles.test.sh` -- passed at the working tree on top of `6f914e4` in the local checkout (macOS, bash 3.2). Last lines `171 passed, 0 failed` and `497 passed, 0 failed`, exit 0. `python3 bin/ytstack-check` exited 2 with no failure and 32 warnings; `python3 -m unittest discover -s tests -p 'codex*_test.py'` was OK.

Not checked: a session that dispatched a lens reviewer from `code-review` or `finish-lane` and recorded its line. The Linux containers ran once for the whole branch, see the report.

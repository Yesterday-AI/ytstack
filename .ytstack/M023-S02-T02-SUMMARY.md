---
milestone: M023
slice: S02
task: T02
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S02-T02 -- Summary

## Commits

- The commit that carries this file (`M023-S02-T02: reassess-roadmap puts open gates to the human in one question`).

## Outcome

The `reassess-roadmap` preamble listed the open gates of the milestone's plans, the tasks with three or more review rounds, and the three slice numbers. Step 3b sorted the gates, put those that need a verdict or have lapsed into one AskUserQuestion together with work that repeats without advancing, and recorded only the answers, as `given:` or `lapsed:` on the gate line. The status line gained "Closed by work W/T, accepted A/T; waiting on: ..." for the case that the two numbers differ, and the closing report names both numbers and the gates by id. The description names gates and work that repeats without advancing among the things the skill checks. `tests/skill-preambles.test.sh` got a `reassess-roadmap)` case with eleven assertions on a fixture with one open, one given and one lapsed gate and three review rounds.

## Deviations from plan

- A defect in the old preamble was found while the eval fixture was written, and fixed here. `_REMAINING` counted every open checkbox of the slice plan, so an open gate made a finished slice look incomplete. And `grep -c ... || echo 0` produced two zeros on two lines when nothing matched, which broke the integer test. The preamble now counts open task lines only and has no `|| echo 0`.

## Follow-ups

- `hooks/teammate-idle:34` has the same `grep -c ... || echo 0` pattern. Not fixed: the file is outside this milestone's scope.
- The two progress numbers are reported in prose and in the STATE status line. The `progress` block of `STATE.md` still has one `done` / `total` pair (decision of 2026-11-11). Whether it gets a second number is open.
- Gates are carried as lines in the plans. Decision queue files, and with them rotation, polling outside the model, the frontier and claims, stay with coordinator mode (issue #34) and are not part of this milestone.

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", Slice boundary). Uncommitted at the time of the check.
artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("States and closure": the `given:` and `lapsed:` forms of a gate line). Uncommitted at the time of the check.

`tests/skill-preambles.test.sh` is in `checks-and-evals`; that area file says nothing about the new case, and no statement there became false.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout. Last line `395 passed, 0 failed`, exit 0. 23 lines start with `reassess-roadmap:`, all `ok`; eleven of them come from the new case.

Not checked: the suite covers the preamble only. Step 3b (sorting the gates, the one question, recording the answers) is prose; what an agent does with it is shown only by the eval case `gates-one-question` in the run that S03-T03 records. The non-interactive branch ("Waiting on a person", `waiting_on`) has no test and no eval case. `tests/run-all.sh --linux` was not run.

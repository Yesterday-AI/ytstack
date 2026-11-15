---
milestone: M023
slice: S02
task: T01
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M023-S02-T01: plan-task records runs and environment, gates in task and slice plans`).

## Outcome

`plan-task` Step 6 asked for runs, environment and, where it applies, a sample with its reason, and remembered them next to the command. The plan template got the line `Runs: {RUNS}. Environment: {ENVIRONMENT}.` and an optional `## Gates` section. The paragraph "Not a verification step: a gate" defined the gate line with its fields `decides`, `how` and `lapses`, told the skill to write `unknown` for a field nobody stated, and said that a gate does not hold the task open. `slice-milestone` got `## Gates` in the slice-plan template and the paragraph "Done by work, accepted by a gate", which keeps "Done when" to what work can establish and sends everything else to a gate line.

## Deviations from plan

none

## Follow-ups

none

## Spec

artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("States and closure": the `Runs:` line, `## Gates`). Uncommitted at the time of the check.
skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", Plan). Uncommitted at the time of the check.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout. The suite printed `395 passed, 0 failed`. The checker printed `OK (with 27 warning[s])`, no `[fail]` line, exit 2.

Not checked: this task changed skill text and templates, no preamble. The suite shows that both skills still parse and resolve; it does not show that an agent writes the `Runs:` line or a gate. No eval case has `plan-task` or `slice-milestone` write one: the fixtures of `bounded-evidence` and `gates-one-question` bring their plans with them. `tests/run-all.sh --linux` was not run.

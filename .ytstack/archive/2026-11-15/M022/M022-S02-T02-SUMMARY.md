---
milestone: M022
slice: S02
task: T02
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S02-T02 -- Summary

## Commits

- The commit that carries this file (`M022-S02-T02: closure check in summarize-task`).

## Outcome

The `summarize-task` preamble ran `bin/ytstack-spec impact` on the plan and the task's commit pattern and printed `HAS_SPEC`, `SPEC_IMPACT_EXIT` and the tool's lines. Step 8 "Check the spec impact" read that result: exit 0 continued with the printed lines as the spec record, exit 1 stopped the closure before the summary was written, exit 3 (a plan without the section) had the impact decided at closure, and `not-run` was handled for a project without a spec and for a host where the script is not reachable. The summary template got `## Spec` between "Follow-ups" and "Verification", the report got a `Spec:` line, and the terminal states got "Abort on an unmet spec impact". The later steps moved up by one (write the summary is Step 9, report is Step 13).

The commit and environment wording of the Verification line and the line `Not checked:` in the same template belong to M023.

## Deviations from plan

None.

## Follow-ups

None.

## Spec

artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("States and closure"), Where implemented
skills: `.ytstack/spec/skills.md` -- Behavior ("The technical spec in the loop")

`bin/ytstack-spec impact` saw both files as uncommitted changes when this summary was written. They are new on this branch and are committed with S01-T04.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout: `395 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: Step 8 is prose. One model run exercised the `none` path (eval run of M023-S03-T03: `summarize-task` passed with the `spec-record` grader); no case exercises the refusal on an unmet impact. The preamble's `SPEC_IMPACT_EXIT` values `not-run`, `3`, `1` and `0` are asserted in `tests/skill-preambles.test.sh` ("technical spec"), added with the M023 commits. No live session on Codex.

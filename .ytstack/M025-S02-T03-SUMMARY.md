---
milestone: M025
slice: S02
task: T03
project: ytstack
closed: 2026-11-13T18:34:04Z
verification: passed
---

# M025-S02-T03 -- Summary

## Commits

- The commit that carries this file (`M025-S02-T03: bin/ytstack-risk route`).
- `M025-S02-T03: by: self counts as the author in route`: a session that reviewed its own change writes `by: self`; as first built, that line passed whenever `--author` named somebody else.

## Outcome

`bin/ytstack-risk route --plan <plan file> --base <sha> --head <sha> [--author <worker>]` printed `route: unattended` with exit 0 only when the floor was not `person`, the newest round line approved, stated `risk` and `invariants: none`, named a reviewer other than `--author` and was valid for the head, and the class was within the ceiling. Every other case printed `route: person` with one `reason:` line per failed condition and exited 10.

A round line without the three new fields failed with one reason that names what is missing. A round stayed valid when only process records changed after it and lost its validity with the first other path. `tests/ytstack-risk.test.sh` pins each failing condition on its own.

## Deviations from plan

- "Valid for a head" is narrower than the format said and wider than the brief said. The format: no file the record covered changed. That lets a file added after the review merge unreviewed. The brief: no changed path of the change differs between the record's head and the head. That fails as soon as the plan with the round line is committed. The rule built: nothing but process records changed since the record's head. The format document says so now.
- `route` also prints `floor:` and `areas:`. `finish-lane` owes the person one line on what merged unattended and why.
- `class:` has two values beside the three classes: `person` when the floor is, `unstated` when the newest round line states no risk.
- A never-low reason is not printed by `route`: it raised the floor and failed no condition.
- `blocking: <n>` is not read. An approving line with open blocking findings is a contradiction for the reviewer, not a condition of the format.

## Follow-ups

- The round line is text in a plan file. Whoever can edit the plan can write an approving line; the script checks that the line is consistent with the commit, not who typed it. A signed record would be a new mechanism.
- `route` does not check that the round's own base is the base of the change.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-risk.test.sh` -- passed at the working tree on top of `871d6bb` in the local checkout (macOS, bash 3.2). Last line `119 passed, 0 failed`, exit 0.

Not checked: a round line written by the `code-review` skill of a real session; that skill writes the old form until M025-S02-T05. The Linux containers ran once for the whole branch, see the report.

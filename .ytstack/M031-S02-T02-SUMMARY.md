---
milestone: M031
slice: S02
task: T02
project: ytstack
closed: 2026-11-15T00:08:00Z
verification: passed
---

# M031-S02-T02 -- Summary

## Commits

- The commit that carries this file (`M031-S02-T02: pass the pull request to the route in ytstack-finish-lane`).

## Outcome

`bin/ytstack-finish-lane route` took `--pr N`. With it the first line named the pull request (`...; plan: <path | none>; pr: #N`), `ytstack-risk route` got `--pr N` and `--plan` only when the lane had a plan file, and a lane without a plan file was routed from the reviews on the host instead of ending `person` with "no plan file". The reviews are read from the main checkout, where `gh` resolves the repository from its remote. Without `--pr` the call read no host and printed what it printed before.

The suite's stand-in `gh` answered the reviews endpoint from a fixture; the field case (no plan, the round on the review of the head) routed `unattended`, a host review by the lane's worker and an empty host without a plan routed `person`, and a plan line counted when no review carried one.

## Deviations from plan

None.

## Follow-ups

None.

## Spec

- checks-and-evals: updated in T03 of this slice

## Verification

Command: `/bin/bash tests/ytstack-finish-lane.test.sh` -- exit 0, last line `183 passed, 0 failed`, local checkout (macOS, bash 3.2.57). Before the implementation the new cases failed with 11 failures (`route: unknown argument '--pr'`).

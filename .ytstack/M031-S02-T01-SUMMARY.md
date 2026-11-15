---
milestone: M031
slice: S02
task: T01
project: ytstack
closed: 2026-11-14T23:58:00Z
verification: passed
---

# M031-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M031-S02-T01: read the review round from the host in ytstack-risk route`).

## Outcome

`bin/ytstack-risk route` took `--pr N` and `--repo OWNER/NAME`. With `--pr` it read the reviews of the pull request once through `gh api --paginate` and took the lines `- Round N:` and `- Lens <name>:` from the bodies of reviews that were submitted, not dismissed and by an owner, member or collaborator. The newest host line counted; the plan counted only when no review carried a line of that kind, and `--plan` became optional with `--pr`. A host line had to name the commit the host tied the review to, and validity for the head was computed from that commit. A review in the state `CHANGES_REQUESTED`, a line naming another commit and a failed read each routed to a person with one reason. With `--pr` the output gained `round: host review <id> by <login> on <sha> | plan | none`.

The field case of issue #54 (context-mcp #1715) was reproduced red first: no plan line in the checkout, the round only on the host review of the head. It routes `unattended` now.

`docs/ux/review-policy-format.md` gained "Records on the host" and the new form of `route`.

## Deviations from plan

- `usage` of `bin/ytstack-risk` printed a sed error instead of the commands (a missing space between the sed script and the file). Fixed, with a test, since the task changed the usage lines.

## Follow-ups

- The reviewer's GitHub login is printed, not compared with `--author`: agents usually share one GitHub account, so the login cannot tell the worker from the reviewer. `by:` still does.

## Spec

- checks-and-evals: updated in T03 of this slice

## Verification

Command: `/bin/bash tests/ytstack-risk.test.sh` -- exit 0, last line `197 passed, 0 failed`, local checkout (macOS, bash 3.2.57). Before the implementation the new section failed with 22 failures (`ytstack-risk: unknown argument --pr`).

`/bin/bash tests/ytstack-finish-lane.test.sh` -- exit 0, `171 passed, 0 failed` (unchanged route without `--pr`).

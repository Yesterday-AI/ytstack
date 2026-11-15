---
milestone: M025
slice: S02
task: T04
project: ytstack
closed: 2026-11-13T19:14:45Z
verification: passed
---

# M025-S02-T04 -- Summary

## Commits

- `5e494d0` -- `M025-S02-T04: merge_by risk as the default in yt_prefs, evidence_dir (preference half)`
- The commit that carries this file (`M025-S02-T04: finish-lane reads the route and merges by it (skill half)`).

## Outcome

Preference half (`5e494d0`): `yt_prefs` set `YT_PREF_MERGE_BY` with the default `risk` and read a value outside `human`, `coordinator` and `risk` as `human`; it set `YT_PREF_EVIDENCE_DIR`.

Skill half: `bin/ytstack-finish-lane route --lane <ref> --base <sha> --head <sha>` printed one line of what it read (the lane, the worker of its `LANES.md` row as the author, the plan) and then the lines of `bin/ytstack-risk route`, with that script's exit code. A reviewer who is the lane's worker, a lane without a row and a lane without a plan gave `route: person`. It read no host. `gates` and `merge` are unchanged.

`finish-lane` read `merge_by` through `yt_prefs`, got the step "Read the route" after the recorded review and decided in "Merge or hand over" from a table: `risk` with `unattended` merges at the reviewed commit and the report says so in one line; `risk` with `person` and `human` stop with the merge command and the reasons; `coordinator` merges and prints the route. A standing instruction that reserves the merge wins. `coordinate` named the route in its Steps 6 and 11, `spawn-milestone-team` said that its local merge is not the risk gate.

The eval case `evals/risk-route/` was written: a lane whose commit skips the filter on archived rows when `since` is given, in an area with `auto_merge: low` whose invariant forbids that.

## Deviations from plan

- **`finish-lane` on a host other than GitHub goes further than before.** It stopped after the leftovers. It now also commissions the review at the local head, records the round line and reads the route, and stops then. The review and the route need only git, and the eval case has no host: without this no round line could be written there. Nothing is pushed or merged on such a host, as before.
- `route` takes `-C` as the checkout of the coordinating session, not as the lane's worktree like the other commands: `LANES.md` and the plan with the review records live there. The skill calls it without `-C`.
- `route` passes `-C <main checkout>` to `bin/ytstack-risk`, so that a relative evidence directory is read from the main checkout of the repository also when the session works in a linked worktree.
- `merge` does not read the route. Who may call it is decided in the skill from `merge_by`, as before.
- `tests/skill-preambles.test.sh` gained three assertions for the preamble of `finish-lane` (the default, a value outside the three).

## Follow-ups

- Under `merge_by: risk` nothing mechanical keeps a session from calling `merge` after a `route: person`. The hard gate of the skill forbids it. A `merge --route` that runs the route itself would close that.
- `route` needs the lane's commits in the repository of the checkout it runs in. A worker in a clone of its own has to be fetched first; without that the exit code is 65, which counts as "not unattended".
- The evidence directory of a visual review lands in the main checkout also when the coordinating session works in a linked worktree.

## Spec

- skills: area file updated by the coordinator in the closing task
- hooks-and-state: area file updated by the coordinator in the closing task
- checks-and-evals: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-finish-lane.test.sh && /bin/bash tests/skill-preambles.test.sh` -- passed at the working tree on top of `1538802` in the local checkout (macOS, bash 3.2). Last lines `160 passed, 0 failed` and `476 passed, 0 failed`, exit 0. `/bin/bash tests/git-ctx.test.sh` passed for the preference half at `5e494d0` (the report of that half). `python3 bin/ytstack-check` exited 2 with no failure and 32 warnings.

The fixture of `evals/risk-route/` was built once in a temporary directory: `bin/ytstack-risk floor` printed `floor: low`, `ceiling: low` for the lane's commit; the lane's tests passed; `route` printed `unattended` for a round line with `risk: low; invariants: none` and `person` for one with `risk: high` and the invariant.

Not checked: the eval case itself was not run (the coordinator runs the evals). No session took a real lane through the route to a merge without a person; the gate G01 of M024 is still open for the same reason. The Linux containers ran once for the whole branch, see the report.

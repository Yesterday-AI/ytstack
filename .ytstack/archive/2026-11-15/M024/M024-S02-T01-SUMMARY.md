---
milestone: M024
slice: S02
task: T01
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M024-S02-T01: bin/ytstack-finish-lane takes a lane from the report to a merge at the reviewed commit`).

## Outcome

`bin/ytstack-finish-lane` was built with eight commands, one step per call: `leftovers`, `commit`, `push`, `open-pr`, `wait-head`, `body-check`, `gates`, `merge`. In the suite a stale host head failed `wait-head` with both commits, a head that moved after the review failed the `head` gate, a body that named a removed test was flagged by `body-check`, and `merge` ran only when the gates held and passed the reviewed commit to the host. `tests/ytstack-finish-lane.test.sh` pins each command on a stand-in for `gh` and a local bare remote.

A dispatched agent wrote the script and the suite. The lead read both and added one exception: `.env.example`, `.env.sample` and `.env.template` are not junk, with a case in the suite.

## Deviations from plan

- The review gate fails when any reviewer's newest review on the head requests changes, not only the newest review overall. With `--verdict-pattern` the newest review on the head must also match the pattern.
- A check that concluded with success, neutral or skipped counts as passed. No check at all fails the gate unless `--allow-no-checks` is given.
- `merge` reads the state back after `gh` accepted the merge. When the host does not report the pull request as merged (a merge queue), it says "not merged yet" and exits 1.
- The comment at the top of the script still lists `.env*` as junk without the exception for the three template names.

## Follow-ups

- The script marks two shortcuts. Two runs of one check on the same commit are both counted, so an older failed run keeps the gate closed. Only the first 100 review threads are read; more than that fails the gate.
- Gate G01 of the slice stays open: the pipeline has not run against a real pull request host. The JSON shapes of `gh`, its built-in `--jq` and a merge queue are untested (`checks-and-evals.md`, "Known limits").
- Not built: hosts other than GitHub. On another host the pipeline stops after the commit step.

## Spec

- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("The coordinator scripts"), Known limits, Where implemented

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/ytstack-finish-lane.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). Last line `142 passed, 0 failed`, exit 0.

Not checked: nothing ran against GitHub. Every `gh` call in the suite is answered by a stand-in from fixture files, so a real `gh pr view`, a real review, a real thread and a real merge were never read or made. Linux: the lead ran all 20 suites in the container (alpine, bash 5.3.9, BusyBox awk), `ALL SUITES PASSED`; this suite was not run there on its own for this record.

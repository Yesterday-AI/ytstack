---
milestone: M025
slice: S02
task: T01
project: ytstack
closed: 2026-11-13T18:18:58Z
verification: passed
---

# M025-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M025-S02-T01: auto_merge in the area frontmatter, REVIEW.md beside the area files`).

## Outcome

`docs/ux/spec-format.md` named the optional frontmatter field `auto_merge: none | low | normal` and got a section on `REVIEW.md`: beside the area files, optional, linked from `SPEC.md`, not an area file. `bin/ytstack-spec lint` failed on an `auto_merge` outside the three values and on a `REVIEW.md` that `SPEC.md` does not link. `REVIEW.md` no longer counted as an area file, so `lint` asked it for no frontmatter and no fixed sections, and `drift`, `impact` and `areas` did not read it.

## Deviations from plan

- The slice plan and the brief put the call from `lint` into `bin/ytstack-risk check` into this task. It lands with M025-S02-T02, where the command exists; this commit would otherwise call a script that is not there.
- `lint` also fails when `REVIEW.md` exists and `SPEC.md` does not link it. The format says "linked from `SPEC.md`"; an area file that is not listed fails the same way.

## Follow-ups

- none

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-spec.test.sh` -- passed at the working tree on top of `8cb7db4` in the local checkout (macOS, bash 3.2). Last line `66 passed, 0 failed`, exit 0.

Not checked: a project with a real `REVIEW.md` run through `lint`. The Linux containers ran once for the whole branch, see the report.

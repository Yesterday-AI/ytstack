---
milestone: M032
slice: S03
task: T01
project: ytstack
closed: 2026-11-15T02:45:00Z
verification: passed
---

# M032-S03-T01 -- Summary

## Commits

- The commit that carries this file (`M032-S03-T01: lesson lanes in the frontier and the brief`).

## Outcome

`bin/ytstack-frontier list` listed one lane `lesson-F###` after the slices for every open or planned lesson whose target is a check, with its key as detail, its state from the lanes table and from questions that name it, blocked as "unplanned" while the lesson lacks `## Files` or `## Verification`, done with "the lesson is not set fixed yet" once merged, and gone once the lesson is fixed. Without a milestone the lesson lanes alone were listed; with neither, `list` still failed with "no milestone". `bin/ytstack-brief render --lesson F###` rendered the lane's brief from the lesson (outcome from title, target and "Assessment"; scope and verification from its sections; ref and commit prefix `lesson-F###`), also as a review brief; it refused an unknown id, a finding of another kind and a lesson without `## Files`. `docs/ux/coordinator-format.md` got the section "Lesson lanes", `docs/ux/signal-format.md` the lane paragraph and its example, `finish-lane` Step 6 the `--lesson` note, the `checks-and-evals` area file both bullets.

## Deviations from plan

- In `tests/ytstack-brief.test.sh` the lesson section uses its own repository variable (`LR`), because the following "failures" section reuses `R` from the slice section.

## Follow-ups

- none

## Spec

- checks-and-evals: the frontier and brief bullets

## Verification

Command: `bash tests/ytstack-frontier.test.sh && bash tests/ytstack-brief.test.sh` -- `140 passed, 0 failed` and `206 passed, 0 failed`, at the working tree on top of `9638425` in the local checkout (macOS, bash 3.2).

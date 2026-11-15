---
milestone: M032
slice: S03
task: T02
project: ytstack
closed: 2026-11-15T02:55:00Z
verification: passed
---

# M032-S03-T02 -- Summary

## Commits

- The commit that carries this file (`M032-S03-T02: open lessons in coordinate's status and repeats per class in retro`).

## Outcome

`coordinate` printed `LESSONS: <n> open (<p> proposals, <c> checks to build)` and the open lessons; Step 11 names them in every status with the classes that repeat; Step 8 "Lesson proposals" asks the oldest open lesson proposal once a UTC day as the question of that turn (after a question that blocks a lane, or alone at the next status on a day without questions); Step 5 "Lesson lanes" claims a lesson lane with `set --state planned --ref lesson-F###`, renders it with `--lesson F###` and writes a missing `## Files`/`## Verification` into the lesson; "After a merge" sets the lesson `fixed`. `retro` (1.2.0) printed `LESSONS` and `SIGNALS_TOOL`, and with lessons step 8 lists per area and class the incidents in the window, all time, the repeat flag (count 2 or more, or a reopened lesson), where the lesson lives and its state, with the "at least 5" note for the five kept sightings, the candidates for "3 Things to Improve" and the snapshot key `lessons`.

## Deviations from plan

- `coordinate` stays at 0.5.0 (bumped in S02 for the same release).

## Follow-ups

- The window count reads only the five sightings a lesson keeps; a class with more than five incidents in one window is reported as "at least 5".

## Spec

- skills: the `coordinate` and `retro` sentences

## Verification

Command: `bash tests/skill-preambles.test.sh && bin/ytstack-check` -- `641 passed, 0 failed`; the checker `OK (with 9 warning[s])`, no `[fail]`; at the working tree on top of `8ba1758` in the local checkout (macOS, bash 3.2).

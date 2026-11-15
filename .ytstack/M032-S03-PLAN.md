---
milestone: M032
slice: S03
project: ytstack
created: 2026-11-15T02:30:00Z
status: done
task_count: 2
completed_tasks: 2
---

# M032-S03 -- Slice Plan

**Goal:** Open lessons are visible and get done: lesson lanes go through the frontier and the brief like slices, `coordinate` shows the open lessons in its status and asks a lesson proposal with the daily question, and `retro` reports incidents and repeats per class for its window.

**Blocked by:** S01, S02

## Tasks

- [x] T01 -- Lesson lanes: `bin/ytstack-frontier list` lists `lesson-F###` for every open or planned lesson whose target is a check (blocked without `## Files`/`## Verification` in the lesson, also without a milestone); `bin/ytstack-brief render --lesson F###` renders its brief. Tests in `tests/ytstack-frontier.test.sh` and `tests/ytstack-brief.test.sh`; `docs/ux/coordinator-format.md` ("Lesson lanes"), `docs/ux/signal-format.md`, `finish-lane`'s brief note, the `checks-and-evals` area file.
- [x] T02 -- `coordinate` prints `LESSONS: <n> open (<p> proposals, <c> checks to build)` and the list, names them in every status, asks the oldest lesson proposal with the daily question, dispatches lesson lanes (`set --state planned --ref lesson-F###` at the claim, `fixed` after the merge); `retro` (1.2.0) reports incidents and repeats per class for the window and adds `lessons` to the snapshot. Tests in `tests/skill-preambles.test.sh`; the `skills` area file.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- `coordinate` was bumped to 0.5.0 in S02 already; this slice ships in the same release and does not bump it again.

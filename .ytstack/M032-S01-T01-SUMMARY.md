---
milestone: M032
slice: S01
task: T01
project: ytstack
closed: 2026-11-15T01:20:00Z
verification: passed
---

# M032-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M032-S01-T01: lesson records and the incident lesson check in ytstack-signals`).

## Outcome

`bin/ytstack-signals` recorded lessons as findings of `kind: lesson`: `lesson new` took the area, the class slug, the title, the target and optionally the incident, wrote the key `lesson:<area>:<class>` with the area as source and a `target:` line, counted a repeat of the class as `seen-again` and a repeat after `fixed` as a `regression`, and with `--incident` wrote the lesson id into the record's `lesson:` line (new in the skeleton as `lesson: none`). `lesson list` printed id, state, area, class, count, the sightings since `--since`, target, ref, reopens and title. `set` took `--target` (lessons only, also without `--state`) and refused `fixed` while the target was a proposal or a missing file. A target in `AGENTS.md` or `CLAUDE.md` was refused with exit 64. `check` failed on a lesson with a key, source or target outside the form, on such a target in `AGENTS.md`/`CLAUDE.md`, on a fixed lesson whose target was a proposal or did not exist, on a closed incident whose `lesson` was `none` or missing, and on a `lesson` id that named no lesson.

## Deviations from plan

- The implementation was written before the test cases in one sitting; the red run was taken afterwards against the script of `9520ff4` (copied into `bin/` under another name so that it found its library): 43 of the 294 cases failed there.
- Two existing test expectations moved: the skeleton has the `lesson: none` line, so a mitigation line sits one line lower (line 24, not 23); the closed records of the incident section now need a recorded lesson to pass.

## Follow-ups

- none

## Spec

- checks-and-evals, artifacts: written in T02

## Verification

Command: `bash tests/ytstack-signals.test.sh` -- exit 0, last line `294 passed, 0 failed`, at the working tree on top of `d8ad935` in the local checkout (macOS, bash 3.2). Against the script of `9520ff4`: `251 passed, 43 failed`.

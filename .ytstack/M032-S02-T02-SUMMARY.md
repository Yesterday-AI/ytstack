---
milestone: M032
slice: S02
task: T02
project: ytstack
closed: 2026-11-15T02:20:00Z
verification: passed
---

# M032-S02-T02 -- Summary

## Commits

- The commit that carries this file (`M032-S02-T02: incident, systematic-debugging, finish-lane and coordinate end with the lesson step`).

## Outcome

The four paths invoked `ytstack:lesson`. `incident` (0.2.0) got Step 10 "Record the lesson" once the person said it holds, with the record's id for `--incident`, area `production` and no code from the session; closing the record needs `lesson:`. The `systematic-debugging` wrapper (0.2.0, vendored text untouched) invoked it once the cause was known, with the regression test as the usual check and the old `KNOWLEDGE.md` routing moved into the skill. `finish-lane` (0.5.0) got Step 14 "Lesson", run before a lane goes back for `changes requested`, a failed lens or a failed check (pending checks and host gates excluded); Steps 7, 8 and 10 point at it and the report has a `lessons:` line. `coordinate` (0.5.0) got the Step 7 row "Lesson" for a red `main` and every slip, and the paragraph "A red `main`" (read which check and since when, dispatch the repair, record the lesson before the next dispatch). Every Terminal State allows `ytstack:lesson`. `tests/skill-preambles.test.sh` checks the invocation, the Terminal State (or the wrapper's notes), `--incident` in the incident step, finish-lane's Step 14 and the red `main` in coordinate's Step 7.

## Deviations from plan

- `coordinate` reads a red `main` with `gh run list --branch <base> --limit 5` or a PR watch notice: `ytstack-watch` watches pull requests only, so no ytstack tool reads the base branch's checks yet.

## Follow-ups

- A watch of the base branch's checks (a red `main` as a notice of the PR watch) does not exist; the coordinator reads it with `gh` after a merge and before a status.

## Spec

- skills: the no-chaining exceptions and the `coordinate`, `finish-lane` and `incident` sentences

## Verification

Command: `bash tests/skill-preambles.test.sh && bin/ytstack-check` -- `633 passed, 0 failed` (the eleven new cases of "the lesson step in its callers" cannot pass on `ab2e596`: `git grep 'ytstack:lesson' ab2e596 -- skills/incident skills/systematic-debugging skills/finish-lane skills/coordinate` finds nothing); the checker `OK (with 9 warning[s])`, no `[fail]`; at the working tree on top of `ab2e596` in the local checkout (macOS, bash 3.2).

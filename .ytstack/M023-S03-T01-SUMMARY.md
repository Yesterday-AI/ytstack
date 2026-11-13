---
milestone: M023
slice: S03
task: T01
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S03-T01 -- Summary

## Commits

- The commit that carries this file (`M023-S03-T01: code-review counts rounds and ends at the third`).

## Outcome

The `code-review` preamble printed `REVIEW_ROUND` and `LAST_REVIEWED_HEAD` from the `## Review` lines of the task plan. The new section "Bounded review (ytstack)" set what each round reviews and what the reviewer may report, listed six points the reviewer is told in addition to the vendored template (assumed load, concrete case and "If skipped" per finding, rating of scale findings, `shortcut:` comments, no new acceptance conditions, the closing "Not checked"), gave the project's severity policy the last word on what blocks, and defined the line that records a round. For a third round it told the skill to dispatch no reviewer, write no further fix, and put a diagnosis of scope, conflicting rules or solution to the human in one question. The section wins over the vendored text where the two differ; nothing under `vendor/` changed.

## Deviations from plan

none

## Follow-ups

- No eval case covers the reviewer's "Assumed load" line; it is text only. The case `review-round-three` covers the third round.

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", Review). Uncommitted at the time of the check.
artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("States and closure": `## Review`). Uncommitted at the time of the check.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout. The suite printed `395 passed, 0 failed`. The checker printed `OK (with 27 warning[s])`, no `[fail]` line, exit 2.

Not checked: `REVIEW_ROUND` and `LAST_REVIEWED_HEAD` are asserted for a first review and for one recorded round (`tests/skill-preambles.test.sh`, "technical spec"); the third round is covered by the eval case only. The rules for the reviewer and for rounds 1 and 2 are prose; what an agent does with them, and with the third round, is shown only by the eval run that S03-T03 records. No reviewer was dispatched for this task. `tests/run-all.sh --linux` was not run.

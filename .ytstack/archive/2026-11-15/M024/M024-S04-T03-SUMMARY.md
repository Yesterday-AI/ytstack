---
milestone: M024
slice: S04
task: T03
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S04-T03 -- Summary

## Commits

- The commit that carries this file (`M024-S04-T03: flake disposition in systematic-debugging, Suggested skills in the handoff`).

## Outcome

`skills/systematic-debugging/SKILL.md` gained the paragraph "A test that fails only sometimes.": raise the reproduction rate, run the test on the base commit, track a flake of the base as a follow-up, treat a failure that comes only with the change as a defect of the change. `skills/handoff-session/SKILL.md` gained the rule "Suggested skills." and the section of that name in the `HANDOFF.md` template.

These are the two smaller proposals of issue #34.

## Deviations from plan

- The vendored debugging text is not edited. The paragraph stands in the wrapper's invocation notes and says that it applies where the two differ.
- `resume-session` reads the new handoff section. That one-line change is committed with M024-S01-T03.

## Follow-ups

- The area files say nothing about either item. `skills.md` and `artifacts.md` were searched for "Suggested skills", "flake" and "fails only sometimes" without a hit. The plan therefore states `none` with what was found. If the flake rule or the handoff section is meant to be part of what applies now, a sentence in `skills.md` is missing.

## Spec

none -- no statement of an area file changed. `skills.md` does not describe the paragraphs a wrapper adds, and `artifacts.md` leaves each file's section template to the skill that creates it.

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for M024 are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: both items are skill text outside a preamble, so no suite case observes them. The eval case `handoff-session` has no grader for the new section. No session has debugged a flaky test with the paragraph.

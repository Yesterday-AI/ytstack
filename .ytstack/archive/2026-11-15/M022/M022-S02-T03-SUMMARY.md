---
milestone: M022
slice: S02
task: T03
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S02-T03 -- Summary

## Commits

- The commit that carries this file (`M022-S02-T03: bounded spec check in code-review and the verifier`).

## Outcome

The `code-review` preamble printed `SPEC_EXISTS` and listed, between `SPEC_AREAS_BEGIN` and `SPEC_AREAS_END`, the area files that cover the task's changed files. The paragraph "Spec check, bounded to the touched area" told the reviewer to read those files and the plan's `## Spec impact` against the diff, named the two findings (a described behaviour changed while the plan says `none`; an area file or its source contradicted by the diff) and kept the rest of the spec out of the review. The additions after the review said that a reversed decision is listed under "Decisions that apply now" of the area it concerns, in place of the old entry. `agents/verifier.md` got step 6 "Check the spec claim, for the touched area only"; the verdict became step 7.

The section "Bounded review" and the round counter in `skills/code-review/SKILL.md` and the evidence paragraphs in `agents/verifier.md` belong to M023.

## Deviations from plan

None.

## Follow-ups

- The preamble splits the changed paths on whitespace, so a path with a space finds no area. The line is marked `shortcut:` in `skills/code-review/SKILL.md`.

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The technical spec in the loop"; the verifier row under "Agents and parallel dispatch")

`bin/ytstack-spec impact` saw the file as an uncommitted change when this summary was written. It is new on this branch and is committed with S01-T04. `skills.md` has no line of its own for the reversed decision; that rule is stated in `docs/ux/spec-format.md` ("Decisions") and in `SPEC.md` ("Keeping this true").

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout: `395 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: the `code-review` eval case passed in the run of M023-S03-T03, but it grades that a reviewer was dispatched, not what it read. The verifier agent was not run on a task with a spec impact. `SPEC_EXISTS` and the `SPEC_AREAS` line are asserted in `tests/skill-preambles.test.sh` ("technical spec"), added with the M023 commits. No live session on Codex.

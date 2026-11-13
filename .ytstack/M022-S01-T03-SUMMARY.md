---
milestone: M022
slice: S01
task: T03
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S01-T03 -- Summary

## Commits

- The commit that carries this file (`M022-S01-T03: spec scaffolds in init-project and adopt-brownfield`).

## Outcome

`init-project` got Step 7 (propose the areas from the pitch, one question, write `spec/SPEC.md` and one area file per area, all `status: planned` with `verified_at: none`) and Step 8 (`ytstack-spec lint`, findings fixed in the direction of the truth). `adopt-brownfield` got Step 7 (areas from the architecture map and the docs index, one question, the code read per area, status and `verified_at` only from that read, pointer-only where a document exists) and the same Step 8. Its preamble prints `HAS_SPEC`, and Step 2 runs a spec-only procedure for a project that has `.ytstack/` and no spec. Both templates carry the "Keeping this true" block verbatim. The eval cases `init-project` and `adopt-brownfield` each got a grader `spec.md` that requires `.ytstack/spec/SPEC.md`.

The skill text was written by a dispatched agent. The lead read its output against the code before closing the task.

## Deviations from plan

- The agent's report found that an initialized project could get no spec from either skill: `init-project` stops when `.ytstack/` exists, and `adopt-brownfield` did the same. The lead added the spec-only run to `adopt-brownfield` Step 2. It writes `spec/` and the codebase map files that are missing and touches no other artifact.
- The limits in the two eval prompts were raised: `init-project` from 40 to 60 turns and from 600 to 900 seconds, `adopt-brownfield` from 60 to 90 turns and from 900 to 1200 seconds.

## Follow-ups

None.

## Spec

none -- not covered by an area yet: the spec did not exist before S01-T04; T04 writes the area files with these changes included

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout: `395 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: the new steps are prose. One model run per case exercised them (eval run of M023-S03-T03: `init-project` and `adopt-brownfield` passed with the `spec` grader); the suite asserts `HAS_SPEC` for `adopt-brownfield` since that run was prepared (`tests/skill-preambles.test.sh`, "technical spec"). The two new graders require that `spec/SPEC.md` exists; that every area is `planned` (`init-project`) or pointer-only (`adopt-brownfield`) is not graded. The spec-only run was not tried on a real initialized project. No live session on Codex.

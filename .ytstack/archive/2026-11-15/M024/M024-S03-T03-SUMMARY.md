---
milestone: M024
slice: S03
task: T03
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S03-T03 -- Summary

## Commits

- The commit that carries this file (`M024-S03-T03: reassess-roadmap carries gates as question files`).

## Outcome

Step 3b of `skills/reassess-roadmap/SKILL.md` gained the paragraph "The question queue.". In a project with `.ytstack/questions/` the skill writes one question file per gate that needs a verdict, lists a gate whose file is already `asked` as waiting since that time, marks each question it puts with `ytstack-questions ask`, and after the human's answer fills `## Answer`, runs `ytstack-questions answer` and changes the gate line. A project without the directory keeps the behaviour of M023: the gate lines alone carry the state.

## Deviations from plan

- The decision queue of issue #34 is `.ytstack/questions/`, one file per question. The gate lines of M023 stay; a question file points at its gate through `blocks:` (`M024-CONTEXT.md`, decision of 13 November 2026).
- The change is one paragraph of prose. The preamble of `reassess-roadmap` does not read `questions/`, so no suite case belongs to this task.

## Follow-ups

- No model has followed the paragraph. The eval case `gates-one-question` has no `questions/` directory in its fixture, so it exercises the path without question files.
- The preamble prints the open gates and not the question files. That a gate is already `asked` is found by the model reading `questions/`, not by a preamble line.

## Spec

- skills: `.ytstack/spec/skills.md` -- Behavior ("Coordinating many lanes", the `reassess-roadmap` line)
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers", the `questions/Q###-<slug>.md` row)

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: the behaviour the task line names. That a gate becomes a question file and that an asked one is not asked again is skill text; no suite and no eval case observes it.

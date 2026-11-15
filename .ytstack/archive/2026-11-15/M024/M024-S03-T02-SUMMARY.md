---
milestone: M024
slice: S03
task: T02
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed
---

# M024-S03-T02 -- Summary

## Commits

- The commit that carries this file (`M024-S03-T02: bin/ytstack-questions keeps the queue of questions for the human`).

## Outcome

`bin/ytstack-questions` was built with six commands. `new` wrote a question file with the next id, a slug, the frontmatter and the four empty sections. `list` printed the open and asked questions, or one state with `--state`. `next` returned the oldest open question. `ask` marked a question as asked with its time and refused a second time. `answer` marked it as answered and refused a file without text under `## Answer`; the placeholder line of the format is not an answer. `check` named each defect of a file. `tests/ytstack-questions.test.sh` pins all six on fixture directories.

## Deviations from plan

- `answer` accepts a question in state `open` as well as `asked`: a question can be answered without having been put. `check` lets an answered file keep whatever `asked` value it had.
- `next` orders by the `opened` time. Files with the same time come in id order, so the lower id wins.

## Follow-ups

- The script does not search the plan, `DECISIONS.md` or the answered questions before `new`. That lookup is a rule for the skill that calls it (`coordinate` Step 8, `docs/ux/coordinator-format.md`), not a check.
- `bin/ytstack-frontier list` reads the `blocks:` line of open and asked questions (M024-S01-T02). The two scripts share the file format and no code.

## Spec

- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("The coordinator scripts"), Where implemented
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers")

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/ytstack-questions.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). Last line `69 passed, 0 failed`, exit 0.

Not checked: a session that queued a question, asked it once and recorded the answer. Linux: the lead ran all 20 suites in the container (alpine, bash 5.3.9, BusyBox awk), `ALL SUITES PASSED`; this suite was not run there on its own for this record.

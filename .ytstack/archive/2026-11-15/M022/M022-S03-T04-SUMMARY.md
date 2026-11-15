---
milestone: M022
slice: S03
task: T04
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M022-S03-T04 -- Summary

## Commits

- The commit that carries this file (`M022-S03-T04: fresh-session eval cases, comparison run, close M022`).

## Outcome

Three eval cases were added on one fixture, a project whose history says archived rows are exported and whose present says they are not: `fresh-resume` (3 graders), `fresh-bugfix` (4 graders), `fresh-requirement` (3 graders). A dispatched agent wrote them. `evals/README.md` lists them. `DECISIONS.md` gained the entry on `STATE.md` as a pointer. M022 is closed on paper: `M022-ROADMAP.md` is `done` with three of three slices, and `M022-CONTEXT.md` carries the reassessment of 13 November 2026.

The lead ran both arms, real model sessions, once per case:

| Case | Current instructions | Revised instructions | Turns, current / revised |
|---|---|---|---|
| `fresh-resume` | passed | passed | 7 / 12 |
| `fresh-bugfix` | passed | passed | 11 / 9 |
| `fresh-requirement` | passed | passed | 12 / 9 |

The current arm cost $1.16. The record is in `KNOWLEDGE.md` under "Eval runs".

## Deviations from plan

- The cases do not separate the arms. On a project this small the model opens `.ytstack/spec/` by itself, so both arms answered correctly. The cases guard the behaviour and show no gain; a gain would need a project whose history is too large to read.
- The task line asks for three measures. Accuracy is the pass column. Reading effort is recorded as turns and cost. "Contradictions met" has no number of its own: each case passes only when the reply follows the present against the contradicting history, and that is all the record says about it.
- The slice was planned to wait for M020 and was built before it on the operator's instruction.
- `evals/README.md` has a fourth new row, `coordinator-resume`. That row and its case belong to M024-S04-T04.

## Follow-ups

- ytstack's own `STATE.md` (about 30 KB, 13 earlier status paragraphs) is not trimmed. The lint reports W8 and W9 until the operator answers `ytstack:reconcile`.
- In the run of all 21 cases on the final tree one case missed: `summarize-task` (skill fired, no summary written). It passed in an earlier run and in two reruns. The cause was not found because the trace was not kept; `KNOWLEDGE.md` says to run with `--keep-temp` when a case fails once.
- `hooks-and-state.md` describes W8, W9 and the cut excerpt, and its "Decisions that apply now" does not list the entry of 2026-11-13 on `STATE.md` as a pointer. `artifacts.md` and `skills.md` list it.

## Spec

- checks-and-evals: `evals/README.md` (a source of `.ytstack/spec/checks-and-evals.md`) -- the three rows
- artifacts: `.ytstack/spec/artifacts.md` -- Decisions that apply now
- skills: `.ytstack/spec/skills.md` -- Decisions that apply now

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `bash tests/run-all.sh; python3 bin/ytstack-check; python3 -m unittest discover -s tests -p 'codex*_test.py'; claude plugin validate .; bash bin/ytstack-spec lint` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). 20 suites, `ALL SUITES PASSED` (`gstack-live` skips without `GSTACK_HOME`); the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line; `Ran 13 tests`, `OK`; `Validation passed`; `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`.

Eval run (by the lead, not repeated for this record): the three cases passed with the current instructions (3 of 3, $1.16) and with the revised ones (3 of 3). The final tree ran all 21 cases: 20 of 21, $7.97.

Linux (by the lead): all 20 suites from an export of the tree in the container (alpine, bash 5.3.9, BusyBox awk), `ALL SUITES PASSED`.

Not checked: a second run per case, so the turn counts are single observations and not a measurement. A project large enough for the spec to save reading. The cause of the one `summarize-task` miss.

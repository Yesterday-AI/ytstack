---
milestone: M024
slice: S04
task: T04
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S04-T04 -- Summary

## Commits

- The commit that carries this file (`M024-S04-T04: eval case coordinator-resume, docs, area files, close M022-S03 and M024`).

## Outcome

The eval case `coordinator-resume` was added and passed on the final tree with 6 of 6 graders. README, QUICKSTART, CHANGELOG, `docs/concept.md` and `NOTICE` were brought in line, the six area files state coordinator mode and `STATE.md` as a pointer, the four new skills run in `tests/skill-preambles.test.sh`, and the global roadmap rows of M022 and M024 are `done`. M022-S03 and M024 are closed on paper on the branch `spec-and-bounded-work`: every task has a plan and a summary.

Exit criteria of M024 against evidence:

| Criterion | Evidence |
|---|---|
| The frontier lists exactly the ready lanes; a held lane is refused with its holder | `tests/ytstack-frontier.test.sh`, 128 cases |
| A session after a compaction lists every lane with its next action from `.ytstack/` alone | `coordinator-resume`: 6 of 6 graders, one run, a fixture without a host |
| A status carries the read time of a host fact; nothing about a pull request is stored as current | `bin/ytstack-watch --once` and the `gates` line `read <UTC>` in the suites; `skills/coordinate/SKILL.md` Steps 4 and 11 and `skills/finish-lane/SKILL.md` (text; no case) |
| The report has `Status:`, `Uncommitted:` and `Next:`; a missing field or an inconsistent status is rejected | `tests/ytstack-brief.test.sh`, 128 cases |
| A stale head starts no review, a moved head blocks the merge, a removed test in the body is flagged, the merge is at the reviewed commit, the human merges by default | `tests/ytstack-finish-lane.test.sh`, 142 cases on a stand-in for `gh`; `merge_by` in `skills/finish-lane/SKILL.md` (text; no case) |
| A human-only step is one staged script that the agent checks and never runs | `tests/ytstack-handover.test.sh`, 79 cases; the rule "never runs" is the HARD-GATE of `skills/handover-step/SKILL.md` (text; no case) |
| No question is asked twice; states open, asked, answered | `tests/ytstack-questions.test.sh`, 69 cases; the lookup before asking is skill text |
| A lane retro lists candidates by category; an accepted one is a check or a pointer | `skills/lane-retro/SKILL.md` (text; no case) |
| Suites pass on macOS and Linux, the checker reports no failure, `vendor/` untouched | 20 suites `ALL SUITES PASSED` on macOS bash 3.2 and in the Linux container; checker exit 2 with 27 warnings; `git status --short vendor/` empty |

## Deviations from plan

- Nothing of M024 ran against a real pull request host or in a real multi-lane run. The suites use a stand-in for `gh`. No model has followed `coordinate`, `finish-lane`, `handover-step` or `lane-retro` end to end; only `coordinator-resume` exercised `coordinate` (or `resume-session`, which the grader also accepts) on a fixture.
- Gate G01 of M024-S02 ("The pipeline works against a real pull request host") stays open for that reason. The slice is closed by work and not accepted; only the operator closes the gate.
- The eval run of the final tree was 20 of 21 ($7.97). The miss was `summarize-task`: the skill fired and no summary was written. The same case passed in an earlier run and in two reruns. Its cause was not found because the trace was not kept.
- Nothing on this branch was committed before the whole change had been shown to the operator (repository rule). The closure check of every task of M022-S03 and M024 therefore saw the area files as uncommitted changes; their statements are in this task's commit.
- The lanes table is its own file `LANES.md`, not a table inside `STATE.md` as issue #34 proposed.

## Follow-ups

- Operator: review and merge the branch, release, `/plugin update`. Run `/ytstack:reconcile` in this repository to move the history out of `STATE.md` (about 30 KB, 13 earlier status paragraphs); the lint reports W8 and W9 until then.
- The first consumer project that coordinates with M024 is its test, and the first lane finished there closes G01.
- Not built: a hook or host event at subagent start that checks a claim; hosts other than GitHub for the pipeline and the watcher; a second number in the `progress` block of `STATE.md` (accepted beside done).
- `dependencies.md` ("Methodology and attribution") names "a concept credit" in the singular. `NOTICE` now carries two: ponytail and mattpocock/skills. The area file was not changed by this task.
- `hooks-and-state.md` and `host-adapters.md` state behaviour of M022-S03, M023 and M024 and do not list the matching entries of 2026-11-13 under "Decisions that apply now".
- `skills.md` and `artifacts.md` say nothing about the flake paragraph of `systematic-debugging` or the "Suggested skills" section of the handoff (M024-S04-T03).

## Spec

- skills: `.ytstack/spec/skills.md` -- Behavior ("Skill classes", "Coordinating many lanes"), Decisions that apply now
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers", "STATE.md is a pointer; host facts are not stored", "Ownership and cleanup"), Decisions that apply now
- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("`bin/ytstack-brief`", "The coordinator scripts"), Known limits, Where implemented, Decisions that apply now; `evals/README.md` (a source of the area)
- hooks-and-state: `.ytstack/spec/hooks-and-state.md` -- Behavior ("STATE lint and progress block", "SessionStart injection")
- host-adapters: `.ytstack/spec/host-adapters.md` -- Behavior ("Codex")

The area files were uncommitted when the closure check ran. Their statements for M022-S03 and for every task of M024 are committed with this task.

## Verification

Command: `bash tests/run-all.sh; python3 bin/ytstack-check; python3 -m unittest discover -s tests -p 'codex*_test.py'; claude plugin validate .; bash bin/ytstack-spec lint` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). 20 suites, `ALL SUITES PASSED` (`gstack-live` skips without `GSTACK_HOME`); the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line; `Ran 13 tests`, `OK`; `Validation passed`; `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`.

Eval run (by the lead, not repeated for this record): all 21 cases on the final tree, real model sessions, once per case: 20 of 21, $7.97. `coordinator-resume` passed with 6 of 6 graders.

Linux (by the lead): all 20 suites from an export of the tree in the container (alpine, bash 5.3.9, BusyBox awk), `ALL SUITES PASSED`.

Not checked: a real pull request host; a real multi-lane run; a live session on Codex; a dispatch with a rendered brief; the interrupt path of a handover script; the cause of the one `summarize-task` miss.

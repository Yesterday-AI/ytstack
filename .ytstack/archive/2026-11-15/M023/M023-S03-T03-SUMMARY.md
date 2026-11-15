---
milestone: M023
slice: S03
task: T03
project: ytstack
closed: 2026-11-13T16:10:00Z
verification: passed_with_caveats
---

# M023-S03-T03 -- Summary

## Commits

- The commit that carries this file (`M023-S03-T03: eval cases, comparison run, docs, close M023`).

## Outcome

Three eval cases were added and both arms were run. `bounded-evidence` gives a task whose plan asks for one run of a 44-scenario script that counts its own runs. `gates-one-question` gives a finished slice with two open gates, one that needs the product owner and one whose condition had already passed. `review-round-three` gives a task with two recorded review rounds and fixes that flip one comparison. README, QUICKSTART, CHANGELOG, `docs/concept.md`, DECISIONS, ROADMAP, the three affected area files and STATE were brought in line. M023 is closed on the branch `spec-and-bounded-work`.

Exit criteria against evidence:

| Criterion | Evidence |
|---|---|
| One pass of 44 stays at 44 | `bounded-evidence`: run counter `1` in both arms |
| Non-blocking finding holds nothing; a risk a person accepts is a gate | `skills/code-review/SKILL.md` "Whose severity counts" (text; no case) |
| Fix-only follow-up; third round is a diagnosis | `review-round-three`: revised arm dispatched no reviewer and gave the diagnosis; current arm dispatched a third reviewer |
| Verifier accepts a result for the same commit, environment and check | `agents/verifier.md` (text; no case) |
| Rendered brief carries the contract; report with a missing field rejected | `tests/ytstack-brief.test.sh`, 86 cases |
| Gates in one question, lapsed named as lapsed, two numbers | `gates-one-question`: revised arm 5 of 5 graders, current arm missed "lapsed"; `tests/skill-preambles.test.sh` `reassess-roadmap` cases |
| Review states the assumed load; `shortcut:` is a decision | `skills/code-review/SKILL.md` "What the reviewer is told" (text; no case) |
| Report ends with "Not checked:" | `bin/ytstack-brief check`, the summary template, `agents/verifier.md` |
| Not worse than the current instructions | 7 comparable cases: current 5 of 7, revised 7 of 7; no case that passed before fails now; 55 against 54 turns, $2.94 against $2.64 (`KNOWLEDGE.md`, "Eval runs") |
| Suites and checker pass, `vendor/` untouched | 15 suites `ALL SUITES PASSED` on macOS bash 3.2 and in the Linux container, checker exit 2 with 27 warnings as on `main`, 13 Codex tests OK, `claude plugin validate .` passed; `git status --short vendor/` empty |

## Deviations from plan

- `bounded-evidence` passes with the current instructions too. A single headless session did not add a second pass on its own, so the case guards the behaviour and does not separate the arms.
- Three criteria are covered by skill text only (severity policy, verifier evidence, assumed load). A case for each needs a reviewer or verifier subagent inside the eval and was not built.
- The comparison ran once per case and arm. It shows that nothing broke and that the two targeted behaviours appear. It is not a cost measurement.
- Nothing on this branch was committed before the whole change had been shown to the operator (repository rule). The closure check of every task therefore saw the area files as uncommitted changes. In the history the area files of M022 sit in the M022-S01-T04 commit and their M023 statements in this task's commit, so `bin/ytstack-spec impact --grep` for a single earlier task finds no area file among that task's own commits. With one commit per task as the work proceeds, the area file travels with its task.
- After the eval run one line of the `code-review` preamble changed (the parent of a root commit); the two review cases were run again on the final tree.
- `bin/ytstack-spec impact` hung on a flag without a value; found by the agent that wrote `bin/ytstack-brief` and fixed, with a test, before the first commit; the fix is part of the M022-S01-T02 commit.

## Follow-ups

- Operator: review and merge the branch, release, `/plugin update`; in each consumer project run `/ytstack:adopt-brownfield` once for the spec.
- A real dispatch with a rendered brief (Claude subagent and `codex exec`) has not been made.
- `hooks/teammate-idle:34` carries the `grep -c ... || echo 0` pattern that was fixed in `reassess-roadmap`.
- A second number in the `progress` block of `STATE.md` (accepted beside done) is open; the status line shows one pair.
- Coordinator mode (#34) builds on the brief, the gates and the round count of this milestone.

## Spec

- skills: `.ytstack/spec/skills.md` -- Behavior, "The work contract"
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior, "States and closure" (the `Runs:` line, `## Gates`, `## Review`)
- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior, "`bin/ytstack-brief`"

## Verification

Command: `bash tests/run-all.sh && python3 bin/ytstack-check; python3 -m unittest discover -s tests -p 'codex*_test.py'; claude plugin validate .` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). Eval run: revised arm 17 of 17 ($6.30), current arm 5 of 7 ($2.94), real model sessions, once per arm.

Linux: `bash tests/run-all.sh --linux` from an export of the final tree (alpine, bash 5.3.9, BusyBox awk): 15 suites, `ALL SUITES PASSED`. The first run failed in `ytstack-check` ("well-formed own spec"): `bin/ytstack-spec lint` reported present sections as missing, because `grep -q` at the end of a pipeline plus `pipefail` turned the writer's SIGPIPE into a failure. Fixed, then green.

Not checked: a live session on Codex; a dispatch with a rendered brief; the behaviour of a long multi-agent run, which no eval case reaches.

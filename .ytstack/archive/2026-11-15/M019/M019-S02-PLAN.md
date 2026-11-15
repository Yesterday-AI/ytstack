---
milestone: M019
slice: S02
project: ytstack
created: 2026-11-07T19:25:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M019-S02 -- Slice Plan

**Goal:** The plugin proves its skills trigger and produce their artifacts (`claude plugin eval`), and CI runs the free checks on every push.

## Tasks

- [x] T01 -- `evals/` suite for `claude plugin eval`: one case per lifecycle skill (resume-session, plan-milestone, slice-milestone, plan-task, summarize-task, reassess-roadmap, handoff-session, quick-task, reconcile, adopt-brownfield, init-project), each with a `fixture.sh` scaffold (`.ytstack/` + git state), a `tool_used: Skill` grader and a free outcome grader (`file_exists` / `regex` on the produced file); `runs: 1`, `append_system_prompt` for headless answers; `evals/results/` gitignored; `evals/README.md` with the run command; one local run recorded (pass rate, cost) in KNOWLEDGE.
- [x] T02 -- `.github/workflows/ci.yml`: shell suites + checker on ubuntu and macOS (landed 2026-11-07, `M019-S02-T02`).
- [x] T03 -- README: CI badge, "Evals" subsection under Contributing/Testing with the run command and the cost note; `docs/ux/skill-structure.md` cross-link; KNOWLEDGE note on `/skill-doctor` + `claude plugin details ytstack`.

## Done when

All tasks `[x]`; `claude plugin eval .` loads all cases (no load errors); `tests/run-all.sh` + `bin/ytstack-check` green.

## Notes

- Eval runs are real model calls on the operator's account; the suite ships with `runs: 1` and the documented command carries `--max-cost-usd`.
- `AskUserQuestion` is not granted in cases; the appended system prompt tells the agent to take each skill's RECOMMENDATION itself.

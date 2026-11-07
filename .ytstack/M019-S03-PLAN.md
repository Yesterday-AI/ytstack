---
milestone: M019
slice: S03
project: ytstack
created: 2026-11-07T19:45:00Z
status: planned
task_count: 5
completed_tasks: 0
---

# M019-S03 -- Slice Plan

**Goal:** The lifecycle has no gaps after "task done": review, branch finish, pre-planning grill, retro, ship and release docs exist as ytstack skills in the two sanctioned wrapper shapes; M011 is absorbed.

## Tasks

- [ ] T01 -- `code-review` (superpowers inline shape): wraps `requesting-code-review` + `receiving-code-review` (two `cat`s, one Namespace note); context = active task plan + its commits (`yt_task_commits`); routes findings into the task summary's Follow-ups / KNOWLEDGE; HARD-GATE on no commits for the task.
- [ ] T02 -- `finish-branch` (superpowers inline shape): wraps `finishing-a-development-branch`; context = branch, worktree flag (`YT_IS_LINKED`), task-ref commits, whether every task in the slice has a non-draft summary; ytstack post-step: never deletes `.ytstack` artifacts, points at `ytstack:reconcile` for leftovers.
- [ ] T03 -- `grill` (superpowers inline shape): wraps `brainstorming` as the relentless-questions step before `plan-milestone` / after `office-hours`; context = PROJECT one-liner, pitch (`OFFICE-HOURS*.md`), DECISIONS tail; writes the design notes into `M###-CONTEXT.md` "Decisions locked in discuss phase" when a milestone is current, else `.ytstack/GRILL-<slug>.md`; the `superpowers:writing-plans` reference maps to `ytstack:plan-milestone` + `slice-milestone`.
- [ ] T04 -- `retro`, `ship`, `document-release` (installed gstack shape, same precheck/HARD-GATE/Skill-tool contract as office-hours): `retro` after a milestone closes (reads the milestone's summaries, writes `M###-RETRO.md`); `ship` at slice/milestone end (gstack ship runs tests, review, PR); `document-release` on a version bump (CHANGELOG from summaries). `tests/gstack-live.test.sh` loops over all six gstack wrappers; `yt_gstack_skill_ok` covers them.
- [ ] T05 -- Routing + bookkeeping: `using-ytstack` lists the six under "Review + release"; `hooks/session-start` "Next action" hints after a closed slice/milestone (reassess, retro, ship); README Workflows + skill count, QUICKSTART, `docs/concept.md` §3.1/3.4 entries, NOTICE; `tests/skill-preambles.test.sh` covers the six preambles; `bin/ytstack-check` 0 fails; evals cases `code-review` + `grill`; global ROADMAP marks M011 absorbed; CHANGELOG Unreleased.

## Done when

All tasks `[x]`; `bash tests/run-all.sh` + `bin/ytstack-check` + `claude plugin validate .` green; the two new eval cases load.

## Notes

- Superpowers v7.0.2 sizes: requesting-code-review 3.0 KB (+ `code-reviewer.md` relative link), receiving-code-review 6.2 KB, finishing-a-development-branch 7.8 KB, brainstorming 15.2 KB (references `superpowers:writing-plans`, ships `visual-companion.md`, `builder-check-prompt.md`, `scripts/`).
- gstack v1.96.0.0 has `retro/`, `ship/`, `document-release/` SKILL.md (51.6 / 61.4 / 17.0 KB); nothing is copied, the Skill tool invokes the installed skill.
- DECISIONS 2026-11-07 (M019 context): no third wrapper shape.

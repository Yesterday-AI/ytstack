---
milestone: M019
project: ytstack
size: L
created: 2026-11-07T18:10:00Z
status: in-progress
total_slices: 5
completed_slices: 1
---

# M019 Roadmap

**Goal:** skills to the 2026 bar (descriptions, metadata, evals, CI), the missing lifecycle skills (absorbs M011), platform-native execution model, release 0.4.0.

**Exit criteria:** see `M019-CONTEXT.md`.

## Slices

- [x] S01 -- Skill metadata + descriptions: `metadata:` migration, trigger-only descriptions, invocability flags for reference skills, checker rules (3 tasks; done 2026-11-07)
- [ ] S02 -- Evals + CI: `evals/` suite for `claude plugin eval`, GitHub Actions workflow for the shell suites + checker, README badge (3 tasks)
- [x] S03 -- New lifecycle skills: `code-review`, `finish-branch`, `grill` (superpowers inline), `retro`, `ship`, `document-release` (installed gstack); using-ytstack routing; M011 absorbed (5 tasks; done 2026-11-07)
- [ ] S04 -- Execution model: `spawn-milestone-team` as orchestrator + worktree subagents, agents/*.md to the subagent contract, advisory `Stop` hook (4 tasks)
- [ ] S05 -- Release 0.4.0: CHANGELOG from Unreleased (M010/M018/M019), manifests, README, clean-clone verification, tag, operator notes (3 tasks)

## Run order

S01 (after the M010 merge, touches every SKILL.md) -> S02 -> S03 -> S04 -> S05. After each slice, `ytstack:reassess-roadmap`.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

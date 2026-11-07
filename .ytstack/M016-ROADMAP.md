---
milestone: M016
project: ytstack
size: M
created: 2026-11-07T10:50:03Z
status: planned
total_slices: 3
completed_slices: 0
---

# M016 Roadmap

**Goal:** No ytstack hook ever writes into a checkout the user did not choose, and no volatile session state lands in tracked files; linked worktrees get correct Git detection and commit discovery. Release 0.2.0. Closes #24, #27 (#26 duplicate).

**Exit criteria:** see `M016-CONTEXT.md` (10 checkable items).

## Slices

Slice detail lives in per-slice `M016-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [ ] S01 -- (to be planned) proposed: `hooks/lib/git-ctx.sh` + rewrite of `pre-compact`, `session-end`, `post-tool-use-bash`, `pre-tool-use-edit`, `session-start` on top of it; out-of-tree state dir; `hooks.json` platform update
- [ ] S02 -- (to be planned) proposed: skill preambles (`summarize-task`, `init-project`, `resume-session`, `handoff-session`, remaining `_PROJECT_DIR` users) on `git rev-parse`; configurable commit discovery; `.gitignore` block; sentinel removal; `bin/ytstack-check` banned-pattern rule
- [ ] S03 -- (to be planned) proposed: `tests/` for all four write paths (main, linked worktree, main-session + worktree command, concurrent sessions); CHANGELOG, version bump 0.2.0, DECISIONS/KNOWLEDGE, issue closure with evidence

## Run order

Slices execute sequentially. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits reality.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

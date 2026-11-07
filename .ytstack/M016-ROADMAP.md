---
milestone: M016
project: ytstack
size: M
created: 2026-11-07T10:50:03Z
status: planned
total_slices: 3
completed_slices: 2
---

# M016 Roadmap

**Goal:** No ytstack hook ever writes into a checkout the user did not choose, and no volatile session state lands in tracked files; linked worktrees get correct Git detection and commit discovery. Release 0.2.0. Closes #24, #27 (#26 duplicate).

**Exit criteria:** see `M016-CONTEXT.md` (10 checkable items).

## Slices

Slice detail lives in per-slice `M016-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [x] S01 -- Hooks resolve from stdin `cwd` via `hooks/lib/git-ctx.sh`, write volatile state out-of-tree only, `hooks.json` on current schema (6 tasks; done 2026-11-07, 218 tests across six suites)
- [x] S02 -- Skill preambles on `git rev-parse` + shared lib, configurable commit discovery, `.gitignore` block, sentinels gone, `ytstack-check` banned patterns (5 tasks; done 2026-11-07, suites: skill-preambles 192, git-ctx 65, ytstack-check 12)
- [ ] S03 -- #26 acceptance as tests (worktree + concurrency), docs for the state model, release 0.2.0 with #24/#27 closed on evidence (4 tasks)

## Run order

Slices execute sequentially. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits reality.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

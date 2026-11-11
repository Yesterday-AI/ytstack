---
milestone: M021
project: ytstack
size: M
created: 2026-11-11T10:25:52Z
status: in-progress
total_slices: 2
completed_slices: 1
---

# M021 Roadmap

**Goal:** Any status line script can append one compact ytstack segment that shows project progress and the current task of the directory it runs in, read from `.ytstack/STATE.md` without per-project scraping.

**Exit criteria:**
- With a `progress` block in the `STATE.md` frontmatter, `bin/ytstack-status` prints label, percentage and done/total; with `waiting_on` set it also prints that item, truncated.
- Without the block it prints the active slice's task count taken from the checkboxes in `M###-S##-PLAN.md`.
- Outside a ytstack project it prints nothing and exits non-zero.
- In a linked worktree the plan progress comes from the default branch and the task pointer from the worktree's own `STATE.md`.
- A malformed block prints nothing; `yt_state_lint` reports it (integers, `done <= total`, short label).
- `summarize-task` and `quick-task` keep the block current when they advance STATE.
- `docs/statusline.md` documents the block, the two-line integration and a stable script location that survives plugin updates; README and CHANGELOG point at it.
- `bash tests/run-all.sh` passes and `bin/ytstack-check` reports no new failures.

## Slices

Slice detail lives in per-slice `M021-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [x] S01 -- `bin/ytstack-status` prints the progress segment for any directory, from one shared parser that the STATE lint also uses.
- [ ] S02 -- The block stays current without hand upkeep and a user can wire the segment into their status line from the documentation.

## Run order

Slices execute sequentially. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits reality.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

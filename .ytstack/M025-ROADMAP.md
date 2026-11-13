---
milestone: M025
project: ytstack
size: L
created: 2026-11-13T18:09:00Z
status: planned
total_slices: 3
completed_slices: 0
---

# M025 Roadmap

**Goal:** Whether a person has to look at a change is decided per change, from its risk and its kind, and a change takes the route without a person only under stated conditions.

**Exit criteria:** see `M025-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M025-S##-PLAN.md` files.

- [ ] S01 -- The product in a worktree: the "Run" section of `RUNTIME.md`, `bin/ytstack-runtime`, the scaffolds and the skills and agents that verify at the running product.
- [ ] S02 -- Risk: classes, the floor, the ceiling per area, review records, the route, `merge_by: risk` in `finish-lane`, the classification in `code-review`.
- [ ] S03 -- Lenses: what a kind of change requires, the lens brief, the skill `visual-review`, eval cases, docs and close.

## Run order

S01 and S02 do not block each other. S03 needs both.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status` to `done` and update global ROADMAP.md

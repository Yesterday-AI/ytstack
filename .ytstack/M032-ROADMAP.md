---
milestone: M032
project: ytstack
size: M
created: 2026-11-15T00:45:00Z
status: planned
total_slices: 3
completed_slices: 0
---

# M032 Roadmap

**Goal:** Every incident of any class ends in the same lesson loop: classify, route the lesson to a machine check first and a knowledge entry second, record it, and surface repeats, as a shared step no skill path can skip.

**Exit criteria:** see `M032-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M032-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [ ] S01 -- Incident and lesson records with class, target and count, and a check that every incident has a lesson with a target.
- [ ] S02 -- The shared lesson step, called by `incident`, `systematic-debugging`, `finish-lane` and `coordinate`.
- [ ] S03 -- Open lessons in `coordinate`'s status and the frontier, repeats per class in `retro`.

## Run order

Sequential. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits.

## How to update this file

- Flip slice checkbox `[ ]` to `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` to `status: done` and update global ROADMAP.md

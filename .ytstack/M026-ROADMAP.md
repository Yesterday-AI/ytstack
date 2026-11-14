---
milestone: M026
project: ytstack
size: S
created: 2026-11-13T18:09:00Z
status: done
total_slices: 2
completed_slices: 2
---

# M026 Roadmap

**Goal:** A merged change is followed until the target serves it and stays healthy; a project's upkeep can run on a schedule.

**Exit criteria:** see `M026-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M026-S##-PLAN.md` files.

- [x] S01 -- The release watch: `bin/ytstack-watch release` over the "Release" section of `RUNTIME.md`, and its step in `finish-lane`.
- [x] S02 -- Recurring upkeep: `bin/ytstack-upkeep`, the recipe per host, docs and close.

## Run order

Both need `bin/ytstack-runtime` (M025-S01). They do not block each other.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status` to `done` and update global ROADMAP.md

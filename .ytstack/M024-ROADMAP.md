---
milestone: M024
project: ytstack
size: L
created: 2026-11-13T16:40:00Z
status: done
total_slices: 4
completed_slices: 4
---

# M024 Roadmap

**Goal:** One session can own a plan with dozens of lanes, delegate all of it, lose its context and continue from files; a lane reaches a merge only through gates read from the host.

**Exit criteria:** see `M024-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M024-S##-PLAN.md` files.

- [x] S01 -- Lanes, edges and claims: the formats, `bin/ytstack-frontier`, `Blocked by` in the plans, claims and re-dispatch in `spawn-milestone-team`, lane kinds and the three new report labels.
- [x] S02 -- A lane becomes a merged pull request: `bin/ytstack-finish-lane` and the skill `finish-lane`.
- [x] S03 -- What only the human can do or decide: `handover-step` with its staged script and static check, the question queue and its place in `reassess-roadmap`.
- [x] S04 -- The coordinating session: the skill `coordinate`, `bin/ytstack-watch`, `lane-retro`, the two smaller items, the eval case, docs and close.

## Run order

S01 first (the others use its formats); S02, S03 and S04 do not block each other.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status` to `done` and update global ROADMAP.md

---
milestone: M033
project: ytstack
size: S
created: 2026-11-15T00:45:00Z
status: done
total_slices: 1
completed_slices: 1
---

# M033 Roadmap

**Goal:** Agents feed their experience with ytstack back upstream through an explicit, configurable channel (`upstream_feedback: suggest | file | off`), without duplicates and without personal or customer data.

**Exit criteria:** see `M033-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M033-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [x] S01 -- The `upstream_feedback` setting, the channel in `using-ytstack`, the agent rules, and an "Upstream" section in `retro` and `lane-retro`.

## Run order

After M032, so the lesson loop can hand ytstack-related lessons to this channel. After the slice, `ytstack:reassess-roadmap` checks if the plan still fits.

## How to update this file

- Flip slice checkbox `[ ]` to `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` to `status: done` and update global ROADMAP.md

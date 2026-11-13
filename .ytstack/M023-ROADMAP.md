---
milestone: M023
project: ytstack
size: L
created: 2026-11-13T15:20:00Z
status: done
total_slices: 3
completed_slices: 3
---

# M023 Roadmap

**Goal:** An agent dispatched on a ytstack project finishes the agreed task with the smallest sufficient evidence, a review ends after its fix round, and a plan row that no work can close reaches the human as one question.

**Exit criteria:** see `M023-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M023-S##-PLAN.md` files.

- [x] S01 -- The work contract reaches every dispatched agent: `minimal-code` as the one directive, the rendered brief, the report shape and its validator.
- [x] S02 -- Completion and gates are defined before execution: runs and environment in the plan, gates with who, how and lapse, one question at the slice boundary, two progress numbers.
- [x] S03 -- Reviews and evidence stay bounded: review rounds, assumed load, concrete findings, evidence identity; the eval cases and the comparison with the current instructions.

## Run order

Slices execute sequentially.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status` to `done` and update global ROADMAP.md

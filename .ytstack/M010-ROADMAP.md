---
milestone: M010
project: ytstack
size: S
created: 2026-11-07T13:40:00Z
status: done
total_slices: 1
completed_slices: 1
---

# M010 Roadmap

**Goal:** existing codebases get a first-class entry into ytstack (`adopt-brownfield`) instead of a greenfield pitch; init-project and the SessionStart hook route there on a shared signal count; STATE.md learns `tracker:`.

**Exit criteria:** see `M010-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M010-S##-PLAN.md` files.

- [x] S01 -- brownfield import end to end: shared detector, adopt-brownfield skill, init-project routing + tracker field, session-start/using-ytstack hint, tracker in plan-milestone/reassess-roadmap, docs (6 tasks; done 2026-11-07)

## Run order

Single slice. `reassess-roadmap` not needed: the milestone closes with the slice.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

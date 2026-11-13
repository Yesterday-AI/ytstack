---
milestone: M022
project: ytstack
size: L
created: 2026-11-13T15:10:00Z
status: in-progress
total_slices: 3
completed_slices: 2
---

# M022 Roadmap

**Goal:** A fresh session finds what applies now for an area, where it is implemented and how a change is verified, in one spec file per area, without reading plans and history.

**Exit criteria:** see `M022-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M022-S##-PLAN.md` files.

- [x] S01 -- The spec artifacts exist, and ytstack has its own: the format contract, `bin/ytstack-spec`, the scaffolds in `init-project` and `adopt-brownfield`, ytstack's `.ytstack/spec/`, entry documents that agree with the repository.
- [x] S02 -- The loop keeps the spec true: "Spec impact" in the plan, the closure check, the bounded check in review and verification, the drift answer at the slice boundary, pointers instead of copies at session start, resume and handoff.
- [ ] S03 -- STATE stays a pointer, milestone close folds, fresh sessions prove it. **Waits for M020** (`hooks/session-start`, `STATE.md`).

## Run order

Slices execute sequentially. S03 starts after M020 has landed on `main`.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status` to `done` and update global ROADMAP.md

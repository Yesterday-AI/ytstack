---
milestone: M017
project: ytstack
size: M
created: 2026-11-07T14:00:00Z
status: planned
total_slices: 2
completed_slices: 0
---

# M017 Roadmap

**Goal:** superpowers pulled to v7.0.2 with a leak check; gstack de-vendored into an installed, tag-pinned dependency behind precheck + Skill invocation; #25 closed; release 0.3.0.

**Exit criteria:** see `M017-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M017-S##-PLAN.md` files.

- [ ] S01 -- superpowers subtree pulled to v7.0.2; inlined-text leak check + wrapper postamble translation (2 tasks)
- [ ] S02 -- gstack de-vendored: lib precheck, wrappers on Skill invocation, vendor removal + checker, live validation in a temp HOME, docs/NOTICE/SECURITY/CHANGELOG + 0.3.0 (5 tasks)

## Run order

Slices execute sequentially. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits reality.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

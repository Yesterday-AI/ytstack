---
milestone: M031
project: ytstack
size: L
created: 2026-11-15T00:45:00Z
status: done
total_slices: 5
completed_slices: 5
---

# M031 Roadmap

**Goal:** An agent in a project that adopted ytstack uses the factory tools that are already shipped (risk route, PR watch, release watch, signals, review lessons) without being told, learns when the plugin changed under it, and a person can set those tools up from one guide.

**Exit criteria:** see `M031-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M031-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [x] S01 -- `coordinate` gets the "Factory tools" step (risk route per merge, PR watch, release watch, signals, review lessons) and a one-step rotation while lanes run.
- [x] S02 -- `ytstack-risk route` reads the review round from the host, so a head-bound review gate can still route `unattended`.
- [x] S03 -- SessionStart and `ytstack-upkeep` say, once and only when it applies, which factory tool is off and when the installed plugin is newer than the session's.
- [x] S04 -- QUICKSTART "Setting up the factory tools" (greenfield, brownfield/upgrade) and an "Upgrading from 0.x" checklist.
- [x] S05 -- `reconcile` detects a large plan outside `.ytstack/` and offers to map it into milestones and slices.

## Run order

S01 and S02 first (the field defects), then S03, S04 (documents what S01-S03 built), S05 last. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits.

## How to update this file

- Flip slice checkbox `[ ]` to `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` to `status: done` and update global ROADMAP.md

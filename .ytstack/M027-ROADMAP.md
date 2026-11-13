---
milestone: M027
project: ytstack
size: M
created: 2026-11-13T18:09:00Z
status: planned
total_slices: 2
completed_slices: 0
---

# M027 Roadmap

**Goal:** What production says reaches the plan, and an incident gets a record and mitigations that only a person carries out.

**Exit criteria:** see `M027-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M027-S##-PLAN.md` files.

- [ ] S01 -- Signal intake: the format of findings, `bin/ytstack-signals`, the skill `signal-intake`.
- [ ] S02 -- Incidents: the record, the skill `incident`, eval cases, docs and close.

## Run order

S01 first (S02 uses its script). Both need `bin/ytstack-runtime` (M025-S01).

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status` to `done` and update global ROADMAP.md

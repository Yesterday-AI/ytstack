---
milestone: M028
project: ytstack
size: M
created: 2026-11-14T09:00:00Z
status: in-progress
total_slices: 3
completed_slices: 0
---

# M028 Roadmap

**Goal:** ytstack ships its own adaptations of the six gstack skills it curates, runs them without any gstack install, and keeps them in step with gstack releases through a recorded baseline and a diff tool.

**Exit criteria:** see `M028-CONTEXT.md`.

## Slices

- [ ] S01 -- No gstack install anywhere: lib, checker, tests and docs describe and enforce self-contained skills, and `bin/ytstack-gstack-diff` reports upstream drift.
- [ ] S02 -- The six skills are rewritten as self-contained ytstack skills from gstack v1.96.0.0.
- [ ] S03 -- The six skills are synced to the newest gstack tag and the whole tree verifies.

## Run order

S01 and S02 run in parallel (S02 by one subagent per skill, S01 in the lead session); S03 after both.

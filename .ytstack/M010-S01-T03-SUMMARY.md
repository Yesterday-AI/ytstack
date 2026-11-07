---
milestone: M010
slice: S01
task: T03
project: ytstack
closed: 2026-11-07T13:40:00Z
verification: passed
---

# M010-S01-T03 -- Summary

## Commits

- `93df507` -- M010: init-project routes mature repos to adopt-brownfield; STATE.md gets tracker:

## Outcome

`init-project` preamble echoes `BROWNFIELD_SIGNALS` + `CANDIDATES` via the shared detector (guarded for the no-lib fallback); new Anti-Pattern "too mature for greenfield ceremony"; Step 3 reports and stops at >= 2 signals without a pitch (no placeholders, no auto-invoke); steps 4-9 renumbered; STATE.md template carries `tracker: none` with a one-line hint; description and terminal state updated. Preamble suite asserts the route condition in the brownfield fixture.

## Deviations from plan

None.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && bin/ytstack-check` -- passed (238/238; 0 fails).

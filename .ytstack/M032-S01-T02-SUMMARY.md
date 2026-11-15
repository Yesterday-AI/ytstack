---
milestone: M032
slice: S01
task: T02
project: ytstack
closed: 2026-11-15T01:30:00Z
verification: passed
---

# M032-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M032-S01-T02: document lesson records, area files and the ledger decision`).

## Outcome

`docs/ux/signal-format.md` got a section "Lessons": the key `lesson:<area>:<class-slug>` with the five areas, the sighting as the dated record of one incident, the four target types with the machine check first, what the four states mean for a lesson, `set --target`, `lesson new --incident` and `lesson list`. The incident example and field table carry `lesson`, and "Checked mechanically" lists the new rules. The `artifacts` rows for `signals/` and `incidents/` and the `checks-and-evals` bullet of `bin/ytstack-signals` say the same in one sentence each (both files stayed at 200 lines). `DECISIONS.md` recorded the choice of a lesson kind in the ledger over a new store or a dated retro file, which answered the milestone's open question 2.

## Deviations from plan

- none

## Follow-ups

- The lesson lane sentence (`## Files` and `## Verification` in a lesson, `ytstack-brief render --lesson`) comes with S03, where the brief learns it.

## Spec

- artifacts: the `signals/` and `incidents/` rows
- checks-and-evals: the `bin/ytstack-signals` bullet

## Verification

Command: `bash bin/ytstack-spec lint && bash bin/ytstack-spec drift && bin/ytstack-check` -- `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`, `spec drift: no area to look at`, the checker `OK (with 9 warning[s])` (the nine warnings are older ones of other skills), no `[fail]` line; at the working tree on top of `2d3d060` in the local checkout (macOS, bash 3.2).

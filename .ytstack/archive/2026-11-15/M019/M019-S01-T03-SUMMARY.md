---
milestone: M019
slice: S01
task: T03
project: ytstack
closed: 2026-11-07T14:08:58Z
verification: passed
---

# M019-S01-T03 -- Summary

## Commits

- `a3011fe` -- M019-S01-T03: ytstack-check fails descriptions over 1,024 chars, warns on procedure-summary phrases and on kind: directive|reference without user-invocable

## Outcome

`bin/ytstack-check` now FAILs a description over 1,024 chars (spec max), WARNs when a description matches `DESC_PROCEDURE_PHRASES` (`RED-GREEN`, `Step N`, "four modes" / "six forcing questions" / "N phases", "Thin ytstack wrapper around", `1) 2)` or `1. Foo 2. Bar` lists) and WARNs when a `kind: directive|reference` skill has no explicit `user-invocable` flag. `tests/ytstack-check.test.sh` section 6 covers all three plus the real-tree zero counts (34/34). Real tree: 0 fails, 19 warnings (all pre-existing vendor sibling notes).

## Deviations from plan

Test and implementation landed in the same edit batch (no separate RED run); the fixture cases exercise each rule positively and the real-tree counts negatively.

## Follow-ups

- `/skill-doctor` and `claude plugin details ytstack` are the manual checks for listing cost; KNOWLEDGE note added in S02-T03 together with the eval run record.

## Verification

Command: `/bin/bash tests/ytstack-check.test.sh && bin/ytstack-check` -- passed (34/34; OK with 19 warnings).

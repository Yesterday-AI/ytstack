---
milestone: M019
slice: S05
task: T01
project: ytstack
closed: 2026-11-07T21:00:00Z
verification: passed
---

# M019-S05-T01 -- Summary

## Commits

- (see `git log --grep '^M019-S05-T01'`) -- CHANGELOG 0.4.0 (M010 + M018 + M019 folded from Unreleased), release notes, compare links

## Outcome

`CHANGELOG.md` has `[Unreleased]` (empty) at the top, then `## [0.4.0] - 2026-11-07` with an intro paragraph (three milestones, research pointer), the Added / Changed / Removed entries that accumulated under Unreleased (M010 brownfield, M018 ceremony, M019 S01-S04, the dependency removal, the Stop hook, CI) and a Notes section (`/plugin update`, gstack for the three new gstack-backed skills, the `## Ceremony` block for existing projects). `[0.3.0]` and the rest follow in order; compare links for 0.4.0 / 0.3.0 / 0.2.0 added (0.3.0 and 0.2.0 had none).

## Deviations from plan

None.

## Follow-ups

- None.

## Verification

Command: `grep -n '^## \[' CHANGELOG.md` (order Unreleased, 0.4.0, 0.3.0, 0.2.0, 0.1.6, 0.1.5, 0.1.0) + em-dash grep -- passed.

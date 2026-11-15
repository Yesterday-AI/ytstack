---
milestone: M016
slice: S02
task: T04
project: ytstack
closed: 2026-11-07T12:19:45Z
verification: passed
---

# M016-S02-T04 -- Summary

## Commits

- `d5b8279` -- M016-S02-T04: plan handoff reading in resume-session / handoff-session
- `115fe44` -- M016-S02-T04: resume-session reads the out-of-tree auto handoff + manual HANDOFF.md; handoff-session marks the file user-owned

## Outcome

`resume-session`'s preamble reads the manual `HANDOFF.md` (`MANUAL_HANDOFF_EVENT`, `MANUAL_HANDOFF_TS`) and resolves the latest automatic handoff through the lib (`$(yt_state_base)/repos/<repo>/worktrees/<wt>/latest-handoff` -> `LATEST_AUTO_HANDOFF`, `AUTO_HANDOFF_TS`); Step 3 reads the automatic breadcrumb first, leans on the manual one when it is newer, and opens the briefing with a `Handoffs: automatic ... / manual ...` line. `handoff-session` states that the file is user-owned (no hook writes it since M016), asks to read it before overwriting, and carries a frontmatter comment saying so. The skill-preamble suite (192 cases) seeds one `pre-compact` run for the main fixture and asserts both handoff sources are reported there and `LATEST_AUTO_HANDOFF: none` in the worktree.

## Deviations from plan

The resume-session assertions were added together with the implementation (no separate RED run); the prose change in handoff-session is untestable by design.

## Follow-ups

- README/QUICKSTART "Where ytstack writes" (S03-T03) must explain the two handoff kinds.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh` -- passed (192/192). `bin/ytstack-check` 0 fails.

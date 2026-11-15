---
milestone: M018
slice: S02
task: T01
project: ytstack
closed: 2026-11-07T13:34:59Z
verification: passed
---

# M018-S02-T01 -- Summary

## Commits

- `6549641` -- M018-S02-T01: plan yt_state_lint
- `de48c73` -- M018-S02-T01: yt_state_lint (malformed fields, pointer behind, summarized task still active, slice while none, stale last_updated, done-but-current)

## Outcome

`yt_state_lint <yt_dir>` in `hooks/lib/git-ctx.sh` sets `YT_STATE_WARNINGS` / `YT_STATE_WARN_COUNT` for six drift classes: malformed frontmatter values (W1), pointer behind the newest `M###-CONTEXT/ROADMAP` on disk (W2 -- the meinkontext M034-vs-M040 case), active task whose non-draft summary exists (W3), slice/task set while milestone is none (W4), `last_updated` older than the newest commit touching `.ytstack` (W5, git-aware, timezone-normalised), milestone `status: done` while STATE still points at it with an open slice (W6); missing STATE.md is its own single warning. Ten new cases in `tests/git-ctx.test.sh` (104 total).

## Deviations from plan

None.

## Follow-ups

- T02 wires the lint into session-start / resume-session / plan-task / summarize-task once the M010 branch is merged (shared files).

## Verification

Command: `/bin/bash tests/git-ctx.test.sh && bash -n hooks/lib/git-ctx.sh` -- passed (104/104).

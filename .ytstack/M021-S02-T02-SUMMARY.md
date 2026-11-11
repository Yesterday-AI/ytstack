---
milestone: M021
slice: S02
task: T02
project: ytstack
closed: 2026-11-11T10:33:54Z
verification: passed
---

# M021-S02-T02 -- Summary

## Commits

- `f7950c8` M021-S02-T02: document the status line segment (docs/statusline.md, README, concept, codex, CHANGELOG)

## Outcome

`docs/statusline.md` describes the segment, the block, the plan/task split, the integration and the limits. README lists the segment under Ships and `bin/` in the repo layout; `docs/concept.md` and `docs/codex.md` point at the new page; CHANGELOG has the `[Unreleased]` entry.

## Deviations from plan

- README repo layout said "10 shell test suites"; it now says 13, the real count. The Ships list went from twelve to thirteen.

## Follow-ups

- The locator glob relies on the plugin cache layout `~/.claude/plugins/cache/<marketplace>/ytstack/<version>/`, which Claude Code does not document. If the layout changes, the snippet in `docs/statusline.md` is the one place to fix.

## Verification

Command: the documented snippet against a fake cache with 0.4.2 (no script), 0.9.0 and 0.10.0 -- passed: picked `0.10.0`, printed `line | M021/S02/T01 0/3`; for `/tmp` it printed `line`; with no plugin installed it printed `line`. `grep -c "—" docs/statusline.md` printed 0.

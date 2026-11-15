---
milestone: M010
slice: S01
task: T01
project: ytstack
closed: 2026-11-07T13:40:00Z
verification: passed
---

# M010-S01-T01 -- Summary

## Commits

- `17ea945` -- M010: yt_brownfield_signals in git-ctx.sh (shared brownfield detection) + 21 lib tests

## Outcome

`hooks/lib/git-ctx.sh` gained `yt_brownfield_signals <toplevel>` (bash 3.2, read-only): six counted signals, `YT_BROWNFIELD_SIGNALS` 0..6, `YT_BROWNFIELD_HINTS` with one `source -> artifact: how` line per finding, plus uncounted hints for RUNTIME/backlog sources and an existing `.ytstack/`. TDD: the 21 new cases in `tests/git-ctx.test.sh` were run red first (`command not found`), then green (106/106).

## Deviations from plan

`.ytstack absent` from the brief is not a counted signal (a fresh empty repo must score 0); an existing `.ytstack/` is reported as a hint instead.

## Verification

Command: `/bin/bash tests/git-ctx.test.sh` -- passed (106/106).

---
milestone: M018
slice: S03
task: T01
project: ytstack
closed: 2026-11-07T13:54:22Z
verification: passed
---

# M018-S03-T01 -- Summary

## Commits

- `30e6483` -- (plan, combined commit) M018-S02: summarize T03/T04; plan T02 lint wiring + S03-T01 layouts
- `0718bc3` -- M018-S03-T01: yt_find_artifacts reads flat + milestones/ + decisions/ + backlog/ + quick/ layouts; session-start, resume-session, summarize-task, reassess-roadmap use it

## Outcome

`yt_find_artifacts <yt_dir> <glob>` returns matching files newest-first (mtime via `stat`, de-duplicated) from the flat `.ytstack/` plus `milestones/`, `milestones/*/`, `decisions/`, `backlog/`, `backlog/*/` and `quick/`. `session-start`'s "Recent tasks", `resume-session`'s recent summaries, `summarize-task`'s plan lookup fallback and `reassess-roadmap`'s stale-milestone check use it (with `ls` fallbacks when the lib is absent). Writing stays flat. git-ctx 131 cases, hooks-readonly 56 (nested `milestones/M777/` summary appears in Recent tasks), skill-preambles 282.

## Deviations from plan

"Newest first" needed a real timestamp sort (`ls -t` per directory does not sort globally) and a `sleep 1` in the test fixture.

## Follow-ups

- T02 docs, T03 CHANGELOG + bookkeeping.

## Verification

Command: `/bin/bash tests/git-ctx.test.sh && /bin/bash tests/hooks-readonly.test.sh && /bin/bash tests/skill-preambles.test.sh` -- passed (131 / 56 / 282). `bin/ytstack-check` 0 fails.

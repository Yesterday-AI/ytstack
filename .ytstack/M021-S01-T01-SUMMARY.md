---
milestone: M021
slice: S01
task: T01
project: ytstack
closed: 2026-11-11T10:29:03Z
verification: passed
---

# M021-S01-T01 -- Summary

## Commits

- `d29ab53` M021-S01-T01: add yt_progress_parse and STATE lint finding W7 for the progress block

## Outcome

`yt_progress_parse` reads STATE.md content on stdin and reports `none`, `ok` or `bad` for the optional frontmatter `progress` block, with label, done, total and waiting_on on `ok` and one error line per problem on `bad`. `yt_state_lint` runs it on `STATE.md` and turns each error line into a warning (W7). A project without the block gets no warning.

## Deviations from plan

none

## Follow-ups

none

## Verification

Command: `bash tests/git-ctx.test.sh` -- passed (150 passed, 0 failed; same result under `/bin/bash` 3.2).

Minimal-code review: rung 6. One awk pass instead of a YAML dependency. Left out on purpose: several tracks, a `done`/`open` pair, multi-line YAML scalars.

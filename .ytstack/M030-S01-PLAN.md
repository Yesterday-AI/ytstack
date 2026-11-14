---
milestone: M030
slice: S01
project: ytstack
created: 2026-11-14T15:30:00Z
status: planned
task_count: 3
completed_tasks: 0
---

# M030-S01 -- Slice Plan

**Goal:** `bin/ytstack-review-escapes` reads a pull request's bot threads, their resolution and the own roles' findings, and says which bot findings escaped.

## Tasks

- [ ] T01 -- Script skeleton and reads: `--pr N [-C DIR] [--repo OWNER/NAME]`; review threads (GraphQL, paginated: author type and login, path, line range, isResolved, first comment URL and body), the PR's commits after each thread's creation with their changed files and hunks. Bot = author type Bot or a login listed in `REVIEW.md`. Fixtures recorded from real responses (no network in tests).
- [ ] T02 -- Classification: resolution `fixed` / `rejected` / `open` per bot thread (a later commit touching the thread's file within the line range, with a small margin, is `fixed`); own-role match `caught` / `escaped` (a thread or review-body line carrying a role marker on the same file and overlapping lines, before or on the same head). TSV output, one line per bot thread; exit 0 without escapes, 10 with at least one `fixed` + `escaped`, 2 on usage or read errors.
- [ ] T03 -- `tests/ytstack-review-escapes.test.sh` (fixtures: fixed+escaped, fixed+caught, rejected, open, a role finding only in the review body, pagination); README tools list, `docs/ux/review-policy-format.md` section "Escapes".

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Measure before S03: run the script read-only on recent merged PRs of the pilot project and record how many matches needed the intake's judgement.

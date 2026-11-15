---
milestone: M032
slice: S01
project: ytstack
created: 2026-11-15T01:00:00Z
status: in-progress
task_count: 2
completed_tasks: 1
---

# M032-S01 -- Slice Plan

**Goal:** What an incident of any class taught is a record with a class, a target and a count in the signals ledger, and a check fails when a closed incident has no recorded lesson or a lesson has no valid target.

**Blocked by:** none

## Tasks

- [x] T01 -- `bin/ytstack-signals`: `kind: lesson` (key `lesson:<area>:<class-slug>`, the source the area, a `target` line), `lesson new` (with `--incident` linking the lesson into the record's new `lesson:` line), `lesson list [--state] [--since]`, `set --target`, `set --state fixed` only for a target in place; `check` on lessons and on closed incidents without a lesson. Tests in `tests/ytstack-signals.test.sh`.
- [ ] T02 -- `docs/ux/signal-format.md` ("Lessons", the incident's `lesson` field, "Checked mechanically"), the `artifacts` and `checks-and-evals` area files, a `DECISIONS.md` entry (lesson kind in the ledger instead of a new store or a dated retro file).

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Source: issue #53 and its scope comment; `M032-CONTEXT.md` (exit criterion 2), open question 2 (where the dated record lives) is decided in T02.
- No new store: the ledger's key, count, regression and states are reused (`review-lessons` has the same shape for review escapes).

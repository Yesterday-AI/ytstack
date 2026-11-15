---
milestone: M028
slice: S01
project: ytstack
created: 2026-11-14T09:00:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M028-S01 -- Slice Plan

**Goal:** No gstack install anywhere: lib, checker, tests and docs describe and enforce self-contained skills, and `bin/ytstack-gstack-diff` reports upstream drift.

## Tasks

- [x] T01 -- Remove `yt_gstack_ctx`, `yt_gstack_skill_ok`, `yt_vergte`, the pin and `tests/gstack-live.test.sh`; `bin/ytstack-check` replaces the wrapper rule by the self-contained rule; preamble, checker and Codex tests follow.
- [x] T02 -- `bin/ytstack-gstack-diff` with `tests/ytstack-gstack-diff.test.sh` (local fixture upstream, 16 cases).
- [x] T03 -- Docs: AGENTS.md sync rule, CONTRIBUTING release-checklist step, NOTICE with gstack's MIT text, README / QUICKSTART / SECURITY / concept / methodology / references / codex docs, KNOWLEDGE gotcha, VENDOR-INVENTORY, CHANGELOG.

## Outcome

Commits `1001c13`, `5af02a3`, `2225843`. All 13 suites pass; checker without failures.

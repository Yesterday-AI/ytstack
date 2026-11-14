---
milestone: M020
slice: S01
project: ytstack
created: 2026-11-09T17:38:24Z
status: done
task_count: 2
completed_tasks: 2
---

# M020-S01 -- Slice Plan

**Goal:** A native Kimi installation loads ytstack skills under their own namespace alongside the original gstack skills from one shared source.

## Tasks

- [x] T01 -- Test-first native Kimi packaging: add manifest, initial `kimi/adapter.md` and regression tests with same-name fixtures for shared skill paths, `ytstack:<name>` invocation and independent gstack resolution.
- [x] T02 -- Verify a fresh isolated Kimi installation: all ytstack skills load as `ytstack:<name>`, gstack originals remain separately invokable, and a same-name wrapper reaches the original rather than recursing.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

S01 covers skill packaging and gstack identity only. Lifecycle hook registration and context-output changes belong to S02. Kimi's native plugin contract is the implementation reference; do not introduce an ytstack `extra_skill_dirs` installation path.

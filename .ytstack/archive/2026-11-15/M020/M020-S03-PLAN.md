---
milestone: M020
slice: S03
project: ytstack
created: 2026-11-09T17:38:24Z
status: done
task_count: 2
completed_tasks: 2
---

# M020-S03 -- Slice Plan

**Goal:** Users can install, update and troubleshoot the Kimi adapter and its independent gstack dependency from the repository documentation, backed by the complete verification suite.

## Tasks

- [x] T01 -- Write `docs/kimi.md` and update README, QUICKSTART, AGENTS.md and `docs/concept.md` for native installation, reload and update behavior, independent gstack discovery, shared-source architecture and support boundaries.
- [x] T02 -- Run the full standard test suite, contract checker and clean isolated Kimi verification; record the actual results and any remaining host limitations for milestone closure.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

S03 depends on the verified S01 and S02 behavior. Documentation must not promise hook injection, gstack interoperability or unsupported Claude-specific workflows beyond what the tests and live CLI runs demonstrate.

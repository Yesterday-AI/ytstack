---
milestone: M023
slice: S01
project: ytstack
created: 2026-11-13T15:20:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M023-S01 -- Slice Plan

**Goal:** The work contract reaches every dispatched agent.

## Tasks

- [x] T01 -- `minimal-code` becomes the work contract (reach before size, the caller rule, no test for a trivial change, evidence, the closing line); the SessionStart pointer, the `using-ytstack` subagent note, the TDD wrapper and NOTICE follow.
- [x] T02 -- `bin/ytstack-brief`: `render` builds a brief from the plan files with the contract included verbatim, `check` validates a worker's report; `brief-template.md` under `skills/spawn-milestone-team/` (the skeleton, the fixed sentences and the report shape); `tests/ytstack-brief.test.sh`.
- [x] T03 -- `spawn-milestone-team` dispatches with the rendered brief and checks the report before the verifier runs; `implementer` and `architect` point at the contract; the Codex adapter says what a rendered brief is and how a Codex worker is started with it.

## Done when

All tasks marked `[x]` and verified.

## Notes

- T02 and T03 were written by a dispatched agent in this worktree; the lead read the output against the brief and ran the suite before closing the tasks.

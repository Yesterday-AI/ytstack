---
milestone: M020
slice: S02
project: ytstack
created: 2026-11-09T17:38:24Z
status: done
task_count: 3
completed_tasks: 3
---

# M020-S02 -- Slice Plan

**Goal:** Kimi plugin hooks provide ytstack session context and lifecycle persistence through the existing shared scripts without changing Claude Code or Codex behavior.

## Tasks

- [x] T01 -- Add executable lifecycle contract tests and the smallest explicit plain-output mode in shared SessionStart. Cover Kimi snake_case payloads, UserPromptSubmit content arrays, pending/no-pending output, plugin roots with spaces, and unchanged Claude Code/Codex JSON contracts.
- [x] T02 -- Add `bin/ytstack-kimi`; register SessionStart, PreCompact, PostCompact, UserPromptSubmit and SessionEnd; implement per-session pending context and exact gstack path guidance when the host supports it. Preserve the shared scripts and existing host defaults.
- [x] T03 -- Exercise startup, resume, compaction, real session close and pending-context injection in a fresh isolated Kimi CLI session. Verify out-of-tree handoff/journal behavior and the supported Kimi version matrix without credentials or external model calls.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

S02 depends on S01's native manifest and adapter. SessionStart stdout is not a Kimi context channel: `sessionStart.skill` supplies only the static directive. SessionStart and PostCompact prepare per-session pending context; UserPromptSubmit consumes it on the next real user prompt. PreCompact retains its handoff side effect. Use `KIMI_PLUGIN_ROOT` for installed files and the payload's project `cwd`; write neither lifecycle state nor pending context into the target checkout or managed plugin copy. See `docs/research/2026-11-14-kimi-native-plugin-best-practices.md`.

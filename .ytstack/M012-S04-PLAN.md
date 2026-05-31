---
milestone: M012
slice: S04
project: ytstack
created: 2026-05-31T08:18:35Z
status: planned
task_count: 2
completed_tasks: 0
---

# M012-S04 -- Slice Plan

**Goal:** the `pre-tool-use-edit` advisory path exits 0 so edits to framework meta-files always land (issue #19).

**Files (exclusive to this slice):** `hooks/pre-tool-use-edit`

## Tasks

- [ ] T01 -- Confirm the working-tree fix is complete: advisory drift path returns `exit 0` (not `exit 2`), the header comment reflects "non-blocking", and the `.ytstack/*|*/.ytstack/*) exit 0` whitelist short-circuit precedes the drift check. Extend the per-path `case` only if a framework meta-file glob is still missing. No further code change if already complete.
- [ ] T02 -- Test before commit by piping a representative PreToolUse payload to the hook (it reads `tool_input.file_path` from stdin JSON, confirmed eng-review 2026-05-31 -- NOT a live Edit). Case 1: `{"tool_input":{"file_path":".ytstack/STATE.md"}}` with `active_task: T01` set -> expect exit 0 (whitelist short-circuit). Case 2: an out-of-scope source path -> expect exit 0 with the advisory drift warning on stderr. Then commit PATH-SCOPED: `git commit -- hooks/pre-tool-use-edit -m "fix: pre-tool-use-edit advisory exit 0 + .ytstack whitelist (#19)"`. NEVER `git add -A` -- the working tree also has an unrelated dirty `.claude-plugin/plugin.json` that must stay out of this commit. Under swarm execution the lead does this commit, not the teammate (DECISIONS 2026-05-31 "Swarm commit discipline").

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- The fix already exists in the working tree (uncommitted) -- HEAD still has `exit 2` at line ~93/123. This slice is "verify + test + commit", not new implementation.
- Real impact: the exit-2-as-block bug silently dropped `summarize-task`'s STATE.md / S##-PLAN.md / T##-SUMMARY.md edits. The `.ytstack/*` whitelist is the durable fix (meta-file edits never trip the gate again).
- Smallest slice; can be claimed first by an idle teammate.

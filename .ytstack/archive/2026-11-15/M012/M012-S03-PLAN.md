---
milestone: M012
slice: S03
project: ytstack
created: 2026-05-31T08:18:35Z
status: planned
task_count: 3
completed_tasks: 0
---

# M012-S03 -- Slice Plan

**Goal:** the session journal records the real `session_id`, not `unknown` (issue #21-RC2).

**Files (exclusive to this slice):** `hooks/session-end`, `hooks/pre-compact`, `hooks/session-start`

## Tasks

- [ ] T01 -- `hooks/session-end`: read the SessionEnd JSON payload from stdin (`INPUT=$(cat)`) and extract `session_id` via `printf '%s' "$INPUT" | jq -r '.session_id // "unknown"'`, replacing `${CLAUDE_SESSION_ID:-unknown}`. Fix the same in the python3 fallback branch (`json.load(sys.stdin).get('session_id','unknown')`). Note: Claude Code delivers `session_id` only on stdin -- there is no `CLAUDE_SESSION_ID` env var (confirmed against the official hooks doc this session).
- [ ] T02 -- Audit `hooks/pre-compact` + `hooks/session-start` (eng-review pre-checked 2026-05-31: NEITHER references `session_id`/`CLAUDE_SESSION_ID` -- session-start uses python3 only for output-JSON formatting). Confirm this still holds, add a one-line comment in each noting `session_id` arrives on stdin (not env) so a future edit does not reintroduce the bug. No behavior change expected -- only `session-end` (T01) is functionally affected.
- [ ] T03 -- Verify: pipe a representative SessionEnd payload (`{"session_id":"abc123","cwd":"...","hook_event_name":"SessionEnd","reason":"clear"}`) into `hooks/session-end` and confirm the appended `journal/sessions.jsonl` entry shows `"session_id":"abc123"` (not `unknown`). Confirm stdin consumption does not break the existing milestone/slice/task fields.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Root cause confirmed: `hooks/session-end:49,61` reads `${CLAUDE_SESSION_ID:-unknown}`; the hook never reads stdin. Empirically every journal entry shows `session_id":"unknown"`.
- claude-code-guide confirmed against https://code.claude.com/docs/en/hooks.md: available hook env vars are `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PLUGIN_DATA`, `CLAUDE_ENV_FILE`, `CLAUDE_EFFORT`, `CLAUDE_CODE_REMOTE` -- NO `CLAUDE_SESSION_ID`. `session_id` arrives on stdin JSON.
- Keep `jq`-with-python3-fallback structure that the hook already uses for JSONL writing.

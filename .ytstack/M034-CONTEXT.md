---
milestone: M034
project: ytstack
created: 2026-11-15T12:00:00Z
size: M
---

# M034 -- Context

## Goal

An operator who switches between agent sessions sees at a glance what each session is doing: the session's current todo item and its progress (n of m done) stay visible in the host's status line on every host that has one, with optional extra sinks (herdr pane metadata, terminal title) for operators who use them.

## Exit criteria

- One reader, `bin/ytstack-todos` (or a mode of `bin/ytstack-status`), prints the active session's todo state in a fixed form: the in-progress item, `done/total`, and the full list on request. It reads the host's own record of the list, per host: Claude Code's task files (`~/.claude/tasks/session-<first 8 of session_id>/<n>.json` interactive, `~/.claude/tasks/<session_id>/` headless; layout undocumented, so the reader is tested against recorded fixtures and degrades to nothing when the layout changes), Codex's plan (`update_plan`) and Kimi's to-dos from where each host keeps them (found in S01). No todo list: no output, never an error.
- `bin/ytstack-status` shows the todo state as its first line (short enough for Kimi, which renders only the first line), and with an opt-in flag (`--todos N`) up to N more lines for hosts that render several (Claude Code). It stays fast: measured under 100 ms on a warm cache, with the measurement in the test suite or the docs (the research saw 0.24 to 0.39 s for today's segment; find and fix the cause or correct the claim in `docs/statusline.md`).
- Codex, which has no custom status line command, gets the documented equivalent: the built-in `task-progress` item in `[tui] status_line`, plus whatever the reader can add through Codex's `terminal_title` or a hook (S01 decides).
- Optional sinks, off by default and switched on in `~/.ytstack/config`: herdr pane metadata (`herdr pane report-metadata "$HERDR_PANE_ID" --source ytstack --title ... --token tasks=n/m --ttl-ms ...`, only when `HERDR_ENV=1`), and the terminal title (OSC 2, documented with `CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1` for Claude Code). Fed by a ytstack hook after the todo tools run, so they update without the user wiring a status line.
- `docs/statusline.md` and QUICKSTART say per host what to wire (status line command, `CLAUDE_CODE_ENABLE_TODO_TOOLS=1` on current Claude models, Codex `task-progress`, Kimi's status line script) and what ytstack ships; the research note `docs/research/2026-11-15-sticky-session-status.md` is part of the PR.
- Tests with fixtures and stand-ins for every host source and sink (no real `herdr` or terminal needed); all suites, checker, spec lint/drift, Codex and Kimi tests, plugin validation.

## Size

M -- 3 slices.

## Planning input

The maintainer's question (2026-11-15): how far can the TUI of the coding agents be influenced, how many lines does a status line take, are there other ways; the goal is a sticky todo list per session so an operator switching sessions knows at once what a session does; integrate it into ytstack. Follow-ups: tmux is not wanted (the maintainer runs the CLIs in herdr), and herdr is optional: the mechanism must be generic, through what most CLIs support (the status line). Research: `docs/research/2026-11-15-sticky-session-status.md` (Claude Code status line has no line cap, refresh on each message plus `refreshInterval`, task files readable from the session id; task tools only on older models unless `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`; Codex has built-in status items only; Kimi renders the first line; herdr `pane report-metadata` tested). Earlier issues: #31 (status line segment, 0.5.0), #42 (research on status lines for progress, to-do lists and operator notes).

## Decisions locked in discuss phase

2026-11-15: The status line is the generic surface; sinks for herdr and the terminal title are optional add-ons, off by default.

2026-11-15: No plugin UI module ("mod") in this milestone: it would add JavaScript to ytstack and is Claude-only; it stays an open option in the research note.

2026-11-15: ytstack never edits a host's settings file; it ships the script, the hook and the instructions.

## Open questions

- Where Codex keeps the current plan for a running session (rollout file under `~/.codex/sessions/`? none of the 400 newest had an `update_plan` record) and where Kimi keeps its to-dos; S01 answers both or records that the host has no readable source.
- Whether Claude Code removes the task files when a session ends; the reader must not show a dead session's list.
- Whether the herdr TUI renders `title` and `tokens` visibly, and where (the API returns them; seen by the maintainer or not).

---
milestone: M012
slice: S02
project: ytstack
created: 2026-05-31T08:18:35Z
status: planned
task_count: 4
completed_tasks: 0
---

# M012-S02 -- Slice Plan

**Goal:** STATE.md frontmatter faithfully tracks `active_slice`/`active_task` across the lifecycle (issue #21-RC1), and completed backlog items get swept on milestone close (issue #16).

**Files (exclusive to this slice):** `skills/plan-task/SKILL.md`, `skills/summarize-task/SKILL.md`, `skills/reassess-roadmap/SKILL.md`. (`skills/slice-milestone/SKILL.md` reserved to this slice but NOT edited -- eng-review resolved the open question to plan-task ownership; reservation kept so no other slice can touch it.)

## Tasks

- [ ] T01 -- `plan-task` PERSISTS the already-computed `_ACTIVE_SLICE` to STATE.md frontmatter (`active_slice: <old> -> active_slice: {ACTIVE_SLICE}`), as a one-line addition next to the existing `active_task` write in the STATE.md-edit step. Note: plan-task already derives `_ACTIVE_SLICE` in its preamble (line ~78, fallback to first open slice in the roadmap) and uses it for the task-plan frontmatter + status body line -- it just never writes it back to the frontmatter field. NO new derivation logic; `slice-milestone` is NOT touched. Wrap the write in a guard: `if [ -z "$CLAUDE_AGENT_TEAM_MEMBER" ]` (plan-task's preamble must compute this env check, same var that drives `_NON_INTERACTIVE` elsewhere) so swarm teammates never mutate STATE.md slice/task frontmatter. Locked: DECISIONS 2026-05-31 "active_slice is plan-task-owned and team-member-guarded".
- [ ] T02 -- `summarize-task` clears `active_slice -> none` inside its EXISTING "slice fully complete (all tasks `[x]`)" branch (line ~213), under the same `CLAUDE_AGENT_TEAM_MEMBER` guard. The last-task detection already exists (it recommends reassess-roadmap there); hook the clear into that branch. Mid-slice task summaries leave `active_slice` intact.
- [ ] T03 -- `reassess-roadmap`: (a) clear `active_slice` to `none` at a slice boundary when no task is active; (b) add the #16 backlog-sweep prompt at milestone close -- read the backlog items folded into the milestone from `M###-CONTEXT.md` scope and prompt per item (delete fully-shipped / trim deferred parts / drop-with-DECISIONS.md-note).
- [ ] T04 -- Verify the SSOT cycle end-to-end on a scratch `.ytstack/` fixture: slice entry -> frontmatter shows `active_slice: S##`; summarize a mid-slice task -> `active_slice` unchanged; summarize the last task -> `active_slice: none`; confirm `hooks/session-end`'s `get_field active_slice` reads the real S## (not `none`) mid-slice. Run UX-contract checks on all four edited skills.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Root cause confirmed: `slice-milestone` never writes `active_slice` (only reads `current_milestone`); `plan-milestone`/`init-project` only ever set it to `none`. So `active_slice` is structurally stuck at `none` and the journal dutifully records `none`.
- Hard constraint (locked decision, commit 8020b43): the fix lives in SKILLS, never in the `session-end` hook. The hook reads frontmatter correctly; skills own the write.
- Conflict guard: this is the ONLY slice allowed to touch `skills/reassess-roadmap/SKILL.md`. #16 must NOT be split into its own parallel slice.
- All four edits must keep the UX contract (frontmatter `name/description/tier/version/allowed-tools`, required sections, no em-dash, sentinel naming).

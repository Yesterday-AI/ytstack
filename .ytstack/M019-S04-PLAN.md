---
milestone: M019
slice: S04
project: ytstack
created: 2026-11-07T20:25:00Z
status: done
task_count: 4
completed_tasks: 4
---

# M019-S04 -- Slice Plan

**Goal:** ytstack's parallel execution matches the platform: a thin orchestrator dispatches one worktree-isolated subagent per slice (default), verifies each slice with a fresh verifier, merges; Agent Teams stay available as an explicit opt-in.

## Tasks

- [x] T01 -- `spawn-milestone-team` rewrite: preamble reads PREFERENCES `team` (default `off`; `on`/`true` = Agent Teams path), slice plans, file overlap, branch and worktree state; default procedure = orchestrator that never edits source: per slice `Agent(subagent_type: "ytstack:implementer", isolation: "worktree", name: ...)` with the slice plan, the ytstack rules and the branch name `ytstack/M###-S##` in the prompt; then `Agent(subagent_type: "ytstack:verifier", isolation: "worktree")` that checks out the slice branch and runs every task plan's verification; then the merge step (slice branch into the working branch, `STATE.md` resolved from the orchestrator's side, pointer advanced by the orchestrator, `reassess-roadmap`); Agent Teams path kept behind `team: on` with the existing instruction block; `plan-ceo-review`-style AskUserQuestion for overlap and for the merge.
- [x] T02 -- Advisory `Stop` hook (landed 2026-11-07, `M019-S04-T02`).
- [x] T03 -- `agents/*.md` to the subagent contract: `implementer` gets `isolation: worktree`, `memory: project`, `maxTurns`, the branch rule and the STATE rule (worktree copy only; orchestrator owns the main pointer); `verifier` gets `isolation: worktree`, the checkout-the-slice-branch step and `memory: project`; `architect` gets `memory: project`; `skills:` kept as preload (honoured for subagents; ignored for teammates); `docs/ux/agent-structure.md` updated (fields, preload semantics, worktree rules); `bin/ytstack-check` accepts the new fields.
- [x] T04 -- Tests + docs: `tests/skill-preambles.test.sh` case for spawn-milestone-team (`EXECUTION: subagents` default, `team: on` flips it, slice count, overlap detection), `tests/ytstack-check.test.sh` agent frontmatter case, README / QUICKSTART / concept §3.4 (`spawn-milestone-team` entry) / DECISIONS cross-ref, CHANGELOG Unreleased; `init-project` PREFERENCES template gains `team: off`.

## Done when

All tasks `[x]`; `bash tests/run-all.sh` + `bin/ytstack-check` + `claude plugin validate .` green.

## Notes

- Platform (sub-agents reference, fetched 2026-11-07): `isolation: worktree` branches from the default branch (not the parent's HEAD) and is removed when the subagent made no changes; Bash inside such a subagent is confined to its worktree; `skills:` preloads full skill content for subagents; plugin agents ignore `hooks`, `mcpServers`, `permissionMode`; `memory: project` lives in `.claude/agent-memory/<name>/`; in a session with Agent Teams enabled, an Agent call with a `name` launches a teammate unless it is a fork or passes `isolation`.
- DECISIONS 2026-11-07 (M019 context): Agent Teams demoted to opt-in.

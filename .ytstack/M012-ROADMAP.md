---
milestone: M012
project: ytstack
size: L
created: 2026-05-31T08:18:35Z
status: planned
total_slices: 4
completed_slices: 0
parallel: true
---

# M012 Roadmap

**Goal:** ytstack's lifecycle skills and hooks are free of the five verified defects from issues #16/#19/#20/#21, shipped as file-disjoint slices for parallel swarm execution.

**Exit criteria:**
- [#20] verification-before-completion preamble runs without a bash parse error (no literal fence in the executable block).
- [#19] pre-tool-use-edit advisory path exits 0; `.ytstack/*` meta-file edits land; WT fix committed + tested.
- [#21-RC1] slice/task state written to STATE.md frontmatter on entry, cleared only when idle; mid-slice session-end journals real S##/T##.
- [#21-RC2] session-end reads session_id from stdin JSON; pre-compact + session-start audited.
- [#16] reassess-roadmap prompts per folded-in backlog item at milestone close.
- All slices file-disjoint; parallel teammates produce zero merge conflicts.

## Slices

Slice detail lives in per-slice `M012-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [ ] S01 -- [#20] verification-before-completion preamble runs without a fence parse error (2 tasks). Files: `skills/verification-before-completion/SKILL.md`.
- [ ] S02 -- [#21-RC1 + #16] STATE.md tracks active_slice/active_task; backlog swept on milestone close (4 tasks). Files: `skills/plan-task/`, `slice-milestone/`, `summarize-task/`, `reassess-roadmap/SKILL.md`.
- [ ] S03 -- [#21-RC2] session-end records real session_id from stdin; hooks audited (3 tasks). Files: `hooks/session-end`, `pre-compact`, `session-start`.
- [ ] S04 -- [#19] pre-tool-use-edit advisory exits 0; WT fix committed + tested (2 tasks). Files: `hooks/pre-tool-use-edit`.

## Run order

**Parallel.** The four slices touch mutually disjoint file-sets (S01: verification skill; S02: planning/lifecycle skills; S03: session-* hooks; S04: pre-tool-use-edit hook), so they execute concurrently via `ytstack:spawn-milestone-team` -- one teammate per slice, each with its own 200k context. No slice depends on another's output. After all four close, run `ytstack:reassess-roadmap` once to confirm the milestone roadmap still fits.

Conflict guard: S02 is the ONLY slice allowed to touch `skills/reassess-roadmap/SKILL.md` (both #21-RC1's clear-discipline and #16's backlog-prompt land there). Do not split #16 into its own slice.

Pre-flight for the swarm: `spawn-milestone-team` requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and Claude Code v2.1.32+ (DECISIONS 2026-04-23). Falls back to sequential subagents if unavailable.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update the global ROADMAP.md table

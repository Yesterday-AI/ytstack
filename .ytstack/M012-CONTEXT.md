---
milestone: M012
project: ytstack
created: 2026-05-31T08:18:35Z
size: L
---

# M012 -- Context

## Goal

ytstack's lifecycle skills and hooks are free of the five verified defects filed as GitHub issues #16/#19/#20/#21: no core skill crashes on launch, edits to framework meta-files always land, STATE.md frontmatter faithfully tracks `active_slice`/`active_task`, the journal records the real `session_id`, and completed backlog items get swept on milestone close. Shipped as file-disjoint slices so Agent Teams executes them in parallel.

## Exit criteria

- [#20] `/ytstack:verification-before-completion` runs its preamble with no bash parse error; the executable block contains no literal triple-backtick (fence produced via `printf`). Verified isolated -- no other skill has the pattern.
- [#19] `pre-tool-use-edit` returns exit 0 on the advisory path and edits to `.ytstack/*` meta-files land; the working-tree fix (exit 0 + `.ytstack/*` whitelist short-circuit) is committed and tested by an actual Edit on a `.ytstack/` file.
- [#21-RC1] `slice-milestone`/`plan-task` write `active_slice: S##` to STATE.md frontmatter on slice entry; `summarize-task`/`reassess-roadmap` clear it only when genuinely idle; a session-end fired mid-slice journals the real `S##`/`T##`, not `none`.
- [#21-RC2] `session-end` reads `session_id` from stdin JSON (`jq -r '.session_id // "unknown"'`), not from the non-existent `CLAUDE_SESSION_ID` env var; a fresh journal entry shows a real id; `pre-compact` + `session-start` audited for the same env-var assumption.
- [#16] `reassess-roadmap` at milestone close prompts per backlog item folded into the milestone (delete fully-shipped / trim deferred parts / drop-with-DECISIONS-note).
- All four slices touch disjoint file-sets and run as parallel Agent Teams teammates with zero merge conflicts.

## Size

L -- see `M012-ROADMAP.md` for slice breakdown. "Wide, not deep": four small parallel slices, not a large milestone.

## Decisions locked in discuss phase

- 2026-05-31: M012 is prioritized ahead of M010/M011 as a fix-pack. All five items are verified correctness defects / low-effort gaps from issues #16/#19/#20/#21 (each checked against the actual repo code this session). M010 (brownfield = issue #18) and M011 (post-summarize lifecycle) stay queued after M012.
- 2026-05-31: Slicing is file-disjoint by design so `spawn-milestone-team` teammates never collide. Issue #16 and #21-RC1 both touch `skills/reassess-roadmap/SKILL.md`, so they MUST stay in the same slice (S02). Skills-cluster (S01, S02) and hooks-cluster (S03, S04) are mutually disjoint.
- 2026-05-31: The #21-RC1 fix lives in the lifecycle skills, NOT in the `session-end` hook. Locked decision (commit 8020b43) forbids hooks mutating STATE.md; the hook reads frontmatter correctly. Skills own the source-of-truth write discipline, same as `current_milestone`.

## Open questions

(All resolved in plan-eng-review 2026-05-31 -- see "Decisions locked" above + DECISIONS.md.)

- ~~#21-RC1: which skill owns the `active_slice` write?~~ RESOLVED: `plan-task` owns it -- it already computes the slice; persist the value + guard on `CLAUDE_AGENT_TEAM_MEMBER`. `slice-milestone` untouched. (DECISIONS 2026-05-31)
- ~~#19: is the WT fix complete?~~ Verified in eng-review: advisory path exits 0, `.ytstack/*` whitelist present. S04 is verify-via-piped-payload + path-scoped commit, not reimplementation.

## Plan-eng-review outcomes (2026-05-31)

- Befund 1 -> DECISIONS "active_slice is plan-task-owned and team-member-guarded". Applied to S02-T01/T02.
- Befund 2 -> DECISIONS "Swarm commit discipline" (M012 runs shared-tree; lead commits path-scoped).
- Befund 3 -> S01-T01 uses prefix-match (`index($0,f)==1`), handles ` ```bash ` tagged fences.
- Befund 4 -> S03 scope shrinks: only `session-end` is functionally affected; pre-compact/session-start get a comment only.
- Befund 5 -> S04-T02 tests via piped PreToolUse JSON payload; commit is path-scoped (dirty plugin.json must stay out).
- Product follow-up (not M012): DECISIONS "ytstack encourages git worktree isolation for parallel swarm execution" + ROADMAP M013 (spawn-milestone-team worktree mode, default-on + opt-out). Out of M012 scope.

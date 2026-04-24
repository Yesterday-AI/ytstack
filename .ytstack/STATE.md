---
project: ytstack
slug: ytstack
last_updated: 2026-04-24T16:00:00Z
current_milestone: review + post-M009-patches
active_slice: none
active_task: none
---

# State

**Status:** Full build cycle complete + post-M009 patches landing. 38/39 roadmap tasks done; 1 deferred (GitHub repo creation + push + v0.1.0 tag — user action). End-of-cycle review in progress.

**Post-M009 patches since 2026-04-23:** using-ytstack skill + session-start hook behavior-priming rewrite; 3 subagent definitions (architect / implementer / verifier); `docs/ux/agent-structure.md` contract; git init + initial scaffold commit; superpowers + gstack subtrees added.

```
Progress:  [####################]  37/39 tasks (95%)
M001 Foundation                  [######] 6/6  DONE
M002 Lifecycle Hooks             [###]    3/3  DONE
M003 Project-OS Skills           [#######] 7/7 DONE
M004 Planning Cherry-Picks       [####]   4/4  DONE (vendor-add deferred)
M005 Execution Cherry-Picks      [####]   4/4  DONE (vendor-add deferred)
M006 Agent Teams Integration     [####]   4/4  DONE
M007 Quality Gates               [###]    3/3  DONE
M008 Publishing & Marketplace    [##..]   2/4  DONE (2 user-action)
M009 Docs & Community            [####]   4/4  DONE
```

## Next action

**Full-cycle review.** See `.ytstack/REVIEW-NOTES.md` for the batch of items flagged during the build. Review categories:

- Blockers before v0.1 publication (interactive-mode test, CI tool, git init, etc.)
- UX issues to revisit (init-project fallbacks, sentinel cleanup, etc.)
- Architecture decisions deferred
- Cross-cutting concerns
- Findings per milestone (M001, M002, M003)

After review, two user-action tasks close M008:
- T33 — Create GitHub repos: `yesterday-ai/ytstack` + `yesterday-ai/ytstack-marketplace`
- T35 — `git init` ytstack, add remote, commit, tag v0.1.0, push

## Completed milestones

All 9 milestones achieved. See ROADMAP.md for per-milestone detail.

## What ships in v0.1.0

**Skills (15):**

- `init-project` (M001) — bootstrap `.ytstack/` artifacts
- `plan-milestone`, `slice-milestone`, `plan-task`, `summarize-task`, `reassess-roadmap`, `handoff-session`, `resume-session` (M003) — Project-OS lifecycle
- `plan-ceo-review`, `office-hours`, `plan-eng-review` (M004) — gstack planning wrappers
- `test-driven-development`, `systematic-debugging`, `verification-before-completion` (M005) — superpowers execution wrappers
- `spawn-milestone-team` (M006) — Agent Teams dispatch
- `using-ytstack` (post-M009) — auto-injected directive that drives agent-side skill selection from natural-language intent. Adapted from superpowers' `using-superpowers` pattern.

**Subagent definitions (3, post-M009):**

- `agents/architect.md` — plan-review, approve-to-implement gate (read-only). Used by `spawn-milestone-team` for the optional architect-lead role.
- `agents/implementer.md` — executes one slice via the `plan-task → TDD → verify → summarize` cycle. Bounded to slice scope.
- `agents/verifier.md` — evidence-before-assertions, runs plan's verification command from cold context, passes/fails task closure.

These are referenced by `skills/spawn-milestone-team/SKILL.md` as the default teammate-role types. Previously the skill named them without providing definitions (gap surfaced during behavior-priming audit).

**Hooks (8):**

- `session-start` (M002) — inject project state on startup/resume/clear/compact
- `pre-compact` (M002) — write HANDOFF.md before context compression
- `session-end` (M002) — finalize STATE.md, append session journal
- `teammate-idle` (M006) — keep teammates claiming open tasks
- `task-created` (M006) — scope-drift check against milestone roadmap
- `task-completed` (M006) — auto-draft T##-SUMMARY.md
- `pre-tool-use-edit` (M007) — scope + schema drift check before file edits
- `post-tool-use-bash` (M007) — auto-append commit to task summary

**Docs:**

- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `QUICKSTART.md`, `LICENSE`, `NOTICE`
- `docs/ux/askuserquestion-format.md`, `writing-style.md`, `skill-structure.md`
- `docs/references.md`, `docs/methodology.md`
- `vendor/README.md`

**Dogfood artifacts:** `.ytstack/PROJECT.md`, `ROADMAP.md`, `STATE.md`, `DECISIONS.md` (8 entries), `KNOWLEDGE.md`, `RUNTIME.md`, `PREFERENCES.md`, `REVIEW-NOTES.md` (~35 items)

**Plugin config:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

## Open decisions

None currently. See DECISIONS.md (8 entries) for locked choices.

## Recent summaries

M003-M009 work tracked above. `ytstack:summarize-task` will format per-task summaries going forward.

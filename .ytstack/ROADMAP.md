---
project: ytstack
last_updated: 2026-04-25T16:00:00Z
total_milestones: 11
completed_milestones: 9
current_milestone: review (M010 + M011 planned, not started)
---

# ytstack Roadmap

Milestone-level plan for building ytstack. Each milestone ships independently and produces testable value. Per-milestone detail lives in `M###-ROADMAP.md` files created by `ytstack:plan-milestone` when the milestone begins.

Progress legend: `[ ]` todo, `[~]` in progress, `[x]` done, `[-]` skipped.

---

## Overview

| ID | Milestone | Status | Tasks | Done |
|----|-----------|--------|------:|-----:|
| M001 | Foundation | **done** | 6 | 6 |
| M002 | Lifecycle Hooks | **done** | 3 | 3 |
| M003 | Project-OS Skills | **done** | 7 | 7 |
| M004 | Planning Cherry-Picks (gstack) | **done** (vendor-add deferred) | 4 | 4 |
| M005 | Execution Cherry-Picks (superpowers) | **done** (vendor-add deferred) | 4 | 4 |
| M006 | Agent Teams Integration | **done** | 4 | 4 |
| M007 | Quality Gates (PreToolUse hooks) | **done** | 3 | 3 |
| M008 | Publishing & Marketplace | **done (2 user-action)** | 4 | 2 |
| M009 | Docs & Community | **done** | 4 | 4 |
| M010 | Workflow Reorder + Brownfield-Without-.ytstack | planned | TBD | 0 |
| M011 | Post-Summarize Lifecycle (ship + canary or document-release) | planned | TBD | 0 |

**Total:** 39 tasks across M001-M009, 37 done (95%). 2 deferred to user action (git init + push, GitHub repo creation). M010 + M011 task counts pending milestone planning.

---

## M001 -- Foundation ✓ done

**Goal:** Establish UX contracts, the first working skill, local installability. Prove the pattern end-to-end before scaling.

**Exit criteria met:** plugin loads locally via `claude --plugin-dir <path>`, `ytstack:init-project` invokable and passes the UX contract (verified in smoke-test at `/tmp/ytstack-sandbox-smoke2-1776965807`), dogfood state visible in `.ytstack/`.

- [x] Write UX contracts (`docs/ux/askuserquestion-format.md`, `writing-style.md`, `skill-structure.md`)
- [x] Draft first skill (`skills/init-project/SKILL.md`) strictly following contracts
- [x] Dogfood: initialize `.ytstack/` for ytstack's own development (PROJECT, ROADMAP, STATE, DECISIONS, KNOWLEDGE, RUNTIME, PREFERENCES) + contributor guide (`CLAUDE.md`) + source references (`docs/references.md`)
- [x] Write plugin manifest (`.claude-plugin/plugin.json`, schema-verified against Claude Code plugins-reference docs)
- [x] Local test-install: verified via `claude --plugin-dir <path> --permission-mode acceptEdits -p`, all 6 artifacts generated correctly, sentinels touched, ISO-timestamp substituted. Two findings logged to KNOWLEDGE.md (headless permission-mode requirement; Skill-tool registration quirk)
- [x] Polish README with install instructions, scope, quickstart, known-limitations

---

## M002 -- Lifecycle Hooks ✓ done

**Goal:** SessionStart/PreCompact/SessionEnd hooks that inject project state and persist handoff.

**Exit criteria met:** hook scripts smoke-tested standalone. SessionStart emits valid JSON context (953 chars) when .ytstack/ present, silent exit elsewhere. PreCompact writes HANDOFF.md. SessionEnd updates last_updated in-place + appends journal entry.

- [x] `hooks/session-start` -- reads `.ytstack/STATE.md`, emits project-state context via `hookSpecificOutput.additionalContext` JSON
- [x] `hooks/pre-compact` -- writes `.ytstack/HANDOFF.md` with current state + reading pointers before compression
- [x] `hooks/session-end` -- updates `STATE.md` `last_updated` in-place, appends `.ytstack/journal/sessions.jsonl` entry

---

## M003 -- Project-OS Skills ✓ done

**Goal:** Core artifact-management skills that realize the milestone/slice/task hierarchy. This is the ytstack "GSD-essence" layer.

**Exit criteria met:** all 7 skills written, each follows M001 UX contracts (frontmatter + Anti-Pattern + Checklist + Preamble + Procedure + Terminal State).

- [x] `ytstack:plan-milestone` -- discuss phase, creates `M###-CONTEXT.md` and `M###-ROADMAP.md`
- [x] `ytstack:slice-milestone` -- breaks milestone into slices, creates `S##-PLAN.md`, enforces 1-7-tasks rule
- [x] `ytstack:plan-task` -- creates `T##-PLAN.md`, enforces "fits one context window" rule
- [x] `ytstack:summarize-task` -- writes `T##-SUMMARY.md`, updates `STATE.md`, optionally stages git
- [x] `ytstack:reassess-roadmap` -- post-slice, A/B/C decision on plan fit, patches ROADMAP + CONTEXT
- [x] `ytstack:handoff-session` -- user-triggered handoff, richer than pre-compact hook
- [x] `ytstack:resume-session` -- 3-paragraph briefing from STATE + HANDOFF + recent 3 summaries

---

## M004 -- Planning Cherry-Picks (gstack) ✓ done (vendor-add deferred to M008)

**Goal:** Vendor gstack via git subtree and cherry-pick the highest-value decision skills as wrappers (no modification of vendored content).

**Status:** Wrapper skills written. Actual subtree-add deferred to M008 pre-release (requires ytstack to be a git repo with resolved gstack URL).

- [~] Add gstack as git subtree: `vendor/gstack/` -- deferred; see `vendor/README.md` for command
- [x] Wrapper: `ytstack:plan-ceo-review` (delegates to `vendor/gstack/plan-ceo-review/`, injects ytstack context + outcome persistence)
- [x] Wrapper: `ytstack:office-hours` (delegates, saves design doc to `.ytstack/docs/office-hours/`)
- [x] Wrapper: `ytstack:plan-eng-review` (delegates, applies architecture findings to slice-plans + DECISIONS.md)

---

## M005 -- Execution Cherry-Picks (superpowers) ✓ done (vendor-add deferred to M008)

**Goal:** Vendor superpowers via git subtree and cherry-pick the core execution skills as wrappers.

**Status:** Wrapper skills written. Superpowers subtree-add deferred to M008 pre-release.

- [~] Add superpowers as git subtree: `vendor/superpowers/` -- deferred; `git subtree add --prefix=vendor/superpowers https://github.com/obra/superpowers.git main --squash`
- [x] Wrapper: `ytstack:test-driven-development` (injects ACTIVE_TASK verification command, propagates NON_INTERACTIVE flag)
- [x] Wrapper: `ytstack:systematic-debugging` (root-cause findings to KNOWLEDGE.md, architectural shifts to DECISIONS.md)
- [x] Wrapper: `ytstack:verification-before-completion` (auto-reads T##-PLAN.md Verification command)

---

## M006 -- Agent Teams Integration

**Goal:** Wrap Claude Code's experimental Agent Teams feature for per-task fresh context (GSD's core value without the TypeScript runtime).

**Exit criteria:** `ytstack:spawn-milestone-team` creates a team from `M###-ROADMAP.md` task list; TaskCompleted hook auto-writes summaries.

- [ ] `ytstack:spawn-milestone-team` -- reads `M###-ROADMAP.md`, creates team with typed subagent roles (architect, implementer, verifier)
- [ ] `hooks/teammate-idle` -- ensures next task gets claimed
- [ ] `hooks/task-created` -- scope-drift check against current milestone's `M###-ROADMAP.md`
- [ ] `hooks/task-completed` -- auto-writes `T##-SUMMARY.md`, updates `STATE.md`, optionally commits

---

## M007 -- Quality Gates

**Goal:** PreToolUse/PostToolUse hooks that enforce discipline at the file-edit boundary.

**Exit criteria:** Scope-drift attempts produce clear warnings; schema changes without migrations flagged.

- [ ] `hooks/pre-tool-use-edit` -- warns if modified file is outside current `T##-PLAN.md` scope
- [ ] `hooks/pre-tool-use-edit` -- schema-drift check (model file change without migration in same turn)
- [ ] `hooks/post-tool-use-bash` -- after `git commit`, append entry to current `T##-SUMMARY.md`

---

## M008 -- Publishing & Marketplace

**Goal:** Ship ytstack as an installable plugin via a Yesterday-owned marketplace.

**Exit criteria:** Third party can run `/plugin marketplace add Yesterday-AI/ytstack && /plugin install ytstack@ytstack` and get a working install.

- [ ] Add `LICENSE` (MIT), `NOTICE` (superpowers + gstack + generic "external AI-first methodology inspired-by" attribution)
- [ ] Add `CLAUDE.md` (contributor guidelines)
- [x] Create GitHub repo: `Yesterday-AI/ytstack` (self-marketplaced, no separate marketplace repo -- see DECISIONS 2026-04-24)
- [ ] Tag v0.1.0 release

---

## M009 -- Docs & Community

**Goal:** User-facing documentation and contributor on-ramp.

**Exit criteria:** A new user can install ytstack, run their first milestone, and understand the artifact model without reading source.

- [ ] User-facing `README.md` with install/quickstart
- [ ] `QUICKSTART.md` with a worked example
- [ ] `CONTRIBUTING.md` with PR guidelines (no third-party content copying, strict UX contract adherence)
- [ ] Methodology attribution writeup (which external concepts we adapted and how -- without naming sources)

---

## M010 -- Workflow Reorder + Brownfield-Without-.ytstack (planned)

**Goal:** Two-part scope. Part 1 finishes the greenfield-flow reorder originally planned 2026-04-24. Part 2 adds explicit handling for users running ytstack inside an existing repo that has no `.ytstack/` directory yet (third workflow case alongside greenfield and brownfield-with-.ytstack).

**Exit criteria:**
- Greenfield smoke-test ("baue mir eine cli...") routes to `office-hours` first (not `plan-milestone` or `init-project`), per DECISIONS 2026-04-24 "Greenfield-flow reorder".
- Brownfield-without-.ytstack case: a user opens an existing project that has no `.ytstack/`, and ytstack offers explicit choice (init-project vs ad-hoc) instead of either silently bypassing or assuming greenfield.
- README documents all three workflows with diagrams; QUICKSTART covers all three.

**Scope reference:**
- DECISIONS 2026-04-24 "Greenfield-flow reorder" + DECISIONS 2026-04-24 "Wrapper mechanism = shell-exec inject + cross-ref check" originally merged this with wrapper-refactor as a single milestone. The wrapper-refactor part was completed in scope of those decisions; what remains is the workflow-reorder part PLUS the new brownfield-without-.ytstack case identified 2026-04-25.

**Plan via:** `ytstack:plan-milestone` -- not yet invoked.

---

## M011 -- Post-Summarize Lifecycle (ship + canary or document-release) (planned)

**Goal:** Close the lifecycle gap between `summarize-task` and shipping a release. Today ytstack covers Plan -> Code -> Verify -> Close (`summarize-task`) and stops. Per DECISIONS 2026-04-25 "Lifecycle-phase as the curation heuristic", ytstack covers the full dev-loop; ship + post-deploy land in ytstack core.

**Exit criteria:**
- `ytstack:ship` wrapper exists -- wraps `vendor/gstack/ship/SKILL.md` per the 2026-04-25 wrapper-mechanism + vendored-preamble-drift DECISIONS. Bumps VERSION, writes CHANGELOG, creates PR with body, runs pre-merge safety checks.
- One additional post-ship skill: `ytstack:canary` (visual monitor) OR `ytstack:document-release` (post-ship doc update). Choice deferred to milestone planning. Hard scope-limit: at most one. Other gstack ship-family skills (`land-and-deploy`, etc.) are explicitly out of scope per DECISIONS 2026-04-25 lifecycle-heuristic.
- README + QUICKSTART updated with the post-summarize loop.

**Scope reference:**
- DECISIONS 2026-04-25 "Lifecycle-phase as the curation heuristic" justifies bringing ship into ytstack core (lifecycle-gap, requires `.ytstack/` state for SUMMARY/STATE/DECISIONS reads).
- DECISIONS 2026-04-25 "Vendored-preamble drift accepted for wrapped skills" applies -- ship is the first concrete test; gstack-side preamble calls fail silently, ytstack injects own context via wrapper preamble.

**Plan via:** `ytstack:plan-milestone` -- not yet invoked.

---

## How to update this file

- When you start a milestone: flip its row to `in-progress` in Overview and in the milestone header
- When you complete a task: flip `[ ]` to `[x]`
- When you complete a milestone: flip to `done` and update the "Done" count
- Update `last_updated` and the `current_milestone` frontmatter field

Eventually this is automated via `ytstack:summarize-task` (M003).

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
| M011 | Post-Summarize Lifecycle (5-skill cherry-pick: ship + closure + PR-review + document-release) | planned | TBD | 0 |
| M012 | Swarm Fix-Pack (issues #16/#19/#20/#21: verification crash, advisory-hook exit, slice/task SSOT, session_id, backlog-sweep) | **done** (released v0.1.5) | 11 | 11 |
| M013 | spawn-milestone-team worktree mode (default-on worktree-per-teammate for parallel slices + merge step + shared-tree opt-out; per DECISIONS 2026-05-31 "ytstack encourages git worktree isolation") | planned | TBD | 0 |
| M014 | Vendor symlink dereferencing for RemotePluginSync compatibility (number reserved 2026-05-31 to resolve the M012 collision; uncommitted draft + README "Desktop + SSH" workaround in the `claude/thirsty-bhabha-a03490` worktree -- salvage/re-plan separately) | planned | TBD | 0 |
| M015 | post-tool-use-bash hook fix (issue #22): stub-once hook + commit-to-task linking moved to summarize-task; kills the duplicate "Commits so far" churn + never-settling tree that broke worktree/swarm dispatch. Regression test `tests/post-tool-use-bash.test.sh`. (v0.1.6) | **done** | 1 | 1 |

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
- Brownfield-without-.ytstack init MUST run a detect-analyze-migrate pass, not scaffold from empty templates. See "Scope clarification 2026-05-02" below.
- README documents all three workflows with diagrams; QUICKSTART covers all three.

**Scope reference:**
- DECISIONS 2026-04-24 "Greenfield-flow reorder" + DECISIONS 2026-04-24 "Wrapper mechanism = shell-exec inject + cross-ref check" originally merged this with wrapper-refactor as a single milestone. The wrapper-refactor part was completed in scope of those decisions; what remains is the workflow-reorder part PLUS the new brownfield-without-.ytstack case identified 2026-04-25.

**Scope clarification 2026-05-02 (from llm-wiki encounter):**

When a brownfield repo without `.ytstack/` is detected, the workflow needs an explicit *detect-analyze-migrate* phase before scaffolding. Symptom that surfaced this: existing project (`docs/design-decisions.md`, `docs/concept.md`, `docs/PROCESS.md`, `docs/plans/`, README, claude-memory `project_*.md`) is not greenfield-unvalidated, so plain `init-project` would create empty stubs that duplicate or contradict what already exists. Greenfield flow (office-hours → plan-ceo-review → init-project) doesn't fit either, because the project is already validated by months of artifacts.

What the brownfield-init flow needs:

1. **Detect** -- scan repo for ytstack-equivalent artifacts:
    - `docs/design-decisions.md`, `docs/decisions/*`, `docs/adr/*` -> candidate for `DECISIONS.md`
    - `docs/concept.md`, README sections, vision docs -> candidate for `PROJECT.md`
    - `docs/PROCESS.md`, `docs/runbook*`, `OPERATING.md` -> candidate for `RUNTIME.md`
    - `docs/plans/`, `ROADMAP.md`, `BACKLOG.md` -> candidate for `.ytstack/backlog/` + `ROADMAP.md`
    - `~/.claude/projects/<encoded>/memory/project_*.md` + `feedback_*.md` -> candidate for `KNOWLEDGE.md` + `PREFERENCES.md`
    - Any `AGENTS.md` / `CLAUDE.md` already referencing ytstack-equivalent concepts
2. **Analyze** -- present a mapping table to the user: what was found, where it would go, what's missing. Surface conflicts (e.g. two competing decision records). Surface gaps (no STATE.md equivalent exists anywhere).
3. **Migrate (with user approval per item)** -- options per artifact:
    - Move into `.ytstack/` (e.g. `docs/design-decisions.md` -> `.ytstack/DECISIONS.md`, update CLAUDE.md/README pointer)
    - Copy/extract subset (e.g. distill `docs/concept.md` into `PROJECT.md` while keeping the long-form doc public-facing)
    - Reference-only via pointer header (when the existing doc must stay where it is for external reasons)
    - Leave alone (artifact is genuinely public-doc, not project-memory)
4. **Scaffold gaps** -- only after migration, create empty `.ytstack/` files for slots that had no source artifact (typically `STATE.md`, `OFFICE-HOURS.md`-current).
5. **Update entry-point docs** -- CLAUDE.md / AGENTS.md / README pointers updated to reflect the new shape.

This is **not** a one-shot prompt; it's an interactive multi-step workflow with per-artifact user decision. Likely a new skill (`ytstack:adopt-brownfield` or similar) that `using-ytstack` routes to when it detects "no `.ytstack/` AND repo has >N candidate artifacts AND is not greenfield-empty".

Open design questions for `ytstack:plan-milestone` to resolve:
- Does the detect step produce a single migration-plan artifact (`.ytstack/ADOPTION-PLAN.md`) the user reviews before any moves happen, or per-artifact prompts inline?
- Where do non-trivial historical docs land (e.g. multi-year ADR archive) -- inline in `.ytstack/DECISIONS.md` or `decisions/archive/`?
- How does the migration interact with `office-hours` -- skip it (project already validated by track record), or run a retroactive condensed version to extract the implicit pitch?

**Plan via:** `ytstack:plan-milestone` -- not yet invoked.

---

## M011 -- Post-Summarize Lifecycle (5-skill cherry-pick) (planned)

**Goal:** Close the lifecycle arc between `summarize-task` and a released version. Today ytstack covers Plan -> Code -> Verify -> Close (`summarize-task`) and stops. Per DECISIONS 2026-04-25 "Lifecycle-phase as the curation heuristic" + 2026-04-25 "M011 scope -- 5-skill cherry-pick", ytstack covers the full dev-loop with a balanced cherry-pick across gstack (ship-mechanics) and superpowers (PR-review-cycle discipline).

**Exit criteria:**

Five new wrapper skills, in normal-flow order:

| # | Skill | Source | Purpose |
|---|---|---|---|
| 1 | `ytstack:finishing-a-development-branch` | `vendor/superpowers/skills/finishing-a-development-branch` | pre-ship closure discipline; ergaenzt verification-before-completion |
| 2 | `ytstack:requesting-code-review` | `vendor/superpowers/skills/requesting-code-review` | prepare + open PR with structured review request |
| 3 | `ytstack:receiving-code-review` | `vendor/superpowers/skills/receiving-code-review` | handle review feedback; classify, apply, re-request (loops with #2 until approved) |
| 4 | `ytstack:ship` | `vendor/gstack/ship` | bumps VERSION, writes CHANGELOG, creates PR-body, pre-merge safety checks, push, PR |
| 5 | `ytstack:document-release` | `vendor/gstack/document-release` | post-ship docs sync (README, ARCHITECTURE, CLAUDE.md, CHANGELOG, VERSION) |

Plus: README + QUICKSTART updated with the post-summarize loop diagram.

**Explicit out-of-scope** (per DECISIONS 2026-04-25 "M011 scope" Option C-rejection):
- `land-and-deploy`, `canary`, `setup-deploy` (gstack) -- deployment + monitoring are a different skill-class (infra / observability), planned for a future milestone if demand emerges.
- `qa` (gstack) -- testing methodology overlaps with ytstack's existing TDD + verification-before-completion.

**Scope reference:**
- DECISIONS 2026-04-25 "M011 scope -- 5-skill cherry-pick from gstack + superpowers" -- justifies the specific cherry-pick after re-reading the dev.to + medium comparison articles cited in `docs/concept.md`.
- DECISIONS 2026-04-25 "Lifecycle-phase as the curation heuristic" -- justifies bringing the ship-arc into ytstack core (lifecycle-gap, requires `.ytstack/` state for SUMMARY/STATE/DECISIONS reads).
- DECISIONS 2026-04-25 "Vendored-preamble drift accepted for wrapped skills" -- applies to all 5 wrappers; gstack-side preamble calls fail silently on `ship` and `document-release`, ytstack injects own context via wrapper preamble.
- Concept §3.6 "Future candidates (deferred)" listed `requesting-code-review` / `receiving-code-review` as v0.2 candidates; M011 pulls them forward.

**Plan via:** `ytstack:plan-milestone` -- not yet invoked.

---

## How to update this file

- When you start a milestone: flip its row to `in-progress` in Overview and in the milestone header
- When you complete a task: flip `[ ]` to `[x]`
- When you complete a milestone: flip to `done` and update the "Done" count
- Update `last_updated` and the `current_milestone` frontmatter field

Eventually this is automated via `ytstack:summarize-task` (M003).

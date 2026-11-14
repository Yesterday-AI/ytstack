---
project: ytstack
last_updated: 2026-11-13T16:50:00Z
total_milestones: 24
completed_milestones: 20
current_milestone: none (M022, M023 and M024 done 2026-11-13; M020 planned, M014 reserved, M011 and M013 absorbed into M019)
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
| M010 | Workflow Reorder + Brownfield-Without-.ytstack (issue #18) -- `adopt-brownfield` skill, shared `yt_brownfield_signals`, init-project routing, SessionStart hint, `tracker:` in STATE.md. Ships in 0.4.0 (CHANGELOG [Unreleased]). | **done** | 6 | 6 |
| M011 | Post-Summarize Lifecycle (5-skill cherry-pick: ship + closure + PR-review + document-release) -- absorbed into M019-S03 (superpowers skills inline + Namespace note, gstack skills via the installed-dependency contract) | absorbed into M019 | 0 | 0 |
| M012 | Swarm Fix-Pack (issues #16/#19/#20/#21: verification crash, advisory-hook exit, slice/task SSOT, session_id, backlog-sweep) | **done** (released v0.1.5) | 11 | 11 |
| M013 | spawn-milestone-team worktree mode (default-on worktree-per-teammate for parallel slices + merge step + shared-tree opt-out; per DECISIONS 2026-05-31 "ytstack encourages git worktree isolation"). Unblocked by M016 (hooks are worktree-safe); absorbed into M019's execution-model work. | absorbed into M019 | 0 | 0 |
| M014 | Vendor symlink dereferencing for RemotePluginSync compatibility (number reserved 2026-05-31 to resolve the M012 collision; uncommitted draft + README "Desktop + SSH" workaround in the `claude/thirsty-bhabha-a03490` worktree -- salvage/re-plan separately) | planned | TBD | 0 |
| M015 | post-tool-use-bash hook fix (issue #22): stub-once hook + commit-to-task linking moved to summarize-task; kills the duplicate "Commits so far" churn + never-settling tree that broke worktree/swarm dispatch. Regression test `tests/post-tool-use-bash.test.sh`. (v0.1.6) | **done** | 1 | 1 |
| M016 | Worktree-safe hooks + out-of-tree state (issues #24/#26/#27; report points 1-3) -- `hooks/lib/git-ctx.sh`, volatile state under `CLAUDE_PLUGIN_DATA`, HANDOFF never overwritten, hooks.json to platform state, `git rev-parse` in all preambles, configurable commit-ref discovery. Release **0.2.0** (tag local; push = operator). | **done** | 15 | 15 |
| M017 | Vendor strategy (issue #25; report point 6; DECISIONS 2026-11-07) -- superpowers at v7.0.2 + inline-leak check; gstack de-vendored into a tag-pinned installed dependency (precheck + Skill-tool invocation, live-validated); SECURITY.md; release **0.3.0** (tag local; push = operator). | **done** | 7 | 7 |
| M018 | Ceremony scaling + STATE pointer validation (report point 5) -- `granularity`/`autonomy`/`quick_lane`/`minimal_code` preferences, `quick-task`, states incl. `dropped`/`shipped-informally`, `yt_state_lint` + session-start injection, `reconcile`, `minimal-code` guard (ponytail concept), read-side layouts. Per-worktree `active_task` deferred to M019. Ships in 0.4.0. | **done** | 11 | 11 |
| M019 | Skill quality, evals, execution model (report point 7 + developer-skills research; absorbs M013) -- trigger-only descriptions within the 1,536-char budget (mattpocock/Anthropic criteria, superpowers' "never summarise the workflow"), `tier`/`version` -> `metadata`, `disable-model-invocation`/`user-invocable` instead of `tier`, `claude plugin eval` suite + CI gate, new skills `code-review` (standards + spec reviewers), `pr`, `retro`, `grilling`, `writing-for-agents` wrapper; orchestrator + `Agent(isolation: worktree)` slices with `worktree.baseRef: head`, verifier Stop-hook; listing on skills.sh; version bump discipline. Released 0.4.0 -> 0.4.1 (Codex merge, PR #23) -> 0.4.2 (Linux `stat` fix), all pushed with green CI 2026-11-07. Shipped: `metadata:` + trigger-only descriptions + checker rules (S01), `evals/` 13 cases + CI (S02), `code-review` / `finish-branch` / `grill` / `retro` / `ship` / `document-release` (S03, absorbs M011), `spawn-milestone-team` 0.2.0 orchestrator + worktree subagents with Agent Teams opt-in, agents to the subagent contract, Stop hook (S04), release 0.4.0 (S05). Not done: `writing-for-agents` wrapper (no consumer asked), skills.sh listing (operator action). | **done** | 18 | 18 |
| M020 | Candidates, not planned (pick with `ytstack:plan-milestone`): (a) dogfood `spawn-milestone-team` 0.2.0 on a real multi-slice milestone (orchestrator + worktree subagents, merge step, STATE resolution) and fix what the live run shows; (b) Codex host: verify the SessionStart `additionalContextLimit` (REVIEW-NOTES 2026-11-07) and the hook-free flow on a real Codex install; (c) PowerShell hook variants when a Windows consumer appears; (d) per-worktree STATE pointer if (a) needs it; (e) re-run the consumer audit (`docs/research/2026-11-07-notes/local-consumer-repos-audit.md`) after the 17 repos update to 0.4.x. | candidate | TBD | 0 |
| M021 | Status line segment (issue #31) -- `bin/ytstack-status`, optional `progress` block in the `STATE.md` frontmatter, `yt_progress_parse` + STATE lint W7, upkeep in `summarize-task` / `quick-task`, `docs/statusline.md`. Done 2026-11-11 (2 slices, 5 tasks); released in 0.5.0. Numbered M021 because M020 is taken by the Kimi adapter planning (issue #30). | **done** | 5 | 5 |
| M022 | Technical spec (issue #36) -- new artifacts `.ytstack/spec/SPEC.md` and `.ytstack/spec/<area>.md` that state what applies now; `bin/ytstack-spec` (lint, drift, impact); the loop keeps them true; ytstack's own spec. S01 to S03 built 2026-11-13 (S03: `STATE.md` as a pointer with lint W8/W9, "Next action" cut to fit, history out through `reconcile`, milestone fold, fresh-session cases). Section "Planned 2026-11-13" below. | **done** | 15 | 15 |
| M023 | Bounded work (issue #35) -- `minimal-code` as the one work contract for code, evidence and reports; `bin/ytstack-brief` (rendered brief with the contract, report check); runs and environment in the plan; gates with one question and two progress numbers in `reassess-roadmap`; review rounds, assumed load and evidence identity. Built 2026-11-13. Section "Planned 2026-11-13" below. | **done** | 8 | 8 |
| M024 | Coordinator mode (issue #34) -- formats in `docs/ux/coordinator-format.md`; `LANES.md` with `bin/ytstack-frontier` (blocking edges, claims, the frontier); lane kinds and three more report labels; `bin/ytstack-finish-lane` + `finish-lane`; `handover-step` + `bin/ytstack-handover`; `questions/` + `bin/ytstack-questions`; `STANDING.md`; `coordinate` + `bin/ytstack-watch`; `lane-retro`. Built 2026-11-13; not yet run against a real pull request host (gate G01 in `M024-S02-PLAN.md`). | **done** | 12 | 12 |
| M028 | Ship the six gstack skills as ytstack's own adaptations (DECISIONS 2026-11-14) -- self-contained `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship`, `document-release` (no gstack install, nothing in `~/.claude/skills/`), `metadata.upstream` baselines, `bin/ytstack-gstack-diff` + release-checklist step, synced to gstack v1.99.3.0. Done 2026-11-14 (3 slices, 11 tasks); released in 0.6.0 (PRs #39, #40). M022-M027 are carried by open PRs #37/#38. | **done** | 11 | 11 |

**Total:** 39 tasks across M001-M009, 37 done (95%). 2 deferred to user action (git init + push, GitHub repo creation). M010 done (6/6, 2026-11-07); M011 task count pending milestone planning.

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

## M010 -- Workflow Reorder + Brownfield-Without-.ytstack ✓ done

**Shipped 2026-11-07** (6 tasks, one slice; detail in `M010-CONTEXT.md`, `M010-ROADMAP.md`, `M010-S01-PLAN.md`, `M010-S01-T0#-SUMMARY.md`). Part 1 (greenfield reorder) was already in place via the `using-ytstack` directive + session-start greenfield block. Part 2 shipped as `skills/adopt-brownfield/SKILL.md` + `yt_brownfield_signals` in `hooks/lib/git-ctx.sh`; `init-project` and `hooks/session-start` route to it at >= 2 signals. The open design questions below were resolved in DECISIONS 2026-11-07 "Brownfield adoption is a reference-first distillation, never a pitch": inline per-artifact questions recorded in PROJECT.md's Adoption table (no `ADOPTION-PLAN.md`); ADR archives stay in place and are listed by reference; office-hours is skipped for existing products. Original scope note kept below for history.

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

## M011 -- Post-Summarize Lifecycle (5-skill cherry-pick) (absorbed into M019-S03, done)

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

## M016 -- Worktree-safe hooks + out-of-tree state ✓ done (released 0.2.0)

**Goal:** Stop every hook from writing into a checkout the user did not choose, and stop writing volatile session state into tracked files at all. Closes #24, #26, #27. Design locked in DECISIONS 2026-11-07 "Hooks never write relative to CLAUDE_PROJECT_DIR".

**Exit criteria:**
- `hooks/lib/git-ctx.sh` exists (bash 3.2, no arrays): reads `cwd` + `session_id` from stdin JSON, resolves toplevel / git-dir / common-dir with `--path-format=absolute` (fallback `--absolute-git-dir`), canonicalises paths, sets `YT_IS_LINKED`, derives the repo key as sha256 of the common dir. All hooks and all skill preambles source it; no `CLAUDE_PROJECT_DIR` write target and no `basename` slug remains (`bin/ytstack-check` rule).
- Auto handoff, journal and locks live under `${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_STATE_HOME:-$HOME/.local/state}/ytstack}}/repos/<key>/worktrees/<key>/sessions/<session_id>/` with a `latest-handoff` symlink; `resume-session` + `session-start` read both locations.
- `pre-compact` never overwrites `.ytstack/HANDOFF.md`; it emits compaction instructions (< 10,000 chars) on stdout.
- `post-tool-use-bash` stubs only in the committing worktree and only when the commit subject matches the task ref (`commit_ref_pattern` from `PREFERENCES.md`, default `^M###-S##-T##:`).
- `session-end` fits the 1.5 s plugin budget (one append, no git calls) or the journal is dropped.
- `hooks/hooks.json`: `SessionStart` matcher includes `fork`; `"shell": "bash"` + powershell variant; `onFailure: "block"` only on `pre-tool-use-edit`.
- `summarize-task` + `init-project` use `git rev-parse --is-inside-work-tree`; commit discovery falls back to `git log <base>..HEAD` for squash-merge repos; `~/.ytstack/.init-project-<slug>-*` sentinels replaced by `PROJECT.md` frontmatter.
- `init-project` writes a `.gitignore` block for `.ytstack/.local/` (fallback state dir). `HANDOFF.md` stays user-owned and committable and is NOT gitignored.
- `tests/` cover main checkout, linked worktree (`.git` file), session in main with commands in a worktree, two concurrent sessions; acceptance: main byte-identical before/after each hook (criteria from #26).
- `plugin.json` 0.1.6 -> 0.2.0, CHANGELOG entry, `/plugin update` note.

**Plan via:** `ytstack:plan-milestone`.

---

## M017 -- Vendor strategy ✓ done (released 0.3.0)

**Goal:** Execute DECISIONS 2026-11-07 "Vendor strategy": superpowers subtree to `22f0b46` (v7.0.2) with namespace/relative-link leak check; gstack de-vendored into a tag-pinned installed dependency. Closes #25 (vulnerable vendored `Dockerfile.ci` leaves the repo).

**Exit criteria:** `vendor/gstack/` removed; wrapper preambles for office-hours / plan-ceo-review / plan-eng-review check `~/.claude/skills/gstack/` (+ Bun >= 1.4.2) and degrade with a clear message; `init-project` precheck; README, QUICKSTART, `docs/concept.md`, `NOTICE`, `VENDOR-INVENTORY.md` updated; `SECURITY.md` note that vendored CI files are never built here; `bin/ytstack-check` flags `superpowers:` namespace leaks in inlined text.

**Plan via:** `ytstack:plan-milestone`.

---

## M018 -- Ceremony scaling + STATE pointer validation ✓ done (in 0.4.0)

**Goal:** Make the M/S/T loop fit real usage (audit: 7/17 brownfield, 3 repos on Ralph-loop autonomy, ceremony skipped under delivery pressure with no state for it, STATE pointer drift M034 vs M040). Report point 5; details in `docs/research/2026-11-07-modernisierung-best-practices.md`.

**Plan via:** `ytstack:plan-milestone`.

---

## M019 -- Evals, budgets, execution model ✓ done (in 0.4.0; absorbed M011 and M013)

**Goal:** `claude plugin eval` suite per wrapper skill; skill descriptions within the 1,536-char / 1 % listing budget; `tier`/`version` under `metadata`; `spawn-milestone-team` rebuilt as orchestrator + `Agent(isolation: "worktree")` per slice (`worktree.baseRef: "head"`), verifier Stop-hook; release discipline (`plugin.json` bump + `claude plugin tag`). Report point 7.

**Plan via:** `ytstack:plan-milestone`.

---

## Planned 2026-11-13 -- issues #35, #36 and #34

Three issues from one consumer migration: #35 (bound verification, review and orchestration work), #36 (current technical specification) and #34 (coordinator mode). The measurements are in the issues and in the comments of 2026-11-13 on #35 and #36. This section fixes the order, who builds what where the issues overlap, and the exit criteria. Slices and tasks come from `ytstack:slice-milestone` when each milestone starts.

**Numbers:** the technical spec is M022 and bounded work is M023 (M020 is the Kimi adapter, planned in the main checkout and not committed; M021 is the status line segment). Coordinator mode takes the next free `M###` when it starts. Detail lives in `M022-*.md` and `M023-*.md`; where those files and this section differ, the milestone files apply.

**Corrections of 13 November 2026** (review comment on #36, applied before the affected rules were built):

1. A documentation impact is satisfied by a change to the area file **or to the authoritative source it names**. A correct pointer is not edited to close a task.
2. The drift report is a prompt to look ("possible documentation impact"), not a finding. "Contract unchanged" is a valid answer and is recorded by setting `verified_at`. A change to a source counts like a change to the area file.
3. A scaffold from a pitch is `status: planned` with `verified_at: none`. Planned, implemented-and-checked, and deployed-or-accepted are three different statements; the spec makes only the first two.
4. The plan and the work live on the branch `spec-and-bounded-work` in a worktree of its own, not in the shared main checkout.

### Order

1. **Technical spec (#36).** First, by the operator's priority of 13 November 2026. Its slices S1 and S2 can start now: the spec artifacts, their templates and the loop changes touch neither `hooks/session-start` nor `STATE.md`, the two files M020 has open. Only S3 waits for M020.
2. **Bounded work (#35).** Second.
3. **Coordinator mode (#34).** After both: it builds on the lane contract of 2 and on the STATE rules of 1.

1 and 2 run one after the other, not in parallel: both edit `plan-task`, `code-review`, `reassess-roadmap` and the verifier agent.

### Overlap -- each thing is built once

| Topic | #34 | #35 | #36 | Built in |
|---|---|---|---|---|
| Brief and report contract for a dispatched agent | item 3, lane contract | "rules must reach agents dispatched with a brief" | parallel work gets a bounded scope and the applicable contracts | Bounded work S1. #34 keeps only the coordinator-specific lane types. |
| A step or verdict only the human can give | item 6, decision queue; item 5, handover step | point 4; comment: who gives the verdict, how it is obtained, when it lapses | unresolved decisions are identifiable | Bounded work S2 defines the gate fields and the detection, carried in the existing open-decisions list. #34 item 6 replaces the carrier with queue files. |
| Review round and evidence tied to a commit | item 4, finishing pipeline; lanes table columns "reviewed head, round" | points 2 and 3 | -- | Bounded work S3 defines round and evidence identity. #34 item 4 builds the host pipeline on them. |
| STATE as a pointer | item 2, lanes table; item 1, host facts never stored as current | point 5, accurate pointers, no history at startup | point 6 and comment: size bound | Technical spec S3. The lanes table of #34 has to fit under that bound. |
| Pointers instead of copies in a handoff | "smaller ones", `handoff-session` | -- | integration point `resume-session` / `handoff-session` | Technical spec S2. |
| What a dispatched agent reads for context | item 3: rules reached by pointer, not pasted | "bounded context" in briefs | the spec artifacts | Technical spec S1 creates the area files; the brief of Bounded work S1 points at the area file instead of plans and history. |
| Dispatch by dependency, frontier, claims | item 2 | point 5, one sentence | -- | #34. |
| Coordinator context: rotation through a handoff, polling outside the model, standing instructions in a file | item 1 | points 5 and 6; comment, measured | -- | #34. |
| A mechanical mistake becomes a check, not prose | item 7, lane retros | comment: the consumer's prose rules did not hold | -- | Principle used in Bounded work S3 (round count); the retro itself stays in #34. |
| Hosts without hooks (#28 OpenCode, #29 Vibe, #30 Kimi / M020) | brief rendered for `codex exec` too | reach must not depend on skill invocation | "hook support must not be the only route" | Constraint on Bounded work S1 and Technical spec S1 and S2: the contract and the spec live in repository files and skill text; a hook is an optional enhancer. |

Closed issues that set boundaries: #21 and #31 read the STATE frontmatter (the size bound must leave it unchanged), #26 and #27 forbid hook writes into the shared checkout, #16 already added the backlog sweep that the fold step of Technical spec S3 extends.

### Technical spec (issue #36)

**Goal:** A fresh session finds what applies now for an area, where it is implemented and how a change is verified, in one spec file per area, without reading plans and history.

**Decision (operator, 13 November 2026):** the technical spec gets artifacts of its own, and they come first. This departs from #36 as written, which says "do not mandate a new folder tree". What #36 protects stays: an existing architecture document keeps its authority, and nothing is copied (see "pointer-only" below). The DECISIONS entry is written when the milestone starts.

**New artifacts** (every ytstack project has them, at the same paths):

| Artifact | What it holds |
|---|---|
| `.ytstack/spec/SPEC.md` | The entry point. One page: what the system is, the areas with one line each and a link to each area file, the invariants that hold everywhere, the commands to build and test. The first thing a new session reads after `STATE.md`. |
| `.ytstack/spec/<area>.md` | One file per system area, describing the area as it is now. Fixed sections: Purpose; Behavior; Interfaces and contracts (links into code, schemas and API definitions, no copies); Data flow; Invariants and security boundaries; Error behavior; Runtime and deployment assumptions; Known limits; Where implemented; How to verify; Decisions that apply now (links to the decision entries, a partial narrowing included). |
| Frontmatter of an area file | `area`, `paths` (the globs of the code it describes), `verified_at` (the commit it was last checked against), `sources` (existing documents that stay authoritative, optional). |
| Frontmatter, continued | `status`: `planned` (the approved design, not built or not checked), `partial`, `implemented` (exists at `verified_at`, its checks passed there). Never a statement about deployment or acceptance. |
| `bin/ytstack-spec` | `lint`: the format. `drift`: the areas whose `paths` changed after the area file and its `sources` were last touched, as a possible documentation impact. `impact`: a task's "Spec impact" against what the task changed. `areas`: which area describes a path. (Planned as `bin/yt-spec-drift`; one script with the repository's `ytstack-` prefix instead.) |
| `docs/ux/spec-format.md` | The format contract for both files and the maintenance rules. |

An area file is rewritten when the area changes; it is a current description, not a log. Plans, summaries and decisions stay the history and are linked from it. **Pointer-only:** where a project already has an authoritative document for an area, the area file holds the frontmatter, the links and the sections that document lacks, and `sources` names the document.

**Exit criteria:**

- `init-project` scaffolds `SPEC.md` and the area files from the pitch and the engineering review, every area `planned` and unverified; `adopt-brownfield` builds them over the existing documents and its four codebase maps, pointer-only where a document exists.
- ytstack has its own `.ytstack/spec/` (areas at least: skills and wrappers, hooks and state, the artifact model, host adapters, the vendored and installed dependencies, checks and evals), and its entry documents agree with the repository: `PROJECT.md` (says M001 in progress and gstack vendored), `KNOWLEDGE.md` line 7 (denies the CI gate that `ci.yml` and `plugin-check.yml` run), this file (frontmatter names 11 milestones and M016 as current; the sections M016 to M019 are headed "planned" while the overview says done; the M020 row says "candidates") and `STATE.md`.
- The task-plan template has a "Spec impact" field naming the area file and section a task changes, or "none"; a new-requirement case produces a plan with it.
- A task whose plan names a spec impact is not summarized unless the area file or one of its `sources` changed in the task's commits, checked from the commits and not from the summary's wording; a bug fix that restores the described behavior, a refactoring and a trivial edit close with "none".
- `bin/ytstack-spec drift` lists an area whose `paths` changed after its description was last touched, stays silent for an untouched one and after `verified_at` was set to the checked commit; `ytstack-check` runs `lint` and `drift` on ytstack's own spec.
- `yt_state_lint` warns when `STATE.md` exceeds the size bound or carries history; the SessionStart injection names `SPEC.md` and shows "Next action" again instead of "omitted ... near the 10,000-char cap".
- Closing a milestone folds what still holds into the area files and offers that milestone's plans and summaries for archiving through `reconcile`; nothing moves without consent.
- Three fresh-session cases (resume, bug fix, new requirement) on one repository snapshot, current against revised instructions, the session allowed to read `STATE.md` and `.ytstack/spec/` first: accuracy, contradictions met, reading effort.

**Slices:**

- S1 -- The spec artifacts exist, and ytstack has its own. The format of `SPEC.md` and of an area file as a contract under `docs/ux/` and a section in `docs/concept.md`; the templates in `init-project` and `adopt-brownfield`; ytstack's own `.ytstack/spec/`; the reconciliation of its entry documents.
- S2 -- The loop keeps the spec true. The "Spec impact" field in `plan-task`; the closure check in `summarize-task` against the task's commits; `bin/ytstack-spec` and its place in `ytstack-check`; a spec check in `code-review` and the verifier, bounded to the touched area; "Decisions that apply now" maintained when a decision is added; `resume-session` and `handoff-session` point at `SPEC.md` instead of copying.
- S3 -- STATE stays a pointer, milestone close folds, fresh sessions prove it. The size bound in `yt_state_lint`; the `SPEC.md` pointer in the SessionStart injection; history out of `STATE.md` with consent; the fold step in `reassess-roadmap` or `retro` with the archive offer through `reconcile`; the three cases with their baseline. **Depends on M020 landed** (`hooks/session-start`, `STATE.md`).

**Not in scope:** the full twelve sections of arc42, a documentation generator, copies of existing documents, any migration of a consumer's artifacts.

**Open questions for slicing:** how a project names its areas (proposed by `adopt-brownfield` from the codebase maps, confirmed by the human); whether `.ytstack/codebase/` of `adopt-brownfield` is folded into `.ytstack/spec/` or kept beside it; the size bound of an area file.

### Bounded work (issue #35)

**Goal:** An agent dispatched on a ytstack project finishes the agreed task with the smallest sufficient evidence, a review ends after its fix round, and a plan row that no work can close reaches the human as one question.

**Exit criteria** (each a case under `evals/` or a fixture under `tests/`, compared with the current instructions on the same input):

- A plan that asks for one pass of 44 scenarios stays at 44 unless a named failure or requirement justifies more.
- A finding the project's policy rates non-blocking stays a tracked follow-up and holds nothing; an open residual-risk acceptance appears in the consolidated question to the human.
- A follow-up review covers the fix and its consequences; an authorization or data-loss defect the fix introduced still blocks; a third round yields a diagnosis of scope or conflicting rules, not another review.
- A fresh verifier accepts evidence for the same commit, environment and check; a changed head gets the check again.
- A general-purpose subagent dispatched with the rendered brief has the work contract without invoking a skill; a validator rejects a report with a missing field.
- `reassess-roadmap` lists, in one question, a row gated on a human verdict and a row gated on a condition that can no longer be met, each with who decides, how and when the gate lapses; rows that work can close are not listed.
- A review opens with the load and the product stage it assumed, taken from the project's documents. A scale finding is rated against that load; a `shortcut:` comment that names its limit is a decision, not a finding. Case: a slow path at a volume the stated load never reaches is at most a note.
- A report ends with what was not run or not checked, and why.
- Correctness and completeness are not worse than the baseline; rounds, turns and cost are recorded in `KNOWLEDGE.md` ("Eval runs"; `evals/results/` is gitignored).
- `bin/ytstack-check` and `tests/run-all.sh` pass; no file under `vendor/` changed.

**From Ponytail** (reviewed 13 November 2026 at 5.3.3, `96608e0`: the skill, the review command and the agentic benchmark of 2026-10-07; concepts only, ytstack's own prose, NOTICE extended). `minimal-code` 0.1.0 carries the ladder of an older Ponytail; what the current one adds and ytstack lacks:

- Reach before size: list every place the change must reach (callers, tests, fixtures, config, exports) and what it could break, then pick the smallest solution. Lazy about the solution, never about the change.
- A bug fix greps every caller and fixes the cause once in the shared code; moved or merged code keeps its validation and error handling; between options of equal size the one that is right on edge cases wins.
- A trivial change needs no test. The benchmark shows the opposite pull too: with the skill a test appeared where none was needed in 45 % of cells against 36 % without, so the rule needs its own case.
- The shortcut comment names the limit and when to upgrade.
- The review command: every finding has a concrete case confirmed by re-reading the lines; findings are grouped Must fix / Should fix / Nice to have and each says what happens if it is skipped; the review states the load it assumed and ends with "Not checked".
- The method: a rule change has to beat the current rules in a paired run, one change at a time, several runs per case with the median, hidden checks for correctness, a blind completeness judge, isolated sessions. Its limit, stated upstream: shell execution is disabled, so it shows nothing about multi-agent orchestration.

Not taken over: the levels lite / full / ultra (ytstack has the `minimal_code` preference and `grill`), the session-wide mode switch, the reply style rules beyond the closing line.

**Slices:**

- S1 -- The work contract reaches every dispatched agent. One ytstack-owned directive text: `minimal-code` extended from "smallest code" to "smallest complete change with the smallest sufficient evidence" (reach before size, the caller rule, no test for a trivial change, the closing line), not a second directive beside it; pointers from `using-ytstack` and the three agent definitions; brief and report templates under `skills/spawn-milestone-team/`, rendered the same for a Claude subagent and for `codex exec`; the report validator.
- S2 -- Completion and gates are defined before execution. `plan-task` and `slice-milestone` record repetitions, sampling and environment of the verification; a gate names who gives the verdict, how it is obtained and when it lapses; `reassess-roadmap` detects rows no work can close and repeated work that does not advance completion, and reports progress as two numbers (closed by work, accepted).
- S3 -- Reviews and evidence stay bounded. `code-review`: the assumed load and stage stated first, a concrete case per finding, "if skipped" per finding, complete first round, fix-only follow-up, a recorded round count, diagnosis at the third round, the project's severity policy respected. Verifier and `verification-before-completion`: evidence identity and the reasons that renew it, resolving the conflict with the verifier's cold re-run rule. The eval cases and the baseline run.

**Not in scope:** coordinator rotation, polling outside the model, frontier and claims (#34). For point 6 of #35 nothing is built: the three agents already declare `model: inherit`.

**Open questions for slicing:** how many runs per case the comparison needs and what it may cost (`claude plugin eval` runs one arm with the plugin; current against revised rules needs two plugin directories); where the round count lives when no pull request host exists; whether the host offers an event at subagent start (`hooks/hooks.json` registers none today) and what #28 to #30 offer instead.

### Coordinator mode (issue #34) -- candidate

What is left of its seven items once the two milestones above are done:

- Item 1, coordinator mode, extended by the three measured points of the comment on #35: rotation through a handoff at a context or compaction threshold, polling by a script that emits events, a standing instruction of the human written to a file when it is given.
- Item 2, blocking edges, claims, the frontier and the lanes table, sized to the STATE bound.
- Item 3, lane contract: delivered by Bounded work S1; only the coordinator-specific lane types remain.
- Item 4, finishing pipeline, on the round count and evidence identity of Bounded work S3.
- Item 5, handover step.
- Item 6, decision queue, replacing the carrier of Bounded work S2.
- Item 7, lane retros that end in checks.

**Plan via:** `ytstack:plan-milestone`, one milestone at a time.

---

## How to update this file

- When you start a milestone: flip its row to `in-progress` in Overview and in the milestone header
- When you complete a task: flip `[ ]` to `[x]`
- When you complete a milestone: flip to `done` and update the "Done" count
- Update `last_updated` and the `current_milestone` frontmatter field

Eventually this is automated via `ytstack:summarize-task` (M003).

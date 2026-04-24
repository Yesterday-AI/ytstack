---
title: ytstack -- Concept Paper
status: draft
approval: not yet approved -- README.md remains authoritative until the user explicitly signs off on this paper
last_updated: 2026-04-24
purpose: condensed reference for the ytstack plugin so future sessions do not reconstruct the architecture from memory. Every section below is synthesized from a primary source listed in its body. No independent interpretation.
sources_of_record:
  - /Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack/README.md  (authoritative)
  - /Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack/.ytstack/DECISIONS.md  (locked decisions, append-only)
  - /Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack/docs/methodology.md  (adaptation provenance)
  - /Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack/.ytstack/PROJECT.md  (one-liner + why it exists)
  - /Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack/CLAUDE.md  (agent-facing contributor rules)
  - /Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack/.ytstack/VENDOR-INVENTORY.md  (full upstream skill listing)
source_articles_analyzed:
  - https://dev.to/imaginex/a-claude-code-skills-stack-how-to-combine-superpowers-gstack-and-gsd-without-the-chaos-44b3
  - https://medium.com/@tentenco/superpowers-gsd-and-gstack-what-each-claude-code-framework-actually-constrains-12a1560960ad
---

# ytstack Concept Paper (DRAFT, not yet approved)

> **README.md is the authoritative source of truth.** This paper is a condensed derivative intended to survive context compaction and give future sessions a clear reference. Where this paper and README disagree, README wins until a user signs off on this paper. If you notice a discrepancy, do not silently "fix" either side -- flag it and ask.

## 1. Purpose

From `README.md` §opening + PROJECT.md one-liner:

- **What:** "Working memory for AI coding agents." A Claude Code plugin that turns multi-session, multi-week projects into something an agent can hold onto. Project memory on disk, curated skill set, parallel execution via native Agent Teams. One install, one namespace.
- **Why:** AI coding agents are excellent inside a single session and fall apart between them. Long projects rot; context-window pressure makes the agent forget early decisions. ytstack removes the "remind me what we were working on" ritual.

## 2. The three upstream sources and their roles

Verbatim facts from `README.md` §"Why it exists":

### 2.1 gstack (Garry Tan) -- vendored at `vendor/gstack/`

- **Strength:** strategy and decision rigor -- CEO / eng-manager / office-hours reviews that force real thinking before code.
- **Also ships:** execution skills (`investigate` for systematic debugging, `qa`, `review`, `ship`) and session-level context save/restore.
- **Lacks:** explicit TDD enforcement, structured milestone / slice / task artifact hierarchy.
- **Upstream:** https://github.com/garrytan/gstack

### 2.2 superpowers (Jesse Vincent / obra) -- vendored at `vendor/superpowers/`

- **Strength:** execution discipline -- TDD, systematic debugging, verification-before-completion.
- **Also ships:** planning skills (brainstorming, writing-plans, executing-plans).
- **Lacks:** business-strategy reviews (no CEO / founder-mode diagnostics, no YC-office-hours forcing questions); on-disk project memory that persists across sessions.
- **Upstream:** https://github.com/obra/superpowers

### 2.3 GSD (Get Shit Done) -- influence, not vendored

- **Strength:** project management -- milestones, slices, tasks, artifact-as-memory, cross-session continuity.
- **Requirement that we reject:** a separate TypeScript runtime with its own CLI and TUI. We replicate the 80/20 via skills + hooks + Claude Code's native Agent Teams (per DECISIONS 2026-04-23 "Don't rebuild GSD as TypeScript runtime").
- **Upstream:** https://github.com/gsd-build/gsd-2

## 3. The curation

From `README.md` §"ytstack is the curation" + `DECISIONS.md` 2026-04-23 "Cherry-pick prioritization based on production evidence".

### 3.1 Wrapped (ytstack surfaces these as `/ytstack:<name>`)

Per README comparison table and DECISIONS:

| Skill | Upstream | Role (per README) |
|---|---|---|
| `plan-ceo-review` | gstack | "CEO / founder-mode strategy review" |
| `plan-eng-review` | gstack | "Engineering plan / architecture review" |
| `office-hours` | gstack | "YC-office-hours forcing diagnostics" |
| `test-driven-development` | superpowers | "TDD as enforced discipline" |
| `systematic-debugging` | superpowers | "Systematic debugging with root-cause gate" |
| `verification-before-completion` | superpowers | "Verification-before-completion gate" |

### 3.2 Explicitly skipped (verbatim from README §"ytstack is the curation")

| Skill | Upstream | Why skipped (README verbatim) |
|---|---|---|
| `investigate` | gstack | "gstack's `investigate` duplicates superpowers' `systematic-debugging`" |
| `writing-plans` | superpowers | "superpowers' `writing-plans` conflicts with our milestone / slice / task flow" |

README closes the clause with "etc." -- no other specific skips are on record. All other upstream skills are outside the current cherry-pick scope but without a dedicated skip-decision; adding any requires a DECISIONS entry. See `.ytstack/VENDOR-INVENTORY.md` for the full upstream listing.

### 3.3 Wrapper mechanism (locked)

Per DECISIONS 2026-04-24 "Wrapper mechanism = shell-exec inject + cross-ref check", every ytstack wrapper is a thin SKILL.md that:

1. Declares minimal frontmatter (`name`, `description`, `allowed-tools`).
2. Runs a shell preamble (```` ```! ```` fenced block) that resolves ytstack context: `_YT_DIR`, `_CURRENT_MILESTONE`, active-task paths, extracted verification commands.
3. States "ytstack invocation notes" -- what to treat as the review subject / work unit, HARD-GATE conditions when ytstack state is missing, and post-procedure outcomes (DECISIONS.md append, ROADMAP edit, KNOWLEDGE.md lesson).
4. Ends with ```` ```! \ncat "${CLAUDE_PLUGIN_ROOT:?}/vendor/<src>/SKILL.md"\n``` ```` which inlines the vendored procedure verbatim at render time.

**Vendor is the single source of truth.** `./sync-upstream.sh` updates flow through without manual adaptation; no fork divergence possible by construction.

Applies to: `plan-ceo-review`, `plan-eng-review`, `office-hours` (vendor/gstack) + `test-driven-development`, `systematic-debugging`, `verification-before-completion` (vendor/superpowers/skills).

**Supersedes:** the earlier 2026-04-23 "Known risk -- superpowers interactive prompts may block Claude Code input" rule that required every superpowers wrapper to pass `YTSTACK_NON_INTERACTIVE=1`. That rule was a defensive workaround for a different wrapper shape (prose indirection telling the agent to "read vendor file and follow it"). Shell-exec-inject sidesteps the interactive-prompt risk because the vendor content is inlined as the same turn's prompt, not re-invoked as a separate Claude Code interaction.

**Cross-ref check:** `bin/ytstack-check` now parses each vendored SKILL.md inlined by a ytstack wrapper and flags sibling-skill references (backtick-quoted or `/slash-command`) that ytstack does not itself wrap. Surfaces dangling invocations before they ship. First run (2026-04-24) flagged ~90 sibling references from gstack's interconnected skill set; human triage decides per case (wrap / strip-ref-in-docs / accept-gap).

### 3.4 Native components (ytstack authors these; no upstream equivalent used)

Lifecycle + artifact + orchestration pieces that GSD inspired but we re-implement in-plugin:

**Skills** (project-OS lifecycle):
- `init-project` -- scope decision + create `.ytstack/` artifacts
- `plan-milestone` -- define a milestone (goal, exit criteria, size)
- `slice-milestone` -- break a milestone into slices + tasks
- `plan-task` -- detail a single task (fits-one-context-window)
- `summarize-task` -- close a task, write summary, update STATE.md
- `reassess-roadmap` -- post-slice sanity check
- `handoff-session` -- write rich handoff file for pause / team handoff
- `resume-session` -- read state + handoff + recent summaries, brief agent
- `spawn-milestone-team` -- dispatch Agent Teams for parallel slice execution
- `using-ytstack` -- meta-directive injected by SessionStart hook

**Artifacts** (git-tracked Markdown under `.ytstack/`):
- `PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, `RUNTIME.md`, `PREFERENCES.md`
- Per-milestone: `M###-CONTEXT.md`, `M###-ROADMAP.md`
- Per-slice: `M###-S##-PLAN.md`
- Per-task: `M###-S##-T##-PLAN.md`, `M###-S##-T##-SUMMARY.md`

**Hooks** (under `hooks/`, registered in `hooks/hooks.json`):
- `session-start` -- injects `using-ytstack` directive + STATE snapshot
- `pre-compact`, `session-end` -- context / state preservation
- `teammate-idle`, `task-created`, `task-completed` -- Agent Teams coordination
- `pre-tool-use-edit`, `post-tool-use-bash` -- quality / safety gates

### 3.5 Distribution (self-marketplace, one repo)

Per DECISIONS 2026-04-24 "ytstack self-marketplaces, no separate `-marketplace` repo" and "Marketplace name equals plugin name":

- Plugin source + marketplace manifest both live in `Yesterday-AI/ytstack` (private GitHub repo). `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are colocated; no separate `-marketplace` repo exists or is needed.
- `marketplace.json` `"name"` = `"ytstack"` (same as the plugin). Install command is `/plugin marketplace add Yesterday-AI/ytstack` followed by `/plugin install ytstack@ytstack`.
- `marketplace.json` `"source": "./"` for self-reference.
- `plugin.json` is minimal: `name`, `version`, `description`, `author`, `homepage`, `repository`, `license`, `keywords`. No explicit `skills` / `agents` / `hooks` path pointers -- Claude Code auto-discovers from `skills/`, `agents/`, `hooks/hooks.json`. Adding those pointer fields triggers duplicate-load errors or schema-validation rejects (verified 2026-04-24 during the install debacle; see KNOWLEDGE.md).
- Private-repo install works via the user's existing `gh auth login` + git credential helper. Background auto-updates require `GITHUB_TOKEN` / `GH_TOKEN` env var.

**Pragmatic, not permanent:** the single-repo self-marketplace choice is scoped to the current state where ytstack is the only Yesterday-AI stack-plugin. If a sibling stack emerges later (e.g. `ycstack` for non-development workflows), the Yesterday-AI org would likely consolidate into a shared marketplace repo that catalogs multiple stacks -- at which point this decision would be superseded by a new DECISIONS entry covering the multi-stack marketplace layout. Today's form is not an architectural stance against separate marketplace repos; it is the minimum-maintenance choice while there is exactly one stack.

### 3.6 Future candidates (deferred, not open questions)

Logged in `.ytstack/REVIEW-NOTES.md`. Example: wrapping superpowers' `requesting-code-review` / `receiving-code-review` for PR-level review in v0.2. These are deferrals with acceptance criteria, not open architectural questions.

## 4. User experience model (per README §"What a session feels like" + §"What you get")

### 4.1 Agent-driven, not user-driven

SessionStart hook injects on every session start:
1. The full `using-ytstack/SKILL.md` content as a directive (trigger map + anti-rationalization Red Flags) -- primes the agent to map natural-language intent to ytstack skills.
2. A project-state snapshot (current milestone / slice / task, recent summaries, next action).

Users talk in plain language. The agent reaches for skills automatically. Slash-commands (`/ytstack:<name>`) are the steering override / escape hatch, not the normal path.

### 4.2 Natural-language trigger examples (verbatim from README §"What a session feels like")

- "let's plan what's next" → `plan-milestone` or `plan-task` (based on where user is)
- "this task is done" → `summarize-task` (writes outcome, flips checkbox)
- "something's broken, find it" → `systematic-debugging` (root-cause required, no symptom patches)
- "where were we" → `resume-session` (3-paragraph briefing)
- "describe a feature you're not sure about" → `office-hours` (forcing questions)
- "let's do a handoff" → `handoff-session` (rich handoff file)

Skills never auto-chain: each skill's Terminal State suggests the next, but invocation is the user's decision.

## 5. Typical workflows

Three reference flows condensed from `README.md` §"What a session feels like" + `QUICKSTART.md`. Presented as they are in the authoritative docs today; open design points are flagged but not resolved in this paper.

### 5.1 Greenfield -- new project, no `.ytstack/` yet

Per DECISIONS 2026-04-24 "Greenfield-flow reorder" (LOCKED, implemented):

```
/ytstack:office-hours              (concept validation -- forcing questions, writes OFFICE-HOURS.md with name + one-liner frontmatter)
  → plan-ceo-review                (concept mode: premise + scope challenge on the pitch)
  → [optional] plan-eng-review     (concept mode: feasibility + architectural-risk check on the pitch)
  → init-project                   (infra-only: scope question, scaffolds .ytstack/, populates PROJECT.md from pitch frontmatter, moves pitch into .ytstack/OFFICE-HOURS-<slug>.md)
  → plan-milestone                 (goal + exit criteria, drawn from pitch)
  → slice-milestone                (break into slices with tasks)
  → [optional] plan-eng-review     (milestone mode: architecture review of slice-plans)
  → plan-task → test-driven-development → verification-before-completion → summarize-task
  → [loop: next task, or reassess-roadmap after slice]
```

Key properties of this flow:

- `office-hours` is the greenfield entry point. The pitch artifact it produces carries structured `name:` + `one-liner:` frontmatter that downstream skills consume without re-asking.
- `plan-ceo-review` and `plan-eng-review` auto-detect mode: "concept" (pitch exists, no milestone) or "milestone" (milestone exists). Same skill, two review subjects.
- `init-project` asks only one question (scope: project-level vs user-level vs both). No name / one-liner prompts; those come from the pitch, or placeholders pointing to office-hours if run without a pitch.
- `using-ytstack` trigger map routes greenfield build-intent ("baue mir eine cli", "build me a tool", "I have an idea") to `office-hours` first, not to `plan-milestone` or `init-project` directly.

### 5.2 Brownfield -- existing `.ytstack/`, continuing or starting new work

SessionStart hook injects STATE + using-ytstack directive before the user's first message. Natural-language branches per README §"What a session feels like":

```
<session start: state injected>
  → "where were we"           → resume-session  (optional deep briefing)
  → "let's plan what's next"  → plan-milestone or plan-task (based on state)
  → "this task is done"       → summarize-task
  → "let's do a handoff"      → handoff-session
```

Continuing-an-open-task subflow per QUICKSTART §"Execute tasks":

```
plan-task → test-driven-development → verification-before-completion → summarize-task
```

After each slice: `reassess-roadmap` to check if the plan still fits reality.

**Parallel variant** per QUICKSTART Option B: `spawn-milestone-team` dispatches Agent Teams teammates (one per slice, each in fresh 200k context). Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + Claude Code v2.1.32+ (DECISIONS 2026-04-23 "Accept Agent Teams experimental status as known risk").

### 5.3 Brownfield debugging -- something is broken

Per README §"What a session feels like" + QUICKSTART §"Debugging":

```
"something's broken, find it"   → systematic-debugging
  (Phase 1: root-cause investigation -- no fixes yet)
  (Phase 2: pattern analysis)
  (Phase 3: hypothesis testing)
  (Phase 4: implementation)
```

Root cause required before any fix (iron rule from `systematic-debugging`). Findings auto-logged to `KNOWLEDGE.md` (pattern) and `DECISIONS.md` (architectural shift).

Fix path: regression test first (TDD) → verification-before-completion → summarize-task. Same task skeleton as feature work, not a separate "debug mode".

## 6. Hard rules (locked; changes require superseding DECISIONS entry)

Per `CLAUDE.md` + DECISIONS 2026-04-23:

1. **Never modify content in `vendor/**`.** Upstream subtree mirrors. Edits get dropped on next `sync-upstream.sh`.
2. **Never copy third-party methodology prose verbatim.** Concepts only; credit generically in `NOTICE`.
3. **Every skill follows the UX contracts** (`docs/ux/askuserquestion-format.md`, `writing-style.md`, `skill-structure.md`, `agent-structure.md`). Validated by `bin/ytstack-check`.
4. **Append-only `DECISIONS.md`.** Never rewrite entries; supersede with new entries.
5. **One namespace, one install.** All skills under `/ytstack:<name>`.
6. **Intelligence in the system, not the agent.** Skills + hooks + artifacts carry the logic.

## 7. Scope boundaries (verbatim from README §"Who this is for" + CLAUDE.md)

**Good fit:**
- Projects that span more than one Claude Code session
- Teams where multiple people (or agents) touch the same codebase
- Any workflow where "what was decided and why" matters a week later
- Users of superpowers or gstack who want the other's strengths without the friction

**Poor fit / explicit non-goals:**
- One-shot scripts that ship in a single session
- Teams that don't want opinionated process
- Workflows already deeply invested in GSD's TypeScript runtime (use GSD directly)
- Not a TypeScript runtime -- we do not rebuild GSD
- Not a replacement for superpowers or gstack -- users can still use each directly for skills we skipped
- Not a redistribution of third-party methodology prose

## 8. How to use this paper

- **As a fallback reference after context compaction.** Re-read README.md for anything important; this paper is condensed, not authoritative.
- **Before proposing any architectural change:** check README + DECISIONS. If the change contradicts either, land a superseding DECISIONS entry FIRST, then update README, then update this paper. Never change this paper in isolation.
- **Before re-opening a settled question:** search DECISIONS.md and this paper's source-sections. If it's already answered, follow the answer.
- **When you spot inconsistency between this paper and README / skills / hooks:** flag it, don't silently fix. Run `/check-consistency` (project-local meta-skill under `.claude/skills/`) (the routine audit skill) for a full diff.

## 9. Known open items (not decided, do not act without user)

- Any REVIEW-NOTES entries marked `[ ]`. (Previously: Greenfield-flow reorder -- LOCKED + implemented 2026-04-24, see §5.1 + DECISIONS.)

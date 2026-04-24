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

Per README comparison table and DECISIONS. Six skills, each with a distinct purpose. The per-skill entries below exist to prevent over-proliferation and guide future curation (see §3.7 "Curation principle" for the gate).

#### `office-hours` (gstack)

**Purpose:** Discovery. Six YC-style forcing questions (demand reality, status quo, desperate specificity, narrowest wedge, observation, future-fit) that turn a raw idea into a structured pitch.
**Produces:** `OFFICE-HOURS.md` (greenfield) or `.ytstack/OFFICE-HOURS-<slug>.md` (brownfield) with `name:` + `one-liner:` frontmatter + pitch body. Downstream skills (plan-ceo-review concept-mode, init-project PROJECT.md population, plan-milestone goal drafting) read this as a contract.
**Triggers on:** greenfield build-intent ("baue mir X", "build me X", "new project") or explicit validation request ("I have an idea", "is this worth building", "brainstorm this", "office hours").
**Differs from plan-ceo-review:** office-hours PRODUCES raw material (no plan yet); plan-ceo-review CRITIQUES existing material. Produce-then-critique, never reversed. Running CEO-review on nothing either aborts or duplicates discovery work office-hours does better.

#### `plan-ceo-review` (gstack)

**Purpose:** Scope + ambition critique. Challenges an existing plan across four modes: SCOPE EXPANSION, SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION. Asks "is this worth building, in the right scope, with the right ambition?"
**Produces:** annotation block on the reviewed artifact + optional `DECISIONS.md` entry if a scope-change is locked.
**Triggers on:** explicit request ("CEO review", "challenge premises", "think bigger", "expand scope"); locked as the concept-mode review step immediately after office-hours in greenfield; optional milestone-mode step between plan-milestone and slice-milestone.
**Differs from office-hours:** critique vs produce (see above).
**Differs from plan-eng-review:** WHAT vs HOW. plan-ceo-review asks whether the plan is the right plan; plan-eng-review asks whether the plan's execution approach is technically sound.

#### `plan-eng-review` (gstack)

**Purpose:** Feasibility + architecture critique. Locks in execution approach: architecture, data flow, edge cases, test coverage, performance, security risks. Asks "given we are building this, is the chosen approach technically sound?"
**Produces:** annotations on the reviewed artifact (pitch in concept-mode; slice-plans in milestone-mode) + optional `DECISIONS.md` entry if an architectural choice is locked.
**Triggers on:** explicit request ("engineering review", "architecture review", "lock in the plan"); optional concept-mode step after plan-ceo-review; standard milestone-mode step after slice-milestone before plan-task.
**Differs from plan-ceo-review:** HOW vs WHAT (see above).

#### `test-driven-development` (superpowers)

**Purpose:** RED-GREEN-REFACTOR discipline for implementation. Write the failing test first, watch it fail, write the minimal code to pass, refactor, commit.
**Produces:** test files + implementation code that satisfies the active task-plan's Verification command.
**Triggers on:** during task execution ("TDD this", "write a test first", "RED-GREEN-REFACTOR"); also implicit in the documented plan-task -> TDD -> verify -> summarize loop.
**Differs from ad-hoc coding:** the vendored superpowers skill enforces test-first ordering with anti-rationalization rules that specifically prevent skipping the RED step.

#### `systematic-debugging` (superpowers)

**Purpose:** Root-cause debugging via four phases: investigate, analyze, hypothesize, implement. Iron Law -- no fixes before the root cause is identified.
**Produces:** the fix + optional `KNOWLEDGE.md` entry (if the pattern generalizes) + optional `DECISIONS.md` entry (if an architectural shift is forced).
**Triggers on:** bugs, test failures, unexpected behavior ("debug this", "why is X broken", "investigate", "root cause", "something's off").
**Differs from TDD:** debugging works backwards (existing symptom -> cause -> fix); TDD works forwards (requirement -> test -> code). A bug found mid-TDD typically hands off to systematic-debugging, which may produce a regression test that feeds back into the TDD cycle.

#### `verification-before-completion` (superpowers)

**Purpose:** Evidence gate before any "done" claim. Runs the task-plan's Verification command, captures real output, confirms pass/fail.
**Produces:** signed-off pass (output matches expectation) or failure report (raw output surfaced; no auto-retry). No artifact; it is a gate.
**Triggers on:** before commit, before PR, before summarize-task, before any "done" claim ("verify", "is it really done", "check before I commit").
**Differs from running the command manually:** enforces that the command was actually executed this session and its output observed. The vendored superpowers skill has specific anti-rationalization rules against "it should work"-style hand-waving.

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

Lifecycle + artifact + orchestration pieces that GSD inspired but we re-implement in-plugin. Ten skills, each with a distinct purpose documented below.

#### `init-project` (lifecycle: infra)

**Purpose:** Scaffold `.ytstack/` with the 6 core artifacts. Pure infra, no PM content.
**Produces:** `.ytstack/PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `RUNTIME.md`, `STATE.md`, `PREFERENCES.md`. PROJECT.md `name:` + `one-liner:` populated from `OFFICE-HOURS.md` pitch frontmatter if present; otherwise placeholders explicitly pointing at office-hours.
**Triggers on:** "scaffold the project", "set up tracking", "init ytstack" -- AFTER the pitch is validated. Asks only one question (scope: project-level vs user-level vs both).
**Differs from office-hours:** init-project is infra, office-hours is content. Greenfield flow runs office-hours -> [plan-ceo-review] -> init-project, never init-project first (see §5.1).

#### `plan-milestone` (lifecycle: milestone-level planning)

**Purpose:** Define a single milestone: goal, exit criteria, rough size (S / M / L). Commits the idea to a shippable slice of work.
**Produces:** `M###-CONTEXT.md` (Q/A locked at plan time) + `M###-ROADMAP.md` (slice skeleton with placeholders).
**Triggers on:** "plan a milestone", "new milestone", "start next milestone", "what's next" (when no active milestone).
**Differs from office-hours:** office-hours validates the premise; plan-milestone commits the premise to a specific shippable unit. plan-milestone assumes the premise is already locked (from a pitch or pre-existing project scope).

#### `slice-milestone` (lifecycle: slice-level planning)

**Purpose:** Break the current milestone into slices, each slice holding 1-7 tasks (iron rule). Task-level granularity must fit one context window.
**Produces:** `M###-S##-PLAN.md` per slice, each with the 1-7 task list + acceptance notes.
**Triggers on:** after plan-milestone, before plan-task. "break this into slices", "slice this milestone".
**Differs from plan-task:** slice is a logical grouping of tasks; plan-task is per-task detail. A slice without tasks is just a header; a task without a slice has no home.

#### `plan-task` (lifecycle: task-level planning)

**Purpose:** Flesh out one task with exact file paths, body description, and Verification command. Enforces fits-one-context-window discipline.
**Produces:** `M###-S##-T##-PLAN.md` (what to touch, what to verify).
**Triggers on:** after slice-milestone, before TDD execution. "next task", "detail the next step", "plan task".
**Differs from slice-milestone:** one task at a time with executable specificity; slice is only the scaffold.

#### `summarize-task` (lifecycle: task closure)

**Purpose:** Close a task after execution. Record outcome, flip the checkbox in the slice-plan, update STATE.md.
**Produces:** `M###-S##-T##-SUMMARY.md` (what happened, what was decided, what follow-ups exist).
**Triggers on:** after task execution complete. "task is done", "ship it", "close this out".
**Differs from verification-before-completion:** verification confirms the task's Verification command passed; summarize records what happened and closes the ledger. Always verify before summarize; never summarize without verify.

#### `reassess-roadmap` (lifecycle: slice-boundary checkpoint)

**Purpose:** Post-slice sanity check. Given what this slice taught us, does the remaining milestone plan still fit reality?
**Produces:** optional ROADMAP edits (add / reorder / remove slices); optional `DECISIONS.md` entry if a major re-scope is locked.
**Triggers on:** slice boundary (after last task of a slice is summarized). "reassess", "is the plan still right", "review progress".
**Differs from plan-ceo-review:** reassess is post-slice, reality-check mode (what did we actually learn?); plan-ceo-review is pre-slice, ambition-check mode (is this worth building at this scope?).

#### `handoff-session` (continuity: export)

**Purpose:** Explicit state export for pausing work or cross-machine / cross-agent handoff. Richer than the automatic pre-compact hook because the user decides what matters.
**Produces:** `.ytstack/HANDOFF.md` with current position + in-flight work + open decisions + recommended resume prompt.
**Triggers on:** "handoff", "pause work", "save state for later", "I'm stepping away".
**Differs from summarize-task:** handoff is session-level (a snapshot for a future reader); summarize is task-level (a closure record for a completed task).

#### `resume-session` (continuity: import)

**Purpose:** State import at session start. User-triggered deep briefing beyond the SessionStart-hook's compact inject.
**Produces:** no artifact; produces a 3-paragraph briefing (state + recent summaries + open items) consumed inline by the agent.
**Triggers on:** "where were we", "resume", "pick up where I left off", "what's open".
**Differs from the SessionStart hook:** the hook injects terse state on every session start automatically; resume-session is user-triggered when more context is needed than the hook gave.

#### `spawn-milestone-team` (orchestration: parallel execution)

**Purpose:** Parallel slice execution via Claude Code's native Agent Teams. Each teammate works on one slice in its own fresh 200k context. Replaces GSD's TypeScript-runtime subprocess model with native CC primitives.
**Produces:** an active Agent Team; artifact-level output is the committed slice-plans per teammate.
**Triggers on:** "spawn team", "dispatch milestone", "parallel slice execution". Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + Claude Code v2.1.32+.
**Differs from the sequential plan-task -> TDD -> verify -> summarize loop:** orchestrates parallel work on multiple slices; the per-slice loop remains unchanged inside each teammate.

#### `using-ytstack` (directive, not user-invokable)

**Purpose:** Agent-behavior primer. Injected on every session start by the SessionStart hook; tells the agent to select ytstack skills by semantic matching against each skill's `description:` field (not a phrase/keyword table) and to invoke via the `Skill` tool when any skill plausibly applies (1%-rule). Without this directive, ytstack behaves as a slash-command menu; with it, the agent proactively reaches for skills based on user intent.
**Produces:** no artifact; the skill content IS the instruction.
**Triggers on:** not invoked directly by user or agent (`user-invocable: false` in frontmatter). Loaded via `cat` by the `session-start` hook and injected as `additionalContext` at session start.
**Differs from every other skill:** it is a meta-directive, not an action. Declaring it as a SKILL.md matches superpowers' `using-superpowers` pattern. Per DECISIONS 2026-04-24 "Skill selection is semantic, not keyword-based", this file does NOT contain a trigger-map / phrase-table; selection is driven by each skill's own description field.

---

**Artifacts** (git-tracked Markdown under `.ytstack/`):
- `PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, `RUNTIME.md`, `PREFERENCES.md`
- Per-milestone: `M###-CONTEXT.md`, `M###-ROADMAP.md`
- Per-slice: `M###-S##-PLAN.md`
- Per-task: `M###-S##-T##-PLAN.md`, `M###-S##-T##-SUMMARY.md`
- Per-pitch (greenfield input): `OFFICE-HOURS.md` (pre-init) -> `OFFICE-HOURS-<slug>.md` (post-init, moved into `.ytstack/`)

**Hooks** (under `hooks/`, registered in `hooks/hooks.json`):
- `session-start` -- injects `using-ytstack` directive (always) + STATE snapshot (brownfield) or greenfield next-step block (greenfield)
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

### 3.7 Curation principle (when to add a new skill)

ytstack stays small by design. Before adding a new skill (wrapped OR native), answer all three gates. Failing any one means the skill should not be added; extend an existing one or leave it out.

1. **What distinct artifact does it produce, critique, or modify?** A skill that produces nothing -- no file, no annotation, no state change -- is probably prose that belongs inside another skill, not a new skill. Examples of valid outputs: a new file, a specific annotation appended to an existing file, a state-field flipped in STATE.md, a locked decision in DECISIONS.md.

2. **How is it distinct from every existing ytstack skill AND from every vendored sibling under `vendor/`?** Hand-wavy differentiation ("a lighter version of X", "a different style of Y") is a red flag. The distinction must name a specific input or output that no existing skill handles. Write the differentiation one-liner BEFORE writing the skill; if you cannot, the skill is not well-scoped.

3. **Does the skill's `description:` field state when-to-use clearly enough for semantic matching against real user intents?** ytstack does NOT use a trigger-map / phrase-lookup (per DECISIONS 2026-04-24 "Skill selection is semantic"). Selection is driven by the `description:` field, which Claude Code's model matches against user intent. A weak description is a skill the agent cannot reach proactively. Write when-to-use in situational / contextual prose (e.g. "Use before claiming work is complete") that covers expected user phrasings semantically without enumerating keywords.

**Wrapped skills count against the budget identically to native skills.** Adding a wrapper is not "free" just because the logic lives in `vendor/`. Our thin-wrapper infrastructure still needs ytstack-context injection + mode detection + cross-ref validation. Every wrapped skill adds to the context-window load that users pay for.

**When in doubt, do not add.** The cost of a missing skill is easy to measure (the user asks for something ytstack cannot do). The cost of an extra skill is distributed (context-bloat, disambiguation confusion, maintenance surface). ytstack's value scales sublinearly with skill count past a threshold; protect the threshold.

## 4. User experience model (per README §"What a session feels like" + §"What you get")

### 4.1 Agent-driven, not user-driven

SessionStart hook injects on every session start:
1. The full `using-ytstack/SKILL.md` content as a directive (1%-rule + anti-rationalization Red Flags + instruction-priority) -- primes the agent to invoke skills via the `Skill` tool based on semantic matching against each skill's `description:` field. No trigger-map / phrase-table (per DECISIONS 2026-04-24 "Skill selection is semantic, not keyword-based").
2. A project-state snapshot (current milestone / slice / task, recent summaries, next action) if `.ytstack/` exists; otherwise a greenfield block telling the agent to prefer `office-hours` for build-intent.

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
- `office-hours`' `description:` field explicitly positions it as "the first step when a new project, feature, or initiative has not yet been validated", which the agent matches semantically against greenfield build-intent in any phrasing (German, English, paraphrase). `init-project` and `plan-milestone` descriptions explicitly name office-hours as their predecessor, so the agent does not route build-intent directly to either of them.

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

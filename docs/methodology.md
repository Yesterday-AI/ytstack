# Methodology Attribution

ytstack's design is opinionated. This file documents which concepts we adapted from external AI-first methodology work and how our implementation differs from the originals. Per ytstack's design direction, external sources are referenced generically, not by name.

## What we adapted

### Three-tier context model

**Adapted concept:** a hierarchy of loaded context -- core (always), task-specific (loaded when relevant), background (on-demand).

**ytstack implementation:** skill frontmatter carries a `tier` field:

- `tier: core` -- session-wide, persisted answers (e.g. project scope, storage location). Loaded on every session start via the `session-start` hook.
- `tier: task` -- per-turn decisions (e.g. team size for milestone dispatch). Not persisted.
- `tier: background` -- skippable, default-pickable (e.g. telemetry opt-in). Only asked when user sets `YTSTACK_FULL_SETUP=1`.

**Divergence:** the external source uses three tiers as a prose recommendation. We bake it into skill frontmatter, read it in the `AskUserQuestion` format contract (`docs/ux/askuserquestion-format.md`), and will enforce via CI (`ytstack-skill-check`, M008).

### Artifact-as-memory

**Adapted concept:** project memory lives in files, not conversation history. Every future session reads the files first.

**ytstack implementation:** `.ytstack/` directory with PROJECT.md, DECISIONS.md, KNOWLEDGE.md, RUNTIME.md, STATE.md, PREFERENCES.md. Per-milestone: M###-CONTEXT.md, M###-ROADMAP.md. Per-slice: M###-S##-PLAN.md. Per-task: M###-S##-T##-PLAN.md + M###-S##-T##-SUMMARY.md. All Markdown-based, git-trackable.

**Divergence:** the external source suggests Notion / Confluence / Google Drive as storage. We use plain Markdown in the repo. Pros: diff-friendly, works offline, no vendor lock-in. Cons: no cross-project query tools (none yet -- future).

### Skill-playbook-based skill creation

**Adapted concept:** skills follow a repeatable creation process to ensure quality.

**ytstack implementation:** `docs/ux/skill-structure.md` defines the mandatory structure. `ytstack-skill-check` (planned M008 pre-release) validates every skill in CI. PR reviews reject skills that skip sections.

**Divergence:** the external source describes an 8-step process we don't follow literally. Our structure (frontmatter → Anti-Pattern → Checklist → Process Flow → Preamble → Procedure → Terminal State) encodes similar rigor in a Claude-Code-native format.

### Append-only decision register

**Adapted concept:** architectural decisions never overwrite -- they accumulate with "supersedes" links.

**ytstack implementation:** `.ytstack/DECISIONS.md` is strictly append-only. Format per entry: Context + Options considered + Chose + Reason + Supersedes (if this replaces an older entry). Hook and skill logic never rewrites past entries.

**Divergence:** this pattern appears in Architecture Decision Records (ADR) more broadly. We took the "append-only + supersedes" rigor specifically from external AI-first methodology and anchored it to our milestone/slice/task artifact flow.

### Risk gate and delivery flow

**Adapted concept:** a published account of an agentic software factory (research note `docs/research/2026-11-13-openai-software-factory.md`, which names the sources and marks what was not read). Five ideas: whether a person looks at a change is decided per change from its risk, and an area of the code may allow low-risk changes to merge without one; some kinds of change get a second review of their own; the agent starts the product per worktree and looks at it in a browser; a rollout is watched after the merge; recurring runs look for drift, and an incident helper proposes mitigations that a person orders.

**ytstack implementation:** `bin/ytstack-risk` (floor from the diff, route from the review records), `auto_merge` per area file of the technical spec, `.ytstack/spec/REVIEW.md` with lenses, `ytstack:visual-review`, `merge_by: risk` (formats in `docs/ux/review-policy-format.md`); `bin/ytstack-runtime` and the "Run", "Release" and "Signals" sections of `RUNTIME.md` (`docs/ux/runtime-format.md`); `bin/ytstack-watch release`; `bin/ytstack-upkeep` with `docs/recipes/recurring-upkeep.md`; `ytstack:signal-intake` and `ytstack:incident` with `bin/ytstack-signals` (`docs/ux/signal-format.md`).

**Divergence:** the account describes a company that runs its own harness with unlimited tokens and an agent connected to every internal system. ytstack keeps a person on every path that is not declared: a project that sets no `auto_merge` merges nothing unattended. A mechanical floor sits under the reviewer's judgment (rule documents, invariants, CI and uncovered paths always go to a person). Lens reviewers are defined by the documents they read, not by a role description, because the account itself doubts that role prompts change a review. The rollout is watched, never executed: the watch, the intake and the incident skill only read production, and every mitigation is a staged handover script that only a person runs. Upkeep is a recipe for the host's or the system's scheduler, not a skill, because not every host can schedule a run. The account's numbers are self-reported throughput figures; ytstack took mechanisms, not numbers.

## What we explicitly did NOT adopt

### Catalog of enumerated skills

The external source enumerates a specific count of recommended skills across categories. We did NOT copy this list. ytstack's skill count grows organically, driven by real user needs, not by fitting a pre-defined taxonomy.

### Feedback taxonomy

The external source proposes a specific categorization of feedback events. We opted for a simpler model: outcome signals flow through `summarize-task` (per-task) and `reassess-roadmap` (per-slice). If a richer feedback pipeline emerges as a real need, we'll add it then.

### Agent-type hierarchy

The external source distinguishes multiple agent types with specific roles. We delegate this to Claude Code's native subagents + Agent Teams. When `spawn-milestone-team` creates teammates, it references subagent definitions (architect, implementer, verifier) -- but we don't enforce a strict taxonomy.

## What we took from named projects (attributed in NOTICE)

### superpowers (MIT, vendored)

- RED-GREEN-REFACTOR enforcement for TDD
- Root-cause-required debugging discipline
- Evidence-before-assertions verification gate
- SessionStart-hook injection pattern (we adapted the mechanism for our own `using-ytstack` bootstrap)

### gstack (MIT, six skills adapted since 0.6.0)

`office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship` and `document-release` are ytstack's own adaptations of the gstack skills of the same name: the method (forcing questions, review modes and sections, retro metrics, release steps) carried over, gstack's runtime left out, the upstream baseline recorded in `metadata.upstream` and re-synced with `bin/ytstack-gstack-diff`. What ytstack adopted as conventions of its own:

- AskUserQuestion 4-part format (Re-ground + Simplify + RECOMMENDATION + Options)
- Sentinel-file-for-ask-once pattern
- Cascading-binary-questions pattern
- Spawned-session-detection pattern
- Outcome-framing vs implementation-framing
- Jargon-gloss-on-first-use
- Writing-style guidance (short sentences, concrete nouns, outcome framing, jargon gloss). Note: the banned-words list from an earlier version was rolled back on 2026-04-24 as scope-creep; only the em-dash punctuation rule is mechanically enforced. See DECISIONS 2026-04-24 "drop banned-vocabulary list".

### mattpocock/skills (MIT, concepts only, not vendored)

Coordinator mode (`coordinate`, `finish-lane`, `handover-step`, `lane-retro`, `bin/ytstack-frontier`, `bin/ytstack-questions`, `docs/ux/coordinator-format.md`) adapts concepts from that collection, reviewed at `4ae2317`:

- A coordinating session whose memory outlives it, written as history (`LANES.md`, `STANDING.md`)
- Blocking edges and a frontier of ready work, a claim before any work
- A brief with checkable completion criteria (`bin/ytstack-brief`)
- A staged script for a step only the human may perform (`handover-step`)
- A queue of decision-ready questions (`.ytstack/questions/`)
- Retros that end in checks, not in prose (`lane-retro`)

The research note `docs/research/2026-11-14-mattpocock-skills.md` re-read the collection at `5863806` skill by skill and found no upstream change to these concepts since `4ae2317`. Its recommendations (a research-note format, measuring the large skills before cutting them, a terms section in the spec, a reproduction criterion for debugging, wide refactorings in slicing, reversibility as a review field) are candidates, not adopted. What ytstack deliberately keeps different: artifacts under `.ytstack/` instead of the issue tracker, decisions through the question format instead of open interviews, bounded review rounds and a risk class, and every skill reachable by the model.

### GSD (Get Shit Done) -- architectural influence, NOT vendored

- Artifact hierarchy (PROJECT / DECISIONS / KNOWLEDGE / ROADMAP / per-milestone / per-slice / per-task)
- Phase workflow (discuss → plan → execute → verify)
- Fits-one-context-window iron rule for tasks
- Verification commands as task contract

We do NOT vendor GSD because it's a standalone TypeScript application, not a skill library. We replicate its 80/20 essence via skills + hooks + Claude Code's native Agent Teams. See `.ytstack/DECISIONS.md` for the 2026-04-23 decision log on this.

## Why the "inspired by" vs. "named credit" split

Per ytstack's design direction, external AI-first methodology work is credited generically as "inspired by external AI-first methodology work" in `NOTICE`, without naming the specific source. Named projects (superpowers, gstack, GSD) are credited by name because they are public software with public authorship and we redistribute (vendor) their code.

The generic-vs-named split preserves:
1. **Attribution fairness** for concepts we genuinely adapted
2. **Respect for the external source's authorial preferences** per ytstack's chosen scope
3. **Transparency about upstream software** we depend on or vendor

## Staying current

When new adaptations happen:

1. Document them in this file under "What we adapted"
2. If concepts come from a named project we vendor, add to the named-projects section
3. Update `NOTICE` for any license-relevant changes
4. Flag to `.ytstack/REVIEW-NOTES.md` if the adaptation adds a new mandatory pattern (so CI / `ytstack-skill-check` can validate)

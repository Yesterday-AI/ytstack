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

### gstack

- AskUserQuestion 4-part format (Re-ground + Simplify + RECOMMENDATION + Options)
- Sentinel-file-for-ask-once pattern
- Cascading-binary-questions pattern
- Spawned-session-detection pattern
- Outcome-framing vs implementation-framing
- Jargon-gloss-on-first-use
- Banned-words + writing-style contract

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

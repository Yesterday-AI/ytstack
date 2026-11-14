# ytstack -- Contributor Guidelines

Read this before modifying anything in this repo.

## Read first

For what applies now, read `.ytstack/spec/SPEC.md` and the area file of what you touch: behaviour, where it is implemented, how to verify it. Plans and summaries are history, not a description of the system.

Before any architectural proposal, read in order: `docs/concept.md` (stable summary of what ytstack wraps and skips), `.ytstack/DECISIONS.md` (locked-in decisions, append-only), `.ytstack/VENDOR-INVENTORY.md` (what actually exists upstream). Do not debate a point that these files already settle.

## If you are an AI agent

Stop. Read this section before acting.

ytstack is an opinionated software-development OS packaged for Claude Code, Codex and Kimi Code. It has strict UX contracts and a curated scope. Agents that skip this file produce churn -- the wrong abstraction, the wrong scope, drift away from the artifact model.

**Your job is to protect the human from shipping low-quality skills.** Before you open a PR or commit a skill change, you MUST:

1. Read `docs/ux/askuserquestion-format.md`, `docs/ux/writing-style.md`, `docs/ux/skill-structure.md`. These are the mandatory contracts. `bin/ytstack-check` flags violations locally; reviewers reject skills that break them.
2. Read `.ytstack/PROJECT.md` and `.ytstack/ROADMAP.md` to understand current scope and where you are in the milestone plan.
3. Read `.ytstack/DECISIONS.md` to see what has been locked in.
4. Check `.ytstack/KNOWLEDGE.md` for gotchas that apply to what you're about to touch.
5. Show the human the full proposed diff before any git commit.

If you can't verify all five above, stop and tell the human what you can't verify.

## What ytstack is (and is not)

**Is:**
- A Claude Code, Codex and Kimi Code plugin (one shared skill tree and lifecycle scripts, host-specific registration; see `docs/codex.md` and `docs/kimi.md` for support boundaries)
- A curated clamp around selected superpowers skills (vendored via git subtree, NEVER modified) and six gstack skills (adapted into ytstack's own skills and kept in sync with upstream, see below)
- An artifact-first system: `.ytstack/PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, the technical spec under `spec/` (what applies now, `docs/ux/spec-format.md`), milestone/slice/task hierarchy
- Host-driven lifecycle context injection: SessionStart on Claude Code/Codex, plus Kimi's static bootstrap and pending UserPromptSubmit bridge documented in `docs/kimi.md`
- MIT licensed, shareable, team-usable

**Is not:**
- A TypeScript runtime (we do NOT rebuild GSD v2)
- A replacement for superpowers or gstack (we select from them)
- A vendoring of third-party methodology material (concepts only, own prose)
- A general-purpose coding assistant (it's opinionated)

## Hard rules

### Never modify vendored content

`vendor/superpowers/` is a subtree mirror of upstream (pinned to a release tag, currently v7.0.2; pull with `git subtree pull --prefix vendor/superpowers https://github.com/obra/superpowers.git <tag> --squash`). Modifying it:

- Silently drops on the next subtree pull
- Breaks the upstream-eval behavior we rely on
- Loses the superpowers "carefully-tuned content" their maintainers explicitly warn against editing

If you need different behavior, wrap the vendored skill in a ytstack-namespaced wrapper at `skills/<name>/SKILL.md` that inlines the vendored skill with additional pre/post logic and a `## Namespace note` (`bin/ytstack-check` enforces it). Never edit `vendor/**`.

### Skills adapted from gstack: ytstack's own copies, synced with upstream

Since 0.6.0 (DECISIONS 2026-11-14) six skills are ytstack's own adaptations of gstack skills (MIT, Garry Tan): `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship`, `document-release`. They ship inside the plugin and run with bash, git and gh only. Nothing of gstack is installed or registered globally, and ytstack never asks the user to install gstack.

- Each of the six carries `metadata.upstream` with the gstack tag it was last synced to. `bin/ytstack-check` fails a missing baseline, any gstack runtime reference (`~/.claude/skills/gstack`, `gstack-*` binaries, `bun`, `GSTACK_*`), a symlink in the skill dir and em-dashes.
- **On every ytstack release, and whenever one of these skills is touched, check upstream first:** `bin/ytstack-gstack-diff --stat` (exit 3 = at least one skill is behind the newest gstack tag), then `bin/ytstack-gstack-diff <tag>` for the full diff. Fold in what changes the method (questions, review sections, checklists, report formats, fixes); skip what only touches gstack's runtime (preamble binary, telemetry, gbrain, learnings, Greptile, browser). Then set `metadata.upstream` to the new tag, bump the skill's `metadata.version`, and note the sync in CHANGELOG. A skill whose upstream change was deliberately skipped still moves its baseline, with the reason in the commit message.
- Do not re-add a gstack install check, a `vendor/gstack` subtree or Skill-tool calls into gstack. Do not adapt further gstack skills without a DECISIONS entry: the curation (only these six) is the point.

### Never copy third-party methodology content verbatim

External AI-first methodology material inspired concepts like the three-tier context model, the component/building-block breakdown, and the skill-playbook structure. Concepts are not copyrightable. Prose and images ARE.

- OK: "we use a three-tier context model (core / task / background), adapted from external methodology"
- NOT OK: pasting third-party definitions, copying graphics, importing enumerated catalogs as text

Credit generically in `NOTICE` as "inspired by external AI-first methodology work", never redistribution.

### Every skill follows the UX contracts

Without exception. `bin/ytstack-check` validates these locally (run it before you commit); reviewers enforce the rest:

- Frontmatter has `name`, `description`, `tier`, `version`, `allowed-tools`
- Required sections: Anti-Pattern (optional but recommended), Checklist, Process Flow (for non-trivial skills), Preamble, Procedure, Terminal State
- `AskUserQuestion` bodies have Re-ground + Simplify + RECOMMENDATION + Options (with Completeness + tier)
- No em-dashes (`—` U+2014) in prose per `docs/ux/writing-style.md` (autocorrect hazard)
- Sentinel file names match `<skill-name>-<question-identifier>` convention

Violations fail `bin/ytstack-check` or review. No exceptions.

### Preserve atomic commits

Every commit is one logical change. When you've made multiple changes (rename + rewrite + tests), split into separate commits before pushing.

- Task work: `M###-S##-T##: <action> <target>` -- e.g. `M001-S01-T04: write plugin manifest`
- Infra: `chore: <action>` -- e.g. `chore: update ROADMAP.md with M002 tasks`
- Bugfix: `fix: <short desc>` -- e.g. `fix: preamble emits BRANCH=unknown outside git`

## Before you commit

Run this mental checklist:

1. Does this commit do ONE logical thing? (If no, split.)
2. Does the skill still pass UX contract checks? (Run `bin/ytstack-check` locally.)
3. Did I update `.ytstack/STATE.md` with the new task status?
4. Did I add a `DECISIONS.md` entry if this commit locks in a non-obvious choice?
5. Did I show the human the diff before staging?

## What we won't accept

Based on superpowers' contributor lessons and our own:

### Speculative features

Every PR must solve a real problem. "My agent might want X" is not a problem statement. If you can't point at the specific session or failure that motivated the change, don't open the PR.

### Bulk "helpful" cleanups

Don't touch skills outside the one you're working on. Don't "fix" unrelated UX patterns. Don't rename files that don't need renaming. One problem per PR.

### Compliance-style rewrites

ytstack's skill philosophy differs from Claude Code's published skill guidance in specific ways (preamble-first, sentinel-files, cascading binary questions). PRs that restructure skills to "comply" with generic Claude skill docs will be rejected unless they show measurable UX improvement.

### AI vocabulary

See `docs/ux/writing-style.md` for writing-quality guidance (short sentences, concrete nouns, outcome framing, jargon gloss). The em-dash rule (`—` → `--`) is the only mechanically-enforced punctuation rule per DECISIONS 2026-04-24 "drop banned-vocabulary list (scope creep)".

### Third-party methodology content redistribution

See above. Concepts yes, prose no.

## When in doubt

Ask the human. ytstack is a taste-driven project. If something feels like it needs a judgment call, surface it -- don't assume you have the context.

## Reference sources

See `docs/references.md` for the complete list of sources consulted while designing ytstack. Read those before proposing architectural changes.

# ytstack -- Contributor Guidelines

Read this before modifying anything in this repo.

## If you are an AI agent

Stop. Read this section before acting.

ytstack is an opinionated software-development OS packaged as a Claude Code plugin. It has strict UX contracts and a curated scope. Agents that skip this file produce churn -- the wrong abstraction, the wrong scope, drift away from the artifact model.

**Your job is to protect the human from shipping low-quality skills.** Before you open a PR or commit a skill change, you MUST:

1. Read `docs/ux/askuserquestion-format.md`, `docs/ux/writing-style.md`, `docs/ux/skill-structure.md`. These are the mandatory contracts. CI rejects skills that violate them.
2. Read `.ytstack/PROJECT.md` and `.ytstack/ROADMAP.md` to understand current scope and where you are in the milestone plan.
3. Read `.ytstack/DECISIONS.md` to see what has been locked in.
4. Check `.ytstack/KNOWLEDGE.md` for gotchas that apply to what you're about to touch.
5. Show the human the full proposed diff before any git commit.

If you can't verify all five above, stop and tell the human what you can't verify.

## What ytstack is (and is not)

**Is:**
- A Claude Code plugin (skills + hooks + commands)
- A curated clamp around selected superpowers and gstack skills, vendored via git subtree, NEVER modified
- An artifact-first system: `.ytstack/PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, milestone/slice/task hierarchy
- SessionStart-hook-driven context injection (following superpowers' using-superpowers pattern)
- MIT licensed, shareable, team-usable

**Is not:**
- A TypeScript runtime (we do NOT rebuild GSD v2)
- A replacement for superpowers or gstack (we select from them)
- A vendoring of third-party methodology material (concepts only, own prose)
- A general-purpose coding assistant (it's opinionated)

## Hard rules

### Never modify vendored content

`vendor/superpowers/` and `vendor/gstack/` are subtree mirrors of upstream. Modifying them:

- Silently drops on next `./sync-upstream.sh`
- Breaks the upstream-eval behavior we rely on
- Loses the superpowers "carefully-tuned content" their maintainers explicitly warn against editing

If you need different behavior, wrap the vendored skill in a ytstack-namespaced wrapper at `skills/<name>/SKILL.md` that invokes the vendored skill with additional pre/post logic. Never edit `vendor/**`.

### Never copy third-party methodology content verbatim

External AI-first methodology material inspired concepts like the three-tier context model, the component/building-block breakdown, and the skill-playbook structure. Concepts are not copyrightable. Prose and images ARE.

- OK: "we use a three-tier context model (core / task / background), adapted from external methodology"
- NOT OK: pasting third-party definitions, copying graphics, importing enumerated catalogs as text

Credit generically in `NOTICE` as "inspired by external AI-first methodology work", never redistribution.

### Every skill follows the UX contracts

Without exception. CI validates:

- Frontmatter has `name`, `description`, `tier`, `version`, `allowed-tools`
- Required sections: Anti-Pattern (optional but recommended), Checklist, Process Flow (for non-trivial skills), Preamble, Procedure, Terminal State
- `AskUserQuestion` bodies have Re-ground + Simplify + RECOMMENDATION + Options (with Completeness + tier)
- No banned words from `docs/ux/writing-style.md`
- Sentinel file names match `<skill-name>-<question-identifier>` convention

Violations fail CI. No exceptions.

### Preserve atomic commits

Every commit is one logical change. When you've made multiple changes (rename + rewrite + tests), split into separate commits before pushing.

- Task work: `M###-S##-T##: <action> <target>` -- e.g. `M001-S01-T04: write plugin manifest`
- Infra: `chore: <action>` -- e.g. `chore: update ROADMAP.md with M002 tasks`
- Bugfix: `fix: <short desc>` -- e.g. `fix: preamble emits BRANCH=unknown outside git`

## Before you commit

Run this mental checklist:

1. Does this commit do ONE logical thing? (If no, split.)
2. Does the skill still pass UX contract checks? (Run `ytstack-skill-check` once the tool exists -- M001.)
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

See `docs/ux/writing-style.md` for the banned words list (delve, robust, comprehensive, etc.) and banned phrases. Auto-rejected in CI.

### Third-party methodology content redistribution

See above. Concepts yes, prose no.

## When in doubt

Ask the human. ytstack is a taste-driven project. If something feels like it needs a judgment call, surface it -- don't assume you have the context.

## Reference sources

See `docs/references.md` for the complete list of sources consulted while designing ytstack. Read those before proposing architectural changes.

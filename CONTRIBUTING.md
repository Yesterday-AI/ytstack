# Contributing to ytstack

Before you change anything, read this file and `AGENTS.md` (agent guidelines; `CLAUDE.md` symlinks to it).

## Philosophy

ytstack is a curated, opinionated stack. Not every idea belongs. Before proposing changes, ask: does this fit ytstack's scope, or does it belong in a separate plugin?

**Belongs in ytstack:**
- Improvements to existing skills that preserve the UX contracts
- Fixes to hook scripts (cross-platform, edge cases, bugs)
- New skills that clearly fit the Project-OS + cherry-pick model
- Documentation updates that keep pace with shipped behavior

**Does NOT belong:**
- New skills that replicate vendored superpowers / gstack skills
- Modifications to `vendor/**` content (never -- wrap, don't edit)
- Alternative UX contracts (one set of contracts, enforced by CI)
- Domain-specific functionality (publish a separate plugin that depends on ytstack)

## Before opening a PR

Every PR MUST:

1. **Solve a real, observed problem.** Not "might be useful" -- something that actually broke or blocked real work. Describe the session or scenario.
2. **Preserve the UX contracts.** If your change touches a skill, re-read `docs/ux/*.md` and confirm the skill still passes. Run `bin/ytstack-check` locally.
3. **Update REVIEW-NOTES.md.** If your PR closes an item there, strike it. If it opens new concerns, add them.
4. **Update STATE.md.** If your PR is part of a milestone, bump the appropriate checkboxes.
5. **Show the full diff to the human partner** before submitting, if working with an AI agent.

## Hard rules

### Never modify `vendor/**`

These are git-subtree mirrors. Changes drift on next pull. Also: upstream maintainers may explicitly reject forks (superpowers does). Wrap with a ytstack-namespaced skill; don't edit.

### Never copy third-party methodology content verbatim

ytstack's prose and artifact formats are original work inspired by external AI-first methodology material. We do NOT:

- Paste definitions, examples, or prose from third-party sources
- Copy graphics or diagrams
- Import enumerated catalogs (e.g. skill lists) as text

We DO:
- Adapt structural concepts (tier-based context, artifact-as-memory)
- Attribute generically via `NOTICE` ("inspired by external AI-first methodology work")
- Give credit to named projects (superpowers, gstack) where we vendor their code

### Never skip the UX contracts

`docs/ux/askuserquestion-format.md`, `writing-style.md`, `skill-structure.md` are mandatory. `bin/ytstack-check` validates them locally (run it before you commit); the rest is reviewer-enforced. PRs that violate contracts without a compelling reason + eval evidence are rejected.

### Atomic commits

One logical change per commit. Rename + rewrite + tests? Three commits. A task's work might span several commits -- that's fine, each should be independently understandable and revertable.

Commit message format:
- Task work: `M###-S##-T##: <action>` (e.g. `M003-S01-T10: write failing test for argon2`)
- Infrastructure: `chore: <action>` (e.g. `chore: update ROADMAP counts after M005`)
- Bugfix: `fix: <short desc>` (e.g. `fix: BSD sed compatibility in session-end hook`)

### Writing style

`docs/ux/writing-style.md` is the quality contract: short sentences, concrete nouns, outcome framing, jargon gloss. Only one rule is mechanically enforced -- no em-dashes (the U+2014 character; use `--`). `bin/ytstack-check` flags them. The earlier banned-words list (delve / robust / comprehensive / nuanced) was retracted as scope creep (DECISIONS 2026-04-24); treat the rest of writing-style.md as guidance reviewers apply, not a grep gate.

## What we won't accept

### Speculative features

"My agent might want X" is not a problem statement. Every PR must trace back to a session that hit a problem. Describe the session.

### Bulk cleanups

Don't touch skills outside the one you're working on. Don't "fix" unrelated UX patterns. One problem per PR.

### Compliance-style rewrites

ytstack's approach differs from generic Claude Code skill conventions in specific, deliberate ways (preamble-first, sentinel-files, cascading binary questions). PRs that restructure skills to "comply with Anthropic's skill guidance" are rejected unless they show measurable UX improvement.

### Modifications to vendored content

See above. Wrap, don't edit.

### Named attribution in public artifacts

Per ytstack's design direction, we credit external methodology work generically, not by name. PRs that add specific named attribution to public artifacts (README, PROJECT.md, etc.) are rejected. `docs/references.md` is the one place where upstream source projects ARE named (superpowers, gstack, GSD).

## How to add a new skill

1. Read `docs/ux/skill-structure.md`.
2. Create `skills/<name>/SKILL.md` following the structure (frontmatter → Anti-Pattern → Checklist → Process Flow → Preamble → Procedure → Terminal State).
3. Every `AskUserQuestion` follows `docs/ux/askuserquestion-format.md` (Re-ground + Simplify + RECOMMENDATION + Options with Completeness + tier).
4. Preamble emits the standard flags (see existing skills for the pattern).
5. Test standalone first (preamble works without Claude), then integration (invoke via `claude --plugin-dir`).
6. Add smoke-test findings to `.ytstack/REVIEW-NOTES.md` if you find gotchas.
7. Update `.ytstack/ROADMAP.md` and `STATE.md` task checkboxes.

## How to add a new hook

1. Read Claude Code's hooks reference: https://code.claude.com/docs/en/hooks
2. Decide the event (SessionStart, PreToolUse, etc.) and matcher.
3. Write the script at `hooks/<name>`, following the pattern of existing hooks (silent-exit for non-ytstack projects, jq-preferred JSON emission, bash+python fallbacks).
4. Register in `hooks/hooks.json`.
5. Test standalone with mock `CLAUDE_PROJECT_DIR`.
6. Add REVIEW-NOTES entry for integration-test-needed.

## How to add a new vendor subtree

1. Verify the license is compatible (MIT / Apache-2.0 / similar permissive).
2. Add to `vendor/` via:
   ```bash
   git subtree add --prefix=vendor/<name> <url> <branch> --squash
   ```
3. Update `vendor/README.md` to list the new subtree.
4. Write wrapper skill(s) at `skills/<vendored-skill-name>/` that delegate to `vendor/<name>/...`.
5. Add attribution to `NOTICE`.

## Review + release cadence

- `main` branch is releasable at all times.
- Version bumps follow semver: patch for bugfixes, minor for new skills, major for breaking changes to skill names / artifact paths.
- Each minor release tags the commit and updates `.claude-plugin/plugin.json`'s version field.

## Reporting issues

Open an issue at [Yesterday-AI/ytstack/issues](https://github.com/Yesterday-AI/ytstack/issues):

- **Bug** -- use the bug-report template. Name the skill or hook, the session that triggered it, what you expected, and what happened.
- **Feature / new skill** -- use the feature-request template. Trace it back to a real session (see "Speculative features" above); "might be useful" gets closed.

## Getting help

- Read `docs/references.md` for sources we've leaned on.
- Check `.ytstack/REVIEW-NOTES.md` -- your question may already be logged.
- Read `AGENTS.md` for agent-specific guidance.

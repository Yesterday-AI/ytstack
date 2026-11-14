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

## Testing

Three layers, cheapest first.

**Static.** `python3 bin/ytstack-check` checks the UX contracts, frontmatter, descriptions, resolver rules, vendor leaks and the repository's own technical spec. Exit 0 or 2 (warnings only) passes; a `[fail]` line does not. `bash bin/ytstack-spec lint` checks the spec format on its own.

**Shell suites.** `bash tests/run-all.sh` runs every `tests/*.test.sh` and ends with `ALL SUITES PASSED`. A new suite is picked up by name; nothing to register. Each script under `bin/` has its own suite, and 0.7.0 added these:

| Suite | Pins |
| --- | --- |
| `ytstack-spec` | spec `lint`, `drift`, `impact`, `areas` |
| `evidence-rule` | an earlier PASS counts only for the same commit, environment and command |
| `ytstack-brief` | the rendered brief and the report check |
| `ytstack-frontier`, `ytstack-questions`, `ytstack-handover` | lanes and claims, question files, staged handover scripts |
| `ytstack-finish-lane`, `ytstack-watch` | a lane to a merge at the reviewed commit, pull request polling, the release watch (against a stand-in for `gh` and fixture targets) |
| `ytstack-risk` | floor, route, policy check, `MANIFEST` hashes |
| `ytstack-runtime` | `up`, `down`, `status`, `get`, `signals`, `check` |
| `ytstack-upkeep`, `ytstack-signals` | the upkeep report, findings and incident records |

A suite is plain bash, writes only into `mktemp` directories, prints one line per assertion and ends with `<n> passed, 0 failed`. The comment at its top states the contract it pins. Scripts and suites run on macOS `/bin/bash` 3.2, with BSD and GNU tools, BusyBox and uutils.

**Linux, three images.** `bash tests/run-all.sh --linux` runs the suites in `alpine/git` with the `coreutils` package. That is not enough on its own: also run them in `ubuntu:26.04`, the image of the CI runner, whose uutils `mkdir` is not a lock, and in plain `alpine` without coreutils, whose BusyBox `date` cannot read an ISO time (`.ytstack/KNOWLEDGE.md`, "Gotchas"). The suites do not run from a linked worktree, so test an export:

```bash
D=$(mktemp -d /tmp/yt-linux.XXXXXX); git archive HEAD | tar -x -C "$D"
docker run --rm -v "$D":/src:ro ubuntu:26.04 bash -c 'apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq git python3 jq >/dev/null 2>&1; cp -r /src /work && cd /work && git init -q && bash tests/run-all.sh'
docker run --rm -v "$D":/src:ro alpine sh -c 'apk add -q bash git python3 jq >/dev/null 2>&1; cp -r /src /work && cd /work && git init -q && bash tests/run-all.sh'
```

**Codex.** `python3 -m unittest discover -s tests -p 'codex*_test.py'` (see "Codex compatibility" below).

**Evals.** `evals/` holds one behavioural case per lifecycle skill for `claude plugin eval` ([`evals/README.md`](evals/README.md)): a user-phrased prompt, a `fixture.sh` and graders. A new skill gets a case, and the cases of new and changed skills are run before a release. They are real model calls on your account and not in CI; record the run under "Eval runs" in `.ytstack/KNOWLEDGE.md`.

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

## Codex compatibility

Both hosts load `skills/` and reuse the lifecycle scripts in `hooks/`.
Keep skill content in that one tree. Codex tool mappings live in
`codex/adapter.md`; the Codex SessionStart path supplies them before the shared
directive. `bin/ytstack-codex` supplies the existing script environment, including
repository-root resolution. Register supported events in `codex/hooks.json`.
There is no generation step, skill copy, or per-skill Codex boilerplate.
Keep `.codex-plugin/plugin.json` and `.claude-plugin/plugin.json` versions aligned.

Run `python3 -m unittest discover -s tests -p 'codex*_test.py' -v` and
`bash tests/post-tool-use-bash.test.sh` alongside `bin/ytstack-check`. CI accepts
the validator's warnings-only exit code (2) and rejects failures. See
[Codex setup](docs/codex.md) for installation and manual discovery checks.

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

### Release checklist

1. `git fetch origin` and merge `origin/main` (never rebase) **before** the release commit; a long local run can hide upstream commits (0.4.0 missed the October Codex support and became 0.4.1 the same evening).
2. All three manifests agree: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json` (`tests/codex_plugin_test.py` checks the Codex one); README version badge; CHANGELOG section with compare link.
3. gstack upstream: `bin/ytstack-gstack-diff --stat`. Exit 3 means at least one of the six skills adapted from gstack is behind the newest gstack tag; fold the method changes in and move `metadata.upstream` (procedure in AGENTS.md "Skills adapted from gstack") before cutting the release.
4. Clean clone: `bash tests/run-all.sh`, `bash tests/run-all.sh --linux` (Docker; the lib has GNU/BSD branches), the same suites in `ubuntu:26.04` and in plain `alpine` (commands under "Testing"), `bin/ytstack-check`, `bash bin/ytstack-spec lint`, `claude plugin validate .`, `python3 -m unittest discover -s tests -p 'codex*_test.py'`.
5. Evals: the cases of every skill added or changed since the last release (`claude plugin eval . --case <name> ...`, [`evals/README.md`](evals/README.md)); the result goes under "Eval runs" in `.ytstack/KNOWLEDGE.md`.
6. Push `main` first, then the tag (`git push origin main && git push origin vX.Y.Z`). `git push origin main --tags` pushes the tags even when `main` is rejected.
7. A pushed tag is immutable (no force-push): anything that has to follow it is the next patch release.
8. Watch `gh run list` for `ci`, `Plugin checks`, `Secret Scanning` on the pushed SHA; update the installed plugin (`claude plugin marketplace update yesterday-public-plugins && claude plugin update ytstack`).

## Reporting issues

Open an issue at [Yesterday-AI/ytstack/issues](https://github.com/Yesterday-AI/ytstack/issues):

- **Bug** -- use the bug-report template. Name the skill or hook, the session that triggered it, what you expected, and what happened.
- **Feature / new skill** -- use the feature-request template. Trace it back to a real session (see "Speculative features" above); "might be useful" gets closed.

## Getting help

- Read `docs/references.md` for sources we've leaned on.
- Check `.ytstack/REVIEW-NOTES.md` -- your question may already be logged.
- Read `AGENTS.md` for agent-specific guidance.

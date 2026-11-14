---
area: dependencies
status: implemented
paths:
  - vendor/superpowers/**
  - vendor/README.md
  - NOTICE
  - bin/ytstack-gstack-diff
verified_at: 799d6bf
---

# dependencies

## Purpose

What ytstack takes from other projects and by which mechanism: superpowers as a read-only git subtree, six gstack skills as ytstack's own adaptations kept in sync with upstream, third-party methodology as concepts only. The area ends where a wrapper skill adds its own ytstack logic (preamble, invocation notes, artifacts); that belongs to the skills.

## Behavior

**superpowers: vendored, inlined**

- `vendor/superpowers/` is a squashed `git subtree` of `https://github.com/obra/superpowers` at a release tag. The vendored tag is the `version` in `vendor/superpowers/package.json`.
- Six wrapper skills inline seven vendored `SKILL.md` files. `NOTICE` (section "superpowers") lists which wrapper takes which upstream skill. `skills/code-review/SKILL.md` inlines two files, the other five one each.
- Mechanism: the wrapper contains a render-time shell block (a fence opened with `` ```! ``) that runs `cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/<name>/SKILL.md"`. The host replaces the block with the file's text, so the agent reads the upstream procedure verbatim.
- Around that block the wrapper has its own context preamble, a `## ytstack invocation notes` section before it and a `## Namespace note` after it.
- The Namespace note tells the agent to read `superpowers:<skill>` as `ytstack:<skill>` and names the directory under which upstream's relative links resolve.
- The remaining vendored skills sit in the tree and no ytstack skill surfaces them.

**gstack: six skills adapted, synced with upstream**

- `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship` and `document-release` are ytstack's own skills, adapted from the gstack skills of the same name (MIT). They carry the method in their own `SKILL.md` (and optional `references/*.md`), run the standard resolver preamble and need only bash, git and gh. Nothing of gstack is installed, registered or called. The list is `_GSTACK_ADAPTED` in `bin/ytstack-check`.
- Each skill records its baseline in `metadata.upstream` (`gstack v<tag> (<skill>/, commit <sha>)`). `bin/ytstack-gstack-diff` shows what changed upstream since that baseline (`--stat`, a target tag, `--source <clone>`; exit 3 when a skill is behind). It keeps a clone under `${XDG_CACHE_HOME:-$HOME/.cache}/ytstack/gstack` and never writes into `~/.claude`.

**Moving a pin**

- superpowers: the pull command is in `AGENTS.md` ("Never modify vendored content"): `git subtree pull` by tag with `--squash`. Afterwards `bin/ytstack-check` must show no `[fail]` line: `check_cross_refs` fails when an inlined path is gone, `check_inline_leaks` fails on a new `superpowers:<name>` token or relative link the wrapper's Namespace note does not cover, `check_vendor_sibling_refs` warns when inlined text points at an upstream skill ytstack does not wrap. `tests/codex_plugin_test.py` must still find exactly six importing wrappers, each printing its vendored file byte for byte. The tag named in the six Namespace notes, `AGENTS.md` and `README.md` is edited by hand.
- gstack: `AGENTS.md` ("Skills adapted from gstack") names the steps, run on every release and whenever one of the six is touched: `bin/ytstack-gstack-diff --stat`, fold method changes in, skip runtime-only changes, move `metadata.upstream`, bump the skill's version, note it in the CHANGELOG.

**Methodology and attribution**

- Third-party methodology material contributes concepts only. Prose, definitions, catalogs and graphics are not copied, and the source is not named.
- `NOTICE` holds the attribution per source: superpowers (vendored, license file in the subtree), gstack (six skills adapted, MIT text and credits in `NOTICE`), two concept credits (ponytail for the work contract and the review rules, mattpocock/skills for coordinator mode; no text of either is included), the external methodology, Claude Code, and GSD as a reference that is not a dependency.

## Interfaces and contracts

- `bin/ytstack-check` (`check_gstack_adapted`) fails an adapted skill without `metadata.upstream`, with a gstack runtime reference (`~/.claude/skills/gstack`, `vendor/gstack`, `gstack-*` binaries, `bun`, `GSTACK_*`, `yt_gstack_*`), with a symlink in its directory or an em-dash in any of its files.
- `bin/ytstack-check` (`check_inline_leaks`) requires a `## Namespace note` that repeats every `superpowers:<name>` token of the inlined file, and the words "resolve under" when the inlined file links relatively to a `.md` file.

## Invariants and security boundaries

- Nothing under `vendor/**` is edited. Different behaviour is added in a wrapper under `skills/<name>/SKILL.md`. No check compares the subtree with upstream; review enforces it.
- gstack is never vendored, never installed by ytstack and never called; ytstack never asks the user to install it. A further gstack skill is adapted only with its own DECISIONS entry.
- `.claude-plugin/plugin.json` declares no plugin `dependencies`.

## Error behavior

- `bin/ytstack-gstack-diff` without network and without `--source`: it cannot fetch tags and says so; nothing in the plugin depends on it at run time.
- A wrapper that names a vendored `SKILL.md` which does not exist fails `bin/ytstack-check`. What the host shows for a failing `cat` block: Unknown -- no test renders a wrapper with a missing vendored file.

## Runtime and deployment assumptions

- The host substitutes `${CLAUDE_SKILL_DIR}` and executes `` ```! `` blocks. On Codex, `bin/ytstack-codex` supplies that environment.
- The plugin is installed with its `vendor/` directory, because the wrappers read from it at render time.

## Known limits

- Whether an adapted skill is behind upstream is only known when `bin/ytstack-gstack-diff` runs; no CI job runs it.
- No check ties the hand-written superpowers tag (Namespace notes, `README.md`, `AGENTS.md`) to `vendor/superpowers/package.json`.
- `check_inline_leaks` asks for a Namespace note only when the inlined file contains a namespace token or a relative link.
- `vendor/README.md` describes a `vendor/gstack/` subtree and a sync script. Neither exists. `AGENTS.md` ("Hard rules") states the rules that hold.
- `.ytstack/VENDOR-INVENTORY.md` is a dated snapshot of upstream skills, not a description of the vendored tree. `ls vendor/superpowers/skills` is the list.
- The third-party methodology rule has no mechanical check.

## Where implemented

- `vendor/superpowers/skills/*/SKILL.md` -- the inlined upstream procedures. `vendor/superpowers/LICENSE` -- upstream license.
- superpowers wrappers: `skills/test-driven-development/`, `skills/systematic-debugging/`, `skills/verification-before-completion/`, `skills/code-review/`, `skills/finish-branch/`, `skills/grill/`.
- Adapted gstack skills: `skills/office-hours/`, `skills/plan-ceo-review/`, `skills/plan-eng-review/`, `skills/retro/`, `skills/ship/`, `skills/document-release/`; the sync tool `bin/ytstack-gstack-diff`.
- `bin/ytstack-check` -- `check_cross_refs`, `check_vendor_sibling_refs`, `check_inline_leaks`, `check_gstack_adapted`.
- `NOTICE` (attributions and the gstack MIT text), `AGENTS.md` ("Hard rules", "Skills adapted from gstack"), `CONTRIBUTING.md` (release checklist).
- Tests that pin the behaviour: `tests/ytstack-check.test.sh` (leak rules, the adapted-skill contract), `tests/codex_plugin_test.py` (vendor imports on both hosts).

## How to verify

Run from the repository root.

- `bin/ytstack-check` -- pass: exit code 0 or 2 and no `[fail]` line. Covers inlined paths, Namespace notes and the adapted-skill contract.
- `bash tests/run-all.sh` -- pass: every line starts with `PASS` and the last line is `ALL SUITES PASSED`.
- `python3 -m unittest discover -s tests -p 'codex*_test.py'` -- pass: `OK`. Covers the verbatim vendor import of all six superpowers wrappers.
- `bin/ytstack-gstack-diff --stat` -- needs network or `--source <clone>`. Exit 0: every adapted skill is at the newest gstack tag; exit 3: at least one is behind.

## Decisions that apply now

- DECISIONS.md -- "2026-11-14: The six gstack skills become ytstack's own adaptations, synced with upstream; no gstack install" (replaces the gstack half of the Vendor strategy entry)
- DECISIONS.md -- "2026-11-07: Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency". In force for superpowers only.
- DECISIONS.md -- "2026-04-24: Wrapper mechanism = shell-exec inject + cross-ref check". In force for the superpowers wrappers.
- DECISIONS.md -- "2026-04-25: Vendored-preamble drift accepted for wrapped skills". Narrowed to superpowers by the Vendor strategy entry.
- DECISIONS.md -- "2026-04-23: Cherry-pick prioritization based on production evidence"
- DECISIONS.md -- "2026-04-25: Lifecycle-phase as the curation heuristic"
- DECISIONS.md -- "2026-04-25: M011 scope -- 5-skill cherry-pick from gstack + superpowers". Selects the skills; the mechanism for its two gstack skills follows the Vendor strategy entry.
- DECISIONS.md -- "2026-04-23: Don't vendor third-party methodology content, only adapt concepts"
- DECISIONS.md -- "2026-04-23: Don't rebuild GSD as TypeScript runtime"
- DECISIONS.md -- "2026-11-07: No hard plugin dependencies"

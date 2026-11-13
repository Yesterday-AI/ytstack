---
area: dependencies
status: implemented
paths:
  - vendor/superpowers/**
  - vendor/README.md
  - NOTICE
  - hooks/lib/git-ctx.sh
  - tests/gstack-live.test.sh
verified_at: f4f54ab
---

# dependencies

## Purpose

What ytstack takes from other projects and by which mechanism: superpowers as a read-only git subtree, gstack as an installed, tag-pinned prerequisite, third-party methodology as concepts only. The area ends where a wrapper skill adds its own ytstack logic (preamble, invocation notes, artifacts); that belongs to the skills.

## Behavior

**superpowers: vendored, inlined**

- `vendor/superpowers/` is a squashed `git subtree` of `https://github.com/obra/superpowers` at a release tag. The vendored tag is the `version` in `vendor/superpowers/package.json`.
- Six wrapper skills inline seven vendored `SKILL.md` files. `NOTICE` (section "superpowers") lists which wrapper takes which upstream skill. `skills/code-review/SKILL.md` inlines two files, the other five one each.
- Mechanism: the wrapper contains a render-time shell block (a fence opened with `` ```! ``) that runs `cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/<name>/SKILL.md"`. The host replaces the block with the file's text, so the agent reads the upstream procedure verbatim.
- Around that block the wrapper has its own context preamble, a `## ytstack invocation notes` section before it and a `## Namespace note` after it.
- The Namespace note tells the agent to read `superpowers:<skill>` as `ytstack:<skill>` and names the directory under which upstream's relative links resolve.
- The remaining vendored skills sit in the tree and no ytstack skill surfaces them.

**gstack: installed, invoked**

- No gstack file is in the repository. Six wrappers call the gstack skill of the same name that is installed on the machine. The list is `_GSTACK_WRAPPERS` in `bin/ytstack-check`.
- Detection is `yt_gstack_ctx` in `hooks/lib/git-ctx.sh`. It looks in `$GSTACK_HOME`, else `~/.claude/skills/gstack`. An install counts as available when it has a `VERSION` file and the `SKILL.md` of `office-hours`, `plan-ceo-review` and `plan-eng-review`.
- The pin (`YT_GSTACK_PIN`) and the minimum bun version (`YT_BUN_MIN`) are defined next to that function. An installed version equal to or newer than the pin passes. `yt_vergte` compares dotted numbers numerically.
- Each wrapper's preamble calls `yt_gstack_ctx` and prints the result as `GSTACK_*` and `BUN_OK` lines. A `## HARD-GATE: gstack installed?` section reads them. The procedure then says "Invoke the Skill tool with `<name>`", the bare gstack skill name, and applies the ytstack post-processing afterwards.

**Moving a pin**

- superpowers: the pull command is in `AGENTS.md` ("Never modify vendored content"): `git subtree pull` by tag with `--squash`. Afterwards `bin/ytstack-check` must show no `[fail]` line: `check_cross_refs` fails when an inlined path is gone, `check_inline_leaks` fails on a new `superpowers:<name>` token or relative link the wrapper's Namespace note does not cover, `check_vendor_sibling_refs` warns when inlined text points at an upstream skill ytstack does not wrap. `tests/codex_plugin_test.py` must still find exactly six importing wrappers, each printing its vendored file byte for byte. The tag named in the six Namespace notes, `AGENTS.md` and `README.md` is edited by hand.
- gstack: `AGENTS.md` ("gstack is an installed dependency") names the steps. `tests/skill-preambles.test.sh` asserts the pin as a literal and changes with it.

**Methodology and attribution**

- Third-party methodology material contributes concepts only. Prose, definitions, catalogs and graphics are not copied, and the source is not named.
- `NOTICE` holds the attribution per source: superpowers (vendored, license file in the subtree), gstack (required install, nothing redistributed), a concept credit, the external methodology, Claude Code, and GSD as a reference that is not a dependency.

## Interfaces and contracts

- Wrappers rely on `yt_gstack_ctx`, `yt_gstack_skill_ok` and `yt_vergte`. The variables they set are listed in the comment above each function in `hooks/lib/git-ctx.sh`.
- `GSTACK_HOME` overrides the install location for detection and for the install command the wrappers print.
- `bin/ytstack-check` (`check_gstack_wrappers`) requires in every gstack wrapper: the `yt_gstack_ctx` precheck, `GSTACK_INSTALL_CMD`, the Skill-tool sentence with the wrapper's own name, a `## HARD-GATE` section, and no `vendor/gstack` reference outside comments.
- `bin/ytstack-check` (`check_inline_leaks`) requires a `## Namespace note` that repeats every `superpowers:<name>` token of the inlined file, and the words "resolve under" when the inlined file links relatively to a `.md` file.

## Invariants and security boundaries

- Nothing under `vendor/**` is edited. Different behaviour is added in a wrapper under `skills/<name>/SKILL.md`. No check compares the subtree with upstream; review enforces it.
- gstack is never vendored, never `cat`-ed and its prose is never copied into ytstack.
- `.claude-plugin/plugin.json` declares no plugin `dependencies`.
- ytstack does not run gstack's `./setup`. The wrappers print the install command and the user runs it.

## Error behavior

- gstack missing (`GSTACK_AVAILABLE` is `no` or `unknown`): the wrapper stops, prints the one-line install command and does not improvise the procedure. `retro`, `ship` and `document-release` also stop when `GSTACK_SKILL_OK` is `no`. `ship` names `ytstack:finish-branch` as the alternative without dependencies.
- `unknown` is printed when the shared library was not loaded, that is when the host did not substitute `${CLAUDE_SKILL_DIR}`.
- Installed gstack older than the pin: the wrapper continues and says so once.
- bun absent or older than the minimum: the wrapper continues with a warning that gstack's helpers may fail.
- A wrapper that names a vendored `SKILL.md` which does not exist fails `bin/ytstack-check`. What the host shows for a failing `cat` block: Unknown -- no test renders a wrapper with a missing vendored file.

## Runtime and deployment assumptions

- The host substitutes `${CLAUDE_SKILL_DIR}` and executes `` ```! `` blocks. On Codex, `bin/ytstack-codex` supplies that environment.
- The six gstack-backed skills need gstack at the pin or newer and bun at the minimum or newer. Every other skill works without both.
- The plugin is installed with its `vendor/` directory, because the wrappers read from it at render time.

## Known limits

- `yt_gstack_ctx` derives "available" from the three planning skills only. The other three wrappers depend on their own `GSTACK_SKILL_OK` line.
- No check ties the hand-written copies of the pins (wrapper prose, `README.md`, `QUICKSTART.md`, `NOTICE`, `AGENTS.md`) to `YT_GSTACK_PIN`, `YT_BUN_MIN` or `vendor/superpowers/package.json`.
- `check_inline_leaks` asks for a Namespace note only when the inlined file contains a namespace token or a relative link.
- `vendor/README.md` describes a `vendor/gstack/` subtree and a sync script. Neither exists. `AGENTS.md` ("Hard rules") states the rules that hold.
- `.ytstack/VENDOR-INVENTORY.md` is a dated snapshot of upstream skills, not a description of the vendored tree. `ls vendor/superpowers/skills` is the list.
- The third-party methodology rule has no mechanical check.

## Where implemented

- `vendor/superpowers/skills/*/SKILL.md` -- the inlined upstream procedures. `vendor/superpowers/LICENSE` -- upstream license.
- `hooks/lib/git-ctx.sh` -- section "gstack as an installed dependency": both pins, `yt_vergte`, `yt_gstack_skill_ok`, `yt_gstack_ctx`.
- superpowers wrappers: `skills/test-driven-development/`, `skills/systematic-debugging/`, `skills/verification-before-completion/`, `skills/code-review/`, `skills/finish-branch/`, `skills/grill/`.
- gstack wrappers: `skills/office-hours/`, `skills/plan-ceo-review/`, `skills/plan-eng-review/`, `skills/retro/`, `skills/ship/`, `skills/document-release/`.
- `bin/ytstack-check` -- `check_cross_refs`, `check_vendor_sibling_refs`, `check_inline_leaks`, `check_gstack_wrappers`.
- `NOTICE`, `AGENTS.md` ("Hard rules"), `README.md` ("Prerequisites" under Install) for the user-facing prerequisite.
- Tests that pin the behaviour: `tests/git-ctx.test.sh` (section "gstack ctx"), `tests/skill-preambles.test.sh` (gstack precheck with an empty and a fake install), `tests/ytstack-check.test.sh` (leak and gstack-wrapper rules), `tests/codex_plugin_test.py` (vendor imports on both hosts), `tests/gstack-live.test.sh` (a real install).

## How to verify

Run from the repository root.

- `bin/ytstack-check` -- pass: exit code 0 or 2 and no `[fail]` line. Covers inlined paths, Namespace notes and the gstack wrapper contract.
- `bash tests/run-all.sh` -- pass: every line starts with `PASS` and the last line is `ALL SUITES PASSED`. Without `GSTACK_HOME` the `gstack-live` line ends in "skipped (0 passed, 0 failed)".
- `python3 -m unittest discover -s tests -p 'codex*_test.py'` -- pass: `OK`. Covers the verbatim vendor import of all six superpowers wrappers.
- `GSTACK_HOME="$HOME/.claude/skills/gstack" bash tests/gstack-live.test.sh` -- needs a gstack install at that path, no network. Pass: last line `<n> passed, 0 failed`. Checks the installed version against the pin, the six skills in the install and the six wrapper preambles against it.

## Decisions that apply now

- DECISIONS.md -- "2026-11-07: Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency"
- DECISIONS.md -- "2026-04-24: Wrapper mechanism = shell-exec inject + cross-ref check". In force for the superpowers wrappers; the Vendor strategy entry replaces it for gstack.
- DECISIONS.md -- "2026-04-25: Vendored-preamble drift accepted for wrapped skills". Narrowed to superpowers by the Vendor strategy entry.
- DECISIONS.md -- "2026-04-23: Cherry-pick prioritization based on production evidence"
- DECISIONS.md -- "2026-04-25: Lifecycle-phase as the curation heuristic"
- DECISIONS.md -- "2026-04-25: M011 scope -- 5-skill cherry-pick from gstack + superpowers". Selects the skills; the mechanism for its two gstack skills follows the Vendor strategy entry.
- DECISIONS.md -- "2026-04-23: Don't vendor third-party methodology content, only adapt concepts"
- DECISIONS.md -- "2026-04-23: Don't rebuild GSD as TypeScript runtime"
- DECISIONS.md -- "2026-11-07: No hard plugin dependencies"

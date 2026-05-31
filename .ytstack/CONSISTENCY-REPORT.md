---
generated: 2026-05-31T09:30:00Z
generator: ytstack:check-consistency (manual run -- using-ytstack freshness + README/CONTRIBUTING reconcile)
authoritative_source: README.md
---

# ytstack Consistency Report

## Summary

- Total checks: 9 (+ targeted audit of using-ytstack, CONTRIBUTING, issue-reporting)
- PASS: 6
- WARN: 3
- FAIL: 4
- Overall: DRIFT DETECTED

The 9 structural checks are mostly green. The drift sits in three places the user
asked about: README install/version block, CONTRIBUTING (stale tool name + retracted
banned-words rule + garbled heading), and a missing issue-reporting channel across
the whole repo.

## Check 1: Skill count drift

Status: PASS

- README badge / hero table / §Status / §Repo-layout all say 21 skills.
- Disk: 21 directories under `skills/`. Consistent.

## Check 2: Wrapped-skill claims vs on-disk

Status: PASS

- All wrapper skills referenced in the README comparison table exist on disk
  (plan-ceo-review, plan-eng-review, office-hours, test-driven-development,
  systematic-debugging, verification-before-completion).

## Check 3: Native-skill claims vs on-disk

Status: PASS

- Native lifecycle skills + 5 engineering-OS additions (atomic-design,
  deutschland-stack-api, european-alternatives-api, oss-project,
  software-craftsmanship) all present.

## Check 4: Explicit-skip claims

Status: PASS

- README §"ytstack is the curation" calls out gstack `investigate` (dup of
  superpowers systematic-debugging) and superpowers `writing-plans` (conflicts
  with milestone/slice/task flow) as skipped. Consistent with concept §3.

## Check 5: Skill selection semantic (no trigger-map) + README examples covered

Status: PASS

- `skills/using-ytstack/SKILL.md` has NO trigger-map table. Version 0.2.0.
  Matches DECISIONS 2026-04-24 "Skill selection is semantic".
- SUBAGENT-STOP block present (Agent Teams teammates skip the directive) --
  aligns with M012 swarm execution.
- README §"What a session feels like" example phrases route to skills whose
  descriptions semantically cover them.

## Check 6: Hook inventory

Status: PASS

- `hooks/` has 8 scripts + hooks.json. README badge / §Status / §Repo-layout
  all say 8 hooks. Consistent.

## Check 7: Artifact list vs init-project

Status: PASS

- 6 core artifacts (PROJECT / DECISIONS / KNOWLEDGE / STATE / RUNTIME /
  PREFERENCES) referenced in concept §3.4 and README. init-project scaffolds them.

## Check 8: Workflow skill references

Status: PASS

- README workflow sections + QUICKSTART reference only skills that resolve to
  `skills/<name>/`.

## Check 9: Em-dash punctuation hygiene

Status: PASS

- README / CONTRIBUTING / QUICKSTART / PROJECT.md: 0 em-dashes.
- CLAUDE.md: 2 hits (lines 68, 109) but both are the rule definition itself
  (showing the forbidden U+2014 char to define the `--` rule). False positives,
  same exemption as writing-style.md. No real violation.

## Targeted findings (the user's three questions)

### FAIL A: Version drift across three files

- `README.md` badge + §Status say **0.1.0** ("full build cycle complete.
  37/39 tasks done; 2 deferred").
- `.claude-plugin/plugin.json` version: **0.1.5**.
- `.claude-plugin/marketplace.json` plugin entry version: **0.1.4**.
- `.ytstack/STATE.md`: 38/39 done, 1 deferred, M010/M011/M012 now in flight.

Three different version strings; plugin.json and marketplace.json disagree with
each other. README §Status is the most stale.

### FAIL B: Install / marketplace block in README is stale

README §Install (lines 189-219) says: add `Yesterday-AI/ystacks` +
`Yesterday-AI/ystacks-internal`, install `ytstack@ystacks-internal`, cross-mp deps
on **skill-creator + web-design** from `Yesterday-AI/ystacks`.

Actual manifests say:
- `marketplace.json`: self-marketplace name `ytstack`, source `./`,
  `allowCrossMarketplaceDependenciesOn: ["yesterday-public-plugins"]`.
- `plugin.json` dependency: **web-design only**, from marketplace
  `yesterday-public-plugins`. No `skill-creator`, no `ystacks`/`ystacks-internal`.
- Recent commit 14f7c19 "update marketplace dependencies to use
  yesterday-public-plugins" confirms the manifest is the newer truth.

The README install instructions cannot be followed as written. The correct
marketplace topology is a maintainer decision. Needs human reconciliation +
a DECISIONS entry before the README is rewritten.

### FAIL C: CONTRIBUTING references a tool that does not exist by that name

- CONTRIBUTING line 26: "Run `ytstack-skill-check` (ships M008 pre-release)".
- Actual binary: `bin/ytstack-check` (already shipped -- "ships M008 pre-release"
  is also stale).
- CLAUDE.md carries the same wrong name.

### FAIL D: CONTRIBUTING "No AI vocabulary" contradicts the locked rule

- CONTRIBUTING §"No AI vocabulary" (lines 64-65): banned list + `grep -riE
  'delve|robust|comprehensive|nuanced'`.
- `docs/ux/writing-style.md` line 3 + DECISIONS 2026-04-24 "drop banned-vocabulary
  list (scope creep)" + CLAUDE.md: the em-dash rule is the ONLY mechanically
  enforced punctuation rule; the banned-words list was retracted.
- CONTRIBUTING still advertises a deleted mechanical rule.

### WARN E: "CI validates" overclaims

- CONTRIBUTING + CLAUDE.md say "CI validates / CI rejects skills that violate".
- `.github/workflows/` contains only `secret-scan.yml`. No UX-contract CI gate.
- `bin/ytstack-check` is local-run only. Wording should say "run locally".

### WARN F: CONTRIBUTING garbled heading

- CONTRIBUTING line 86: "### Schlenther-source-named attribution". "Schlenther"
  is a stray word; the section is about not adding named attribution to public
  artifacts. Heading needs a clean rewrite.

### WARN G: No issue-reporting channel anywhere

- No `.github/ISSUE_TEMPLATE/`, no "Reporting issues / Support" section in README,
  CONTRIBUTING §"Getting help" only points at local files.
- `using-ytstack/SKILL.md` has no issue-reporting hint (confirmed absent).
- plugin.json homepage/repository = https://github.com/Yesterday-AI/ytstack
  (the natural issue channel).

## using-ytstack freshness verdict

UP TO DATE with locked policies:
- Semantic (description-based) selection, no trigger-map -- DECISIONS 2026-04-24.
- SUBAGENT-STOP for Agent Teams teammates -- aligns with M012.
- Version 0.2.0, kind: directive, user-invocable: false.
- Skill list is illustrative, correctly omits unshipped M010/M011 skills.

GAP: no issue-reporting hint (see WARN G).

## Actions suggested (human decides)

- A (version): pick canonical version, sync plugin.json + marketplace.json +
  README badge + §Status.
- B (marketplace): confirm live topology, then rewrite README §Install. Maintainer
  call -- do not guess.
- C (tool name): rename `ytstack-skill-check` -> `ytstack-check`, drop "ships M008
  pre-release". SAFE.
- D (banned words): rewrite CONTRIBUTING §"No AI vocabulary" to match
  writing-style.md (em-dash only). SAFE.
- E (CI claim): soften "CI validates" to "bin/ytstack-check, run locally". SAFE.
- F (heading): fix the garbled "Schlenther" heading. SAFE.
- G (issues): add a Reporting-issues section to README + CONTRIBUTING; optionally a
  brief agent-facing note in using-ytstack.

## Next steps

- Maintainer decides A, B, and G-placement.
- C/D/E/F are unambiguous doc fixes inside the user-authorized README/CONTRIBUTING scope.
- Re-run check-consistency after reconciliation.

---

## Addendum 2026-05-31: CLAUDE.md -> AGENTS.md rename

The contributor guide was renamed `CLAUDE.md` -> `AGENTS.md` (git mv, history
preserved) and `CLAUDE.md` is now a symlink -> `AGENTS.md`. Consistency verdict:

### PASS: rename is symlink-safe

- Only ONE in-repo textual reference to `CLAUDE.md` lives in code/skill space:
  `skills/using-ytstack/SKILL.md:30` -- a generic mention of the Claude Code
  convention file, correct as written. No hook, no `bin/` script, and no skill
  READS or WRITES `CLAUDE.md`. The symlink fully satisfies Claude Code's native
  CLAUDE.md load. Nothing breaks.
- `check-consistency` preamble `[ -f CLAUDE.md ]` still returns yes (the test
  follows the symlink). HARD-GATE unaffected.

### PASS: matches workspace convention

- Sibling repo `clawrag/` already uses the exact `AGENTS.md + CLAUDE.md(symlink)`
  pattern, and its docs reference `AGENTS.md` (zero `CLAUDE.md` textual hits).
  ytstack now matches that precedent.

### WARN H: 15 doc/artifact files still say "CLAUDE.md" textually

- Tracked, non-vendor files referencing the old name: `README.md`,
  `QUICKSTART.md`, `CONTRIBUTING.md`, `NOTICE`, `docs/concept.md`,
  `docs/references.md`, `skills/using-ytstack/SKILL.md`, and the `.ytstack/*`
  artifacts (`DECISIONS.md`, `KNOWLEDGE.md`, `ROADMAP.md`, `STATE.md`,
  `VENDOR-INVENTORY.md`, `REVIEW-NOTES.md`, this report).
- All still resolve via the symlink, so nothing is broken. But the clawrag
  precedent is: docs name `AGENTS.md`, symlink stays as a pure compat shim.
- Reconciliation (human decides): bulk-rename the textual references
  `CLAUDE.md` -> `AGENTS.md` in prose to match the canonical name, OR leave them
  (symlink keeps them valid). NOT auto-applied -- this is a 15-file prose sweep
  outside the rename's mechanical scope.

### Note on Check 9 line references

Earlier checks cite "CLAUDE.md lines 68/109" (em-dash meta-refs). Those lines now
live in `AGENTS.md` (identical content, file renamed). Still false positives, no
real violation.

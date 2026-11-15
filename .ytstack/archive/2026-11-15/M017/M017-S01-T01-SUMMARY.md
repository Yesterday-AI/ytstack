---
milestone: M017
slice: S01
task: T01
project: ytstack
closed: 2026-11-07T12:53:36Z
verification: passed
---

# M017-S01-T01 -- Summary

## Commits

- `b679c34` -- M017-S01-T01: plan superpowers subtree pull to v7.0.2
- `ffe9191` -- Squashed 'vendor/superpowers/' changes from 6fd4507..22f0b46
- `c516914` -- chore(vendor): superpowers 6fd4507 -> v7.0.2 (22f0b46)
- `b293a05` -- M017-S01-T01: record superpowers pin v7.0.2 (22f0b46) in KNOWLEDGE

## Outcome

`vendor/superpowers/` now mirrors upstream tag v7.0.2 (commit `22f0b46`; the annotated tag object `c62ffea` peels to it). The three wrapped files `skills/{test-driven-development,systematic-debugging,verification-before-completion}/SKILL.md` exist at the same paths with unchanged two-field frontmatter; the leak surface predicted by the drift research is present (one `superpowers:verification-before-completion` reference in systematic-debugging, one relative `writing-good-tests.md` link in TDD) and is the target of T02. All ten suites pass, `bin/ytstack-check` has 0 fails and the same 109 vendor warnings, the merge commit is SSH-signed. KNOWLEDGE records the pin and the tag-resolution gotcha (`git ls-remote --tags ... '^{}'`, not the tags API with a short SHA).

## Deviations from plan

No DECISIONS append (the 2026-11-07 vendor decision already covers the pull; the pin is a KNOWLEDGE fact). Diff-stat inspection must address squash commits by subtree-relative paths (`skills/...`), not `vendor/superpowers/skills/...`.

## Follow-ups

- T02: Namespace note + checker rule.
- `.ytstack/VENDOR-INVENTORY.md` (14 -> 15 superpowers skills, `diagnosing-superpowers` added) is refreshed in S02-T03 together with the gstack split.

## Verification

Command: `git log -1 --format='%s' -- vendor/superpowers | grep -q 22f0b46 && bash tests/run-all.sh && bin/ytstack-check` -- passed (ALL SUITES PASSED; checker OK with 109 warnings). `grep -c 'superpowers:verification-before-completion' vendor/superpowers/skills/systematic-debugging/SKILL.md` = 1.

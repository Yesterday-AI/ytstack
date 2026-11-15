---
milestone: M019
slice: S01
task: T01
project: ytstack
closed: 2026-11-07T14:05:18Z
verification: passed
---

# M019-S01-T01 -- Summary

## Commits

- `6c6dc4b` -- M019-S01-T01: move tier/version/kind/triggers under metadata: in all 25 skills; ytstack-check parses one nested level, reads metadata.* first, warns on legacy top-level keys and missing tier/version

## Outcome

All 25 skills carry ytstack's own keys under `metadata:` (`tier`, `version`, `kind`, `triggers`); the six wrappers that had none now have `tier: core`, `version: 0.1.0`. `parse_frontmatter` in `bin/ytstack-check` understands one nested level for `metadata:` (scalars and lists), `skill_meta()` merges metadata-first with legacy top-level fallback, and the checker warns "move under metadata:" on legacy keys and "missing metadata.tier / metadata.version" when both are absent. `docs/ux/skill-structure.md` documents the shape and the reason (Agent Skills spec portability). `claude plugin validate .` clean; 12 suites green; checker tests 27/27.

## Deviations from plan

`triggers:` (also a non-spec key, read by nothing) moved under `metadata:` as well; the plan listed only tier/version/kind.

## Follow-ups

- None.

## Verification

Command: `/bin/bash tests/ytstack-check.test.sh && bin/ytstack-check && claude plugin validate . && bash tests/run-all.sh` -- passed.

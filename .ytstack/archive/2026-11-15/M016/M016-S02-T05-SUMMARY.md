---
milestone: M016
slice: S02
task: T05
project: ytstack
closed: 2026-11-07T12:26:07Z
verification: passed
---

# M016-S02-T05 -- Summary

## Commits

- `7da6711` -- M016-S02-T05: plan ytstack-check banned-pattern rules
- `0e45574` -- M016-S02-T05: ytstack-check enforces the resolver contract (banned patterns, shared lib, version agreement); docs updated

## Outcome

`bin/ytstack-check` gained `check_resolver_contract`: over `skills/*/SKILL.md` and `hooks/*` (not `hooks/lib`, not `hooks.json`; comment lines excluded) it FAILS on `[ -d .git ]`, `basename "$(git rev-parse --show-toplevel`, `CLAUDE_PROJECT_DIR` (hooks only) and `~/.ytstack/.` / `$HOME/.ytstack/.` sentinel paths, each with a hint naming the replacement; skills with an executable preamble (`## Preamble` or a ```! block) must source `hooks/lib/git-ctx.sh`, every hook must source the lib; `plugin.json` vs `marketplace.json` version disagreement is a WARN (currently 0.1.6 vs 0.1.5, aligned in S03-T03). `docs/ux/skill-structure.md` now documents the resolver contract (banned-pattern table, the verbatim preamble block, required exports, lib function list) and replaces "Sentinel File Conventions" with "Ask-once answers" (record in the artifact). `tests/ytstack-check.test.sh` (12 cases) plants fixture skill/hook files with every banned pattern and asserts the exact fails.

## Deviations from plan

The preamble rule was narrowed to skills that actually have a shell preamble: `kind: reference` skills (deutschland-stack-api etc.) carry ```bash curl examples and were false positives on the first run.

## Follow-ups

- S03-T03: align the two versions (0.2.0) so the new WARN disappears; consider promoting it to FAIL afterwards.
- S02 complete: 5/5. Reassessment: S03 unchanged (tests + docs + release), plus the marketplace.json bump already noted.

## Verification

Command: `/bin/bash tests/ytstack-check.test.sh && bin/ytstack-check` -- passed (12/12; checker 0 fails, 110 warnings = 109 vendor + 1 version). All eight suites green: git-ctx 65, hooks-json 45, hooks-readonly 37, post-tool-use-bash 19, pre-compact 39, session-end 32, skill-preambles 192, ytstack-check 12.

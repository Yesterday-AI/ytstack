---
milestone: M017
slice: S01
task: T02
project: ytstack
closed: 2026-11-07T12:57:38Z
verification: passed
---

# M017-S01-T02 -- Summary

## Commits

- `2cb7886` -- M017-S01-T02: plan inline-leak guard
- `6adb07d` -- M017-S01-T02: Namespace note postambles in the superpowers wrappers + ytstack-check inline-leak rule

## Outcome

The three superpowers wrappers end with a `## Namespace note (ytstack)` that maps `superpowers:<skill>` to `ytstack:<skill>` (naming the tokens the inlined v7.0.2 text actually uses: `verification-before-completion`, and in systematic-debugging also `test-driven-development`) and states that relative links resolve under `vendor/superpowers/skills/<skill>/` in the plugin dir. `bin/ytstack-check` gained `check_inline_leaks`: for every wrapper that cat-inlines a vendor SKILL.md it scans the vendor text for `superpowers:` tokens and relative `.md` links and FAILS unless the wrapper's note names the token / says where links resolve (absolute URLs ignored). The test suite builds a fake vendor skill with both leak kinds on the copied tree (vendor catalog dirs are now real dirs with per-skill symlinks so fixtures can be added) and checks flag -> note -> clear.

## Deviations from plan

The first wrapper note missed `superpowers:test-driven-development` (present in the systematic-debugging text); the checker caught it on the real tree, which is exactly the guard's purpose.

## Follow-ups

- S01 complete (2/2). S02 starts with the gstack install context in the lib.

## Verification

Command: `/bin/bash tests/ytstack-check.test.sh && bin/ytstack-check && /bin/bash tests/skill-preambles.test.sh` -- passed (16/16; checker 0 fails, 109 vendor warnings; 192/192).

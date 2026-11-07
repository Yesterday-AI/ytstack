---
milestone: M019
slice: S01
project: ytstack
created: 2026-11-07T19:10:00Z
status: in-progress
task_count: 3
completed_tasks: 0
---

# M019-S01 -- Slice Plan

**Goal:** Every skill's frontmatter is platform-native (`metadata:` for ytstack's own keys, explicit invocability flags) and every description is a trigger statement within budget; the checker enforces it.

## Tasks

- [ ] T01 -- `metadata:` migration: move `tier`, `version`, `kind` under `metadata:` in all 25 skills (incl. the six wrappers that had none: give them `metadata: {tier: core, version: 0.1.0}`); `bin/ytstack-check` parser learns one level of nesting for `metadata` and reads tier/version/kind from there (top-level still accepted with a WARN "move under metadata"); `docs/ux/skill-structure.md` frontmatter section updated; `claude plugin validate .` clean; preamble/hook suites unaffected.
- [ ] T02 -- Trigger-only descriptions: rewrite all 25 descriptions as third-person what + when + when-not statements (no procedure summaries, no mode lists, no step names), each under 1,024 chars; reference skills get `user-invocable: true`; directives `user-invocable: false`; `using-ytstack`/`minimal-code` keep `disable-model-invocation: false`.
- [ ] T03 -- Checker rules: FAIL description > 1,024 chars or missing; WARN on procedure-summary phrases (`RED-GREEN`, `Step 1`, `six forcing questions`, `four modes`, numbered lists, "Thin ytstack wrapper around"); WARN when `user-invocable` is absent on `kind: reference|directive`; `tests/ytstack-check.test.sh` cases; KNOWLEDGE note on `/skill-doctor` + `claude plugin details ytstack` as the manual checks.

## Done when

All tasks `[x]`; `bin/ytstack-check` 0 fails; `claude plugin validate .` clean; `tests/run-all.sh` green.

## Notes

- Platform facts (research): unknown top-level frontmatter keys are ignored by Claude Code but hard-error on claude.ai upload; description + when_to_use capped at 1,536 chars per listing entry; spec max 1,024 for description; "never summarise the workflow in the description" (superpowers writing-skills) + third-person what/when (Anthropic).

---
milestone: M019
slice: S01
task: T02
project: ytstack
closed: 2026-11-07T14:08:58Z
verification: passed
---

# M019-S01-T02 -- Summary

## Commits

- `416cd63` -- M019-S01-T02: trigger-only descriptions (what + when + when-not, third person, < 450 chars) for all 25 skills; user-invocable: true on the five reference skills

## Outcome

Every description is now a third-person trigger statement: what the skill is, when it applies (including the phrasings users actually say), when it does not (with the skill to use instead). Procedure summaries, mode lists, step names and "Thin ytstack wrapper around" are gone; the longest description is 449 chars (was 644), all 25 are single-line quoted scalars. The five reference skills carry `user-invocable: true`; `using-ytstack` and `minimal-code` keep `user-invocable: false`.

## Deviations from plan

`disable-model-invocation: true` was not set on the lookup skills (`deutschland-stack-api`, `european-alternatives-api`): their when-clauses exist precisely so the model triggers them on EU-sovereignty questions; locking them to user invocation would defeat that. Recorded here rather than in DECISIONS because it is reversible per skill.

## Follow-ups

- S02-T01 evals measure whether the trimmed descriptions still trigger (`tool_used: Skill` graders).

## Verification

Command: `bin/ytstack-check && claude plugin validate .` -- passed (0 fails; validate clean). Description lengths measured: max 449.

---
milestone: M018
slice: S02
task: T04
project: ytstack
closed: 2026-11-07T13:38:04Z
verification: passed_with_caveats
---

# M018-S02-T04 -- Summary

## Commits

- `2b012b7` -- M018-S02-T03/T04: plan reconcile skill + minimal-code guard
- `fa00508` -- M018-S02-T04: minimal-code guard directive (six-rung ladder, never-cut list, shortcut: markers); ponytail concept credit in NOTICE; TDD note

## Outcome

`skills/minimal-code/SKILL.md` (34 lines, `kind: directive`, not user-invocable) carries the six-rung ladder (needed? exists? stdlib? dependency? one line? minimum that passes), the never-cut list (validation at trust boundaries, auth, boundary error handling, accessibility, the one small test), `shortcut:` markers that summarize-task lists under Follow-ups, the review question "which rung, what did you leave out on purpose", and a scope note (does not override user requests, DECISIONS or a plan's Files). NOTICE credits the ponytail project for the concept; the prose is ytstack's. The TDD wrapper's Namespace note points at the guard for the GREEN step.

## Deviations from plan

The session-start injection (pref-gated six-line pointer) and its hooks-readonly case are deferred to S02-T02 together with the lint wiring, because the M010 worktree agent is editing `hooks/session-start` concurrently. Until then the guard is available via the Skill tool and the TDD note, not auto-injected -- caveat.

## Follow-ups

- S02-T02: session-start injection of lint + minimal-code pointer after the M010 merge.

## Verification

Command: `bin/ytstack-check && wc -l skills/minimal-code/SKILL.md` -- passed (0 fails; 34 lines).

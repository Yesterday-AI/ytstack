---
milestone: M010
slice: S01
task: T02
project: ytstack
closed: 2026-11-07T13:40:00Z
verification: passed
---

# M010-S01-T02 -- Summary

## Commits

- `1999bbd` -- M010: adopt-brownfield skill (detect -> map -> per-artifact decision -> codebase map -> scaffold gaps)

## Outcome

New core skill `skills/adopt-brownfield/SKILL.md` (479 lines, 0 em-dashes, checker-clean): verbatim M016 resolver preamble, signals + candidate list, HARD-GATE (no moves without approval, no office-hours), two Anti-Patterns, 10-step checklist, dot graph, mapping table, one AskUserQuestion per slot (reference / extract / move / leave with Completeness + tier + re-ask hint), four read-only mapper subagents into `.ytstack/codebase/`, templates for PROJECT (`origin: brownfield-import`, Validated, Adoption table), DECISIONS (inherited by reference), KNOWLEDGE (link index), RUNTIME (derived), STATE (`tracker:`), PREFERENCES, optional backlog, `.gitignore` block, entry-point pointer, report, terminal state. Preamble verified in a brownfield fixture (5 signals, README one-liner extracted), a plain dir (0) and the no-lib fallback (`unknown`).

## Deviations from plan

Scope is fixed to project level without a question (user scope via init-project); recorded in DECISIONS.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && bin/ytstack-check` -- passed (233/233 at the time; 0 fails).

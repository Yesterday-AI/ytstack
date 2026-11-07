---
milestone: M018
slice: S01
task: T03
project: ytstack
closed: 2026-11-07T13:30:09Z
verification: passed
---

# M018-S01-T03 -- Summary

## Commits

- `d6c9c92` -- M018-S01-T03: plan artifact states enum
- `03451ac` -- M018-S01-T03: artifact states enum (planned/in-progress/done/dropped/shipped-informally): reassess-roadmap stale-milestone step, plan-task/summarize-task flips, session-start in-progress line, UX doc

## Outcome

`docs/ux/skill-structure.md` defines the artifact-state enum (`planned | in-progress | done | dropped | shipped-informally`) with who writes each. `reassess-roadmap` computes `STALE_MILESTONES` (planned/in-progress roadmaps with no summaries and no file touched for 14 days) and has a Step 10 AskUserQuestion per stale milestone (`dropped` / `shipped-informally` / keep) that writes the frontmatter and the global row and never deletes plans. `plan-task` flips a milestone to `in-progress` on its first planned task; `summarize-task` flips slice and milestone to `done` when the last task / last slice closes. `session-start` adds "Milestones in progress: ..." when more than one roadmap is in progress (pointer-drift smell). hooks-readonly suite 39 cases.

## Deviations from plan

Test fixture lesson: a test must restore, not delete, a tracked fixture file it overwrites (the cleanliness assertions later in the suite depend on it).

## Follow-ups

- T04 quick-task; S02 adds the lint that makes the pointer smell explicit.

## Verification

Command: `/bin/bash tests/hooks-readonly.test.sh && /bin/bash tests/skill-preambles.test.sh && bin/ytstack-check` -- passed (39/39; 218/218; checker 0 fails, 19 warnings).

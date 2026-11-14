---
milestone: M028
slice: S02
project: ytstack
created: 2026-11-14T09:00:00Z
status: done
task_count: 6
completed_tasks: 6
---

# M028-S02 -- Slice Plan

**Goal:** The six skills are rewritten as self-contained ytstack skills from gstack v1.96.0.0.

## Tasks

- [x] T01 -- office-hours (SKILL.md + four references: startup diagnostic, builder brainstorm, pitch templates, founder resources)
- [x] T02 -- plan-ceo-review (SKILL.md + review sections); milestone-mode review goes to `M###-CEO-REVIEW.md`
- [x] T03 -- plan-eng-review (SKILL.md + test review, outside voice, outputs); milestone-mode review goes to `M###-ENG-REVIEW.md`
- [x] T04 -- retro (SKILL.md; git metrics inline, history in earlier `M###-RETRO.md` files)
- [x] T05 -- ship (SKILL.md + six references)
- [x] T06 -- document-release (SKILL.md)

## Outcome

Commit `255cc10`, one subagent per skill, briefed by the adaptation rules; the lead harmonised the review-file names, the pitch lookup (newest first) and the retro task count, and removed document-release's unused ship-dispatch mode. Each skill keeps its ytstack artifact path, frontmatter keys and Terminal State. Not yet run end to end in a real session; the preambles run in the test fixtures and in scratch repos.

## Notes

- Deliberately not carried over: cross-session state (builder profile, learnings, telemetry), external services (Greptile, Capy, Apple release), the browser and designer binaries, the specialist review army (ship: one checklist pass plus one adversarial subagent).

---
milestone: M022
slice: S03
project: ytstack
created: 2026-11-13T15:10:00Z
status: done
task_count: 4
completed_tasks: 4
---

# M022-S03 -- Slice Plan

**Goal:** STATE stays a pointer, milestone close folds, fresh sessions prove it.

Planned to wait for M020 (Kimi adapter), which edits `hooks/session-start` and `STATE.md` too. Built before M020 landed, on the operator's instruction of 13 November 2026; the two changes meet at merge time.

## Tasks

- [x] T01 -- `yt_state_lint` reports a `STATE.md` above the size bound and status paragraphs beside the current one (W8, W9), as prompts that stop no skill; the frontmatter that #21 and #31 read stays unchanged.
- [x] T02 -- The SessionStart injection cuts the "Next action" excerpt to what fits instead of dropping it; `reconcile` offers to move the history of `STATE.md` verbatim into the archive. ytstack's own `STATE.md` is not trimmed here: that needs the operator's answer to `reconcile`.
- [x] T03 -- At the last slice of a milestone `reassess-roadmap` folds what still holds into the area files and names the archive offer; `reconcile` archives the slice and task files of closed milestones on request. Nothing moves without consent.
- [x] T04 -- Three fresh-session cases on one repository snapshot (`fresh-resume`, `fresh-bugfix`, `fresh-requirement`), run with the current and the revised instructions: accuracy, contradictions met, reading effort; recorded in `KNOWLEDGE.md` ("Eval runs").

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

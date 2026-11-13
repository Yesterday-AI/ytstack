---
milestone: M022
slice: S03
project: ytstack
created: 2026-11-13T15:10:00Z
status: planned
task_count: 4
completed_tasks: 0
---

# M022-S03 -- Slice Plan

**Goal:** STATE stays a pointer, milestone close folds, fresh sessions prove it.

**Waits for M020** (Kimi adapter): it edits `hooks/session-start` and `STATE.md`, the two files this slice changes most.

## Tasks

- [ ] T01 -- `yt_state_lint` warns when `STATE.md` exceeds a size bound or carries dated history below "Next action"; the frontmatter that #21 and #31 read stays unchanged.
- [ ] T02 -- The SessionStart injection shows "Next action" again instead of "omitted ... near the 10,000-char cap"; ytstack's own `STATE.md` history moves out with the operator's consent.
- [ ] T03 -- Closing a milestone folds what still holds into the area files (`reassess-roadmap` at the last slice, or `retro`) and offers that milestone's plans and summaries for archiving through `reconcile`; nothing moves without consent.
- [ ] T04 -- Three fresh-session cases (resume, bug fix, new requirement) on one repository snapshot, current against revised instructions: accuracy, contradictions met, reading effort; recorded in `KNOWLEDGE.md` ("Eval runs").

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

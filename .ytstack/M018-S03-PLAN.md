---
milestone: M018
slice: S03
project: ytstack
created: 2026-11-07T16:00:00Z
status: planned
task_count: 3
completed_tasks: 1
---

# M018-S03 -- Slice Plan

**Goal:** Read-side support for the layouts consumers already use, documentation of the ceremony dials, and the milestone's tests/changelog.

## Tasks

- [x] T01 -- Read-side layouts: `yt_find_artifacts <yt_dir> <glob>` in the lib searches flat `.ytstack/`, `milestones/M###/`, `decisions/`, `backlog/{,shipped,rejected}/`; `session-start` (recent summaries), `resume-session`, `summarize-task` (plan lookup), `reassess-roadmap` use it; tests with both layouts.
- [ ] T02 -- Docs: README workflows ("Dialing ceremony up or down", quick lane, reconcile), QUICKSTART section with the four preferences and the Ralph-loop default, `docs/concept.md` §3 (new skills quick-task / reconcile / minimal-code, states enum), `docs/ux/skill-structure.md` (`kind: directive` injection contract), NOTICE (ponytail concept credit), KNOWLEDGE gotchas.
- [ ] T03 -- CHANGELOG `[Unreleased]` entries for M018; `ytstack-check` + `run-all` green from a clean clone; milestone bookkeeping; no version bump (0.4.0 ships with M019).

## Done when

All tasks `[x]`; clean-clone `run-all.sh` + `ytstack-check` green.

## Notes

- Writing stays flat in `.ytstack/` (one convention); only reading tolerates the alternatives.

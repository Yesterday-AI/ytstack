---
milestone: M022
slice: S01
project: ytstack
created: 2026-11-13T15:10:00Z
status: done
task_count: 5
completed_tasks: 5
---

# M022-S01 -- Slice Plan

**Goal:** The spec artifacts exist, and ytstack has its own.

## Tasks

- [x] T01 -- The format contract `docs/ux/spec-format.md` (both files, the maintenance rules, what is checked mechanically); section in `docs/concept.md`; glossary entry; DECISIONS entry; the four corrections of the review comment applied to the plan in `ROADMAP.md`.
- [x] T02 -- `bin/ytstack-spec` with `lint`, `drift`, `impact` and `areas`, and `tests/ytstack-spec.test.sh` with one case per rule.
- [x] T03 -- `init-project` scaffolds `SPEC.md` and area files as `planned`; `adopt-brownfield` builds them over existing documents, pointer-only, with honest status; an outcome grader per eval case.
- [x] T04 -- ytstack's own `.ytstack/spec/`: `SPEC.md` and the six areas, each statement read against the code; `bin/ytstack-check` runs `lint` and `drift` on it.
- [x] T05 -- The entry documents agree with the repository: `PROJECT.md`, `KNOWLEDGE.md`, `ROADMAP.md` frontmatter and section states, `AGENTS.md`, and the counts in README, QUICKSTART and `docs/concept.md` that the area agents found wrong.

## Done when

All tasks marked `[x]` and verified.

## Notes

- T03 and T04 were written by four dispatched agents in this worktree, one file set each; the lead read their output against the code before closing the tasks.
- Push, pull request and release are operator actions.

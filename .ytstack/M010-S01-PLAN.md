---
milestone: M010
slice: S01
project: ytstack
created: 2026-11-07T13:40:00Z
status: done
task_count: 6
completed_tasks: 6
---

# M010-S01 -- Slice Plan

**Goal:** a documented repo without `.ytstack/` is detected once (lib), adopted through its own skill, and never pitched; init-project, the SessionStart hook and the milestone skills know about it.

## Tasks

- [x] T01 -- `yt_brownfield_signals <toplevel>` in `hooks/lib/git-ctx.sh` (TDD): README > 30 lines, > 2 `docs/*.md`, CHANGELOG.md, `docs/adr/` | `docs/decisions/` | `docs/design-decisions.md`, manifest + > 50 commits, AGENTS.md/CLAUDE.md; `YT_BROWNFIELD_HINTS` one line per source; extras (`.env.example`, compose, workflows, `docs/plans/`, existing `.ytstack/`) as hints only; 21 cases in `tests/git-ctx.test.sh`.
- [x] T02 -- `skills/adopt-brownfield/SKILL.md`: resolver preamble + signals + candidates, HARD-GATE, two Anti-Patterns, 10-step checklist, dot flow, mapping table, per-artifact AskUserQuestion (A reference / B extract / C move / D leave, Completeness + tier), four read-only mapper subagents -> `.ytstack/codebase/`, templates (PROJECT Validated + Adoption table, DECISIONS by reference, KNOWLEDGE link index, RUNTIME derived, STATE with `tracker:`, PREFERENCES), `yt_ensure_gitignore`, entry-point pointer, report, terminal state; added to `tests/skill-preambles.test.sh` with a brownfield fixture.
- [x] T03 -- `init-project`: Anti-Pattern "too mature for greenfield ceremony", preamble `BROWNFIELD_SIGNALS` + `CANDIDATES`, Step 3 route (report + stop at >= 2 signals and no pitch), renumbered steps, `tracker: none` in the STATE.md template, terminal state; preamble suite asserts the route condition.
- [x] T04 -- `hooks/session-start`: greenfield branch runs the detector; >= 2 signals -> "existing codebase (N signals: sources); invoke `ytstack:adopt-brownfield` FIRST, not office-hours"; empty repos keep office-hours-first plus a pointer; `using-ytstack` lists the skill and the rule; `tests/hooks-readonly.test.sh` covers both variants and the < 9500 char guard.
- [x] T05 -- `plan-milestone` / `reassess-roadmap`: preambles read `tracker:` and echo `TRACKER`; one sentence each (goal question / backlog sweep) when it is not `none`; preamble suite checks default and set value.
- [x] T06 -- Docs: README (Workflows paragraph, Quickstart bullet, 22 skills / 596 cases), QUICKSTART "Adopting ytstack in an existing project", `docs/concept.md` 3.4 + artifacts + 5.1 note, `docs/ux/skill-structure.md` lib list, CHANGELOG `[Unreleased]`, KNOWLEDGE gotchas, DECISIONS entry; milestone bookkeeping + ROADMAP flip.

## Done when

All tasks `[x]`; `bash tests/run-all.sh` prints `ALL SUITES PASSED`; `bin/ytstack-check` reports 0 fails. Verified 2026-11-07: 596 cases green, `OK (with 19 warning[s])`.

## Notes

- `.ytstack/STATE.md` was deliberately not edited in this slice (owned by the main session); M016/M017 files untouched.
- No version bump; CHANGELOG `[Unreleased]`.

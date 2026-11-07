---
milestone: M010
project: ytstack
created: 2026-11-07T13:40:00Z
size: S
---

# M010 -- Context

## Goal

An existing codebase with its own README, docs, CHANGELOG, ADRs and commit history gets a first-class entry into ytstack instead of a greenfield pitch: a new `adopt-brownfield` skill links what the repo already documents into `.ytstack/`, maps the codebase with read-only subagents and scaffolds only the gaps; `init-project` and the SessionStart hook recognise such a repo through one shared signal count and route there. Closes the behaviour gap in issue #18.

## Exit criteria

- `hooks/lib/git-ctx.sh` has `yt_brownfield_signals <toplevel>` setting `YT_BROWNFIELD_SIGNALS` (0..6) and `YT_BROWNFIELD_HINTS` (one source -> artifact line per finding); unit tests: fresh repo 0, README 40 + docs x3 + CHANGELOG + docs/adr = 4, + package.json with > 50 commits = 5.
- `skills/adopt-brownfield/SKILL.md` passes `bin/ytstack-check` and `tests/skill-preambles.test.sh` (main, worktree, brownfield fixture with `BROWNFIELD_SIGNALS >= 2`); procedure = detect -> analyze -> per-artifact AskUserQuestion (reference / extract / move / leave) -> four read-only mapper subagents into `.ytstack/codebase/` -> templates only for gaps -> `.gitignore` block -> entry-point pointer -> report; never runs office-hours, never moves a file without approval, writes `init_completed` + `scope` + `origin: brownfield-import`.
- `init-project` echoes `BROWNFIELD_SIGNALS`, carries the "too mature for greenfield ceremony" Anti-Pattern, and at >= 2 signals without a pitch reports + stops (no auto-invoke, no placeholders). STATE.md template has `tracker:`.
- `hooks/session-start` greenfield block names the sources and routes to `adopt-brownfield` at >= 2 signals; injection stays well under 10,000 chars (test guard < 9500). `using-ytstack` lists the skill.
- `plan-milestone` / `reassess-roadmap` read `tracker:` and mention in one sentence that BAU work tracked there needs no milestone; no new questions.
- README, QUICKSTART, `docs/concept.md`, CHANGELOG `[Unreleased]`, KNOWLEDGE, DECISIONS updated; `tests/run-all.sh` and `bin/ytstack-check` green.

## Size

S -- one slice, six tasks, executed in one worktree session.

## Decisions locked in discuss phase

- 2026-11-07: separate skill, not a flag on init-project; one shared detector in the lib (DECISIONS "Brownfield adoption is a reference-first distillation, never a pitch").
- 2026-11-07: per-artifact decisions asked inline and recorded in PROJECT.md's Adoption table; no `ADOPTION-PLAN.md`.
- 2026-11-07: brownfield memory is project-scoped without a scope question; user scope stays reachable through init-project.
- 2026-11-07: `tracker:` is a STATE.md frontmatter field (`none | linear | github-projects | paperclip | jira`), default `none`, never asked for; set by hand.

## Open questions

- Whether `plan-milestone` should read `.ytstack/codebase/*.md` explicitly (today the skill text relies on the agent reading them because PROJECT.md and STATE.md point there). Candidate for M018 ceremony scaling.
- Release: shipped under CHANGELOG `[Unreleased]`; version bump is the operator's call (0.3.0 is reserved by M017).

## Research basis

`docs/research/2026-11-07-notes/agentic-sdlc-methodology.md` Key Question 5 (GSD `/gsd-onboard` + `/gsd-map-codebase`, BMAD `bmad-project-context`, OpenSpec `/opsx:onboard`); `docs/research/2026-11-07-notes/local-consumer-repos-audit.md` "Brownfield" (7 of 17 consumers); issue #18 + SunoFlow `FRICTION-NOTES.md`.

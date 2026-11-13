---
milestone: M026
project: ytstack
created: 2026-11-13T18:09:00Z
size: S
---

# M026 -- Context

## Goal

A merged change is followed until the target serves it and stays healthy, and the upkeep of a project's `.ytstack/` can run on a schedule and leave one report.

## Exit criteria

- `bin/ytstack-watch release --commit <sha>` reads the "Release" section of `RUNTIME.md`, waits until the target reports the commit, asks the health command for the settle time and prints one receipt with read times; it changes nothing on the target and exits non-zero when the commit never arrives or the target turns unhealthy.
- `finish-lane` runs that watch after a merge when the project has a "Release" section, and says so when it has none.
- `bin/ytstack-upkeep` collects in one run what needs a look (spec drift, the STATE lint, open and lapsed gates, questions that were never asked, lanes without movement) and exits 0 when nothing does.
- `docs/recipes/recurring-upkeep.md` shows how to schedule that run on each supported host and what it may leave behind (a question file, never a product change).
- `bash tests/run-all.sh` passes on macOS and in the Linux containers; `bin/ytstack-check` reports no failure.

## Size

S -- see `M026-ROADMAP.md`.

## Decisions locked in discuss phase

- 2026-11-13T18:09:00Z: the watch observes, it does not deploy and does not roll back. The rollout stays with the person or the project's pipeline.
- 2026-11-13T18:09:00Z: the release watch is a subcommand of `bin/ytstack-watch` and a step of `finish-lane`, not a skill of its own.
- 2026-11-13T18:09:00Z: recurring upkeep is a script and a recipe, not a skill: not every host has scheduled runs.

## Open questions

(none)

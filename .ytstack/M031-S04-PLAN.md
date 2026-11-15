---
milestone: M031
slice: S04
project: ytstack
created: 2026-11-15T11:30:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M031-S04 -- Slice Plan

**Goal:** A person sets up the factory tools from one guide: `QUICKSTART.md` gets "Setting up the factory tools" (greenfield and brownfield/upgrade variants) and an "Upgrading from 0.x" checklist (issue #54 comment "Addition: the setup guide has the same gap").

## Tasks

- [x] T01 -- `QUICKSTART.md` "Setting up the factory tools": which steps apply to a new and to an adopted or upgraded project, then numbered steps with the exact command and how to check each: risk routing (`REVIEW.md` with lenses and `## Own reviewers`, `auto_merge`, `merge_by: risk`, `ytstack-risk check`, a dry `ytstack-risk route --pr <n>`), PR watch (`enable`, `install-worker --yes`, the asdf/mise shim caveat, restart of running sessions, `register --all-open` for a coordinator, `handover` on rotation), `RUNTIME.md` "Release" and "Signals" (`ytstack-runtime check` / `sections`), `ytstack-upkeep` on a schedule, standing instructions and external plans, and what the SessionStart "Factory tools" lines and the version notice mean.
- [x] T02 -- `QUICKSTART.md` "Upgrading from 0.x": a checklist by version range, derived from `CHANGELOG.md` and the upgrade notes in it, every command present in `bin/` or the host CLI.
- [x] T03 -- README pointers to both sections; the README and QUICKSTART sentences "nothing has run against a real host yet" corrected from the sources (issue #54 field note, M030-S01 measurement); every relative link and every `bin/` command in the new text checked by a one-off script.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- No suite checks documentation links or commands (`tests/`, `bin/ytstack-check`: only vendor-leak links of wrappers), so no test is added; T03 checks the new text once with a throwaway script outside the repository.
- `QUICKSTART.md` and `README.md` belong to no spec area (`bin/ytstack-spec areas` says `no area`), so the slice changes no area file.
- `STATE.md`, `ROADMAP.md`, `M031-ROADMAP.md` and `CHANGELOG.md` stay with the coordinating session.

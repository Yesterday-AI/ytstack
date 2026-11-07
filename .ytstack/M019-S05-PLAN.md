---
milestone: M019
slice: S05
project: ytstack
created: 2026-11-07T20:50:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M019-S05 -- Slice Plan

**Goal:** 0.4.0 is cut: CHANGELOG folded, manifests and README bumped, clean-clone verification green, tag set, operator notes written.

## Tasks

- [x] T01 -- CHANGELOG: `[Unreleased]` (M010 + M018 + M019 + fixes) becomes `## [0.4.0] - 2026-11-07` above `[0.3.0]`; fresh empty `[Unreleased]`; compare links updated; wording pass (no em-dashes, one entry per change).
- [x] T02 -- Manifests + docs: `plugin.json` / `marketplace.json` 0.4.0; README badge + Status paragraph (what 0.4.0 ships, what is next); QUICKSTART / AGENTS.md / NOTICE version mentions; `bin/ytstack-check` version agreement.
- [x] T03 -- Verification + close: clean clone -> `bash tests/run-all.sh` + `bin/ytstack-check` + `claude plugin validate .`; eval re-run of the cases that changed (`code-review`, `grill`, `handoff-session`); tag `v0.4.0` (same style as v0.3.0); M019-ROADMAP / global ROADMAP / M019-CONTEXT closing note / STATE with the operator notes (push + tags, `/plugin update`, catalog sync in `Yesterday-AI/skills`, skills.sh listing, gstack install).

## Done when

All tasks `[x]`; clean-clone verification green; `git tag v0.4.0` exists locally; STATE lists the operator actions.

## Notes

- Push, issue closing and catalog sync are operator actions (standing instruction).

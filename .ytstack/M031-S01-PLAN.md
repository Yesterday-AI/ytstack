---
milestone: M031
slice: S01
project: ytstack
created: 2026-11-14T23:45:00Z
status: in-progress
task_count: 3
completed_tasks: 1
---

# M031-S01 -- Slice Plan

**Goal:** A coordinator uses the shipped factory tools without being told (route before every merge, PR watch or `ytstack-watch`, release watch, signals, review lessons), and it can rotate to a fresh session in one step while lanes run, its PR watches going with it.

**Blocked by:** none

## Tasks

- [x] T01 -- PR watch handover: `ytstack-pr-watch handover --from SESSION [--to SESSION]` moves every watch, undelivered notice, branch binding and candidate of the old session to the new one (default: the current session) and forwards later registrations for the old session to the new one. Unittests in `tests/pr_watch/test_handover.py`, `docs/pr-watch.md`, the `hooks-and-state` and `checks-and-evals` area files.
- [ ] T02 -- `coordinate` Step 7 becomes "Factory tools": one table with command, when and when skipped for the route (`ytstack-finish-lane route`, or `ytstack-risk route` for a merge outside the lanes, also when this session merges itself), the PR watch registration or `ytstack-watch`, `ytstack-watch release` after every merge to production, `signal-intake` / `incident`, `review-lessons` after a merge with a bot finding. The PR watch text of Step 7 is unified, not repeated. A test in `tests/skill-preambles.test.sh` checks that every `ytstack-*` command the step names exists with that subcommand. `skills` area file.
- [ ] T03 -- `coordinate` Step 12 rotates in one step while lanes run: handoff written from the files with the PR watch session, the background watches and every running worker's address; the successor's Step 3 runs `ytstack-pr-watch handover --from <old session>`; the old session stays open only as a relay for its workers' reports. `docs/ux/coordinator-format.md` "Rotation", test assertions, `skills` area file.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Sources: issue #54 point 1 and "coordinate: an explicit Factory tools step"; issue #61, the last smaller observation (rotation after one compaction is not followable under load).
- No renumbering: the factory tools take Step 7, which already held the PR watch and the release watch; no doc outside the skill cites a coordinate step number.

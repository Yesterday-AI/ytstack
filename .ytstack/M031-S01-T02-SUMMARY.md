---
milestone: M031
slice: S01
task: T02
project: ytstack
closed: 2026-11-15T00:15:00Z
verification: passed
---

# M031-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M031-S01-T02: coordinate runs the factory tools in Step 7`).

## Outcome

Step 7 of `coordinate` became "Run the factory tools": one table named, for the route, the PR watch, the release watch, signals and review lessons, the command, when it runs and the only condition that skips it. The route runs before every merge, also one the coordinator makes itself outside `finish-lane`; such a merge follows `finish-lane` Step 11 for who merges and goes through `ytstack-finish-lane merge`. The PR watch text of the old Step 7 stands once, under the table, with `ytstack-watch` as the fallback. The preamble printed `MERGE_BY`, `REVIEW_POLICY`, `OWN_REVIEWERS`, `PR_WATCH` (flag and heartbeat age, from local state only), `RELEASE` and `SIGNALS`. The Terminal State allowed `signal-intake`, `incident` and `review-lessons`. `metadata.version` 0.3.0 to 0.4.0.

## Deviations from plan

- The preamble reads the heartbeat with `sed` from `ytstack-pr-watch status`, not with a second Python call: under a version-manager shim (asdf) `python3` fails without the user's HOME, and the test fixture runs with its own HOME. The test hands the engine the resolved interpreter through `YTSTACK_PYTHON`, the variable `bin/ytstack-pr-watch` already reads.
- The step number stayed 7 (it already held the PR watch and the release watch), so no cross-reference changed; no document outside the skill cites a `coordinate` step number.

## Follow-ups

- none

## Spec

- skills: the `coordinate` line names the factory tools, the preamble lines and the route on an own merge

## Verification

Command: `bash tests/skill-preambles.test.sh && bin/ytstack-check` -- the suite exit 0, last line `570 passed, 0 failed` (17 new cases were red before the skill change); the checker exit 2, `OK (with 9 warning[s])`, no `[fail]` line; at the working tree on top of `f05852c` in the local checkout (macOS, bash 3.2). `bash bin/ytstack-spec lint`: `6 area file(s), 0 failure(s), 0 warning(s)`.

Not checked: the step in a live coordinator run (an eval case is named in the slice report).

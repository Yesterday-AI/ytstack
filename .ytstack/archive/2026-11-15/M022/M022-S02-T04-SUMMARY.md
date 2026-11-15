---
milestone: M022
slice: S02
task: T04
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S02-T04 -- Summary

## Commits

- The commit that carries this file (`M022-S02-T04: drift answer at the slice boundary, pointers to SPEC.md`).

## Outcome

The `reassess-roadmap` preamble printed the drift report between `SPEC_DRIFT_BEGIN` and `SPEC_DRIFT_END`, and Step 3a answered it once per area: correct the area file or its source when a statement became false, set `verified_at` to the checked commit when none did. `resume-session` printed `HAS_SPEC`, read the "Areas" table of `spec/SPEC.md` only and named the area file of the next work in the briefing; without a spec it pointed at `adopt-brownfield`. `handoff-session` got the rule "Point, do not copy" and two lines in the `HANDOFF.md` template that name `spec/SPEC.md`. `hooks/session-start` got `SPEC_HINT`: when `spec/SPEC.md` exists, the closing sentence of the state block names it as the place for what applies now.

Step 3b and the gate block in `skills/reassess-roadmap/SKILL.md` and the reworded minimal-code line in `hooks/session-start` belong to M023.

## Deviations from plan

- The one-line pointer to `spec/SPEC.md` in the SessionStart injection was planned for S03 and was built here. Without it the route to the spec depends on a skill being invoked. It sits in the closing sentence, away from the output mode M020 adds to `hooks/session-start`.

## Follow-ups

- M020 edits `hooks/session-start` as well. Whoever merges second keeps `SPEC_HINT` in the closing sentence.

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The technical spec in the loop")
hooks-and-state: `.ytstack/spec/hooks-and-state.md` -- Behavior ("SessionStart injection")
artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers", the row for `spec/`)

`bin/ytstack-spec impact` saw the three files as uncommitted changes when this summary was written. They are new on this branch and are committed with S01-T04.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` and `/bin/bash tests/hooks-readonly.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout: `395 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line; `63 passed, 0 failed`. One run of `hooks/session-start` with this worktree as `cwd` printed the closing sentence with "spec/SPEC.md for what applies now,"; the injection measured 8,760 characters.

Not checked: the answer to a drift line (Step 3a) is prose and no eval case has an area that drifted. The `SPEC.md` hint is asserted in `tests/hooks-readonly.test.sh` and the drift report in `tests/skill-preambles.test.sh`, both added with the M023 commits; `reassess-roadmap`, `resume-session` and `handoff-session` passed their eval cases in the run of M023-S03-T03. No live session on Codex, where the same hook script runs through `bin/ytstack-codex`.

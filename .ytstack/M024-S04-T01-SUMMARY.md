---
milestone: M024
slice: S04
task: T01
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S04-T01 -- Summary

## Commits

- The commit that carries this file (`M024-S04-T01: skill coordinate and bin/ytstack-watch`).

## Outcome

`skills/coordinate/SKILL.md` was written: thirteen checklist items, of which items 4 to 13 are one loop, and three terminal states (the frontier is empty and no lane is held, a question waits for the human, the session rotated). The skill may invoke `finish-lane`, `handover-step`, `reassess-roadmap`, `handoff-session` and `lane-retro` and no other skill.

`bin/ytstack-watch` was built with its suite. In the suite the first poll printed every pull request, later polls printed a line only when a value changed, a finished pull request was not read again, a failed read printed one line and the loop went on, three failed polls in a row ended it with exit 1, and nothing was written into the repository. `--once` printed one line per pull request ending in `read <UTC>`.

## Deviations from plan

- An "unknown" mergeability after a known value is not a change. The host answers "unknown" for every open pull request while it recomputes after a merge into the base; the watcher keeps the last known value and prints no line.
- Rotation has no hook. It is a handoff plus current files, triggered after the first compaction or by the host's context indicator (`M024-CONTEXT.md`, decision of 13 November 2026).
- The interval has a minimum of 20 seconds (default 60); a lower value is a usage error.

## Follow-ups

- The script marks one shortcut: a second review with the same state on the same commit changes no value and prints no line.
- The watcher supports GitHub through `gh` only. Other hosts are not built.
- No model has followed `coordinate` end to end. The eval case `coordinator-resume` (M024-S04-T04) exercised the start from files on a fixture without a host, and its grader accepts `resume-session` as well as `coordinate`.
- The line in `tests/skill-preambles.test.sh` that adds the four new skills to `SKILLS` is committed with M024-S04-T04. Before that commit the suite does not run this preamble.

## Spec

- skills: `.ytstack/spec/skills.md` -- Behavior ("Skill classes", "Coordinating many lanes")
- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("The coordinator scripts"), Known limits, Where implemented
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers")

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/ytstack-watch.test.sh; /bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `65 passed, 0 failed`; `466 passed, 0 failed`, twelve of them for the `coordinate` preamble; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: the watcher against GitHub. The suite answers `gh pr view` from fixture files and replaces the sleep, so no real poll and no real interval ran. A coordinating session over many lanes, a compaction and a rotation. The watcher as a background process whose lines reach a model.

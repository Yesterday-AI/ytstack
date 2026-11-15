---
milestone: M024
slice: S01
task: T02
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M024-S01-T02: bin/ytstack-frontier, Blocked by in the plans, claims in spawn-milestone-team`).

## Outcome

`bin/ytstack-frontier` listed the frontier of a milestone from the roadmap checkboxes, the `**Blocked by:**` lines of the slice plans and `.ytstack/LANES.md`, and kept the claims in that file: `claim` refused a held lane and named the holder, `set` changed one row and left every other row byte-identical, `release` freed a row, `check` named each defect of the file. `tests/ytstack-frontier.test.sh` pins all five commands on fixture repositories.

The slice plan template of `slice-milestone` carries `**Blocked by:**` with the rule that only real dependencies are written. The task plan template of `plan-task` carries the line only when a task needs another task's result. `spawn-milestone-team` claims before it dispatches, records every stage with `set`, looks at the frontier again after each verified or merged lane, and does not count a changed `.ytstack/LANES.md` as a dirty tree; `tests/skill-preambles.test.sh` has two cases for that.

A dispatched agent wrote the script, the suite and the skill changes. The lead read them and added one rule afterwards.

## Deviations from plan

- The script goes beyond its brief in three points. A row with status `merged` counts as done even while the roadmap checkbox is open. A row with status `blocked` is listed as blocked with its next action. Every write takes a lock (`LANES.md.lock`), so that two claims sent together do not lose a row.
- Added by the lead: a lane that an open or asked question names under `blocks:` is listed as blocked with `question Q###`. Two cases in the suite cover it (an asked question blocks, an answered one does not).
- Issue #34 proposed the lanes table inside `STATE.md`. It is its own file (M024-S01-T01).

## Follow-ups

- The script marks one shortcut: a lock left behind by a killed process is not recognised as stale. The message names the directory to remove. Upgrade to a pid check if that happens in practice.
- Not built: a hook or host event at subagent start that checks a claim. The claim holds only as far as the orchestrator runs `claim` before it dispatches.
- `skills.md` ("Agents and parallel dispatch") still says that `spawn-milestone-team` refuses a dirty tree, without the exception for `.ytstack/LANES.md`.

## Spec

- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("The coordinator scripts"), Where implemented
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers", "States and closure")
- skills: `.ytstack/spec/skills.md` -- Behavior ("Coordinating many lanes")

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/ytstack-frontier.test.sh; /bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `128 passed, 0 failed`; `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: no orchestrator session has claimed a lane with the script and dispatched a worker, so the claim before dispatch is tested as a command and not as behaviour of `spawn-milestone-team`. Two claims at the same moment were not raced in a live run. Linux: the lead ran all 20 suites in the container (alpine, bash 5.3.9, BusyBox awk), `ALL SUITES PASSED`; this suite was not run there on its own for this record.

---
milestone: M027
slice: S02
task: T01
project: ytstack
closed: 2026-11-13T19:24:21Z
verification: passed
---

# M027-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M027-S02-T01: the incident record, bin/ytstack-signals incident new and its check`).

## Outcome

`docs/ux/signal-format.md` gained the incident record: the frontmatter, the six sections in a fixed order and the one-line form of a mitigation with its four statuses. `bin/ytstack-signals incident new` wrote the skeleton of a record under `.ytstack/incidents/` with the time it was opened and refused a second record of the same day and title. `incident list` printed the records that are not closed. `check` validated the records beside the findings: name and id, state and times, the root cause of a closed record, the sections, every mitigation line, and for a mitigation that is not declined a script that exists and passes `bin/ytstack-handover check`. Its last line now counts both: `signals ok: <n> finding(s), <m> incident(s)`.

## Deviations from plan

- `incident list [--state <state>]` was added. The brief named `incident new` only; a session that resumes an incident has to find the open record, and reading frontmatter in a skill's preamble would be a second parser.
- There is no command that changes the state of a record. The skill edits the frontmatter with the file tools and `check` rejects times that contradict the state.
- `check` also fails a `carried out` mitigation whose receipt file does not exist. The brief asked for the script only; a status that names a receipt nobody can read is a claim without its evidence.
- A mitigation line is `- M<n> -- <what> | changes: | effect: | risk: | undo: | script: | status:`. The brief listed the content; the id and the field names are this task's choice, in the style of the gate lines of a slice plan.
- Hypotheses, timeline lines and facts have a documented form that `check` does not read.

## Follow-ups

- Paths of scripts and receipts are read from the root of the checkout. A record checked in a clone without the committed handover directory fails there by design.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-signals.test.sh` -- exit 0, last line `199 passed, 0 failed`, at the working tree on top of `4483a00` in the local checkout (macOS, bash 3.2.57).

The same suite from an export of that working tree: exit 0, `199 passed, 0 failed` in `ubuntu:26.04` and in `alpine`.

`bash tests/run-all.sh` -- exit 0, `ALL SUITES PASSED` (22 suites), local checkout. `python3 bin/ytstack-check` -- exit 2, no `[fail]` line, 32 warnings, the same as at `85298e0`.

Not checked: the full set of suites in the two containers for this commit (it runs once for the head of the branch). A record written by a session during a real incident.

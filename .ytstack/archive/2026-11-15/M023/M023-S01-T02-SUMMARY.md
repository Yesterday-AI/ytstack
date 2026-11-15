---
milestone: M023
slice: S01
task: T02
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M023-S01-T02: bin/ytstack-brief renders the worker brief and checks the report`).

## Outcome

`bin/ytstack-brief` rendered a brief for a task or a slice from the plan files and `skills/spawn-milestone-team/brief-template.md`, with the body of `skills/minimal-code/SKILL.md` under "Work contract". It refused to print a brief without a plan, a `## Files` section, the template or the contract (exit 1). `check` accepted a report with the eight labels and an exit code in every `Checks run:` line and named each missing or empty label otherwise. `tests/ytstack-brief.test.sh` pins both commands on fixture repositories.

A dispatched agent wrote the three files. The lead read the script and the template and rendered a brief for a real task of this repository. A render of `M021-S02-T02` gave 106 lines with the sections Outcome, Scope, Read for context, Verification, Spec impact, Work contract and Report; that plan has no `## Spec impact` section, so the brief says "not stated in the plan".

## Deviations from plan

- The milestone plan (`ROADMAP.md`, "Planned 2026-11-13") spoke of brief and report templates. There is one file: the report shape is the "Report" section of `brief-template.md`.
- In a rendered brief the contract's headings sit two levels lower, so that they stand under "Work contract". The text is otherwise byte-identical to the file; the suite moves the headings back up and compares.
- After reading the output the lead added one line: a project without a technical spec gets `KNOWLEDGE.md` under "Read for context".

## Follow-ups

- The script marks one shortcut: template values travel through the environment, so one value is limited to what the OS allows per variable (about 128 KB on Linux). Upgrade to temporary files if a plan section ever gets that long.

## Spec

checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("`bin/ytstack-brief`: the brief of a dispatched worker and its report"), Where implemented. Uncommitted at the time of the check.
skills: `.ytstack/spec/skills.md` -- Interfaces and contracts. Uncommitted at the time of the check.

## Verification

Command: `/bin/bash tests/ytstack-brief.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout. Last line `86 passed, 0 failed`, exit 0.

Not checked: no real dispatch was made with a rendered brief (no Agent call, no `codex exec` run). `tests/run-all.sh --linux` was not run as a whole. The dispatched agent ran `tests/ytstack-brief.test.sh` in an alpine container, 85 passed at that time; the suite prints 86 now, so what was added since ran on macOS only.

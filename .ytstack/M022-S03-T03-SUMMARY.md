---
milestone: M022
slice: S03
task: T03
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M022-S03-T03 -- Summary

## Commits

- The commit that carries this file (`M022-S03-T03: reassess-roadmap folds a closed milestone into the spec`).

## Outcome

`skills/reassess-roadmap/SKILL.md` gained Step 8a, "Fold the milestone into the spec", and checklist item 9 names it before the backlog sweep. At the last slice of a milestone, in a project with `.ytstack/spec/`, the skill read each affected area file against the milestone's summaries and its context file and brought over what applies from now on: changed behaviour, decisions in force, limits that still hold, and a `status` raised only for what was read in the code. It then named the archive offer of `ytstack:reconcile` and moved nothing.

The second half of the task line, `reconcile` archiving the slice and task files of closed milestones on request, was built in `skills/reconcile/SKILL.md` and is committed with T02.

## Deviations from plan

- The fold is prose in a skill. No preamble line and no suite case belongs to it, so the verification below shows that the skill file is still well-formed, not that a fold happens.
- The area file states the fold in the section "Coordinating many lanes" of `skills.md`, in the `reassess-roadmap` line, together with the question files of M024.

## Follow-ups

- The first milestone close in a project with a technical spec is the first run of Step 8a. In this repository the area files were written together with M022, M023 and M024; no record shows a run of this step.

## Spec

- skills: `.ytstack/spec/skills.md` -- Behavior ("Coordinating many lanes", the `reassess-roadmap` line)
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Ownership and cleanup")

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: no model session has followed Step 8a. The eval case `reassess-roadmap` closes a slice that is not the last of its milestone, so no case reaches the fold.

---
milestone: M023
slice: S01
task: T01
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M023-S01-T01: minimal-code becomes the work contract`).

## Outcome

`skills/minimal-code/SKILL.md` was rewritten as the work contract: "Reach before size", the ladder with the caller rule, "Never cut" with the rule that a trivial change gets no new test, "Evidence" and "Report" with the closing line "Not checked:". It has 59 lines. The SessionStart line now reads "smallest complete change, smallest sufficient evidence" and tells the agent to load the skill before writing code or adding a check. The stop note in `using-ytstack` covers a subagent, a teammate and a worker on another host. The TDD wrapper got the paragraph "Which changes get a new test (ytstack)", which wins over the vendored text where the two differ. `NOTICE` names the concepts that follow ponytail 5.3.3 and says that applying them to verification, review rounds and dispatched agents is ytstack's own extension. The milestone files `M023-CONTEXT.md`, `M023-ROADMAP.md` and the three slice plans were written with this task.

## Deviations from plan

none

## Follow-ups

- The SessionStart pointer line grew by 53 characters (408 to 461). On a project whose injection is already at the cap, the "Next action" excerpt is replaced by the one-line note sooner. The cap itself belongs to M022-S03.

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", the `minimal_code` row under "Ceremony preferences"). Uncommitted at the time of the check.

Two files of this task belong to other areas, and the plan names neither. `hooks/session-start` is in `hooks-and-state`: the area file says the state block carries "the minimal-code line when `minimal_code` is on" and does not describe its wording, so no statement there became false. `NOTICE` is in `dependencies`: the area file says `NOTICE` holds "a concept credit" and does not name ponytail or its version.

## Verification

Command: `/bin/bash tests/hooks-readonly.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout. The suite printed `63 passed, 0 failed`. The checker printed `OK (with 27 warning[s])`, no `[fail]` line, exit 2. `wc -l skills/minimal-code/SKILL.md` printed 59.

Not checked: the contract is prose; what an agent does with it is shown only by the eval run that S03-T03 records. The injection size on a project that is already at the cap was not measured (the suite's fixtures inject 8627 and 7867 characters). `tests/run-all.sh --linux` was not run.

<!-- Skeleton of a worker brief. `bin/ytstack-brief render` fills the {{MARKERS}} from the plan and drops these comment lines. -->
<!-- By hand: replace each marker with the named part of the plan (CONTRACT: the body of skills/minimal-code/SKILL.md) and leave out a section whose marker has no value (Gates, Git). -->
<!-- What stands in for a part the plan does not have: -->
<!-- no-verification: No verification command in the plan. Stop and report this as a blocker. -->
<!-- no-spec-impact: not stated in the plan -->
<!-- unplanned: not planned yet: run ytstack:plan-task first, or plan it yourself with exact files and a verification command before you write code -->
<!-- unplanned-part: comes with its plan, see Scope -->
# Brief: {{REF}} ({{PROJECT}})

## Outcome

{{OUTCOME}}

## Scope

{{FILES}}

Anything outside these files is reported as a blocker, not changed.

## Read for context

{{CONTEXT}}

Other plans, summaries and the history in STATE.md are not needed for this task.

## Verification

{{VERIFICATION}}

## Spec impact

{{SPEC_IMPACT}}

## Gates

{{GATES}}

A gate is never recorded as given by the worker. The task closes on its verification; the gate stays open for the person it names.

## Git

Before you change anything, run:

    git checkout -B {{BRANCH}} {{BASE}}

Commit each task with the prefix `{{COMMIT_PREFIX}}:`. Do not merge or push.

## Work contract

{{CONTRACT}}

## Report

End with exactly this report: all eight labels, in this order, each at the start of a line.

- One `Checks run:` line per check, with the raw exit code. No check ran: `Checks run: none -- <why>`.
- Claim nothing that has no line here. What you did not run goes under `Not checked:`, not into `Outcome:`.

```
Task: <ref>
Outcome: <what holds now, one to three sentences, past tense>
Commits: <git log --oneline <base>..HEAD, or "none">
Checks run: <command> -- exit <n> at <short sha> in <environment>
Spec: <area: file that changed | none -- reason>
Deviations: <or "none">
Blockers: <or "none">
Not checked: <what was not run or not looked at, and why; "nothing" only when that is true>
```

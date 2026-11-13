<!-- Skeleton of a worker brief. `bin/ytstack-brief render` fills the {{MARKERS}} from the plan and drops these comment lines. -->
<!-- By hand: replace each marker with the named part of the plan (CONTRACT: the body of skills/minimal-code/SKILL.md; KIND and COMMIT_RULE: the sentences below for the lane's kind) and leave out a section whose marker has no value (Gates, Git). -->
<!-- What stands in for a part the plan does not have: -->
<!-- no-verification: No verification command in the plan. Stop and report this as a blocker. -->
<!-- no-spec-impact: not stated in the plan -->
<!-- unplanned: not planned yet: run ytstack:plan-task first, or plan it yourself with exact files and a verification command before you write code -->
<!-- unplanned-part: comes with its plan, see Scope -->
<!-- What the worker may do, per `--kind`: KIND is the kind-<kind> lines followed by the commit-<kind> line; COMMIT_RULE is the commit-<kind> line. RANGE is "the range `<base>..<head>`", without `--base` "the commit `<head>`". A review has no commit line and no Git section. -->
<!-- kind-implement: Implement: change the files named under Scope and no others. -->
<!-- commit-implement: Commit each task with the prefix `{{COMMIT_PREFIX}}:`. -->
<!-- kind-review: Review, read only: review exactly {{RANGE}}, no other commit and no uncommitted state. -->
<!-- kind-review: Report findings the way the work contract and the project's review rules say: the assumed load first, per finding a concrete case and what happens if it is skipped, "Not checked" at the end. -->
<!-- kind-review: `Outcome:` carries the verdict (`approved` or `changes requested`) and the reviewed commit. -->
<!-- kind-review: Change nothing: no file, no commit, no branch. Scope names what the reviewed change may touch, and Verification what its author had to run; you run that command only when this brief asks for an independent run. -->
<!-- kind-prepare: Prepare: write the files named under Scope and no others. -->
<!-- kind-prepare: List every file you wrote under `Uncommitted:` in the report. -->
<!-- commit-prepare: Commit nothing. -->
# Brief: {{REF}} ({{PROJECT}})

## Outcome

{{OUTCOME}}

## Kind

{{KIND}}

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

{{COMMIT_RULE}} Do not merge or push.

## Work contract

{{CONTRACT}}

## Report

End with exactly this report: all eleven labels, in this order, each at the start of a line.

- `Status:` is one of the three words and nothing else. `partial` and `blocked` are said there, never in a paragraph. `blocked` names what blocks under `Blockers:`; `complete` has `Blockers: none`.
- One `Checks run:` line per check, with the raw exit code. No check ran: `Checks run: none -- <why>`.
- `Uncommitted:` names every file you changed and did not commit.
- Claim nothing that has no line here. What you did not run goes under `Not checked:`, not into `Outcome:`.

```
Task: <ref>
Status: <complete | partial | blocked>
Outcome: <what holds now, one to three sentences, past tense>
Commits: <git log --oneline <base>..HEAD, or "none">
Uncommitted: <files changed and not committed, or "none">
Checks run: <command> -- exit <n> at <short sha> in <environment>
Spec: <area: file that changed | none -- reason>
Deviations: <or "none">
Blockers: <or "none">
Not checked: <what was not run or not looked at, and why; "nothing" only when that is true>
Next: <the next action for whoever dispatched this, in one line>
```

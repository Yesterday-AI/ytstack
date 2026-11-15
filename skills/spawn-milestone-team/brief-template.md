<!-- Skeleton of a worker brief. `bin/ytstack-brief render` fills the {{MARKERS}} from the plan and drops these comment lines. -->
<!-- By hand: replace each marker with the named part of the plan (CONTRACT: the body of skills/minimal-code/SKILL.md; KIND and COMMIT_RULE: the sentences below for the lane's kind) and leave out a section whose marker has no value (Lens, Gates, Git). -->
<!-- What stands in for a part the plan does not have: -->
<!-- no-verification: No verification command in the plan. Stop and report this as a blocker. -->
<!-- no-spec-impact: not stated in the plan -->
<!-- unplanned: not planned yet: first write its plan `{{PLAN}}` in the format of `ytstack:plan-task` (Step 9 of `{{PLAN_FORMAT}}`: Files, What this does, Spec impact, Verification), commit it alone, then change the files it names -->
<!-- unplanned-part: comes with its plan, see Scope -->
<!-- A task without a plan, rendered with `--task` (implement or prepare): OUTCOME is the task line of the slice plan followed by the plan-first lines, FILES the plan-first-scope line and, when the task line names paths in backticks, the plan-first-hint line with those paths as a list. PLAN is the path of the plan to write, beside the slice plan; PLAN_FORMAT the path of skills/plan-task/SKILL.md. -->
<!-- plan-first: This task has no plan yet. Your first deliverable is its plan: write `{{PLAN}}` in the format of `ytstack:plan-task` (Step 9 of `{{PLAN_FORMAT}}`): the frontmatter, `**Summary:**`, `## Files` with the exact paths, `## What this does`, `## Spec impact` (one line `- <area>: <section> -- <what changes>` per area the task changes, read from the area files under "Read for context", or `none -- <reason>`) and `## Verification` with one or two commands that run now. Then implement what the plan names, and nothing else. -->
<!-- plan-first: The plan is part of the change: it goes into your first commit, alone, before any other file changes (a lane that commits nothing writes it first and lists it under `Uncommitted:`). Nobody else plans it for you; a task too big for one plan is a blocker, not two half plans. -->
<!-- plan-first-scope: `{{PLAN}}` (the plan you write first), then the files that plan names under `## Files`. -->
<!-- plan-first-hint: Named in the slice plan for this task: -->
<!-- plan-first-verification: The command your plan names under `## Verification`. Run it before you report; a plan without one is a blocker. -->
<!-- plan-first-spec-impact: What your plan names under `## Spec impact`. -->
<!-- What the worker may do, per `--kind`: KIND is the kind-<kind> lines followed by the commit-<kind> line; COMMIT_RULE is the commit-<kind> line. RANGE is "the range `<base>..<head>`", without `--base` "the commit `<head>`". A review has no commit line and no Git section; its KIND ends with the round-review lines (the verdict and the class of the change, docs/ux/review-policy-format.md "Records"). -->
<!-- kind-implement: Implement: change the files named under Scope and no others. -->
<!-- commit-implement: Commit each task with the prefix `{{COMMIT_PREFIX}}:`. -->
<!-- kind-review: Review, read only: review exactly {{RANGE}}, no other commit and no uncommitted state. -->
<!-- kind-review: Report findings the way the work contract and the project's review rules say: the assumed load first, per finding a concrete case and what happens if it is skipped, "Not checked" at the end. -->
<!-- kind-review: Change nothing: no file, no commit, no branch. Scope names what the reviewed change may touch, and Verification what its author had to run; you run that command only when this brief asks for an independent run. -->
<!-- round-review: `Outcome:` carries the verdict (`approved` or `changes requested`) and the reviewed commit. -->
<!-- round-review: You are not the author of this change, and you state its class; its author never does. If you wrote any part of it, stop and report that. After `Next:` the report carries four more labels, each at the start of a line: `Risk: <low | normal | high>`, `Severity: <what the worst plausible mistake in this change costs>`, `Reach: <what it can affect: these files, one area, several areas, stored data, users>` and `Invariants touched: <none | area: the invariant or decision, in its own words>`. -->
<!-- round-review: `Risk:` follows from severity and reach, not from the size of the diff. `high`: the change touches an invariant or a decision that applies now, a security boundary, stored data or its shape, an interface another part or a user relies on, or a revert does not take it back. `low`: a mistake in it is contained and cheap to take back, and nothing a user or another part relies on changes (documentation, tests, comments, copy, an internal rename). `normal`: behaviour changes inside the contract of one area, and a revert takes it back. -->
<!-- round-review: For `Invariants touched:` read the change against the sections "Invariants and security boundaries" and "Decisions that apply now" of every area file under "Read for context". Name a rule the change shifts with its area, in the document's own words, also when the change edits only code and leaves the document alone; its `Risk:` is then `high`. With no area file listed the answer is `none`, and `Not checked:` says so. -->
<!-- The lens of a review, with `--lens <name>` (docs/ux/review-policy-format.md, "Lenses"): KIND ends with the lens-kind line in place of the round-review lines, and LENS is filled: the lens-intro line, the lens line of REVIEW.md, the lens-reads line, the `reads` documents as a list, the lens-rules lines, the lens-visual or the lens-none lines by the `evidence` of the lens, the lens-skill line when the lens names a skill, and the lens-report line. EVIDENCE is `<evidence_dir>/<ref>/<short sha>/<lens>`, EVIDENCE_ROOT the main checkout of the repository, SKILL_FILE the path of skills/visual-review/SKILL.md. Without `--lens` the section "Lens" is left out. -->
<!-- lens-kind: This is a lens review: a second, independent review with one question, described under "Lens". Its verdict is `pass`, `fail` or `not run` and stands under `Lens:`. `Outcome:` says what you looked at and names the reviewed commit. -->
<!-- lens-intro: This review is the lens `{{LENS_NAME}}` of the project's review policy (`.ytstack/spec/REVIEW.md`): -->
<!-- lens-reads: Review the change against these documents, as they are at the reviewed commit, and against nothing else: -->
<!-- lens-rules: You are not the author of this change and you start with a fresh context: this brief, the documents above and the pinned commit, nothing of the author's reasoning. If you wrote any part of the change, stop and report that. -->
<!-- lens-rules: The verdict is `pass`, `fail` or `not run`. `fail` names each finding with the sentence of the document it breaks. If you could not do what the lens asks, the verdict is `not run` and the report says why. `not run` never counts as `pass`, and a partial look is no pass. -->
<!-- lens-rules: A document above that you cannot read means the lens cannot run: `not run`. -->
<!-- lens-visual: The evidence of this lens is visual: you look at the running product, not at its code. Load the skill `ytstack:visual-review` and follow it; on a host without a skill tool read `{{SKILL_FILE}}` and follow that. -->
<!-- lens-visual: You start the product yourself, in a worktree of your own at the reviewed commit, through `bin/ytstack-runtime up`, and operate it in a browser. You take your own screenshots of the views, states and widths the change affects, and you look at each of them. Images from the author do not count. Reading code or the DOM does not count as this lens. -->
<!-- lens-visual: Store the images with their `MANIFEST` under `{{EVIDENCE}}`. A relative path starts at the root of the main checkout of the repository (`{{EVIDENCE_ROOT}}`), not at your worktree: the route reads it there, and the lens line names it relative to that root. It is the one place you write to. -->
<!-- lens-visual: No "Run" section in `RUNTIME.md`, a product that does not come up, or no browser tool that renders the page and returns a screenshot you can look at: the verdict is `not run`. -->
<!-- lens-none: This lens asks for no evidence: the report says `Evidence: none`. -->
<!-- lens-skill: The project names a skill for this lens: load `{{LENS_SKILL}}` before you start. -->
<!-- lens-report: After `Next:` the report carries two more labels, each at the start of a line: `Lens: {{LENS_NAME}} -- <pass | fail | not run>` and `Evidence: <directory> (<n> images)`, or `Evidence: none` when there is none. -->
<!-- kind-prepare: Prepare: write the files named under Scope and no others. -->
<!-- kind-prepare: List every file you wrote under `Uncommitted:` in the report. -->
<!-- commit-prepare: Commit nothing. -->
# Brief: {{REF}} ({{PROJECT}})

## Outcome

{{OUTCOME}}

## Kind

{{KIND}}

## Lens

{{LENS}}

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

This is a duty, not background. When your change makes a sentence of an area file under "Read for context" false (behaviour, a contract, a guard, an error path, where it is implemented), edit that section in the same commits, or the source the area file names. The report's `Spec:` line names what you edited; an unchanged spec needs its reason there.

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
- `Spec:` is the spec delta: per section you edited `<area>: <file> (<section>)`, several joined by `;`, or `none -- <reason>` (restores the described behaviour, no behaviour or contract changes, not covered by an area). A bare `none` fails the check, and a change to behaviour, a contract or a guard without an edited section or a reason does not merge without a person.
- Claim nothing that has no line here. What you did not run goes under `Not checked:`, not into `Outcome:`.

```
Task: <ref>
Status: <complete | partial | blocked>
Outcome: <what holds now, one to three sentences, past tense>
Commits: <git log --oneline <base>..HEAD, or "none">
Uncommitted: <files changed and not committed, or "none">
Checks run: <command> -- exit <n> at <short sha> in <environment>
Spec: <area>: <file you edited> (<section>); ... | none -- <reason>
Deviations: <or "none">
Blockers: <or "none">
Not checked: <what was not run or not looked at, and why; "nothing" only when that is true>
Next: <the next action for whoever dispatched this, in one line>
```

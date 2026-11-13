---
milestone: M022
slice: S02
task: T05
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S02-T05 -- Summary

## Commits

- The commit that carries this file (`M022-S02-T05: eval graders and user docs for the technical spec`).

## Outcome

The eval case `plan-task` got the grader `spec-impact.md` (the plan's `## Spec impact` starts with `none`), the case `summarize-task` got `spec-record.md` (the summary's `## Spec` starts with `none`). The new case `spec-impact` shipped with a fixture whose spec has the areas `export` and `users` and with an outcome grader that requires `- export:` under `## Spec impact`. `evals/README.md` listed the new case and the second outcome graders. `README.md` got the paragraph "A technical spec that says what applies now", `spec/` in the state table and `bin/ytstack-spec` in the repository layout. `QUICKSTART.md` got the area question in both walk-throughs, the spec-only run and `spec/SPEC.md` in the reading list. `CHANGELOG.md` got the technical-spec entries under `[Unreleased]` and two upgrade notes.

The rows for `bounded-evidence`, `gates-one-question` and `review-round-three` in `evals/README.md`, the paragraph "Work is bounded like code" in `README.md` and the bounded-work entries in `CHANGELOG.md` belong to M023.

## Deviations from plan

- The task line names ytstack's own area files. They are new on this branch and are committed with S01-T04, already updated for what this milestone changed.
- `evals/README.md` also got rows for the cases `code-review` and `grill`, which existed without a row.
- `README.md` and `QUICKSTART.md` carry the count corrections of S01-T05 (six gstack wrappers; 15 suites, 9 hooks, 31 skills and 17 eval cases in README).

## Follow-ups

- The new case and the new graders ran against a model with the eval run of M023-S03-T03: `spec-impact`, `plan-task`, `summarize-task`, `init-project` and `adopt-brownfield` passed with all graders (record in `KNOWLEDGE.md`, "Eval runs").

## Spec

checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("Behavioural evals: `evals/`")

`bin/ytstack-spec impact` saw the area file as an uncommitted change when this summary was written; it is committed with S01-T04. The source `evals/README.md`, which this task's commit carries, changed as well.

## Verification

Command: `root=$PWD; d=$(mktemp -d); (cd "$d" && bash "$root/evals/spec-impact/fixture.sh") && bash bin/ytstack-spec -C "$d" lint` -- passed at the working tree on top of `f4f54ab` in the local checkout: the fixture built a repository with two commits, and lint printed `spec lint: 2 area file(s), 0 failure(s), 0 warning(s)`. In a fixture repository built the same way, `bin/ytstack-spec areas` named `export` for `src/export.ts` and `tests/export.test.ts`.

Not checked: nothing beyond one model run per case (see Follow-ups); a single run does not show how stable the graders are.

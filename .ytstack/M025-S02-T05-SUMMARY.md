---
milestone: M025
slice: S02
task: T05
project: ytstack
closed: 2026-11-13T19:07:18Z
verification: passed
---

# M025-S02-T05 -- Summary

## Commits

- The commit that carries this file (`M025-S02-T05: a review states the class of the change, the round line records it`).

## Outcome

`code-review` printed the floor of the task's commit range between `RISK_FLOOR_BEGIN` and `RISK_FLOOR_END` and told the reviewer to end with `Risk:`, `Severity:`, `Reach:` and `Invariants touched:`. The paragraph "The class of the change" says how: severity and reach first, never below the floor, and the change read against "Invariants and security boundaries" and "Decisions that apply now" of the area files under `SPEC_AREAS`, also when only code changed. The round line gained `risk`, `invariants` and `by`; `by` is the dispatched reviewer (`review-<task>`) or `self`. The preamble counted a round line of the new form like one of the old form.

`bin/ytstack-brief render --kind review` asked the reviewer of a lane for the same four labels, from four `round-review` sentences in `brief-template.md`, and refused a template without them. `bin/ytstack-brief check` read the four labels as labels: a report that carries one of them has to carry all four with a value, and `Risk:` is `low`, `normal` or `high`.

`finish-lane` sent a review report without the four labels back once and appended the extended round line to the lane's plan under `## Review`, with `by: review-<lane>`.

## Deviations from plan

- The review brief repeats the three classes in one sentence each. A dispatched reviewer may run on a host that cannot read the plugin's `docs/`, and a brief does not depend on a skill or a document. `code-review` points at the table of `docs/ux/review-policy-format.md` and does not repeat it.
- `bin/ytstack-brief check` validates the four labels when a report carries one of them. It cannot tell a review report from another one, so a review report without any of the four still passes the check; `finish-lane` asks for them, and the route of such a round is `person`.
- `finish-lane` got `Edit` in its `allowed-tools`: it appends one line to a plan.
- `tests/skill-preambles.test.sh` gained four assertions beside the `code-review` ones.

## Follow-ups

- The floor is unknown for a task whose first commit is the root commit of the repository: there is no base commit to compare with. `code-review` prints the script's message and the reviewer says so under `Not checked:`.
- `by: self` is what `code-review` writes for a session that reviews its own change. `bin/ytstack-risk route` has to count that value as the author; at `d562772` it compares `by` with `--author` only (reported to the worker of that script).
- Round 2 restates the class for the whole change from the labels of round 1. Nothing checks that the reviewer was given them.

## Spec

- skills: area file updated by the coordinator in the closing task
- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-brief.test.sh && /bin/bash tests/skill-preambles.test.sh` -- passed at the working tree on top of `d562772` in the local checkout (macOS, bash 3.2). Last lines `143 passed, 0 failed` and `473 passed, 0 failed`, exit 0. `python3 bin/ytstack-check` exited 2 with no failure and 32 warnings, the number at `d562772`.

Not checked: a session in which a dispatched reviewer stated the four labels and the round line was written from them. The Linux containers ran once for the whole branch, see the report.

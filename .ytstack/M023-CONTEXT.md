---
milestone: M023
project: ytstack
created: 2026-11-13T15:20:00Z
size: L
---

# M023 -- Context

## Goal

An agent dispatched on a ytstack project finishes the agreed task with the smallest sufficient evidence, a review ends after its fix round, and a plan row that no work can close reaches the human as one question.

## Exit criteria

- A plan that asks for one pass of 44 scenarios stays at 44 unless a named failure or requirement justifies more (eval case `bounded-evidence`).
- A finding the project's policy rates non-blocking stays a tracked follow-up and holds nothing; a risk a person has to accept is a gate and appears in the one question to the human.
- A follow-up review covers the fix and its consequences; a permission or data-loss defect the fix introduced still blocks; a third round yields a diagnosis of scope, conflicting rules or solution, not another review (eval case `review-round-three`).
- A fresh verifier accepts an independent result for the same commit, environment and check; a changed head gets the check again.
- A worker dispatched with the rendered brief has the work contract without invoking a skill; a validator rejects a report with a missing field (`tests/ytstack-brief.test.sh`).
- `reassess-roadmap` lists, in one question, a gate that needs a person's verdict and a gate whose condition can no longer be met, each with who decides, how and when it lapses; rows that work can close are not listed; progress is reported as two numbers (eval case `gates-one-question`, `tests/skill-preambles.test.sh`).
- A review opens with the load and the product stage it assumed, taken from the project's documents; a scale finding is rated against that load; a `shortcut:` comment that names its limit is a decision, not a finding.
- A report ends with what was not run or not checked, and why.
- Correctness and completeness are not worse than with the current instructions on the same cases; turns and cost of both arms are recorded in `KNOWLEDGE.md` ("Eval runs").
- `bin/ytstack-check` and `tests/run-all.sh` pass; no file under `vendor/` changed.

## Size

L -- 3 slices. See `M023-ROADMAP.md` for slice breakdown.

## Planning input

GitHub issue #35, the comment of 13 November 2026 on it (measurements from one consumer migration), the review of ponytail 5.3.3 of the same day, and the operator's instruction to implement the plan in `ROADMAP.md` ("Planned 2026-11-13"). Runs after M022 because both edit `plan-task`, `code-review`, `reassess-roadmap` and the verifier.

## Decisions locked in discuss phase

2026-11-13: One directive, not two. `minimal-code` grows from "smallest code" to "smallest complete change with the smallest sufficient evidence" and keeps its name, its preference (`minimal_code`) and its SessionStart pointer. A second directive beside it would have been a competing copy of the policy.

2026-11-13: The contract reaches a dispatched worker through the brief, not through a skill load. `bin/ytstack-brief render` builds the brief from the plan files and includes the body of `skills/minimal-code/SKILL.md` verbatim, so the contract text lives in one file. The same text is the prompt for a Claude subagent and for `codex exec`.

2026-11-13: A worker's report has eight fixed labels, the last one "Not checked:". `bin/ytstack-brief check` validates it. A report with a missing field goes back once; the orchestrator does not fill the gap itself.

2026-11-13: A gate is a line in a slice plan or task plan under `## Gates`: what, who decides, how the verdict is obtained, when it lapses. It never holds a task open. `reassess-roadmap` takes all open gates and all non-converging work to the human in one question per slice boundary. No queue files: that carrier belongs to coordinator mode (#34).

2026-11-13: The review round count lives in the task plan (`## Review`, one line per round with the reviewed range). It works without a pull request host and survives a new session. Round 1 is complete, round 2 covers the fix, round 3 is a diagnosis.

2026-11-13: Evidence is a check on a commit in an environment. The verifier's cold run stays the independent run, once per commit; an independent result for the same commit, environment and check is not repeated because the context is new. This narrows the verifier's old "run it again, now" and the vendored "run it fresh" to the commit being claimed.

2026-11-13: The project's severity policy rates findings where it exists. ytstack does not define severities of its own beyond the vendored reviewer template.

2026-11-13: Nothing is built for point 6 of #35 (model effort): the three agents already declare `model: inherit`.

2026-11-13: Not taken from ponytail: the levels lite / full / ultra, the session-wide mode switch, the reply style rules beyond the closing line.

## Open questions

- Whether the host offers an event at subagent start that could inject the contract without a rendered brief (`hooks/hooks.json` registers none today; #28 to #30 for other hosts). The rendered brief does not depend on it.
- Coordinator rotation, polling outside the model, frontier and claims stay with #34.

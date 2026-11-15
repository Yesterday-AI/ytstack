---
milestone: M023
slice: S03
task: T02
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S03-T02 -- Summary

## Commits

- The commit that carries this file (`M023-S03-T02: evidence is a check on a commit in an environment`).

## Outcome

`agents/verifier.md` replaced "Run it again, now, with fresh eyes" by two paragraphs: evidence is a check on a commit in an environment, and it does not expire because the verifier is new. Step 2 reads the worker's report when no summary exists. Step 3 runs the command as often as the plan's `Runs:` line says and captures the commit, and cites an earlier verdict when `git diff --quiet <that commit> HEAD -- <the plan's Files>` exits 0. The verdict block got a `Commit:` line, the "You do NOT" list forbids added passes and a FAIL for a non-blocking finding, and the report ends with `Not checked:`.

`verification-before-completion` printed `RUNS_LINE` and `HEAD` in its preamble and got the paragraph "How much evidence (ytstack)", which wins over the vendored text where the two differ. `summarize-task` writes the Verification line with commit and environment and `Not checked:` under it, and says that it records the run already made. Nothing under `vendor/` changed.

## Deviations from plan

none

## Follow-ups

- No eval case covers the verifier's evidence rule (the cited verdict, the reasons that renew a check); it is text only. The case `bounded-evidence` covers the single pass on the way through `verification-before-completion` and `summarize-task`.

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", Evidence). Uncommitted at the time of the check.
artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("States and closure": the summary's Verification line and `Not checked:`). Uncommitted at the time of the check.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout. The suite printed `395 passed, 0 failed`. The checker printed `OK (with 27 warning[s])`, no `[fail]` line, exit 2.

Not checked: `RUNS_LINE` (the stated default) and `HEAD` are asserted in `tests/skill-preambles.test.sh` ("technical spec"); a plan with its own `Runs:` line is not. The evidence rules are prose; what an agent does with them is shown only by the eval run that S03-T03 records. No verifier was dispatched, so the cited verdict was not exercised. `tests/run-all.sh --linux` was not run.

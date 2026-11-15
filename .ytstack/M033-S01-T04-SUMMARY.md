---
milestone: M033
slice: S01
task: T04
project: ytstack
closed: 2026-11-15T01:50:00Z
verification: passed_with_caveats
---

# M033-S01-T04 -- Summary

## Commits

- The commit that carries this file (`M033-S01-T04: upstream eval cases, spec areas and the decision`).

## Outcome

`evals/upstream-suggest` and `evals/upstream-file` shared one scenario (a coordinator polled pull requests by hand and wrote `scripts/poll-prs.sh` while the PR watch existed; the person asks that the experience not be lost) and differed in the `upstream_feedback` line of the fixture. Their system prompt forbade publishing: a filing command runs with `echo` in front. `upstream-suggest` graded `ytstack-upstream mode`, `draft --kind gap`, `check` and a final message with the draft path and Yesterday-AI/ytstack; `upstream-file` graded `mode`, `gh issue list --search` on the repository, `draft`, `check` and the `echo gh issue create|comment ... --body-file` call. `evals/README.md` listed both, with the note that they have no `skill-fired` grader and that `upstream-file` needs a signed-in `gh`. The `skills`, `checks-and-evals`, `hooks-and-state` and `artifacts` area files described the setting, the helper, the Upstream sections and the eval rule; `dependencies` got its `verified_at`. `DECISIONS.md` recorded why the script checks and the agent posts.

## Deviations from plan

- none

## Follow-ups

- Run the two eval cases once: `claude plugin eval . --trust-plugin --scaffold --allow-tools Write Edit Bash --ablation none --no-publish --max-cost-usd 4 --case upstream-suggest` and the same with `--case upstream-file` (the latter on a machine with a signed-in `gh`).

## Spec

- skills, checks-and-evals, hooks-and-state, artifacts, dependencies: written in this task

## Verification

Command: the plan's chain. `bash tests/run-all.sh` -- 30 `PASS` lines, `ALL SUITES PASSED` (`ytstack-upstream 68 passed, 0 failed`, `skill-preambles 663 passed, 0 failed`, `git-ctx 153 passed, 0 failed`, `hooks-readonly 70 passed, 0 failed`); `bash bin/ytstack-spec lint` -- `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`; `python3 -m unittest` -- Codex 16 tests `OK`, `kimi_plugin_test.py` 2 `OK`, `kimi_lifecycle_test.py` 9 `OK`; `claude plugin validate .` -- `✔ Validation passed`. Drift and the checker were read after the commit (drift skips area files edited in the working tree); their lines are in the slice report. Each fixture ran once in a temporary directory, and `bin/ytstack-upstream mode` printed `mode: suggest`, `set: suggest (preferences)` there. Caveat: the eval cases themselves did not run (they cost money). At the working tree on top of `c5b405d`, local checkout (macOS, bash 3.2).

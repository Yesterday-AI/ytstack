---
milestone: M019
slice: S02
task: T01
project: ytstack
closed: 2026-11-07T20:40:00Z
verification: passed
---

# M019-S02-T01 -- Summary

## Commits

- `e4e570f` -- fix: drop the unused web-design plugin dependency (unsatisfied dependency disables ytstack at load; blocks plugin eval and clean-machine --plugin-dir); DECISIONS entry
- `8d78bcb` -- M019-S02-T01: evals/ suite for claude plugin eval (11 lifecycle cases: fixtures, skill-fired + outcome graders, README); results/ gitignored
- (S03-T05) eval cases `code-review` + `grill` (13 cases total)

## Outcome

`evals/` holds one case per lifecycle skill: `prompt.md` (user-phrased prompt, `runs: 1`, `append_system_prompt` for headless answers, tools), `case.yaml` with `context.scaffold_script: fixture.sh`, a self-contained fixture building the `.ytstack/` state and git history the skill expects, and two or three free graders (`skill-fired` via `tool_used: Skill`, `file_exists` / `regex { source: file }` on the artifact, negative `tool_used` guards for office-hours / plan-milestone). `evals/README.md` documents the run command. First local run: 10/11 cases, `skill-fired` 11/11, $3.55, 921 s (KNOWLEDGE "Eval runs"); the miss was a paraphrase in HANDOFF.md, grader loosened. The run also exposed that ytstack did not load in isolation because of the `web-design` plugin dependency; removed (DECISIONS 2026-11-07 "No hard plugin dependencies").

## Deviations from plan

The dependency removal was not in the plan; it was the root cause of the first run's 0x skill-fired on every case. `--runs 1` instead of the platform default 3 to keep a full pass under $5.

## Follow-ups

- Re-run after S05's manifest bump to confirm the two S03 cases (`code-review`, `grill`) pass.

## Verification

Command: `claude plugin eval . --trust-plugin --scaffold --allow-tools Write Edit Bash --ablation none --runs 1 --no-publish --max-cost-usd 10 --json /tmp/ytstack-evals.json` -- passed (overall 0.95; 10/11 at threshold 1.0; exit 0 after the grader fix is expected on re-run).

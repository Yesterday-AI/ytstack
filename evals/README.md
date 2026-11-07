# ytstack evals

Behavioural tests for `claude plugin eval` (Claude Code >= 2.1.269): one case per lifecycle skill. Each case is a user-phrased prompt that never names the skill, a `fixture.sh` that builds the `.ytstack/` state the skill expects, and two free graders: `skill-fired` (`tool_used: Skill`, the plugin-fired indicator) and `outcome` (`file_exists` or a `regex` over the produced artifact). No `llm` graders, so a run costs only the agent sessions.

| Case | Fixture | Outcome grader |
| --- | --- | --- |
| `resume-session` | M001 in progress, T01 summarized, T02 planned | briefing names M001 and T02 |
| `plan-milestone` | initialized `.ytstack/`, no milestone | `M001-CONTEXT.md` + `M001-ROADMAP.md` |
| `slice-milestone` | M001 with an unplanned S01 | `M001-S01-PLAN.md` with `- [ ] T01` |
| `plan-task` | S01 with two unplanned tasks | `M001-S01-T01-PLAN.md`, STATE `active_task: T01` |
| `summarize-task` | T01 planned + a `M001-S01-T01:` commit | `M001-S01-T01-SUMMARY.md`, checkbox flipped |
| `reassess-roadmap` | S01 done, S02 planned | reply names S02 |
| `handoff-session` | M001 in progress | `HANDOFF.md` carries the in-flight note |
| `quick-task` | README typo, `quick_lane: on` | `quick/Q001-SUMMARY.md`, typo fixed |
| `reconcile` | one `closed: draft` stub | `RECONCILE-<date>.md` |
| `adopt-brownfield` | README + docs/ + CHANGELOG + commits, no `.ytstack/` | `.ytstack/PROJECT.md` |
| `init-project` | fresh repo with `OFFICE-HOURS.md` | `.ytstack/STATE.md` |

## Run

```bash
claude plugin eval . --trust-plugin --scaffold --allow-tools Write Edit Bash --ablation none --no-publish --max-cost-usd 10
```

- `--scaffold` runs each case's `fixture.sh` (as you, outside the sandbox; only for suites you authored).
- `--allow-tools Write Edit Bash` because the skills write artifacts and run preambles; without the grant those tools are removed and every outcome grader fails.
- `--ablation none` skips the no-plugin arm (halves the cost; `Δ` is meaningless for skills that only exist with the plugin). Drop it to see the baseline.
- `runs: 1` per case in `prompt.md`; `--runs 3` for a stability check.
- Every run is a real model call on your account; `--max-cost-usd` caps it. `evals/results/` is gitignored.
- Single case: `--case plan-task`. Debug a failure: `--keep-temp` and read `aggregate-result.json` in `evals/results/<timestamp>/`.

Runs are headless: `AskUserQuestion` is not granted and the appended system prompt tells the agent to take each skill's RECOMMENDATION. Nothing project-level loads in a run (no `CLAUDE.md`, no user settings), so a fixture must create everything a skill reads.

Record of the last local run: `.ytstack/KNOWLEDGE.md` ("Eval runs").

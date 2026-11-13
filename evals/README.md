# ytstack evals

Behavioural tests for `claude plugin eval` (Claude Code >= 2.1.269): one case per lifecycle skill, plus cases for a rule that spans skills. Each case is a user-phrased prompt that never names the skill, a `fixture.sh` that builds the `.ytstack/` state the skill expects, and free graders: `skill-fired` (`tool_used: Skill`, the plugin-fired indicator), `outcome` (`file_exists` or a `regex` over the produced artifact) and, where the table names one, a second outcome grader. No `llm` graders, so a run costs only the agent sessions.

| Case | Fixture | Outcome grader |
| --- | --- | --- |
| `resume-session` | M001 in progress, T01 summarized, T02 planned | briefing names M001 and T02 |
| `plan-milestone` | initialized `.ytstack/`, no milestone | `M001-CONTEXT.md` + `M001-ROADMAP.md` |
| `slice-milestone` | M001 with an unplanned S01 | `M001-S01-PLAN.md` with `- [ ] T01` |
| `plan-task` | S01 with two unplanned tasks, no technical spec | `M001-S01-T01-PLAN.md`, STATE `active_task: T01`, `## Spec impact` says `none` |
| `spec-impact` | S01 with one unplanned task and a technical spec whose area `export` covers the files | the plan's `## Spec impact` names `export` |
| `summarize-task` | T01 planned + a `M001-S01-T01:` commit | `M001-S01-T01-SUMMARY.md`, checkbox flipped, `## Spec` says `none` |
| `code-review` | T01 planned and implemented in one task-ref commit | a reviewer subagent was dispatched, no summary written |
| `grill` | initialized `.ytstack/`, no milestone, a new idea | `GRILL-<slug>.md`, no milestone created |
| `reassess-roadmap` | S01 done, S02 planned | reply names S02 |
| `handoff-session` | M001 in progress | `HANDOFF.md` carries the in-flight note |
| `quick-task` | README typo, `quick_lane: on` | `quick/Q001-SUMMARY.md`, typo fixed |
| `reconcile` | one `closed: draft` stub | `RECONCILE-<date>.md` |
| `adopt-brownfield` | README + docs/ + CHANGELOG + commits, no `.ytstack/` | `.ytstack/PROJECT.md`, `.ytstack/spec/SPEC.md` |
| `init-project` | fresh repo with `OFFICE-HOURS.md` | `.ytstack/STATE.md`, `.ytstack/spec/SPEC.md` |
| `bounded-evidence` | T01 committed, its plan asks for one run of a 44-scenario script that counts its own runs | `M001-S01-T01-SUMMARY.md`, `tests/.scenario-runs` holds `1` |
| `gates-one-question` | S01 done with two open gates: one needs the product owner, one whose lapse condition already occurred | reply names G01 and G02, the product owner, and G02 as lapsed |
| `fresh-resume` | `csvexport` snapshot whose history contradicts its present (M001 says archived rows are exported, M002 and the spec say they are not) | reply says archived rows are excluded today and names M003 |
| `fresh-bugfix` | the same snapshot; with `--since` archived rows leak | the defect is fixed, a test for the combination exists, the spec sentence is unchanged |
| `fresh-requirement` | the same snapshot, one unplanned task | `M003-S01-T01-PLAN.md` exists and names the export area |
| `coordinator-resume` | M001 with five slices, a `LANES.md` with three rows, one open question, a `STANDING.md` | reply names the three lanes, the question and the running lane's next action |
| `review-round-three` | T01 with two fix commits that flip one comparison, two review rounds recorded in the plan | no reviewer subagent dispatched, reply carries a diagnosis |

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

# Rules and suggestions

`tools/process-review/rules.mjs` holds one object per rule. `analyze.mjs` evaluates them and writes `results` and `scores` to `metrics.json`; `report.mjs` renders a triggered rule as a suggestion card (severity, the problem with its counts, why it matters, the change to make, threshold and sample) and a passed rule as a line under "What works".

The rules judge the last 28 days of the period (`ruleWindowDays` in `config.json`), not the whole of it: a suggestion should describe the process as it runs now. The CI rules `ci-hours-not-green` and `ci-cancelled` count runs on pull request branches only.

## States

| State | Meaning |
| --- | --- |
| `triggered` | The sample is large enough and the threshold is crossed. |
| `passed` | The sample is large enough and the threshold holds. |
| `not-evaluated` | Too few cases or no data (no CI runs mined, no readable finding counts, no second reviewer). Shown with the reason. |
| `off` | Switched off in `config.json`. |

## The rules

| Rule | Group | Severity | Triggers when | Threshold | Minimum sample |
| --- | --- | --- | --- | --- | --- |
| `later-rounds-low-yield` | review | high | share of later rounds without a blocking finding is at or above | 0.6 | 20 readable later rounds |
| `rounds-after-merge-only` | review | medium | share of later rounds after merge commits only | 0.1 | 20 later rounds |
| `many-rounds` | review | medium | share of reviewed pull requests with three or more rounds | 0.1 | 30 |
| `merged-without-review` | review | medium | share merged without any review | 0.2 | 30 |
| `unresolved-threads` | review | low | pull requests merged with an open thread, more than | 0 | 30 |
| `reviewers-disagree` | review | medium | share of commits reviewed by both `compare` reviewers where only one blocked | 0.2 | 20 |
| `first-pass-low` | flow | medium | share that passed on the first attempt is below | 0.5 | 30 |
| `slow-first-review` | flow | medium | median hours to the first review above | 4 | 30 |
| `large-prs` | flow | low | median changed lines above | 228 | 30 |
| `ci-hours-not-green` | ci | high | share of CI hours in runs that did not end green | 0.2 | 100 runs |
| `ci-cancelled` | ci | medium | share of cancelled runs | 0.2 | 100 runs |
| `flaky-reruns` | ci | medium | share of runs that turned green on a re-run | 0.01 | 100 runs |
| `red-default-branch` | quality | high | failure rate of push runs on the default branch above | 0.1 | 30 runs |
| `follow-up-fixes` | quality | medium | share of pull requests named by a later fix that is not worded as a review follow-up | 0.08 | 50 |
| `fixes-without-tests` | quality | medium | share of source-code fixes without a test file | 0.2 | 50 fixes |
| `high-fix-share` | quality | low | share of fix pull requests | 0.35 | 50 |

Three thresholds follow a published reference, named on the card with source and year: `slow-first-review` and `large-prs` (LinearB 2026 benchmarks, 75th percentile of that vendor's customers) and `red-default-branch` (CircleCI 2026, 90 % main-branch success). All others are coaching defaults: a place to start, not a proven standard. Published tiers describe the vendor's customer base and change from year to year; do not present them as a grade.

## Changing a rule

```json
{ "rules": { "large-prs": { "threshold": 400 }, "high-fix-share": { "off": true } } }
```

Set a threshold to what the team has agreed on. A threshold raised only so that a card disappears hides the finding from the next reader too.

## Score per group

`100 × (1 − penalties ÷ (evaluated rules × 12))`, with 12 points for a triggered high rule, 7 for medium and 3 for low (the formula of Microsoft's AI Engineer Coach). Two properties to keep in mind when reading it: a rule costs its penalty once, however often it fired, and a group with few evaluated rules swings widely. There is deliberately no overall score: it would hide what the four group scores explain.

## Adding a rule

Add an object to `RULES`: `id`, `group`, `severity`, `name`, `th` (default threshold), `min` (smallest sample), `check(metrics, threshold)` returning `{ n, hit, problem, good }`, plus `why`, `action` and, where the threshold comes from a publication, `ref` with source and year. `problem` and `good` are full sentences with counts and denominators ("413 of 458 ..."), because the card shows them verbatim. If the rule needs a number that `metrics.json` does not hold yet, compute it in `analyze.mjs` first.

## Since the last report

`analyze.mjs` reads the previous `metrics.json` of the working directory before it overwrites it (or the file given with `--prev`) and stores the earlier period, headline values and triggered rule ids under `previous`. The report then shows "last report: ..." in the headline tiles, marks each suggestion as new or repeated, and marks a passed rule that was triggered last time as settled. A re-run over the same period keeps the comparison it already had.

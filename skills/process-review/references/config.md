# config.json

Optional file in the working directory, read by `analyze.mjs`. Every key is optional.

```json
{
  "repo": "owner/name",
  "reviewers": [
    { "name": "Review bot", "login": "some-review-bot", "ignoreBody": "usage limit" },
    { "name": "Agent review", "bodyMatch": "^#+ Independent review" },
    { "name": "Security team", "login": "alice" }
  ],
  "rounds": { "kind": "Agent review" },
  "findings": { "pattern": "critical (\\d+), high (\\d+), medium (\\d+), low (\\d+)", "blockingGroups": [1, 2] },
  "compare": ["Review bot", "Agent review"],
  "ciWorkflows": ["ci"],
  "defaultBranch": "main",
  "changes": [{ "at": "2026-01-15", "label": "new reviewer" }, { "at": "2026-02-01", "label": "agent tooling 2.0" }],
  "fixPattern": "^(fix|hotfix|revert)\\b",
  "followUpDays": 7,
  "sampleSize": 12
}
```

| Key | Meaning | Default |
| --- | --- | --- |
| `repo` | Shown in the report and used for pull request links. | none |
| `reviewers` | Rules that name who reviewed. Checked in order; the first rule whose `login` (exact) and `bodyMatch` (regular expression, case-insensitive, on the first 300 characters) both fit wins. `ignoreBody` drops the event instead (quota notices). | see below |
| `rounds.kind` | The reviewer whose reviews count as review rounds. | `human` if humans reviewed at least 5 % of the pull requests, else the most frequent reviewer |
| `findings.pattern` | Regular expression with one capture group per severity, matched on a review's text. `blockingGroups` lists the groups (from 1) that block a merge. | none: the review state decides (changes requested blocks, approved is clean) |
| `compare` | Two reviewer names; counts agreement where both reviewed the same head. Needs `findings`. | none |
| `ciWorkflows` | Workflow names that count for CI metrics. | all workflows |
| `defaultBranch` | Branch whose pushes are the "red default branch" metric. | the most frequent base branch |
| `changes` | Dated process changes, `{ "at", "label" }` plus the optional `expect`, `decidedBy` and `approval` (see "Change entries" below). Drawn as lines in the charts and compared before and after (`markers` is read as an older name for the same list). | none |
| `changeWindowDays`, `changeMinSample` | Days on each side of a change; smallest number of cases on each side for a verdict. | 7, 20 |
| `processPaths` | Regular expression on file paths that marks a pull request as a change to the process itself (candidates for `changes`). | workflows and other files under `.github/`, agent instruction files, review rules, linter and test runner configuration |
| `fixPattern` | Regular expression on the title that marks a fix. | conventional `fix`, `hotfix`, `bugfix`, `revert` prefixes |
| `testPattern`, `sourcePattern`, `ignorePaths` | Regular expressions on file paths: what is a test, what is source code, what never counts as a shared file. | common test directories and suffixes; common source extensions; lock files and Markdown |
| `docsPattern`, `sensitivePattern` | Regular expressions on file paths for the risk classes: what is documentation, and what is sensitive (default: migrations, SQL, authentication and security paths, workflows, deployment files). | see `analyze.mjs` |
| `agentPattern` | Regular expression that marks an AI tool in co-author trailers and the end of the description. | common assistant and agent names |
| `rules` | Thresholds or `off` per rule, see `references/rules.md`. | none |
| `roles.pattern` | Regular expression with one capture group that reads the review role out of an inline thread (for example ``"`(code|security|tests)`"`` when threads name their role in backticks). Splits blocking threads by role and by round. | none |
| `plannedFollowUpPattern` | Regular expression on the title and the first 600 characters of a fix that marks it as the planned follow-up of a review finding and not a defect found after merge. | wording such as "follow-up", "review r2", "non-blocking", "nit" |
| `ruleWindowDays` | The rules judge the last so many days of the period. | 28 |
| `ignoreFailedJobs` | Regular expression on `job › step` for jobs that only report that another job failed ("require all checks" gates); dropped from the failure tables. | none |
| `followUpDays` | Window in which a later fix counts as a follow-up. | 7 |
| `sampleSize` | Threads per reviewer in the hand-check sample. | 12 |

## How reviewers are named without rules

1. An event by a bot account is named by its login.
2. An event by a person other than the pull request's author is `human`.
3. The author's own comments count as nothing.

So two cases need a rule:

- **A reviewer under the author's account.** Coding-agent sessions often post reviews with the token of the account that also opened the pull request. Give the rule only a `bodyMatch` that fits the review's heading.
- **A reviewer that posts plain comments.** A comment counts as a review round only when a rule named it; otherwise only real reviews do, so that ordinary discussion is not counted as rounds.

An inline thread is attributed through the text of the review it was posted with, so the rule for a review also names its threads.

A bot's notice that it did not review (usage limit, quota, "couldn't run") is dropped by default; `noticePattern` replaces that expression.

## Rules for common review bots

A bot that never approves needs `cleanMatch` (regular expression on the first 300 characters) so that its "nothing found" answer counts as a clean round. Check the wording on a few pull requests of the repository first; bots change their texts.

```json
{
  "reviewers": [
    { "name": "Codex", "login": "chatgpt-codex-connector", "ignoreBody": "usage limits|codex-pull-request-review-summary", "cleanMatch": "Didn't find any major issues" },
    { "name": "Bugbot", "login": "cursor", "ignoreBody": "usage limit" },
    { "name": "Greptile", "login": "greptile-apps" }
  ],
  "rounds": { "kind": "Codex" }
}
```

A status comment that a bot edits in place (a review summary) is not a review: put it into `ignoreBody`.

## Rounds

One round is one reviewed head commit: several reviews of the round reviewer on the same head are one round. A plain comment has no head; it is assigned the last commit dated before it. Force-pushed branches lose their earlier commits, which merges rounds; note it when a repository rebases.

## Change entries

```json
{ "at": "2026-01-15", "label": "second review only on request", "expect": { "metric": "rounds", "direction": "down" }, "decidedBy": "team", "approval": "pending" }
```

| Field | Meaning |
| --- | --- |
| `at`, `label` | The day the change took effect (UTC) and its name in the charts and cards. An entry outside the analysed period is ignored. |
| `expect.metric`, `expect.direction` | What the change was meant to do: one metric key and `up` or `down` (anything else reads as `down`). The card then carries a verdict of its own: `confirmed` (the metric moved clearly in that direction), `refuted` (it did not move clearly, or moved the other way), `too early` (the window after the change is not complete, or a side has fewer than `changeMinSample` cases), `unknown metric`. |
| `decidedBy` | Who decided the change; shown on the card. |
| `approval` | Free text shown on the card. The value `pending` marks a change that awaits a person's approval; the daily digest lists those. |

Metric keys for `expect.metric`: `mergedPerDay`, `lead` (median hours), `rounds` (mean per reviewed pull request), `ciHours` (mean per pull request), `size` (median changed lines), `firstPass`, `multiRound` (two or more rounds), `ciFailed` (pull requests with a failed CI run), `noReview`, `fixShare`, `followUp` (fixed again by a linked fix), `fixNoTest`, `mainFailed` (failed CI on the default branch). `mergedPerDay` and `size` are context rows without a verdict, so an expectation on them is never `confirmed`; do not use them.

A row's verdict is `better`, `worse`, `no clear change` (the difference is within what chance explains: a rank-sum test for values, a two-proportion test for shares, |z| below 1.96), `too few` or `context`.

## asks.json

Optional file in the working directory, written by `coach-process`: one object per ask delivered to a coordinator. `analyze.mjs` judges each like a change with an expectation (the metric keys above), from its day on, and counts how often the same `key` was asked.

```json
[{ "key": "round-rules-followed", "at": "2026-11-22", "to": "v2 coordinator", "ask": "Hold later rounds to the round rules", "metric": "multiRound", "direction": "down", "ref": "coach-2026-11-22.txt" }]
```

## labels.tsv

Optional file in the working directory: what a reader decided by hand. Tab-separated, one line per verdict; lines starting with `#` and a header line starting with `date` are skipped.

```text
date	kind	ref	subject	label	by	note
2026-01-20	block	#1234	Review bot	right	alice	fixed as asked in the next commit
2026-01-20	block	#1240	Review bot	false alarm	alice	author explained, reviewer withdrew
2026-01-21	main-failure	run 9912	 	flaky test	agent	passed on re-run without a change
```

| Column | Meaning |
| --- | --- |
| `date` | The day of the verdict. |
| `kind` | `block` (was a reviewer's block right) or `main-failure` (what caused a failed push to the default branch). |
| `ref` | The pull request or run. |
| `subject` | For `block`: the reviewer's name as the report shows it. Empty for `main-failure` (keep the tab). |
| `label` | For `block`: `right` or `false alarm`; anything else counts as unclear. For `main-failure`: the cause in a few words (`merged defect`, `inherited`, `flaky test`, `infrastructure`); the report counts each distinct label. |
| `by`, `note` | Who labelled it (a person or an agent) and one sentence of evidence. |

The hit rate of a reviewer is `right / (right + false alarm)`; unclear blocks are shown and left out of it.

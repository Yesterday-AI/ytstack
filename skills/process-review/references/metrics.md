# Metrics

All metrics are per merged pull request, grouped by merge day or merge week (UTC, weeks from Monday). `metrics.json` holds them as `total`, per `weeks` and, for counts, per `days`.

## Throughput

| Metric | Definition | Pitfall |
| --- | --- | --- |
| `merged` | Merged pull requests. | Says nothing about value. Many small pull requests and few large ones can be the same work; read with `sizeMedian`. |

## Efficiency

| Metric | Definition | Pitfall |
| --- | --- | --- |
| `leadMedianH`, `leadP90H` | Hours from opening to merge. | Work before the pull request opened is invisible. Draft time counts. |
| `firstReviewMedianH` | Hours from opening to the first review event of any named reviewer. | A bot that answers in a minute hides a slow human review. Look at the reviewer that gates the merge. |
| `roundsMean`, `multiRoundShare`, `threePlusShare` | Review rounds of the round reviewer per reviewed pull request; share with two or more, three or more. | Depends entirely on `rounds.kind` and the reviewer rules. |
| `firstRoundBlockingShare` | First rounds that blocked, of those whose outcome is readable. | Without `findings`, only "changes requested" blocks. |
| `laterClean`, `laterNonBlocking`, `laterBlocking`, `laterUnknown` | What each round after the first found: nothing, only non-blocking findings, a blocking finding, not readable. | The core answer to "too many loops": clean and non-blocking later rounds are the avoidable ones. A later blocking round can be a real late find or a regression from the fix; read some. |
| `laterAfterMergeOnly` | Later rounds preceded only by merge commits of the base branch. | A review repeated although the author changed nothing. |
| `reworkCommitsMean` | Commits after the first round, without merge commits. | Squashing authors show one commit. |
| `ciRunsPerPrMedian`, `ciHoursPerPr`, `ciFailedRunShare` | Workflow runs on the pull request's branch; their summed wall time; failed of finished runs. | Matched by branch name, so a reused branch name mixes pull requests. Wall time of a run, not job minutes. |

| `firstPassShare` | Pull requests whose first finished CI run was green and whose first review round did not block, of those with both known. | The repository-level success rate of the first attempt; its complement is the fix-push-wait load. Not available where the review outcome cannot be read. |
| `ciLoopShare` | Pull requests with at least one failed CI run on their branch. | A failed run from a flaky test counts too. |
| `phases` | Hours from open to the first review, from the first to the last review event, from the last review to merge; median, 75th and 90th percentile each. | Medians of phases do not add up to the median of the total. Vendors cut the phases differently (review may start at open, at the review request or at "ready for review"); compare with a published tier only on the same cut and percentile. |
| `leadHistogram`, `heat` | Pull requests by lead-time bucket; merges by weekday and hour (UTC). | The histogram shows the tail the median hides. The heatmap shows when the pipeline is under load, not when people work. |
| `roundYield` | Per round position (1, 2, 3, 4+): rounds with a blocking finding, only non-blocking findings, nothing, not readable. | The answer to "is a third round worth it". Needs `findings` or review states. |
| `laterYield.byClass`, `laterYield.byRole` | Later rounds that found a blocker, per risk class; blocking threads per review role, in round 1 and in later rounds. | Read these before recommending fewer rounds: a low overall yield can hide a role or a class whose later rounds pay. Role counts are small; give the counts, not only the share. |
| `ci.prBranches`, `ci.defaultBranchPush` | CI statistics for runs on pull request branches and for pushes to the default branch, separately. | Cancelled runs mean different things: a superseded push on a branch, possibly a deliberate queue policy on the default branch. |
| `failures` (from `mine-failures.mjs`) | Failed pushes to the default branch of the last days with the failed job and step and the merged pull request behind the commit; jobs that failed on the first attempt of runs that later turned green. | Job and step, not the test: the failing test is in the log. A failure repeated on consecutive merges is usually inherited from an earlier one. Gate jobs that only mirror other failures need `ignoreFailedJobs`. |
| `classes` | Lead time, review coverage, rounds, CI runs and CI hours per risk class (docs only, tests only, configuration, source code, sensitive). | Classes come from path patterns; set `sensitivePattern` and `docsPattern` to fit. Cost that does not rise with risk is waste at the low end or a gap at the high end. |

## Authors

| Metric | Definition | Pitfall |
| --- | --- | --- |
| `authors.classes` | Pull requests by author class: bot account, AI-assisted or agent (a co-author trailer, a footer in the description or a branch prefix names an AI tool), no AI mark. | Detection undercounts: some tools leave no mark and trailers can be switched off. "No AI mark" is not "human". The signal that classified each pull request is counted in `authors.signals`. Compare classes inside one repository only. |

## Quality

| Metric | Definition | Pitfall |
| --- | --- | --- |
| `fixShare` | Pull requests whose title marks a fix. | Depends on title discipline. A rising share can mean more defects or more honest titles. |
| `reverts` | Titles that mark a revert. | Reverts by direct push are invisible. |
| `followUpExplicitShare`, `followUpMedianH` | Pull requests that a later fix names by number (`#123` in title or body) within the window; hours until that fix merged. | The strongest automatic signal of a defect that passed review. Still counts planned follow-ups ("addresses the notes from #123"): read a sample. Right-censored for the newest pull requests. |
| `followUpDefectShare`, `followUpPlannedShare` | The linked follow-ups split by the wording of the fixing pull request: not worded as a review follow-up (possible defect), or only planned follow-ups of review findings. | Where non-blocking findings are deliberately moved to the author's next pull request, the planned part grows when the process works as intended; only the defect part is a quality signal. The split is by wording (`plannedFollowUpPattern`), so read a sample of both. |
| `followUpOverlapShare` | As above, or a later fix touched one of the same files (files touched by more than 5 % of all pull requests, lock files and Markdown ignored). | An upper bound. Busy files make it large without any defect. Use it for the trend only. |
| `noReviewShare` | Merged without any review event or thread by a named reviewer. | Zero if a bot comments on everything; then look per reviewer. |
| `unresolvedThreadPrs` | Merged with at least one unresolved thread. | Zero where a ruleset enforces resolution. |
| `sourceWithoutTestShare`, `fixWithoutTestShare` | Pull requests touching source files without touching any test file; the same among fixes. | Refactorings and configuration need no test. The share among fixes is the telling one. Only the first 60 files are read. |
| CI `failureRate` on the default branch | Failed of finished push runs on the default branch. | Mixes merged defects, flaky tests and infrastructure. Classify the failures by reading the logs of a sample. |
| CI `red` | Periods in which the default branch was red, from the first failed push run to the end of the next green one: count, median, longest, total hours. | A stand-in for time to restore. Runs of several workflows are mixed unless `ciWorkflows` names the gating one. |
| `hotspots` | Files touched by three or more fix pull requests, with all pull requests touching them. | Only the first 60 files of a pull request are read; generated and lock files are ignored through `ignorePaths`. A hotspot is where to look, not a verdict. |
| `meta` | Pull requests closed without a merge in the period, open now, and open for more than a week. | Everything else on the page covers merged pull requests only; these three numbers say how much that leaves out. |
| CI `rerunGreen` | Runs whose later attempt succeeded. | Candidates for flaky tests; a re-run after an infrastructure outage looks the same. |
| CI `hoursNotGreen`, `cancelledShare` | Wall time of runs that did not end green; share of cancelled runs. | Cancelling a superseded run is efficient; a high share of cancelled hours still shows pushes arriving faster than CI finishes. |

## Reviewers

| Metric | Definition | Pitfall |
| --- | --- | --- |
| `prs`, `prShare` | Pull requests with at least one event of the reviewer. | Presence, not usefulness. |
| `threadsOutdated` of `threadsJudged` | Threads whose lines a later commit changed (GitHub's outdated flag). | The cheapest sign that a finding was acted on. Not causal: rebases and unrelated edits count. Read it as one reviewer against another in the same repository, never against a published number. |
| `threads`, `threadsResolved` | Inline threads the reviewer opened; resolved ones. | Resolved does not mean the finding was right: authors resolve false alarms too. |
| `sample` | A fixed pseudo-random sample of the reviewer's threads. | This is the input for the hand check of precision; the script does not judge it. |
| `compare` | For two reviewers on the same head: both block, only one, neither. | Agreement is not correctness. Read the one-sided cases. |

## Changes

| Metric | Definition | Pitfall |
| --- | --- | --- |
| `changes[].rows` | Per dated change: each metric in the window before and the window from the change on, with the number of cases on both sides and a reading: `better`, `worse`, `no clear change`, `too few`, `context`. | A reading of better or worse means the difference is larger than chance explains at the 5 % level (rank-sum test for lead time, rounds and CI hours; two-proportion test for shares). It is not proof of cause. |
| `changes[].confounded` | Other marked changes inside either window. | With several changes in one window the effect belongs to the group, not to one of them. |
| `changes[].incomplete`, `followUpsCensored` | The window after the change runs past the last mined day; later fixes for it may still come. | Re-run when the window is complete before reporting an effect. |
| `changeCandidates` | Merged pull requests that touched process files, and the first and last day each reviewer was seen. | Candidates only: a typo fix in a workflow is not a process change. Changes made outside the repository (a bot's settings, a tool update on a developer machine) do not appear here at all. |

Two things a before/after window cannot separate from a process change: a different mix of work (a week of documentation next to a week of migrations) and load (twice as many pull requests on the same runners). Check the risk-class table and the merged-per-day row of the same card before attributing an effect.

## What cannot be measured this way

- **Recall of a review** (defects it missed) has no direct measure. Follow-up fixes and failures on the default branch are its shadow.
- **Precision of a review** needs reading (the skill's Step 10, "Read samples by hand"). State the sample size with the result.
- **Production quality** (incidents, error rates) lives outside GitHub. If the team has an error tracker or an incident log, add its numbers per week next to the report's quality section and say where they come from.

## Reading the result

Efficiency and quality are read together; either alone misleads.

| Pattern | Likely meaning | Check |
| --- | --- | --- |
| Many later rounds that find nothing | Re-reviews without cause: every push triggers a full round | Rounds after merge-only commits; let a non-blocking review stand. First read "Which later rounds pay": keep the rounds of the role or risk class whose later rounds do find blockers |
| Later rounds with only non-blocking findings | Reviewer reports new details each round, author fixes them one push at a time | Limit later rounds to the changed lines; collect details for the next pull request |
| High first-round blocking share, low follow-up fixes | The review earns its cost | Sample that the findings were right |
| Low blocking share and rising follow-up fixes or red default branch | Review misses defects | Read the follow-ups; what would have caught them |
| Long lead time, few rounds | Waiting, not working: queue for review or CI | Time to first review, CI p90, cancelled runs |
| High share of runner-hours not green | CI spent on runs that were cancelled or failed | Per workflow; concurrency groups, change classes, flaky tests |
| Fixes without a test file | Defects come back | Read five such fixes |

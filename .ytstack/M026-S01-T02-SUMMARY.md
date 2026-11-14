---
milestone: M026
slice: S01
task: T02
project: ytstack
closed: 2026-11-13T19:30:45Z
verification: passed
---

# M026-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M026-S01-T02: finish-lane watches the release after a merge`).

## Outcome

`finish-lane` got the step "Watch the release" after "Merge or hand over"; the report is Step 13. The step runs after a merge by anyone. It reads the merge commit of the pull request from the host (`gh pr view <n> --json mergeCommit`), because a squash gives the base branch another commit than the reviewed one, and starts `bin/ytstack-watch release --commit <merge commit>`. A table says what each result means: `released` and `no health command` go into the report with the five lines of the receipt; `not arrived` and `unhealthy` go to the person at once; without a "Release" section, or with a `RUNTIME.md` that fails its check, one line in the report says that nothing was watched and why. The hard gate forbids deploying, restarting, reverting and rolling back. A session with other lanes writes the report with `release: watching` and adds the receipt later.

`coordinate` names the watch in its Step 7: a pull request that merged, also by a person, gets its lane set to `merged` and its merge commit watched.

## Deviations from plan

- `no health command` (exit 0) is put into the report with the plain sentence that nobody asked whether the target is healthy. It is not sent to the person as an alarm: the commit arrived, and the project chose to name no health command.
- The watch is started in the background and the report may precede the receipt. A full run takes up to 17 minutes, and a coordinating session has other lanes.
- Exit 1 of the watch (a `RUNTIME.md` that fails `bin/ytstack-runtime check`) has its own row: one line in the report with the problems.

## Follow-ups

- Nothing was run: `bin/ytstack-watch release` is not in this branch. The step names the command line, the exit codes and the receipt as the report of M026-S01-T01 states them (`/tmp/mk_analysis/reports/c-after-merge.md`); the two meet when the branches are merged.
- On a host other than GitHub the skill stops before the merge, so the step has no merge commit to read there. A person names it.
- The preamble does not print whether a "Release" section exists. The watch answers that with exit 4.

## Spec

- skills: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && python3 bin/ytstack-check` -- the suite passed at the working tree on top of `417bfdd` in the local checkout (macOS, bash 3.2), last line `497 passed, 0 failed`, exit 0; the checker exited 2 with no `[fail]` line and 32 warnings.

Not checked: the step against the real `bin/ytstack-watch release`, and a session that merged a lane and watched a target. The Linux containers ran once for the whole branch, see the report.

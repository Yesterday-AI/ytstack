---
milestone: M026
slice: S02
task: T01
project: ytstack
closed: 2026-11-13T19:10:29Z
verification: passed
---

# M026-S02-T01 -- Summary

## Commits

- The commit that carries this file (`M026-S02-T01: bin/ytstack-upkeep collects what needs a look and can leave one question`).

## Outcome

`bin/ytstack-upkeep` was built. One run printed one report for a project's `.ytstack/`: a first line with the directory, the read time and the commit, seven sections (`spec`, `state`, `gates`, `questions`, `lanes`, `runtime`, `review policy`) with a count and one line per item, and a last line with the sum or `nothing needs a look`. It exited 0 for a clean project and 10 when a count was not 0. Without `--question` it wrote nothing; the suite compares the checksums of every file before and after.

With `--question` it wrote one file through `bin/ytstack-questions new`, titled `Upkeep found N things that need a look`, with the report as an indented block under `## Context`. While such a question was open or asked it wrote none and named the one that waits. After the answer a new run wrote a new one.

`tests/ytstack-upkeep.test.sh` pins it with 97 assertions on fixture projects: a clean one, one case per section, the three thresholds, the two branches of the review policy section on a copy of the scripts in a stand-in directory, `--question` with its dedupe, usage.

On this repository the run listed nine things: five drifted areas, three findings of the STATE lint and the open gate G01 of `M024-S02-PLAN.md`.

## Deviations from plan

- **Lanes are read from `LANES.md` directly**, with the row pattern of `bin/ytstack-frontier`, and not through `ytstack-frontier list`. `list` prints the slices of one milestone; a lane may be a task or a named piece (`review-pr-12`), and a stuck one of those is what this run is for. `ytstack-frontier check` runs first: a table with problems is reported with those problems and its rows are not read.
- **A lapsed gate is one whose `lapses:` value holds a date before today (UTC).** A date of today is still open. A value without a date (`when S03 merges`, `never`) is open: the script cannot know whether the condition occurred.
- **The earlier question is recognised by its title** (`Upkeep found ...`) in the output of `ytstack-questions list`, which prints the open and the asked ones. The title and the slug come from the same text.
- **The question is decided by `the operator`**, fixed. `## Options` and `## Recommendation` stay empty: the file reports, it does not propose.
- **Exit 1** also when the question file could not be written.
- **The report names the commit** of the checkout in its first line when the project is a repository.

## Follow-ups

- shortcut: a question or a lane whose time does not parse is skipped here; `ytstack-questions check` and `ytstack-frontier check` name it. Only the second runs as part of this script.
- `bin/ytstack-risk` did not exist in this worktree. The section calls `ytstack-risk -C <dir> check` and takes every output line of a failing call as an item. Check after the merge that the real script takes `-C` in front and prints one line per problem; the suite then runs the clean project against it.
- One run took 0.2 seconds on an empty fixture project and 2.7 seconds on this repository (six spec areas, 253 entries in `.ytstack/`), measured once each on this machine. No cache.
- A scheduled run in CI needs the full history for the drift section (`fetch-depth: 0`); the recipe (M026-S02-T02) says so.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-upkeep.test.sh` -- passed at the tree `3c2cd11` (the staged files of this task on top of `bfe6d14`) in the local checkout (macOS, bash 3.2.57). Last line `97 passed, 0 failed`, exit 0.

Also run on that tree: `bash tests/run-all.sh` locally, `ALL SUITES PASSED` (23 suites), exit 0; `python3 bin/ytstack-check`, exit 2, 32 warnings, no `[fail]` (the baseline of 27 and five spec drift warnings; the one for `checks-and-evals` now also counts `bfe6d14`, the commit of M026-S01-T01); `bash tests/run-all.sh` in `ubuntu:26.04` (bash 5.3.9) from an export of the tree, `ALL SUITES PASSED`, exit 0; the same in `alpine` with `coreutils` (bash 5.3.9), `ALL SUITES PASSED`, exit 0.

The suite was written before the script and first run after it; no failing run was recorded.

Not checked: the real `bin/ytstack-risk` (see Follow-ups). A scheduled run on any host. A project with the `.ytstack` directory in user scope (`~/.ytstack/projects/<key>`). `alpine` without `coreutils` (BusyBox `date`).

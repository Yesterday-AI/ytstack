---
milestone: M026
slice: S01
task: T01
project: ytstack
closed: 2026-11-13T19:02:17Z
verification: passed
---

# M026-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M026-S01-T01: ytstack-watch release follows a commit until the target serves it and stays healthy`).

## Outcome

`bin/ytstack-watch` got the subcommand `release --commit <sha> [--timeout <seconds>] [--interval <seconds>] [-C <dir>]`. It read `deployed`, `healthy`, `settle` and `target` through `bin/ytstack-runtime get`, ran `deployed` until the output named the commit, then ran `healthy` for the settle time, and printed one receipt of five labelled lines (`Target:`, `Commit:`, `Arrived:`, `Health:`, `Result:`) with the read times. While it waited it printed a line only when an answer changed. A short SHA matched a full one in either direction, from seven characters. The pull request mode kept its behaviour: its 82 assertions pass unchanged.

Exit codes: 0 released (also for `no health command`), 2 not arrived, 3 unhealthy, 4 no "Release" section or no `deployed`, 1 a `RUNTIME.md` that fails `ytstack-runtime check`, 64 usage. They stand at the top of the script and in the "Release" section of `docs/ux/runtime-format.md`, which now also shows the receipt.

`tests/ytstack-watch.test.sh` gained 56 assertions on fixture projects whose two commands count their calls and answer from a file.

## Deviations from plan

- **`no health command` exits 0.** The brief lists it as a result and not among the exit codes. The commit arrived and nothing failed; the `Result:` line tells it from `released`.
- **One failed health call does not end the watch.** It asks until the settle time is over and exits 3 then, so the receipt can say how often the call failed. The failure is printed as a line the moment it is read.
- **A call is bounded.** A `deployed` or `healthy` call that still runs after 30 seconds is stopped with its process group and counts as failed (`stopped after 30 seconds`). Without that, a `curl` without a time limit holds the watch past `--timeout`. The timeout can therefore run over by one call.
- **A `RUNTIME.md` that fails `check` is not run** (exit 1), as `ytstack-runtime up` does. The check for "no section, no `deployed`" comes first, so that case keeps its own code.
- **`--interval` defaults to 15 seconds and takes 1 or more** in this mode. The minimum of 20 belongs to the pull request mode, which asks GitHub.
- **The match is on runs of hex digits**, not on any substring: the commit never matches in the middle of another hash. `v1.4.2-3-ga1b2c3d` names `a1b2c3d`. The exit status of `deployed` is not part of the match; a failed call that prints no commit is shown with its exit code.
- **The suite.** One case appends the commit in the background while the watcher runs, as the brief asks. The other cases answer from a file with one line per call, which makes "turns unhealthy" and "never arrives" exact without a race. The watch counts wall time, so these cases take about ten seconds.

## Follow-ups

- The receipt is five lines with fixed labels; `finish-lane` (M026-S01-T02) can copy them as they are and branch on the exit code.
- shortcut: `-C <dir>` is accepted in front of `release` and among its flags; the pull request mode takes it in front only.
- An ask costs five calls of `bin/ytstack-runtime` at the start (four `get`, one `check`), about 0.4 seconds. One command that prints a whole section would save four; not needed for a watch that runs for minutes.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-watch.test.sh` -- passed at the tree `4d781b0` (the staged files of this task on top of `85298e0`) in the local checkout (macOS, bash 3.2.57). Last line `138 passed, 0 failed`, exit 0.

Also run on that tree: `bash tests/run-all.sh` locally, `ALL SUITES PASSED` (22 suites), exit 0; `python3 bin/ytstack-check`, exit 2, 32 warnings, no `[fail]` (the baseline of 27 and five spec drift warnings that name commits of the base, `c8db914` and `85c4f27`); `bash tests/run-all.sh` in `ubuntu:26.04` (bash 5.3.9) from an export of the tree, `ALL SUITES PASSED`, exit 0; the same in `alpine` with `coreutils` (bash 5.3.9), `ALL SUITES PASSED`, exit 0.

Not checked: a real target (a version endpoint over the network, a rollout that takes minutes). `finish-lane` calling the subcommand: that step is M026-S01-T02. A `deployed` command that prints several commits at once (a rolling deploy with two versions live): the first run of hex digits that fits decides. The 30 second limit with its real value: the suite sets it to 1.

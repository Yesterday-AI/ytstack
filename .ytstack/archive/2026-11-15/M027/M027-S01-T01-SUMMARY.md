---
milestone: M027
slice: S01
task: T01
project: ytstack
closed: 2026-11-13T19:07:26Z
verification: passed
---

# M027-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M027-S01-T01: signal format and bin/ytstack-signals record a finding once`).

## Outcome

`docs/ux/signal-format.md` fixed the record of a finding, and `bin/ytstack-signals` was built with four commands. `new` decided by the key: it wrote a finding with the next id, counted a sighting of an open or planned finding and kept its newest five sightings, counted a sighting of a dismissed finding without keeping it, and wrote a new finding with `reopens:` for a sighting of a fixed one. `list` printed the open and planned findings, one state or all with `--state`. `set` changed the state, asked for a reference on `planned` and for a reason on stdin on `dismissed`. `check` named each defect of a file and of a key's chain. Six `new` calls with one key at the same moment gave one file with `count: 6`. `tests/ytstack-signals.test.sh` pins all of it on fixture directories.

## Deviations from plan

- `new` takes `--read-at <UTC time>`. The brief's signature had no such option; without it `first_seen` and `last_seen` would hold the time of the call, not the time the source was read.
- `list --state all` prints every finding. An intake has to compare a line with the fixed and dismissed findings too before it chooses a key.
- Keys and references are one word of letters, digits and `. _ : / @ + = -`. They stand in a frontmatter line, and `new` compares keys as text.
- Per key only the newest finding may be in a state other than `fixed`: `set` refuses the change and `check` names it. Without that rule `new`, which asks the newest finding, could write a second live finding for a key.
- Of one sighting the first twenty lines are kept, and blank lines are dropped. A stack trace of a thousand lines would otherwise land in a committed file on every run.
- `check` also fails a dismissed finding without a reason under "Assessment" and a body without the three sections.

## Follow-ups

- A lock left behind by a killed process is not recognised as stale; the message names the file to remove (the same shortcut as in `bin/ytstack-frontier`).
- The script cannot see a secret in a sighting. The format document names it as a judgment of whoever records.

## Spec

- checks-and-evals: area file updated by the coordinator in the closing task
- artifacts: area file updated by the coordinator in the closing task

## Verification

Command: `/bin/bash tests/ytstack-signals.test.sh` -- exit 0, last line `144 passed, 0 failed`, at the working tree on top of `85298e0` in the local checkout (macOS, bash 3.2.57).

The same suite from an export of that working tree: exit 0, `144 passed, 0 failed` in `ubuntu:26.04` (mawk 1.3.4, uutils coreutils 0.10.0) and in `alpine` (bash 5.3.9, BusyBox 1.37.0).

The lock, 100 rounds of six `new` calls with one key in `ubuntu:26.04`: no round with a second file or a lost count.

`bash tests/run-all.sh` -- exit 0, `ALL SUITES PASSED` (22 suites), local checkout. `python3 bin/ytstack-check` -- exit 2, no `[fail]` line, 32 warnings, the same 32 as at `85298e0`.

Not checked: the full set of suites in the two containers for this commit (it runs once for the head of the branch, after the last task). A lock held by a killed process was not tried.

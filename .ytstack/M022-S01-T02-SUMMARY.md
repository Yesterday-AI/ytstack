---
milestone: M022
slice: S01
task: T02
project: ytstack
closed: 2026-11-13T15:45:00Z
verification: passed
---

# M022-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M022-S01-T02: add bin/ytstack-spec (lint, drift, impact, areas) with its suite`).

## Outcome

`bin/ytstack-spec` shipped with four modes. `lint` failed a spec on each format rule of `docs/ux/spec-format.md` and warned on an oversize file and on a `verified_at` that names no commit. `drift` listed an area whose `paths` changed after its area file or one of its `sources` was last touched, stayed silent for an untouched area, a `planned` area and an area file that is new or edited in the working tree, and exited 0 unless `--exit-code` was given. `impact` closed a plan that says `none`, accepted a named area when its area file or a source changed (committed or not), exited 1 when neither did and 3 when the plan has no `## Spec impact` section. `areas` named the area of a path. `tests/ytstack-spec.test.sh` pinned all of this on fixture repositories with 58 assertions.

## Deviations from plan

- The plan named a script `bin/yt-spec-drift`. It became `bin/ytstack-spec` with four modes: the loop needed the format check, the closure check and the path lookup as well, and the repository's scripts carry the `ytstack-` prefix.
- `drift` does not read `verified_at`. It compares with the last commit that touched the area file or a source, because a squash merge can orphan the commit a stamp names. Setting the stamp is itself such a touch and quiets the report. `lint` only warns about a stamp that names no commit.

## Follow-ups

- `areas` matches with a shell `case` pattern in which `*` also crosses `/`. That is wider than a git pathspec glob and is marked `shortcut:` in the script. If the hint has to be exact, switch to `git ls-files ':(glob)<pattern>'`.

## Spec

none -- not covered by an area yet: the spec did not exist before S01-T04; T04 writes the area files with these changes included

## Verification

Command: `/bin/bash tests/ytstack-spec.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout: `58 passed, 0 failed`.

Not checked: Linux bash 5 was not run for this task alone. The run at the close of M023 (`tests/run-all.sh --linux`, alpine, BusyBox awk) found that `lint` reported present sections as missing: `grep -q` at the end of a pipeline exits on the first match and `pipefail` turned the writer's SIGPIPE into a failure. Fixed in this task's commit; the suite passes there (58 cases). A shallow clone, where `lint` skips the stamp warning: no fixture covers it.

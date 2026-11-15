---
milestone: M031
slice: S05
task: T01
project: ytstack
closed: 2026-11-15T09:40:00Z
verification: passed
---

# M031-S05-T01 -- Summary

## Commits

- The commit that carries this file (`M031-S05-T01: bin/ytstack-plans finds a plan outside .ytstack and lists its rows`).

## Outcome

`bin/ytstack-plans` was written test-first. `scan` looks at eight fixed directories (`plans`, `plan`, `planning`, `roadmap` and the same under `docs/`), reads their `*.md` files up to three levels deep in one `awk` pass and prints one line per directory with plan files: files, open and done rows, `verdict=large|small` and the answer `PREFERENCES.md` records. It exits 0 only when a large directory has no answer yet, so a skill preamble can branch on the exit code. `rows` prints `path:line`, state, id, section and title per work row; `--open` filters, a PATH lists one file or directory in full. Work rows are task-list items and data rows of tables with a status or checkbox column; tables without one (comparisons, cost tables) and fenced code are not counted. Nothing is written.

Thresholds: a file is a plan file from 3 work rows; a directory is large from 10 open rows (`YTSTACK_PLAN_MIN_OPEN`).

## Deviations from plan

- The header word `Step` is not an id column: a two-column table `| Step | Status |` would otherwise lose its title.
- `ok`, `yes` and a bare `x` are not read as done; they appear as free text in status cells too often.

## Follow-ups

- Task-list items under a work package that a board row marks done stay `open` (the real example ticks the board, not the checklist). The mapping rules in T02 tell the agent to map from the board when a file has one.

## Spec

- checks-and-evals: updated in T03 (path list and the script's behavior line)

## Verification

Command: `/bin/bash tests/ytstack-plans.test.sh` -- exit 0, last line `32 passed, 0 failed` (macOS bash 3.2.57; also under the default bash).

Real example, read only: `bin/ytstack-plans -C .../meinkontext scan` printed `dir=plans files=23 open=1467 done=462 verdict=large answer=none`, exit 0, in 0.4 s. `rows` listed the board rows of the AV-08 package plan with their ids (70 open). A `cksum` over every file under its `plans/` was identical before and after.

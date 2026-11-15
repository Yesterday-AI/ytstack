---
milestone: M016
slice: S03
task: T01
project: ytstack
closed: 2026-11-07T12:35:33Z
verification: passed
---

# M016-S03-T01 -- Summary

## Commits

- `f4b9085` -- M016-S03-T01: plan #26 acceptance suite + run-all + Linux run
- `07dbb43` -- M016-S03-T01: #26 acceptance suite (main/worktree/mixed sessions), tests/run-all.sh with --linux, ytstack-check test on a copied tree

## Outcome

`tests/hooks-worktree.test.sh` (24 cases) is the executable form of the #26 acceptance criteria: a fixture main checkout with committed hand-written `HANDOFF.md`, a linked worktree, and three session shapes -- (a) session in main, (b) session in the worktree, (c) `CLAUDE_PROJECT_DIR`=main with payload `cwd`=worktree. For each it fires all eight hooks in a realistic order (incl. a task-ref commit) and asserts byte-identical snapshots of the other checkout, only the two legitimate artifacts (draft stub, team summary) in the committing checkout, auto handoff + journal only under `CLAUDE_PLUGIN_DATA` keyed by the right worktree, `HANDOFF.md` unchanged, nothing under the bogus project dir, and idempotency on repeat. `tests/run-all.sh` runs every suite from a neutral cwd (stops on first failure) and `--linux` runs them in `alpine/git` + bash 5 via Docker (skips with a clear line without Docker). `tests/ytstack-check.test.sh` now works on a copied plugin tree (vendor symlinked), so it never writes fixtures into the real checkout and runs on a read-only mount.

## Deviations from plan

`alpine/git` has `git` as entrypoint (`--entrypoint sh` needed); the ytstack-check suite had to move to a copied tree to pass on the read-only container mount. One shell typo (`$(( ... ))` arithmetic instead of `$( ( ... ) )` subshell) fixed in the new test.

## Follow-ups

- Linux run passed: bash 5.3.9, 9 suites, 464 cases, 0 failures (git-ctx reports 64 there because the macOS `/private` canonicalisation case is skipped). The T01 follow-up from S01 is closed.
- S03-T02 adds the concurrency suite and `ytstack-check --tests`.

## Verification

Command: `/bin/bash tests/hooks-worktree.test.sh && /bin/bash tests/run-all.sh` -- passed (24/24; ALL SUITES PASSED on macOS bash 3.2, 465 cases). `/bin/bash tests/run-all.sh --linux` -- ALL SUITES PASSED (bash 5.3.9, Linux).

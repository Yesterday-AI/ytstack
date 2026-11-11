---
milestone: M021
slice: S02
task: T03
project: ytstack
closed: 2026-11-11T10:35:58Z
verification: passed_with_caveats
---

# M021-S02-T03 -- Summary

## Commits

- The commit that carries this file (`M021-S02-T03: close milestone M021`). Artifacts only, no source change.

## Outcome

M021 is closed on the branch `feat/status-segment`. Exit criteria against evidence:

| Criterion | Evidence |
|---|---|
| Block: label, percentage, done/total, truncated `waiting_on` | `tests/ytstack-status.test.sh` "progress block" cases |
| No block: slice task count | "no progress block" cases; live run in this worktree printed `M021/S02/T01 0/3` |
| Outside a project: nothing, non-zero | "outside a project" cases; live run for `/tmp` exit 1 |
| Linked worktree: plan from default branch, pointer local | "default branch" cases (worktree, detached HEAD, clone with newer `origin/main`) |
| Malformed block: nothing, lint reports it | status suite "malformed block", `tests/git-ctx.test.sh` W7 case |
| Skills keep the block current | `summarize-task` Step 10, `quick-task` Step 6 (prose, checker clean) |
| Docs and stable location | `docs/statusline.md`; snippet run against a fake cache picked the highest version |
| Suites and checker | 13 suites `ALL SUITES PASSED`, checker 27 warnings as on `main`, 13 Codex tests OK, `claude plugin validate .` passed |

## Deviations from plan

- `bash tests/run-all.sh --linux` was skipped: no Docker daemon on this machine. Linux coverage comes from CI after the push.

## Follow-ups

- Operator: push `feat/status-segment` (or merge it into `main`), let CI run the ubuntu job, then release and `/plugin update` so the script exists in the plugin cache. Close issue #31 after that.
- Merge note: the main checkout holds uncommitted M020 planning that also edits `STATE.md` and appends to `DECISIONS.md`. Both files will conflict textually; keep both DECISIONS entries and the M020 pointer.

## Verification

Command: `bash tests/run-all.sh && bin/ytstack-check; python3 -m unittest discover -s tests -p 'codex*_test.py'; claude plugin validate .` -- passed_with_caveats (macOS only, see Deviations).

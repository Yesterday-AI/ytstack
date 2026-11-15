---
milestone: M031
slice: S03
task: T01
project: ytstack
closed: 2026-11-15T09:50:00Z
verification: passed
---

# M031-S03-T01 -- Summary

## Commits

- The commit that carries this file (`M031-S03-T01: say which factory tool is off in SessionStart and ytstack-upkeep`).

## Outcome

`yt_factory_notices` in `hooks/lib/git-ctx.sh` returns one line per factory tool that is off although the project would use it: risk routing (`.ytstack/spec/` without `REVIEW.md` or without an area that allows `auto_merge: low|normal`, while `merge_by` is `risk`), the PR watch (GitHub origin and no `pr_watch` line in `~/.ytstack/config`, or `pr_watch=on` with a heartbeat that is missing or 10 minutes old), and `RUNTIME.md` without "Release" or "Signals" while deploy or signal evidence exists. The heartbeat comes from `watch.sqlite3` through `sqlite3 -readonly`, else from the mtime of `worker.lock`; no hook calls GitHub.

`session-start` shows the lines as a "Factory tools (said once per session)" block on `startup` and `clear` (and on a SessionStart payload without a source), never on `resume` or `compact`, so the hook stays read-only. Near the 10,000-character cap the block shrinks to one pointer line after the Next action excerpt was cut. `bin/ytstack-upkeep` prints the same lines in a ninth section, "factory tools", that is not counted. `bin/ytstack-runtime sections` names the sections that have a list line, also when `check` fails.

On this repository the block names the missing risk routing (no `REVIEW.md`); its injection was already near the cap and now ends with the pointer line.

## Deviations from plan

- Explicit choices stay silent: `merge_by: human` or `coordinator`, and `pr_watch=off`. The brief listed "no merge_by" as a trigger; `merge_by` defaults to `risk`, so a missing line cannot switch routing off.
- `yt_read_stdin` now also sets `YT_SOURCE` (the payload `source`).

## Follow-ups

- The PR watch condition is a GitHub origin, not "open pull requests": telling those apart needs a host call.

## Spec

- hooks-and-state and checks-and-evals: updated in M031-S03-T03.

## Verification

Command: `bash tests/session-notices.test.sh && bash tests/ytstack-upkeep.test.sh && bash tests/ytstack-runtime.test.sh && bash tests/hooks-readonly.test.sh` -- passed in the local checkout (macOS, bash 3.2): `32 passed, 0 failed`, `131 passed, 0 failed`, `140 passed, 0 failed`, `69 passed, 0 failed`. Also `hooks-worktree` 24, `git-ctx` 144 and `hooks-json` 71 passed.

Not checked: a live Claude Code session; the injection was measured by running the hook on this repository (9,458 characters with the pointer line).

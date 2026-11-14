---
milestone: M029
project: ytstack
size: M
created: 2026-11-14T12:00:00Z
status: done
total_slices: 3
completed_slices: 3
---

# M029 Roadmap

**Goal:** ytstack users can switch on a PR watcher that tells the owning agent session about red CI, unresolved bot review threads and merge conflicts, without the agent having to monitor PRs itself.

**Exit criteria:** see `M029-CONTEXT.md`.

## Slices

- [x] S01 -- The engine runs from `tools/pr-watch/` with its state in `~/.ytstack/pr-watch/`, on Python 3.9+, behind `bin/ytstack-pr-watch` (enable/disable, install-worker, uninstall-worker, migrate plus the engine commands).
- [x] S02 -- Claude Code and Codex hooks are registered and exit at once unless `pr_watch=on`.
- [x] S03 -- Tests (`tests/pr-watch.test.sh`, `tests/pr_watch/`), docs (`docs/pr-watch.md` and pointers), full verification.

## Notes

- Ported by one subagent from the maintainer's local install, verified by the lead: all suites pass (pr-watch 55 shell cases, 43 unit tests also on `/usr/bin/python3` 3.9.6), checker without failures, Codex tests OK, `claude plugin validate .` passed; enable / hook / install-worker plan / status / disable exercised under a temporary HOME.
- Not exercised: a real `launchctl bootstrap` and real Codex delivery. The switch of the maintainer's live install is a separate, explicit step after the release.
- Under a temporary HOME the asdf `python3` shim exits 126 without a message; `YTSTACK_PYTHON=/usr/bin/python3` avoids it. The hook wrapper fails open, so a broken interpreter means no PR watch, never a blocked prompt.

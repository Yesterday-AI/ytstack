---
milestone: M016
slice: S01
task: T05
project: ytstack
closed: 2026-11-07T11:53:45Z
verification: passed
---

# M016-S01-T05 -- Summary

## Commits

- `a90fdd2` -- M016-S01-T05: plan read-only hook migration to git-ctx.sh
- `f8c0894` -- M016-S01-T05: migrate read-only and team hooks to git-ctx.sh; session-start points at the latest auto handoff and guards the 10k cap

## Outcome

All eight hooks now source `hooks/lib/git-ctx.sh`; no hook uses `CLAUDE_PROJECT_DIR` or a basename slug (enforced by `tests/hooks-readonly.test.sh` static cases). `session-start` resolves the checkout from the payload `cwd`, reports `Working tree` / `ytstack dir`, lists the manual `HANDOFF.md` with its `event:` and the latest automatic handoff from the out-of-tree state dir (path computed without creating directories), and sheds the Next-action excerpt when the injection approaches the 10,000-char cap (warning on stderr if still over). `pre-tool-use-edit` resolves target paths against `YT_TOPLEVEL`; `task-created`, `task-completed` (summary gains `worktree:`), `teammate-idle` only swapped their resolver. 37 test cases cover main, greenfield, linked worktree, advisory drift, team hooks and the static invariants.

## Deviations from plan

`yt_resolve_yt_dir` sets `YT_SCOPE` in the calling shell only when invoked directly; `YT_DIR=$(yt_resolve_yt_dir)` lost it (`set -u` crash). `session-start` now calls it directly. Test-side: `OUT=$(run ...)` lost the exit code (subshell), fixed by writing stdout to a file; the `task-created` corpus is slice plans + roadmap (not task plans), the fixture was adjusted rather than the hook. Draft stubs for T04/T05 were created in this repo by the still-active cached 0.1.6 hook and were overwritten by the real summaries.

## Follow-ups

- Library hygiene (S02-T01 or S03-T03 KNOWLEDGE): functions that set globals must be called directly, not inside `$(...)`; document the `>/dev/null` idiom.
- Consumers see the new session-start lines only after `/plugin update`.

## Verification

Command: `bash -n` on the five hooks && `/bin/bash tests/hooks-readonly.test.sh` -- passed (37/37). All suites: git-ctx 46/46, pre-compact 39/39, session-end 32/32, post-tool-use-bash 19/19. Live run of `session-start` against this repo renders the state block with manual-handoff line; stderr empty.

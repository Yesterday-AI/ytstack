---
milestone: M018
slice: S02
project: ytstack
created: 2026-11-07T16:00:00Z
status: planned
task_count: 4
completed_tasks: 3
---

# M018-S02 -- Slice Plan

**Goal:** The STATE pointer cannot drift silently, leftovers get reconciled with consent, and an always-on minimal-code guard shapes every implementation.

## Tasks

- [x] T01 -- `yt_state_lint <yt_dir>` in the lib: sets `YT_STATE_WARNINGS` (newline-separated) for: pointer older than newest `M###-CONTEXT.md`; `active_task` whose SUMMARY exists; `last_updated` older than the newest commit touching `.ytstack`; malformed frontmatter values; `active_slice`/`active_task` set while `current_milestone` is `none`; tests.
- [ ] T02 -- `session-start` injects `STATE lint: <warnings>` (max 5 lines) when any; `resume-session` echoes them; `summarize-task`/`plan-task` run the lint and refuse to advance on a malformed pointer (clear message); hooks-readonly suite case.
- [x] T03 -- `skills/reconcile/SKILL.md`: preamble lists the five leftover classes with counts; procedure = one AskUserQuestion per non-empty class (close via summarize / archive to `.ytstack/archive/<date>/` / keep), never delete, writes a `RECONCILE-<date>.md` log; `using-ytstack` gains "artifacts in `.ytstack/` are user-owned: never delete, move or revert them without this skill's consent flow"; preamble suite case with a fixture holding each class.
- [x] T04 -- `skills/minimal-code/SKILL.md` (`kind: directive`, under 60 lines, own prose; concept credit to ponytail in NOTICE) + `session-start` injects a 6-line pointer ("minimal-code guard on: ladder + never-cut list, read `ytstack:minimal-code` before writing code") when `minimal_code: on`; `test-driven-development` wrapper's Namespace note references it; injection stays under the 10k cap (measured in the hooks-readonly suite).

## Done when

All tasks `[x]`; `tests/run-all.sh` green; fixture with a drifted pointer produces the lint line in `session-start` output.

## Notes

- Starts after the M010 worktree branch is merged (both touch `session-start`, `using-ytstack`).

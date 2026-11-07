---
milestone: M019
slice: S04
task: T02
project: ytstack
closed: 2026-11-07T20:20:00Z
verification: passed
---

# M019-S04-T02 -- Summary

## Commits

- (see `git log --grep '^M019-S04-T02'`) -- advisory Stop hook, hooks.json entry, tests/hooks-stop.test.sh, hooks-json nine events

## Outcome

`hooks/stop` reads the Stop payload, returns silently when `stop_hook_active` is true, when there is no `.ytstack`, when the active task is `none`, or when a non-draft summary exists; otherwise it prints `{"systemMessage": "..."}` naming the task and `ytstack:summarize-task` (exit 0, never blocks). `hooks/hooks.json` has the Stop entry; `tests/hooks-stop.test.sh` (13 cases) and `tests/hooks-json.test.sh` (nine events) cover it. Landed before the slice was opened, as the M019 context allowed.

## Deviations from plan

None.

## Follow-ups

- None.

## Verification

Command: `/bin/bash tests/hooks-stop.test.sh && /bin/bash tests/hooks-json.test.sh && bin/ytstack-check` -- passed.

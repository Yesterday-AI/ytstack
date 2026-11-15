---
milestone: M022
slice: S03
task: T01
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed
---

# M022-S03-T01 -- Summary

## Commits

- The commit that carries this file (`M022-S03-T01: STATE lint reports size and history (W8, W9)`).

## Outcome

`yt_state_lint` gained two findings. W8 fired when `STATE.md` was larger than `YT_STATE_MAX_BYTES` (12,000 bytes, set beside the function). W9 counted the status paragraphs beside the current one: lines starting with `**Previous` or `**Prior`, and every `**Status` line after the first. Both name `ytstack:reconcile` and stop no skill. The frontmatter checks W1 to W7 were not touched.

`tests/git-ctx.test.sh` gained three cases: one status paragraph and a next action give no warning, two earlier paragraphs are counted, and a file with 260 ledger rows is reported as oversize.

Run on ytstack's own `.ytstack/`, the lint printed both findings: 29,253 bytes and 13 earlier status paragraphs.

## Deviations from plan

- The slice was planned to wait for M020 (Kimi adapter). It was built before M020 on the operator's instruction of 13 November 2026 (`M022-CONTEXT.md`, "Reassessment 2026-11-13").

## Follow-ups

- ytstack's own `STATE.md` was not trimmed. The lint reports W8 and W9 for it until the operator answers the history question of `ytstack:reconcile`.
- W9 recognises three paragraph openers (`**Previous`, `**Prior`, a second `**Status`). History written under another heading is caught by W8 only when it makes the file large.

## Spec

- hooks-and-state: `.ytstack/spec/hooks-and-state.md` -- Behavior ("STATE lint and progress block": the rows W8 and W9 and the sentence under the table)
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("STATE.md is a pointer; host facts are not stored")

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/git-ctx.test.sh` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). Last line `153 passed, 0 failed`, exit 0.

Not checked: the lint on a consumer project's `STATE.md`. The suite was not run on its own in the Linux container for this record; the lead ran all 20 suites there from an export of the tree (alpine, bash 5.3.9, BusyBox awk): `ALL SUITES PASSED`.

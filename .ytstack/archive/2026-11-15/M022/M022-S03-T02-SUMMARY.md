---
milestone: M022
slice: S03
task: T02
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed
---

# M022-S03-T02 -- Summary

## Commits

- The commit that carries this file (`M022-S03-T02: injection keeps a cut Next action; reconcile offers the STATE history and closed milestones`).

## Outcome

`hooks/session-start` no longer dropped the "Next action" excerpt when the injection was above the guard. It cut the excerpt to what fitted and marked the cut with `... (cut: rest in STATE.md)`; below 200 remaining characters it printed the one-line note as before. `tests/hooks-readonly.test.sh` gained four cases on a `STATE.md` with five lines of about 600 characters under "Next action": the start is kept, the cut is marked, the excerpt is not dropped, and the injection fits the guard.

`skills/reconcile/SKILL.md` (version 0.2.0) gained two classes. `STATE_HISTORY` is `yes` when the file holds earlier status paragraphs or is above the bound; answer A moves the paragraphs verbatim to `.ytstack/archive/<date>/STATE-history.md` and leaves the frontmatter, the current status, "Next action" and "Open decisions". `CLOSED_MILESTONES` lists milestones with a `done` roadmap and slice or task files, only in a project with a technical spec; answer A archives those files and keeps `CONTEXT` and `ROADMAP`. `tests/skill-preambles.test.sh` gained four `reconcile` assertions for the two preamble lines.

## Deviations from plan

- The closed-milestones class belongs to T03 by its task line. It is in this task's commit because both classes live in `skills/reconcile/SKILL.md`.
- The reworded sentence under the lint block was not in the task line. It follows from T01: with W8 and W9 the old sentence ("Fix STATE.md ... before planning") would have called a prompt a blocker.

## Follow-ups

- ytstack's own `STATE.md` (29,253 bytes, 13 earlier status paragraphs) was not trimmed. That is the operator's answer to the history question of `ytstack:reconcile`.
- A table or ledger that makes `STATE.md` large is not moved by the history class; the skill asks where it should live.

## Spec

- hooks-and-state: `.ytstack/spec/hooks-and-state.md` -- Behavior ("SessionStart injection", the "Cap" rule)
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Ownership and cleanup": the class list and the paragraph on the history class and the closed-milestone class)

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/hooks-readonly.test.sh; /bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `69 passed, 0 failed`; `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: no session ran `reconcile` and answered one of the two new questions, so the move itself (archive file written, `STATE.md` shortened, every line accounted for) was never performed. The suites test the two preamble lines, not Step 3 or Step 4. The cut was not observed in a live session start.

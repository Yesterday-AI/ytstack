---
milestone: M031
slice: S01
task: T03
project: ytstack
closed: 2026-11-15T00:35:00Z
verification: passed
---

# M031-S01-T03 -- Summary

## Commits

- The commit that carries this file (`M031-S01-T03: coordinate rotates in one step while lanes run`).

## Outcome

Step 12 of `coordinate` became one step that waits for nothing: the files brought up to date, `HANDOFF.md` written directly in the format of `handoff-session` without its four questions, with a "Rotation" block (`PR watch session:`, `Background watches:`, `Running workers:` with each worker's address), one line to the user, and from then on the old session acted only as a relay that checked each arriving worker report, set the row to `reported` and appended the report under "Reports after the rotation". Step 3 of the successor ran `ytstack-pr-watch handover --from <session>` (T01), started the listed watches again and left the rows of the listed workers alone until their reports arrived. `docs/ux/coordinator-format.md` gained the section "Rotation" with the block, its lines and the relay rule. The test checked Step 12 and Step 3 for the handover and the block, and every `ytstack-*` command of the whole Procedure (27) for its script and subcommand.

## Deviations from plan

- The `artifacts` area file was changed too: `HANDOFF.md` now has a second writer (the rotating coordinator), and its row and rule said `handoff-session` only.
- The successor reaches a worker at its address only where the host lets another session reach it; the relay is what makes the reports arrive on every host.

## Follow-ups

- `handoff-session` itself does not know the "Rotation" block; a coordinator writes it in that skill's format without invoking it. If `handoff-session` changes its format, Step 12 follows by reference.

## Spec

- skills: the `coordinate` line names the one-step rotation, the handover and the relay
- artifacts: the `HANDOFF.md` row and rule name the rotating coordinator

## Verification

Command: `bash tests/skill-preambles.test.sh && bin/ytstack-check && bash bin/ytstack-spec lint` -- the suite exit 0, last line `596 passed, 0 failed` (8 new cases red before the skill change); the checker `OK (with 9 warning[s])`, no `[fail]`; lint `6 area file(s), 0 failure(s), 0 warning(s)`; at the working tree on top of `cbe55d1` in the local checkout (macOS, bash 3.2).

Not checked: a rotation in a live coordinator session with running background workers (whether a host keeps workers alive while their session stays open is the host's behaviour, not tested here).

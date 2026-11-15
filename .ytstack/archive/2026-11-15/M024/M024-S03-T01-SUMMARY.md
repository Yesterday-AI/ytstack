---
milestone: M024
slice: S03
task: T01
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S03-T01 -- Summary

## Commits

- The commit that carries this file (`M024-S03-T01: handover-step, its script template and bin/ytstack-handover`).

## Outcome

`skills/handover-step/SKILL.md`, `skills/handover-step/template.sh`, `bin/ytstack-handover` and `tests/ytstack-handover.test.sh` were written. `new` produced an executable copy of the template with title and time filled and did not overwrite an existing path. `check` passed a well-formed script with its counts of stages, mutations and manual steps, and failed each rule on its own. At run time, without a terminal, `confirm` stopped the script, `mutate` did not run and the receipt named what did not run; a failed `check` stopped the script; a `mutate` without a `confirm` in its stage was refused.

The skill forbids running the script in any form. Its only contact with the file is `ytstack-handover check`.

## Deviations from plan

- `check` is stricter than "every command is a helper call". Outside the helper block it also refuses command substitution, a pipe, a redirection, a chain, a group and a line continuation. Such a command goes inside the helper call as `bash -c '...'`.
- The confirming path of the template (yes runs the change, anything else stops, done and skip are recorded) is tested through the `pty` module of python3, which plays the person at a terminal. Without python3 the suite skips those cases and says so; in this run they ran.
- The template is ytstack's own text. The idea of a staged script comes from a public skill collection; `NOTICE` credits the concept (M024-S04-T04).

## Follow-ups

- The signal path was never executed. The template traps INT, TERM and HUP and writes "interrupted in stage ..." into the receipt; no test sends Ctrl-C or a signal to a running script.
- `check` marks one shortcut in the token rule: a slash ends a run of characters, so a path is never flagged and a base64 secret with a slash every few characters is missed.
- No model has followed `handover-step` end to end, and no person has run a script that it prepared.

## Spec

- skills: `.ytstack/spec/skills.md` -- Behavior ("Skill classes", "Coordinating many lanes")
- checks-and-evals: `.ytstack/spec/checks-and-evals.md` -- Behavior ("The coordinator scripts"), Where implemented
- artifacts: `.ytstack/spec/artifacts.md` -- Behavior ("Files and writers")

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `/bin/bash tests/ytstack-handover.test.sh; /bin/bash tests/skill-preambles.test.sh; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `79 passed, 0 failed`, no skip line; `466 passed, 0 failed`; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: an interrupt of a running script (Ctrl-C, TERM, HUP). A real terminal with a person; the suite uses a pseudo terminal. The procedure of the skill, of which the suite runs only the preamble. Linux: the lead ran all 20 suites in the container (alpine, bash 5.3.9, BusyBox awk), `ALL SUITES PASSED`; whether the pseudo-terminal cases ran or were skipped there is not recorded.

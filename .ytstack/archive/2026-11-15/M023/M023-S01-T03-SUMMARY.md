---
milestone: M023
slice: S01
task: T03
project: ytstack
closed: 2026-11-13T16:30:00Z
verification: passed
---

# M023-S01-T03 -- Summary

## Commits

- The commit that carries this file (`M023-S01-T03: spawn-milestone-team dispatches with the rendered brief`).

## Outcome

`spawn-milestone-team` rendered the brief of every open slice with `bin/ytstack-brief render` instead of filling a prose template, and got a new Step 6 that validates the worker's report with `bin/ytstack-brief check` before the verifier is dispatched. The verifier prompt in Step 7 carries the worker's report, and a verifier after a fix cites the earlier verdict for tasks whose files did not change. The skill has nine steps instead of eight. `agents/implementer.md` reports in the brief's shape and names the contract in the brief as the measure. `agents/architect.md` asks for a concrete case per finding. `codex/adapter.md` and `docs/codex.md` say what a rendered brief is on that host and how a worker is started with it. `docs/ux/agent-structure.md` names the brief's "Git" section as the place of the re-base command.

A dispatched agent wrote the changes; the lead read them against the brief.

## Deviations from plan

- A skill may not name a host: `tests/codex_plugin_test.py` fails on the word in any `SKILL.md`. The `codex exec` command therefore lives in `codex/adapter.md` and `docs/codex.md`, and `spawn-milestone-team` speaks of "the command-line agent of another host".
- `agents/implementer.md` said "No implementation before a failing test exists". It now exempts a trivial change (a rename, a constant, a text, a config value), in line with the contract.

## Follow-ups

- The first live dispatch with a rendered brief is still to come, for a Claude subagent and for `codex exec`. `docs/codex.md` says so in its row ("Not exercised in a live run yet").

## Spec

skills: `.ytstack/spec/skills.md` -- Behavior ("The work contract", Dispatch), Interfaces and contracts. Uncommitted at the time of the check.
host-adapters: `docs/codex.md` -- "Supported behavior", row "A Codex worker under an orchestrator on another host". This is the source the area names. `.ytstack/spec/host-adapters.md` itself has no sentence about a rendered brief; its line on `codex/adapter.md` still holds.

`docs/ux/agent-structure.md` is a source of the `skills` area; the changed phrase there names a section of the brief and alters no rule.

## Verification

Command: `python3 bin/ytstack-check; python3 -m unittest discover -s tests -p 'codex*_test.py'` -- passed at the working tree on top of `f4f54ab` in the local checkout. The checker printed `OK (with 27 warning[s])`, no `[fail]` line, exit 2. The Python tests printed `Ran 13 tests` and `OK`. `bash bin/ytstack-brief render --task M021-S02-T02 | grep -c "Work contract"` printed 2.

Not checked: no real dispatch was made with a rendered brief (no Agent call, no `codex exec` run). Steps 5 to 7 are skill text and no eval case names `spawn-milestone-team`, so the report going back once and the cited verdict were not exercised. What an agent does with the rules is shown only by the eval run that S03-T03 records. `tests/run-all.sh --linux` was not run.

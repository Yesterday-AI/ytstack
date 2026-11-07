---
milestone: M017
slice: S02
task: T04
project: ytstack
closed: 2026-11-07T13:16:32Z
verification: passed_with_caveats
---

# M017-S02-T04 -- Summary

## Commits

- `e4ac112` -- M017-S02-T04: plan live validation against a real gstack install
- `4bf63c0` -- M017-S02-T04: opt-in live validation suite against a real gstack install; installed-layout facts recorded

## Outcome

A real gstack v1.96.0.0 checkout (`git clone --depth 1 --branch v1.96.0.0`) in a temporary HOME confirmed the install contract: `VERSION` 1.96.0.0, the three wrapped skills are skeletons (`office-hours` 43.9 KB + 12 sections, `plan-ceo-review` 60.6 KB + 6, `plan-eng-review` 41.4 KB + 6) with bare `name:` values, each telling the agent to run `~/.claude/skills/gstack/bin/gstack-skill-start --skill "<name>" --model ...` from the absolute install path; `engines.bun >= 1.4.2`. `tests/gstack-live.test.sh` (opt-in via `GSTACK_HOME`, skip line otherwise so `run-all.sh` stays green) asserts version >= pin, layout, `yt_gstack_ctx` flags and the three wrapper preambles against the install: 21/21. KNOWLEDGE records the layout facts; CONTEXT's open questions are resolved (Skill-tool target = bare name; `./setup` is an operator step).

## Deviations from plan

`./setup --no-browser` was not executed: running a freshly downloaded third-party installer was blocked by the session's safety classifier, and I did not route around it. Everything that does not require executing gstack code was validated. Caveat for the operator: run the install one-liner once and `/skills` to see `office-hours` (gstack) next to `ytstack:office-hours`.

## Follow-ups

- T05 closes the milestone and the release.

## Verification

Command: `GSTACK_HOME=<temp clone> /bin/bash tests/gstack-live.test.sh && /bin/bash tests/gstack-live.test.sh` -- passed (21/21; then "skipped" with exit 0).

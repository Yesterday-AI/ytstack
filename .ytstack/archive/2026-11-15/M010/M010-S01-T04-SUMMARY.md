---
milestone: M010
slice: S01
task: T04
project: ytstack
closed: 2026-11-07T13:40:00Z
verification: passed
---

# M010-S01-T04 -- Summary

## Commits

- `52ebe23` -- M010: session-start + using-ytstack flag an existing codebase without .ytstack/

## Outcome

`hooks/session-start` runs `yt_brownfield_signals` in the greenfield branch; at >= 2 signals the state block says "existing codebase (N brownfield signals: sources)" and routes build-intent to `ytstack:adopt-brownfield`, explicitly not office-hours or init-project; empty repos keep the office-hours-first list plus a one-line pointer. Injection measured at 6595 chars (cap 10,000; test guard < 9500). `using-ytstack` lists the skill and the routing rule. `tests/hooks-readonly.test.sh` covers both variants and read-only behaviour.

## Deviations from plan

None.

## Verification

Command: `/bin/bash tests/hooks-readonly.test.sh` -- passed (47/47).

---
milestone: M017
slice: S02
task: T01
project: ytstack
closed: 2026-11-07T13:01:56Z
verification: passed
---

# M017-S02-T01 -- Summary

## Commits

- `24c0cf8` -- M017-S02-T01: plan yt_gstack_ctx
- `1aaf5de` -- M017-S02-T01: yt_gstack_ctx / yt_vergte / yt_gstack_skill_ok in git-ctx.sh (installed gstack detection, pin v1.96.0.0, bun >= 1.4.2)

## Outcome

`hooks/lib/git-ctx.sh` knows about gstack as an installed dependency: `YT_GSTACK_PIN="1.96.0.0"` (latest stable tag on 2026-11-05), `YT_BUN_MIN="1.4.2"`, `yt_vergte` (dotted-numeric compare, bash 3.2), `yt_gstack_skill_ok <name>`, and `yt_gstack_ctx` which sets `YT_GSTACK_DIR` (`${GSTACK_HOME:-$HOME/.claude/skills/gstack}`), `YT_GSTACK_AVAILABLE` (VERSION + the three wrapped SKILL.md present), `YT_GSTACK_VERSION`, `YT_GSTACK_PIN_OK`, `YT_BUN`/`YT_BUN_VERSION`/`YT_BUN_OK` and the ready-to-paste `YT_GSTACK_INSTALL_CMD` (`git clone --branch v1.96.0.0 ... && ./setup --no-browser`). 20 new cases in `tests/git-ctx.test.sh` (85 total): empty HOME, fake install, older version, `GSTACK_HOME` override, version-compare table, bun detection.

## Deviations from plan

The bun detection case cannot run under a foreign `HOME`: bun here is an asdf shim (`~/.local/bin/bun -> ~/.asdf/shims/bun`) that exits 126 without the real HOME; the test keeps HOME and overrides only `GSTACK_HOME`. Worth a KNOWLEDGE line (S02-T05): version-manager shims need the real HOME, and the gstack wrappers inherit the shim latency noted in M016.

## Follow-ups

- T02 wires the context into the three wrappers.

## Verification

Command: `/bin/bash tests/git-ctx.test.sh && bash -n hooks/lib/git-ctx.sh` -- passed (85/85).

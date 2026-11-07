---
milestone: M016
slice: S01
task: T06
project: ytstack
closed: 2026-11-07T11:57:22Z
verification: passed
---

# M016-S01-T06 -- Summary

## Commits

- `1794867` -- M016-S01-T06: plan hooks.json schema update; record fail-open + md5-key deviations
- `4d5503c` -- M016-S01-T06: hooks.json on current schema (fork matcher, shell bash, realistic SessionEnd timeout, fail-open)

## Outcome

`hooks/hooks.json` fires `SessionStart` on `startup|resume|clear|compact|fork`, declares `"shell": "bash"` on all eight command handlers, keeps every handler synchronous, sets the `SessionEnd` timeout to 2 s (hook runs in 0.3-0.5 s against a 1.5 s default budget) and carries a `description` that states the cwd-resolution and fail-open contract. No `onFailure: "block"` anywhere (deviation recorded in CONTEXT: advisory hooks must not block on crash, issue #19). `tests/hooks-json.test.sh` (45 cases) checks the event set, matchers, shell, command targets (exist, `bash -n` clean, under `hooks/`), fail-open, timeouts, and runs `claude plugin validate .` when the CLI is present (passes, v2.1.319).

## Deviations from plan

`onFailure: "block"` dropped entirely (see above). `claude plugin validate` reports a stale `.claude-plugin/marketplace.json` entry version (0.1.5 vs plugin.json 0.1.6; plugin.json wins at install time) and a missing listing icon; the version drift is fixed in the S03-T03 release bump (both files to 0.2.0), the icon stays a follow-up. `.DS_Store` warnings concern untracked files only.

## Follow-ups

- S03-T03: bump `marketplace.json` `plugins[0].version` together with `plugin.json`; add a `ytstack-check` rule that the two agree.
- Optional: plugin listing icon (`.claude-plugin/icon.png`, 512-2048 px square) before any directory submission.
- S01 complete: all eight hooks resolve from payload `cwd`, write volatile state out of tree, and are covered by 218 test cases across six suites.

## Verification

Command: `/bin/bash tests/hooks-json.test.sh` -- passed (45/45). All suites green: git-ctx 46, pre-compact 39, session-end 32, post-tool-use-bash 19, hooks-readonly 37, hooks-json 45. `claude plugin validate .` passes with warnings (version drift, icon, .DS_Store). `bin/ytstack-check` unchanged (0 fails).

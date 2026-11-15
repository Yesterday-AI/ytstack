---
milestone: M020
slice: S02
task: T02
project: ytstack
closed: 2026-11-14T11:35:24Z
verification: passed
---

# M020-S02-T02 -- Summary

## Commits

No commits found for this task: no subject matched `^M020-S02-T02:` and the current branch has no commits past its base. The work is intentionally uncommitted because no commit was requested.

## Outcome

`bin/ytstack-kimi` now runs shared skill blocks with the installed-root/target-project environment and delegates five native lifecycle hooks. SessionStart/PostCompact atomically prepare plain pending context out of tree; UserPromptSubmit consumes it at most once, including parallel calls. PreCompact writes the existing handoff without returning ignored guidance, and SessionEnd writes the existing journal.

The native manifest registers startup/resume, manual/auto compaction, UserPromptSubmit and exit/archive with quoted `${KIMI_PLUGIN_ROOT}` commands. The adapter documents the helper, pending lifecycle, exact gstack `path` selection when supported and the older bare-name stop rule. CI runs the lifecycle suite.

The executable suite covers installed/target paths, prepare/consume, no-pending silence, PostCompact rearm, parallel consume-once, handoff, journal and hook registration. Minimal-code review: one Bash helper around existing scripts and stdlib tests; no dependency, copied skill tree or shared-library rewrite.

## Deviations from plan

Test fixtures initially used lowercase event names, omitting Kimi's `source`/`trigger`; they were corrected to the real CamelCase payloads. Another assertion expected the adapter before the directive wrapper, while the existing shared hook places it inside that wrapper. Both were test corrections, not production behavior changes.

## Follow-ups

- T03 must prove actual Kimi delivery of all five events, real close, replay/compaction and the supported version matrix.
- Exact gstack `path` behavior still needs a host that exposes that schema; the 2.5.3 tests cover the fallback.
- Real upstream gstack procedures remain outside the fixture-based identity proof.

## Verification

Command: `python3 -m unittest discover -s tests -p 'kimi_lifecycle_test.py' -v && python3 -m unittest discover -s tests -p 'kimi_plugin_test.py' -v && python3 -m unittest discover -s tests -p 'codex_plugin_test.py' -v && /bin/bash tests/hooks-readonly.test.sh` -- passed. Fresh result: 9/9 lifecycle, 2/2 Kimi packaging, 13/13 Codex and 63/63 read-only checks. All 12 shell suites also passed; `gstack-live` skipped without a real installation.

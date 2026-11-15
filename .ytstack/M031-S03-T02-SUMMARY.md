---
milestone: M031
slice: S03
task: T02
project: ytstack
closed: 2026-11-15T10:10:00Z
verification: passed
---

# M031-S03-T02 -- Summary

## Commits

- The commit that carries this file (`M031-S03-T02: tell a session once when the installed plugin is newer`).

## Outcome

`hooks/version-notice` runs first on UserPromptSubmit (Claude Code, 5 s). The first prompt of a session records the version of its plugin root under `<state base>/sessions/<session id>/plugin-version`; every prompt compares it with the installed version and, when that is newer, says once per installed version "ytstack X installed, this session loaded A: reload the skills you use" plus one line with the CHANGELOG entry titles in between, cut at 600 characters with a pointer to the file. Against the real installation on this machine (0.10.0) with a recorded 0.9.2 it printed the two 0.10.0 titles; with equal versions it stayed silent. One prompt costs about 60 ms.

The suite covers: first prompt silent and recorded; the update said once, also after the hook root moves to the new version; a new session silent; a stale root on the first prompt said at once; the cache-sibling fallback and `.orphaned_at`; no session id, a session id with a slash; the bound with 21 versions in between; plain output.

## Deviations from plan

- None.

## Follow-ups

- Codex and Kimi do not register the hook: Codex has no UserPromptSubmit entry in `codex/hooks.json` (it needs hook trust), and Kimi's installed-version source is unknown. Their sessions see no version notice.
- With several ytstack entries in `installed_plugins.json` (user and project scope) the highest version counts, also when that install belongs to another project.

## Spec

- hooks-and-state: updated in M031-S03-T03.

## Verification

Command: `bash tests/session-notices.test.sh && bash tests/hooks-json.test.sh` -- passed in the local checkout (macOS, bash 3.2): `53 passed, 0 failed`, `76 passed, 0 failed`.

Not checked: a live Claude Code session through a real plugin update.

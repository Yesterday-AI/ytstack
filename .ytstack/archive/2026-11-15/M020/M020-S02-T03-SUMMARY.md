---
milestone: M020
slice: S02
task: T03
project: ytstack
closed: 2026-11-14T12:59:07Z
verification: passed
---

# M020-S02-T03 -- Summary

## Commits

No commits found for this task: no subject matched `^M020-S02-T03:` and the current branch has no commits past its base. The work is intentionally uncommitted because no commit was requested.

## Outcome

`tests/kimi_live_test.py` now proves native installation, five registered hooks and the complete pending lifecycle with real Kimi processes and controlled local model requests. SessionStart prepares context, UserPromptSubmit injects it once, manual compaction writes the out-of-tree handoff and PostCompact rearms context. A persisted session resumes through the CLI and an automated pseudo-terminal accepts the temporary trust prompt and closes with the implemented Ctrl+C-twice path, producing SessionEnd `exit`.

The same seven-test live suite passes on local Kimi 2.5.3 and on official Kimi 2.6.2 in a fresh Node 24 Linux container. The local 2.6.2 npm binary failed operational commands with exit 126 and no diagnostics, so the passing platform is Linux explicitly, not a claim about that macOS npm install.

The override test now accepts version-specific catalogs. Exact gstack `path` selection is used only when the original is an active variant; if a project override hides it, the host must reject the path as not found. `kimi/adapter.md` now states this boundary instead of promising unconditional precedence bypass.

## Deviations from plan

The test harness needed explicit model binding on 2.5.3, a longer startup budget and captured request diagnostics. Real close required the interactive Ctrl+C path: headless `-p` exit and web shutdown/archive probes produced no handler call on 2.5.3, consistent with upstream #4380's headless gap. The current-stable run moved to Linux after the local npm startup failure. The adapter's exact-path wording was corrected after the 2.6.2 not-found result.

## Follow-ups

- Document the interactive close requirement and headless/archive limitations in `docs/kimi.md` and link #4380.
- Keep the 2.6.2 result scoped to Linux; rerun on macOS when a working binary is available.
- No external model was used; semantic auto-selection still needs a separately authorized real-model smoke test.
- The gstack identity fixture is not execution of upstream gstack procedures.

## Verification

Command 1: `python3 -m unittest discover -s tests -p 'kimi_live_test.py' -v && python3 -m unittest discover -s tests -p 'kimi_lifecycle_test.py' -v` -- passed, 7/7 live and 9/9 helper/lifecycle tests on 2.5.3.

Command 2: `docker run --rm -v "$PWD":/w:ro -w /w node:24-bookworm bash -c 'set -e; apt-get update -qq && apt-get install -y -qq python3 git jq >/dev/null; npm install --prefix /tmp/kimi-2.6.2 --no-audit --no-fund @moonshot-ai/kimi-code@2.6.2 >/dev/null; KIMI_BIN=/tmp/kimi-2.6.2/node_modules/.bin/kimi PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p "kimi_live_test.py" -v'` -- passed, 7/7 live tests on Kimi 2.6.2 in Linux. No test was skipped in either run.

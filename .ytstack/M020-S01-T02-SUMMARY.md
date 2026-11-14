---
milestone: M020
slice: S01
task: T02
project: ytstack
closed: 2026-11-14T10:43:23Z
verification: passed
---

# M020-S01-T02 -- Summary

## Commits

No commits found for this task: no subject matched `^M020-S01-T02:` and the current branch has no commits past its base. All T02 work is intentionally uncommitted because no commit was requested. Unrelated Antigravity work in `git status` remains untouched.

## Outcome

`tests/kimi_live_test.py` performs native Kimi installation, session creation, skill discovery and `<name>:activate` calls against fresh temporary directories. A loopback-only OpenAI fixture returns fixed responses; no external model, real credential, whole-checkout copy or persistent user configuration is used. On Kimi 2.5.3 the suite verified all 31 source skills under `ytstack:<name>`, six independent bare gstack fixtures, and the `ytstack:ship` -> bare `ship` original-resolution chain without wrapper recursion.

A project override fixture proved that Kimi returns and activates the project winner instead of extra-scope gstack. The adapter's path-mismatch stop condition is therefore observable, but direct REST activation deliberately does not claim to follow adapter prose. Cleanup checks found no leftover Kimi server or live-test temp directory.

Three shared skills now survive Kimi positional-placeholder expansion: verification-before-completion avoids literal `$0`, reconcile uses `${1}`, and spawn-milestone-team uses awk `$ 1` / `$ 2`. Each fix has an executable host-activated regression test. KNOWLEDGE.md records the general gotcha. Minimal-code review: reused Kimi's real API, existing shared source and Python stdlib; added no dependency or production abstraction.

## Deviations from plan

The task was initially verification-only. Live activation exposed the `$0` defect and a sweep found `$1` / `$2` defects, so the plan expanded to three one-line shared-skill fixes plus KNOWLEDGE.md. The override fixture initially expected two catalog variants; instrumentation proved Kimi 2.5.3 returns only the project winner. Adding `.git` alone did not change that, so the test now asserts the winning path and activated override content.

## Follow-ups

- S02 owns native lifecycle hooks, the Kimi helper and plain SessionStart output.
- The same-name override stop is an agent instruction, not server-side enforcement. The negative test proves the mismatch and actual override selection, not autonomous agent compliance.
- The gstack tests prove identity with controlled original fixtures, not upstream gstack procedure execution. The optional `gstack-live` shell suite still skips without a real `GSTACK_HOME`.
- The Kimi live suite requires a local `kimi` binary and skips clearly otherwise; no CI installation was added.

## Verification

Command: `python3 -m unittest discover -s tests -p 'kimi_live_test.py' -v && python3 -m unittest discover -s tests -p 'kimi_plugin_test.py' -v` -- passed. Fresh result: 6/6 live tests and 2/2 packaging tests. Codex/Claude packaging: 13/13. All 12 shell suites passed; skill-preambles alone reported 386/386. `bin/ytstack-check` had 0 failures and the same 27 baseline warnings (exit 2). `git diff --check` passed.

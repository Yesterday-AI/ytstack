---
milestone: M033
slice: S01
task: T01
project: ytstack
closed: 2026-11-15T00:55:00Z
verification: passed
---

# M033-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M033-S01-T01: upstream_feedback setting and bin/ytstack-upstream`).

## Outcome

`yt_prefs` read `upstream_feedback` through the new `yt_upstream_feedback`: `PREFERENCES.md` first, then the last `upstream_feedback=` line of `~/.ytstack/config`, then `suggest`; it set `YT_PREF_UPSTREAM_FEEDBACK` and `YT_PREF_UPSTREAM_FEEDBACK_FROM` (`preferences`, `config`, `default`), and a value outside `suggest | file | off` read as `suggest` with a line in `YT_PREF_WARNINGS`. `bin/ytstack-upstream mode` printed the effective mode, the setting with its source, `gh:` and the repository; it asked `gh auth status` only for `file`, and `file` without a login printed `mode: suggest` with a note. `draft` wrote an issue body (kind, three sections with `TODO:` lines, a footer with the ytstack version from `.claude-plugin/plugin.json`, the host and the OS, a `Searched:` line) under `$TMPDIR` or `--out`, refused an existing file, an unknown kind and a missing title, and never called `gh`. `check` failed on a `TODO:` left, an empty "Evidence", a missing or unfilled `Searched:` line, an email address other than a `noreply` one, a token-looking string (the rule of `bin/ytstack-handover`) and a home directory path, and passed `~/` and `/Users/Shared/`.

## Deviations from plan

- none

## Follow-ups

- A full 40-character commit hash in the evidence trips the token rule (32 or more hex digits). The message says to write commits short; if that turns out to be a nuisance in real reports, the rule can skip a run of exactly 40 hex digits.

## Spec

- skills, checks-and-evals: written in T04

## Verification

Command: `bash tests/ytstack-upstream.test.sh && bash tests/git-ctx.test.sh` -- exit 0, last lines `66 passed, 0 failed` and `153 passed, 0 failed`, at the working tree on top of `054e6e0` in the local checkout (macOS, bash 3.2). Red first: the nine new `git-ctx` cases failed against the library of `054e6e0` (`144 passed, 9 failed`), and the new suite failed on the missing script (`0 passed, 1 failed`).

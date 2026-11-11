---
milestone: M021
slice: S01
task: T02
project: ytstack
closed: 2026-11-11T11:15:00Z
verification: passed
---

# M021-S01-T02 -- Summary

## Commits

- `967d90d` M021-S01-T02: add bin/ytstack-status, the status line segment for a ytstack project

## Outcome

`bin/ytstack-status` reads `cwd` from the status line JSON (else `$PWD`), resolves the ytstack project and prints one line: with a `progress` block `V2 76% 138/180 · M021/S01/T02 · waiting: …`, without it the pointer plus the active slice's checkbox count (`M021/S01/T02 1/2`). On a branch other than the default one the block is read with `git show` from the newer of `origin/<default>` and `<default>`; the pointer stays local. It prints nothing and exits 1 outside a project, for a malformed block, and when there is neither block nor pointer. `NO_COLOR` and `--no-color` switch the colour off.

## Deviations from plan

none

## Follow-ups

- `shortcut:` in `bin/ytstack-status`: `waiting_on` is cut by characters of the current locale; under `LC_ALL=C` a multi-byte character at the cut can be split.
- One run takes about 90 ms on this machine (ten runs 0.92 s), most of it the git calls in `yt_git_ctx`. Fine for a status line that is debounced at 300 ms; a cache is the lever if it ever matters.

## Verification

Command: `bash tests/ytstack-status.test.sh` -- passed (31 passed, 0 failed; same under `/bin/bash` 3.2). Live: this worktree printed `M021/S01/T02 1/2`, `/tmp` printed nothing with exit 1.

Minimal-code review: rung 2 for input and resolution (`yt_read_stdin`, `yt_git_ctx`, `yt_resolve_yt_dir`, `yt_find_artifacts` reused), rung 6 for the rest. Left out on purpose: reading `workspace.current_dir` (Claude Code documents it as equal to `cwd`), symlink resolution of the script path, a cache.

---
milestone: M016
slice: S01
task: T01
project: ytstack
closed: 2026-11-07T11:26:14Z
verification: passed_with_caveats
---

# M016-S01-T01 -- Summary

## Commits

- `1726b9b` -- M016-S01-T01: plan hooks/lib/git-ctx.sh + unit test
- `66f6e89` -- M016-S01-T01: add hooks/lib/git-ctx.sh shared context library + unit test

## Outcome

`hooks/lib/git-ctx.sh` is the shared, sourceable bash-3.2 library for hooks and skill preambles. `yt_read_stdin` captures the hook payload once and parses `cwd`, `session_id`, `hook_event_name`, `tool_input.command` and the exit code via `jq` (single call, `@sh`-quoted assignments) or `python3 -I` when `jq` is absent; a `cwd` that is not a directory is dropped. `yt_git_ctx` resolves the directory the agent actually works in: `YT_IS_GIT` via `git rev-parse --is-inside-work-tree`, canonical `YT_TOPLEVEL`, `YT_GIT_DIR` and `YT_COMMON_DIR` (`--path-format=absolute` with `--absolute-git-dir` / relative fallback), `YT_IS_LINKED` when the two differ, `YT_MAIN_TOPLEVEL`, and 16-hex-char sha256 keys `YT_REPO_KEY` (common dir, shared by all worktrees) and `YT_WT_KEY` (toplevel). `yt_state_dir` creates `<base>/repos/<repo>/worktrees/<wt>/sessions/<session_id>/` with base order `CLAUDE_PLUGIN_DATA`, `PLUGIN_DATA`, `$XDG_STATE_HOME/ytstack`, `~/.local/state/ytstack`, falling back to `<toplevel>/.ytstack/.local` (only when `.ytstack` exists) or a tmp dir. `yt_resolve_yt_dir` finds the project `.ytstack` or a user-scope dir keyed by `YT_REPO_KEY`; no basename anywhere.

## Deviations from plan

Test case 8 ("`bash --posix`-free run") is covered by running the whole suite under `/bin/bash` 3.2 rather than a separate case. One test line had to move into a helper function because bash 3.2 cannot parse `case ... )` inside `$(...)`. Nothing else differed.

## Follow-ups

- Linux / bash 5 run of `tests/git-ctx.test.sh` is outstanding (no newer bash on this machine); owned by S03-T01.
- The existing `post-tool-use-bash` matcher did not fire on the T01 commit: the RTK hook rewrites `git commit` to `rtk git commit`, so `git` no longer follows a command separator. S01-T04 must allow a leading wrapper token (`rtk`, `sudo`, `env VAR=x`) before `git commit`. Capture as a KNOWLEDGE gotcha in S03-T03.
- User-scope layout moves from `~/.ytstack/projects/<slug>` to `~/.ytstack/projects/<repo-key>` (no existing user-scope projects found locally); README note in S03-T03.

## Verification

Command: `bash -n hooks/lib/git-ctx.sh && /bin/bash tests/git-ctx.test.sh` -- passed (46/46). `bin/ytstack-check` -- exit 2, 0 fails, 109 pre-existing vendor warnings (unchanged). `bash tests/post-tool-use-bash.test.sh` -- 10/10. Caveat: Linux not yet run.

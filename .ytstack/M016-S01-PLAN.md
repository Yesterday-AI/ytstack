---
milestone: M016
slice: S01
project: ytstack
created: 2026-11-07T11:05:00Z
status: planned
task_count: 6
completed_tasks: 4
---

# M016-S01 -- Slice Plan

**Goal:** Every hook resolves its target from the stdin `cwd` through a shared `hooks/lib/git-ctx.sh`, writes volatile state only to the out-of-tree session dir, and leaves `.ytstack/` in any checkout byte-identical; `hooks.json` matches the current Claude Code schema.

## Tasks

- [x] T01 -- Create `hooks/lib/git-ctx.sh` (bash 3.2, no arrays, no `flock`): `yt_read_stdin` (captures payload once; `jq` then `python3` fallback for `cwd`, `session_id`, `tool_input.command`, `tool_response`), `yt_git_ctx <dir>` (sets `YT_TOPLEVEL`, `YT_GIT_DIR`, `YT_COMMON_DIR` via `--path-format=absolute` with `--absolute-git-dir` fallback, canonicalised with `pwd -P`, `YT_IS_LINKED`, `YT_REPO_KEY` = sha256 of common dir via `shasum -a 256`, `YT_WT_KEY` = sha256 of toplevel), `yt_state_dir` (`${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_STATE_HOME:-$HOME/.local/state}/ytstack}}/repos/$YT_REPO_KEY/worktrees/$YT_WT_KEY/sessions/$SESSION_ID`, `mkdir -p`, fallback `$YT_TOPLEVEL/.ytstack/.local/` when the data dir is not writable), `yt_resolve_yt_dir` (project `.ytstack` in `YT_TOPLEVEL`, else user-level keyed by `YT_REPO_KEY`, no basename). Unit test `tests/git-ctx.test.sh`: main checkout, linked worktree (`.git` file), non-git dir, submodule, `/tmp` vs `/private/tmp`.
- [x] T02 -- Rewrite `hooks/pre-compact`: consume stdin, `yt_git_ctx "$cwd"`, write the auto handoff to `$(yt_state_dir)/HANDOFF.auto.md` and refresh the `../latest-handoff` symlink atomically (`ln -sfn` to temp + `mv`); never open `.ytstack/HANDOFF.md` for writing; emit compaction instructions on stdout (position M/S/T, open decisions, next action, path to the auto handoff; under 10,000 chars).
- [x] T03 -- Rewrite `hooks/session-end`: one `printf >>` of a JSON line into `$(yt_state_dir)/session.jsonl` (single writer per session, no `git` subprocess, fits the 1.5 s plugin budget); remove every write to `.ytstack/journal/`; `jq`-free encoding path for the fast case.
- [x] T04 -- Rewrite `hooks/post-tool-use-bash`: resolve from stdin `cwd` (the directory the Bash call ran in), `yt_git_ctx` there, read HEAD subject via `git -C "$YT_TOPLEVEL" log -1 --pretty=%s`, stub the draft SUMMARY only when the subject matches `commit_ref_pattern` from that checkout's `PREFERENCES.md` (default `^M[0-9]{3}-S[0-9]{2}-T[0-9]{2}:`) AND the stub does not exist yet; write it into that checkout's `.ytstack/`, never into `CLAUDE_PROJECT_DIR`. Extend `tests/post-tool-use-bash.test.sh` with: commit in a linked worktree while `CLAUDE_PROJECT_DIR` points at main, commit without task ref (no stub).
- [ ] T05 -- Migrate the read-only hooks to the lib: `session-start` (resolve from `cwd`, append a "latest auto handoff: <path>" line when the symlink resolves, measure total injection against the 10,000-char cap and warn on stderr when exceeded), `pre-tool-use-edit`, `task-created`, `task-completed`, `teammate-idle` (resolve `.ytstack` through `yt_resolve_yt_dir`, no `basename`). Replace `$(cat)` with `yt_read_stdin`; add `trap '' PIPE`.
- [ ] T06 -- Update `hooks/hooks.json`: `SessionStart` matcher `startup|resume|clear|compact|fork`; `"shell": "bash"` on every command hook; `onFailure: "block"` only on `pre-tool-use-edit`; drop the ineffective `"timeout": 5` on `SessionEnd` (document the 1.5 s plugin budget in a comment field via `description`). Validate with `claude plugin validate .` and `bin/ytstack-check`.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`. Slice-level check: run every hook from a linked worktree with a realistic payload while `CLAUDE_PROJECT_DIR` points at the main checkout; `git -C main status --porcelain` is empty before and after.

## Notes

- Platform basis: hook stdin carries `cwd` (follows worktree and `cd`) and `session_id`; `CLAUDE_PROJECT_DIR` is pinned to the session start dir (code.claude.com/docs/en/hooks, /worktrees). Pre-compact currently does not read stdin at all.
- PowerShell hook variants (superpowers pattern) are deferred to M019: no Windows consumer exists and the bash lib is the contract to port from.
- Open question from CONTEXT: if a Claude Code version delivers no `cwd` in the PreCompact payload, fall back to the last `cwd` recorded by `post-tool-use-bash` for the same `session_id` in the state dir; if nothing is recorded, skip the write and log to stderr. Never fall back to `CLAUDE_PROJECT_DIR`.

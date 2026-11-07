---
milestone: M016
project: ytstack
created: 2026-11-07T10:50:03Z
size: M
---

# M016 -- Context

## Goal

No ytstack hook ever writes into a checkout the user did not choose, and no volatile session state (auto handoff, journal, locks) lands in tracked files: a session that runs entirely from a shared main checkout leaves `git status` clean after compaction, session end and commits, while a linked worktree gets correct Git detection and correct commit discovery.

## Exit criteria

- `hooks/lib/git-ctx.sh` exists (bash 3.2, no arrays) and is sourced by every hook and every skill preamble: reads `cwd` + `session_id` from stdin JSON, resolves toplevel / git-dir / common-dir with `--path-format=absolute` (fallback `--absolute-git-dir`), canonicalises paths, sets `YT_IS_LINKED`, derives the repo key as sha256 of the common git dir. No `CLAUDE_PROJECT_DIR` write target and no `basename`-slug remains; `bin/ytstack-check` fails on `[ -d .git ]` and `basename "$(git rev-parse --show-toplevel)"`.
- Auto handoff, journal and locks live under `${CLAUDE_PLUGIN_DATA:-${PLUGIN_DATA:-${XDG_STATE_HOME:-$HOME/.local/state}/ytstack}}/repos/<repo-key>/worktrees/<worktree-key>/sessions/<session_id>/` with a `latest-handoff` symlink; `resume-session` and `session-start` read both locations (out-of-tree first, `.ytstack/HANDOFF.md` as the user-owned manual artifact).
- `pre-compact` never overwrites `.ytstack/HANDOFF.md` and emits compaction instructions (< 10,000 chars) on stdout.
- `post-tool-use-bash` stubs only in the worktree that committed and only when the commit subject matches the task ref (`commit_ref_pattern` from `PREFERENCES.md`, default `^M###-S##-T##:`).
- `session-end` fits the 1.5 s plugin budget (single append, no git calls) or the journal is dropped.
- `hooks/hooks.json`: `SessionStart` matcher includes `fork`; `"shell": "bash"` plus a powershell variant; `onFailure: "block"` only on `pre-tool-use-edit`.
- `summarize-task` and `init-project` detect Git via `git rev-parse --is-inside-work-tree` (repro from #24 passes in a linked worktree); commit discovery falls back to `git log <base>..HEAD` for squash-merge repos; `~/.ytstack/.init-project-<slug>-*` sentinels are replaced by `PROJECT.md` frontmatter.
- `init-project` writes a `.gitignore` block for `.ytstack/.local/` (fallback state dir); `HANDOFF.md` stays committable.
- `tests/` cover: main checkout, linked worktree (`.git` as file), session started in main with commands running in a worktree, two concurrent sessions. Acceptance per #26: main is byte-identical before and after each hook invocation with a realistic payload.
- `plugin.json` 0.1.6 -> 0.2.0, CHANGELOG entry, DECISIONS/KNOWLEDGE updated, issues #24 and #27 closed with evidence (#26 already marked duplicate).

## Size

M -- see `M016-ROADMAP.md` for slice breakdown. Borderline to L; `slice-milestone` may add a fourth slice if the hook rewrite and the skill-preamble work do not fit 1-7 tasks each.

## Decisions locked in discuss phase

- 2026-11-07: design locked in `DECISIONS.md` "Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree" (option C). Platform basis: hook stdin `cwd` follows the worktree, `CLAUDE_PROJECT_DIR` does not (code.claude.com worktrees docs; anthropics/claude-code#84723 closed not-planned 2026-10-05); `CLAUDE_PLUGIN_DATA` is the sanctioned durable plugin state dir.
- 2026-11-07: milestone number M016 assigned in ROADMAP.md although the highest `M###-*.md` on disk is M012 (M013/M014 reserved, M015 shipped without milestone files); the preamble's computed `M013` is overridden.
- 2026-11-07: journal keeps existing only if `resume-session` consumes it ("last N sessions touched M/S/T"); otherwise it is dropped. Audit evidence: 80-100 % `task: none`, no reader.

## Open questions

- Does `pre-compact` receive `cwd` in its stdin payload on all supported Claude Code versions (>= v2.1.159)? Verify against the hooks reference before relying on it; fallback = `session_id` lookup of the last known `cwd` written by `post-tool-use-bash`.
- Codex adapter: Codex hooks carry a Claude-shaped stdin with `cwd` = session cwd and no `CwdChanged`; confirm the state-dir fallback `PLUGIN_DATA` is set there.
- Worktree key: basename of the worktree path vs. sha256 of its absolute path -- readability vs. collision safety. Decide in S01.

## Research basis

`docs/research/2026-11-07-modernisierung-best-practices.md` points 1-3; notes `docs/research/2026-11-07-notes/hook-state-isolation-and-node-cve.md` (git detection recipes, state-dir conventions, lock patterns), `claude-code-platform-changes.md` (hook stdin fields, budgets, hooks.json schema), `local-consumer-repos-audit.md` (field evidence).

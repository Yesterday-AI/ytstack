# Changelog

All notable changes to ytstack are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-11-07

### Fixed

- **Hooks no longer write into a checkout the session did not work in**
  ([#26], [#27]). All eight hooks resolve the checkout from the hook payload's
  `cwd` through the new shared library `hooks/lib/git-ctx.sh`, never from
  `CLAUDE_PROJECT_DIR` (pinned to the session-start directory; it does not
  follow the agent into a linked worktree). A coordinator session started in
  `main` while the work happens in `.worktrees/<x>` leaves `main` byte-for-byte
  unchanged (acceptance: `tests/hooks-worktree.test.sh`).
- **`summarize-task` and `init-project` recognise linked worktrees as Git**
  ([#24]). Detection uses `git rev-parse --is-inside-work-tree` instead of
  `[ -d .git ]` (a linked worktree's `.git` is a file). Same fix in all 15
  skill preambles.
- **`.ytstack/HANDOFF.md` is never overwritten by a hook** ([#27]). The
  pre-compact breadcrumb now lives out of tree; the file is user-owned
  (`handoff-session` writes it on purpose).
- **No more `.ytstack/journal/sessions.jsonl` churn** ([#26]). The session
  journal is written per session out of tree.
- **Draft summary stubs only for this task's commits** ([#26]). The
  `post-tool-use-bash` stub is created in the committing checkout only when
  HEAD's subject matches the task's commit ref; wrapper tokens (`rtk`,
  `sudo`, `env X=1`) before `git commit` are recognised.

### Changed

- **Volatile session state moved out of the repository.** Automatic handoff
  (`HANDOFF.auto.md`) and journal (`session.jsonl`) live under
  `${CLAUDE_PLUGIN_DATA}/repos/<repo-key>/worktrees/<worktree-key>/sessions/<session_id>/`
  with a `latest-handoff` symlink per worktree; fallback `.ytstack/.local/`
  (gitignored by `init-project`). `resume-session` and `session-start` read
  both handoff kinds and say which one they used.
- **`pre-compact` emits compaction instructions** (stdout, exit 0) telling
  Claude Code what to preserve in the summary.
- **`session-end` fits the 1.5 s plugin budget** (one append, no `jq`
  encoder); the library prefers real `jq`/`python3` binaries over
  version-manager shims and uses md5-based keys instead of perl `shasum`
  (hooks went from ~1 s to 0.3-0.5 s).
- **`hooks/hooks.json`** fires `SessionStart` on `fork` too, declares
  `shell: bash` on every handler, keeps every hook fail-open (no
  `onFailure: block`), and uses a realistic `SessionEnd` timeout.
- **Commit discovery is configurable** (`commit_ref_pattern` in
  `PREFERENCES.md`, default `^M###-S##-T##:`, tokens `M###`/`S##`/`T##`/
  `{task}`) with a branch fallback (merge-base with the default branch ..
  HEAD) for squash-merge / conventional-commit repos; `summarize-task` names
  the source of its `## Commits` list and no longer guesses "shipped
  uncommitted".
- **`init-project`** writes a `.gitignore` block for `.ytstack/.local/`,
  records `init_completed` and `scope` in `PROJECT.md` frontmatter, and keys
  the user-scope dir by repo key (`~/.ytstack/projects/<repo-key>`); the
  `~/.ytstack/.init-project-<slug>-*` sentinels are retired (also the
  `plan-milestone` size sentinel hint).
- **`session-start`** reports working tree, ytstack dir, manual and automatic
  handoff pointers and sheds the Next-action excerpt when the injection nears
  the 10,000-character cap.
- **`bin/ytstack-check`** enforces the resolver contract (fails on
  `[ -d .git ]`, basename slugs, `CLAUDE_PROJECT_DIR` in hooks, sentinel
  paths, preambles without the shared lib) and warns when `plugin.json` and
  `marketplace.json` versions disagree; `--tests` runs the suite runner.

### Added

- `hooks/lib/git-ctx.sh` -- shared bash-3.2 library: `yt_read_stdin`,
  `yt_git_ctx`, `yt_resolve_yt_dir`, `yt_state_dir`, `yt_commit_ref_pattern`,
  `yt_task_commits`, `yt_ensure_gitignore`, `yt_jq`, `yt_python`.
- Ten test suites (488 cases) under `tests/` plus `tests/run-all.sh`
  (`--linux` runs them in a bash 5 container); `docs/ux/skill-structure.md`
  documents the resolver contract and the retired sentinel convention.
- README "Where ytstack writes"; `docs/research/2026-11-07-*` (modernisation
  research, vendor drift, peer frameworks, developer-skills landscape, audit
  of 17 consumer repos).

### Notes

- Run `/plugin update` to get 0.2.0 into running sessions; the cached 0.1.6
  hooks keep writing into the tree until then.
- User-scope projects move from `~/.ytstack/projects/<folder-name>` to
  `~/.ytstack/projects/<repo-key>`; no existing user-scope project was found
  in the field, so no migration is shipped.

[#24]: https://github.com/Yesterday-AI/ytstack/issues/24
[#26]: https://github.com/Yesterday-AI/ytstack/issues/26
[#27]: https://github.com/Yesterday-AI/ytstack/issues/27

## [0.1.6] - 2026-05-31

### Fixed

- **`post-tool-use-bash` hook is now stub-once** ([#22]). It previously appended
  a `## Commits so far` line on every command matching the glob `*git*commit*`
  (echoes, `git log | grep commit`, doc strings), with no new-commit check and
  no dedup, and rewrote a tracked file after each commit without staging it. The
  working tree never settled (committing the draft re-fired the hook), and the
  churning `.ytstack` draft was invisible to a worktree branched from `main`,
  breaking `spawn-milestone-team` dispatch. The hook now matches a real
  `git commit` (after a command separator), creates the draft stub once, and
  never re-writes it.

### Changed

- **Commit-to-task linking moved into `summarize-task`** ([#22]). It greps
  `git log` for the `M###-S##-T##:` commit ref into a committed `## Commits`
  section, replacing the throwaway hook draft. See DECISIONS 2026-05-31
  "post-tool-use-bash is stub-once".

### Added

- `tests/post-tool-use-bash.test.sh` -- 10-case regression guard for the hook.

## [0.1.5] - 2026-05-31

### Fixed

- **Swarm Fix-Pack** (M012), resolving four issues found running milestones as
  parallel Agent-Team swarms:
  - `verification-before-completion` crashed for every user: a literal
    triple-backtick inside an executable block truncated the extracted preamble
    ([#20]). Fences are now generated at runtime and matched by prefix.
  - `pre-tool-use-edit` now exits 0 (advisory) instead of hard-blocking, and
    short-circuits on `.ytstack/**` paths ([#19]).
  - `active_slice` / `active_task` writes are guarded for swarm teammates and
    treated as a single source of truth ([#21]).
  - hooks read `session_id` from stdin JSON instead of a non-existent env var
    ([#21]).
  - `reassess-roadmap` gained a backlog sweep ([#16]).

## [0.1.0] - 2026-04-24

### Added

- Initial release: the full ytstack build cycle (M001-M009). Skills for the
  Project-OS lifecycle (`init-project`, `plan-milestone`, `slice-milestone`,
  `plan-task`, `summarize-task`, `reassess-roadmap`, `handoff-session`,
  `resume-session`), curated gstack planning wrappers and superpowers execution
  wrappers, `spawn-milestone-team` for Agent Teams, the `using-ytstack`
  SessionStart directive, eight hooks, three subagent definitions, and the
  `.ytstack/` artifact model (PROJECT / DECISIONS / KNOWLEDGE / STATE /
  milestone-slice-task hierarchy).

[0.1.6]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.1.6
[0.1.5]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.1.5
[0.1.0]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.1.0
[#16]: https://github.com/Yesterday-AI/ytstack/issues/16
[#19]: https://github.com/Yesterday-AI/ytstack/issues/19
[#20]: https://github.com/Yesterday-AI/ytstack/issues/20
[#21]: https://github.com/Yesterday-AI/ytstack/issues/21
[#22]: https://github.com/Yesterday-AI/ytstack/issues/22

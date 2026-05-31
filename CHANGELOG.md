# Changelog

All notable changes to ytstack are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

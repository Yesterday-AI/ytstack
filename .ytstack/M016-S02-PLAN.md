---
milestone: M016
slice: S02
project: ytstack
created: 2026-11-07T11:05:00Z
status: planned
task_count: 5
completed_tasks: 0
---

# M016-S02 -- Slice Plan

**Goal:** Every skill preamble detects Git and resolves the `.ytstack` dir the same way the hooks do (no `[ -d .git ]`, no basename slug, no `~/.ytstack` sentinels), `summarize-task` finds commits in squash-merge and conventional-commit repos, `init-project` ships the gitignore block, and `bin/ytstack-check` enforces the banned patterns.

## Tasks

- [ ] T01 -- Replace the `_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel ...)")` + `~/.ytstack/projects/$_PROJECT_SLUG` resolution in all 15 skill preambles (handoff-session, office-hours, plan-ceo-review, init-project, plan-milestone, reassess-roadmap, plan-eng-review, slice-milestone, resume-session, spawn-milestone-team, systematic-debugging, plan-task, summarize-task, test-driven-development, verification-before-completion) with `source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/git-ctx.sh"; yt_git_ctx "$PWD"; yt_resolve_yt_dir`; replace `_IS_GIT=$([ -d .git ] ...)` in `summarize-task` and `init-project` with `git rev-parse --is-inside-work-tree`. Reproduce #24 before (IS_GIT: no in a linked worktree) and after (yes).
- [ ] T02 -- `summarize-task` commit discovery: read `commit_ref_pattern` from `PREFERENCES.md` (default `^M###-S##-T##:` rendered for the active task); fallback when the grep is empty: `git log --no-merges <merge-base with default branch>..HEAD` on the current branch, labelled "branch commits (no task ref found)"; never claim "shipped uncommitted" when either list is non-empty. Test with a fixture repo using conventional commits.
- [ ] T03 -- `init-project`: write (or extend) `.gitignore` with a marked block `# ytstack local state` / `.ytstack/.local/`; replace the `~/.ytstack/.init-project-<slug>-completed` and `-scope-prompted` sentinels with `init_completed: <ISO>` and `scope: project|user` in `PROJECT.md` frontmatter; keep `HANDOFF.md` committable (not ignored); document in the skill's Procedure.
- [ ] T04 -- `resume-session` and `handoff-session`: `resume-session` reads `latest-handoff` from the state dir first, then `.ytstack/HANDOFF.md`, and says which one it used and how old each is; `handoff-session` keeps writing `.ytstack/HANDOFF.md` with `event: user-triggered` and adds a note that hooks never touch this file. Remove the "(future)" journal hint from `pre-compact` text and point to `session.jsonl` in the state dir.
- [ ] T05 -- `bin/ytstack-check`: new FAIL rules for `skills/**/SKILL.md` and `hooks/*` (vendor excluded): `[ -d .git ]`, `basename "$(git rev-parse --show-toplevel`, `CLAUDE_PROJECT_DIR` used as the target of `>`/`>>`/`cat >`/`mkdir -p` in hooks, `~/.ytstack/.` sentinel paths. Run the checker; 0 fails on the migrated tree; add the rules to `docs/ux/skill-structure.md`.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`. Slice-level check: `bin/ytstack-check` exits 0 or 2 (warnings only) and the #24 repro script prints `IS_GIT: yes` in a linked worktree.

## Notes

- `${CLAUDE_PLUGIN_ROOT}` is substituted inside skill `!`-blocks; the Codex adapter exposes `PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT` for compatibility (research notes, hook-state-isolation). Preambles must tolerate both being empty (fallback: skip the lib, emit `YT_DIR` from `.ytstack` in `$PWD` only).
- User-scope `~/.ytstack/projects/<slug>` layouts already on disk: none found locally (`ls ~/.ytstack/projects` empty), so no migration path is needed; document the keyed layout in README.

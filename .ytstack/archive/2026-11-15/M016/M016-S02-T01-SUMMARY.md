---
milestone: M016
slice: S02
task: T01
project: ytstack
closed: 2026-11-07T12:05:08Z
verification: passed
---

# M016-S02-T01 -- Summary

## Commits

- `e077033` -- M016-S02-T01: plan skill-preamble migration to git-ctx.sh
- `214a70e` -- M016-S02-T01: skill preambles resolve via git-ctx.sh (git rev-parse detection, keyed user scope, no CLAUDE_PROJECT_DIR)

## Outcome

All 15 skill preambles (9 ```bash, 6 ```! wrappers) open with the same resolver block: source `${CLAUDE_SKILL_DIR}/../../hooks/lib/git-ctx.sh`, `yt_git_ctx "$PWD"`, `yt_resolve_yt_dir`, then `_PROJECT_DIR`/`_YT_DIR`/`_YT_SCOPE`/`_IS_GIT`/`_PROJECT_KEY` from the lib; when the host does not substitute `CLAUDE_SKILL_DIR`, a fallback uses `git rev-parse --is-inside-work-tree` / `--show-toplevel` and project scope only. `_PROJECT_SLUG` is display-only (`basename "$_PROJECT_DIR"`). `summarize-task` and `init-project` dropped their `[ -d .git ]` lines (closes the detection half of #24); `init-project` names the user-scope dir `~/.ytstack/projects/<repo-key>` via `_USER_YT_DIR` and its prose says so. `tests/skill-preambles.test.sh` (187 cases) extracts each preamble, substitutes the skill dir, and runs it in a fixture main checkout and a linked worktree: `HAS_YTSTACK: yes` everywhere, `IS_GIT: yes` in the worktree for summarize-task/init-project, no `CLAUDE_PROJECT_DIR` leak, worktree resolves its own `.ytstack`, fallback path works, fixture tree stays clean.

## Deviations from plan

None in scope. The test had the same `OUT=$(run ...)` subshell bug as the hooks test (fixed the same way).

## Follow-ups

- Sentinel lines (`~/.ytstack/.init-project-<slug>-*`) still use the slug: S02-T03.
- `summarize-task` commit discovery: S02-T02.
- KNOWLEDGE: `${CLAUDE_SKILL_DIR}` substitution inside fenced blocks is relied upon; verified only via the test's own substitution, the live substitution shows up on the next `/plugin update`. Add to S03 live check.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh` -- passed (187/187). `bin/ytstack-check` -- 0 fails (109 pre-existing vendor warnings).

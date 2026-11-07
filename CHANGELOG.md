# Changelog

All notable changes to ytstack are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-11-07

### Changed

- **gstack is an installed, tag-pinned dependency instead of a vendored
  subtree.** Upstream (v1.9x) turned its skills into skeletons that load
  `sections/*.md` and run `~/.claude/skills/gstack/bin/gstack-skill-start`
  from the install path, and deprecated vendored installs; a `cat`-inlined
  copy no longer rendered the procedure. `office-hours`, `plan-ceo-review`
  and `plan-eng-review` now run a precheck (`yt_gstack_ctx`: install at
  `${GSTACK_HOME:-~/.claude/skills/gstack}`, `VERSION` >= pin 1.96.0.0,
  bun >= 1.4.2), stop with the one-line install command when gstack is
  missing, and otherwise invoke the installed gstack skill through the Skill
  tool before applying the ytstack post-processing. **New prerequisite** for
  those three skills: `git clone --branch v1.96.0.0
  https://github.com/garrytan/gstack ~/.claude/skills/gstack && (cd
  ~/.claude/skills/gstack && ./setup --no-browser)`. All other skills and
  hooks need neither gstack nor bun. See DECISIONS 2026-11-07 "Vendor
  strategy".
- **superpowers subtree pulled to v7.0.2** (`6fd4507` -> `22f0b46`). The
  three superpowers wrappers gained a `## Namespace note` that maps
  `superpowers:<skill>` to `ytstack:<skill>` and anchors relative links;
  `bin/ytstack-check` fails on unhandled leaks in inlined vendor text.
- `bin/ytstack-check` also enforces the gstack wrapper contract (precheck,
  install command, Skill-tool invocation, no `vendor/gstack`).
- AGENTS.md, NOTICE, README, QUICKSTART, `docs/concept.md`,
  `docs/methodology.md`, `.ytstack/VENDOR-INVENTORY.md` describe the two
  consumption models (vendored superpowers, installed gstack).

### Added

- `hooks/lib/git-ctx.sh`: `yt_gstack_ctx`, `yt_gstack_skill_ok`, `yt_vergte`,
  `YT_GSTACK_PIN`, `YT_BUN_MIN`.
- `tests/gstack-live.test.sh` -- opt-in (`GSTACK_HOME=...`) validation of a
  real gstack install (layout, version, wrapper flags); `tests/run-all.sh`
  prints a skip line without it.
- `SECURITY.md`.

### Removed

- `vendor/gstack/` (641 files, 39 MB). History keeps the `aeea57f` squash.

### Security

- Resolves [#25]: the vendored upstream `Dockerfile.ci` pinning Node
  22.20.0 (CVE-2026-111497) is gone with the subtree. ytstack never built
  it; see `SECURITY.md`.

### Notes

- `/plugin update` to 0.3.0, then install gstack once if you use the three
  planning skills.

[#25]: https://github.com/Yesterday-AI/ytstack/issues/25

## [Unreleased]

### Added

- **Ceremony dials in `PREFERENCES.md`** (M018, DECISIONS 2026-11-07
  "Ceremony scales with the change"): `granularity: task|slice|milestone`,
  `autonomy: loop|step` (loop = chain plan-task -> TDD -> verify ->
  summarize inside a slice without asking), `quick_lane: on|off`,
  `minimal_code: on|off`; read by `yt_prefs`, honoured by plan-task /
  slice-milestone / summarize-task; `init-project` writes the block.
- **`quick-task` skill**: the quick lane for one-sentence changes --
  `Q###-PLAN/SUMMARY` under `.ytstack/quick/`, TDD + verification, no pitch,
  no review, no milestone pointer change; `using-ytstack` routes there.
- **`reconcile` skill**: consent-based cleanup of `.ytstack` leftovers (draft
  stubs, unfilled auto-drafts, planned-never-sliced milestones, untracked
  files, `.local` without gitignore); archives into `.ytstack/archive/<date>/`,
  never deletes. `using-ytstack` now states that `.ytstack` artifacts are
  user-owned.
- **`minimal-code` directive** (six-rung YAGNI ladder, never-cut list,
  `shortcut:` markers; concept credit to ponytail in NOTICE) injected by the
  SessionStart hook when `minimal_code: on`; referenced by the TDD wrapper.
- **STATE pointer lint** (`yt_state_lint`): malformed fields, pointer behind
  the newest milestone, task already summarized, slice while milestone none,
  stale `last_updated`, done-but-current; injected by `session-start`,
  echoed by `resume-session`, enforced (malformed only) by `plan-task` /
  `summarize-task`.
- **Artifact states** `planned | in-progress | done | dropped |
  shipped-informally` (docs/ux/skill-structure.md): `reassess-roadmap` asks
  about stale milestones (14 days, no summaries) and writes the state;
  `plan-task` / `summarize-task` flip in-progress / done; `session-start`
  flags more than one milestone in progress.
- **Read-side layout tolerance** (`yt_find_artifacts`): `milestones/M###/`,
  `decisions/`, `backlog/{,shipped,rejected}/`, `quick/` are searched by
  `session-start`, `resume-session`, `summarize-task`, `reassess-roadmap`;
  writing stays flat.
- **Advisory `Stop` hook** (M019): a `systemMessage` reminder when the agent
  stops with an unsummarized active task; never blocks.
- **CI workflow** (`.github/workflows/ci.yml`, M019): shell suites +
  `ytstack-check` on ubuntu and macOS.
- **`adopt-brownfield` skill** ([#18]). First-class entry for an existing
  codebase without `.ytstack/`: detects what the repo already documents
  (README, `docs/`, CHANGELOG, ADRs, manifests + commit history, entry-point
  docs), shows a mapping table, asks per artifact how to handle it
  (reference / extract / move / leave; nothing is moved without that
  answer), dispatches four read-only subagents into
  `.ytstack/codebase/{stack,architecture,conventions,concerns}.md`, and
  scaffolds only the gaps: PROJECT.md with `origin: brownfield-import`, a
  **Validated** section and an **Adoption** table; DECISIONS.md seeded from
  ADRs by reference; KNOWLEDGE.md as a link index over `docs/`; RUNTIME.md
  derived from package scripts / `.env.example` / compose / workflows;
  STATE.md with `tracker:`. Never runs office-hours.
- **`yt_brownfield_signals`** in `hooks/lib/git-ctx.sh`: the shared detector
  (six signals, one source -> artifact hint each) behind init-project,
  adopt-brownfield and the SessionStart hook; 21 lib tests.
- **`tracker:` field in STATE.md** (`none | linear | github-projects |
  paperclip | jira`). `plan-milestone` and `reassess-roadmap` read it and
  say in one sentence that BAU work tracked there needs no milestone.

### Changed

- **`init-project`** counts brownfield signals in its preamble; with >= 2
  and no pitch it stops and points at `adopt-brownfield` instead of writing
  placeholder artifacts. New Anti-Pattern clause ("too mature for greenfield
  ceremony").
- **`session-start` hook** flags an existing codebase without `.ytstack/`
  (>= 2 signals: names the sources, routes build-intent to
  `adopt-brownfield`, not office-hours); the injection stays at ~6.6k of the
  10,000-char cap and `tests/hooks-readonly.test.sh` guards it.
- **`using-ytstack`** lists `adopt-brownfield` and the routing rule.

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
[#18]: https://github.com/Yesterday-AI/ytstack/issues/18
[#19]: https://github.com/Yesterday-AI/ytstack/issues/19
[#20]: https://github.com/Yesterday-AI/ytstack/issues/20
[#21]: https://github.com/Yesterday-AI/ytstack/issues/21
[#22]: https://github.com/Yesterday-AI/ytstack/issues/22

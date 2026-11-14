# Changelog

All notable changes to ytstack are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Technical spec** (issue #36): every project gets `.ytstack/spec/SPEC.md`
  (entry point, one page) and one `.ytstack/spec/<area>.md` per system area.
  They say what applies now: behaviour, contracts, where it is implemented,
  how a change is verified, which decisions are in force. Plans and summaries
  stay the history. Where a project already has an authoritative document for
  an area, the area file points at it (`sources`) and repeats nothing. Format
  and maintenance rules: `docs/ux/spec-format.md`.
- `bin/ytstack-spec`: `lint` (format), `drift` (areas whose `paths` changed
  after their description or its source was last touched, as a prompt to
  look), `impact` (a task plan's "Spec impact" against what the task changed),
  `areas` (which area describes a path). Suite `tests/ytstack-spec.test.sh`.
- `init-project` scaffolds the spec from the pitch, every area
  `status: planned` and unverified. `adopt-brownfield` builds it over the
  existing documents and its codebase map, and marks an area `implemented`
  only after its code was read. For a project that already has `.ytstack/`
  and no spec, `adopt-brownfield` adds only the spec.
- `plan-task` writes a `## Spec impact` section (area and section, or `none`
  with a reason). `summarize-task` does not close a task whose named area was
  not updated: the area file or one of its `sources` has to have changed with
  the task. The summary records the result under `## Spec`.
- `code-review` and the verifier read the area files that cover the changed
  paths against the change, and nothing else of the spec. `reassess-roadmap`
  answers the drift report once per area at the slice boundary.
- `bin/ytstack-check` lints ytstack's own `.ytstack/spec/` and fails when the
  maintenance block in the two scaffolding skills differs from the format
  document.
- Eval case `spec-impact`; second outcome graders on `plan-task`,
  `summarize-task`, `init-project` and `adopt-brownfield`.
- **Bounded work** (issue #35): `minimal-code` is now the work contract for
  code, evidence and reports: list what a change must reach before choosing
  the smallest solution, fix a bug once in the shared code, no new test for a
  trivial change, run what the plan's Verification names as often as it says,
  end every report with "Not checked:".
- `bin/ytstack-brief`: `render` builds the brief for a dispatched worker from
  the plan files and includes the contract verbatim (the same text for a
  Claude subagent and for `codex exec`); `check` validates the worker's
  report (fixed labels, among them "Not checked:"). `spawn-milestone-team` dispatches with the
  rendered brief and checks the report before the verifier runs. Suite
  `tests/ytstack-brief.test.sh`.
- Gates: a slice plan or task plan can carry `## Gates` (what, who decides,
  how the verdict is obtained, when it lapses). A gate never holds a task
  open and no agent records it as given. `reassess-roadmap` puts all open
  gates and all non-converging work to the human in one question and reports
  two numbers: slices closed by work, slices accepted.
- `plan-task` records how often and where a verification runs (`Runs:`,
  `Environment:`, optional `Sample:` with its reason).
- `code-review` counts rounds in the task plan (`## Review`): round 1 is
  complete, round 2 covers the fix and its consequences, a third round is a
  diagnosis of scope, conflicting rules or solution instead of another
  review. The reviewer states the assumed load, gives a concrete case and
  "if skipped" per finding, treats a `shortcut:` comment that names its limit
  as a decision, and follows the project's severity policy.
- Eval cases `bounded-evidence`, `gates-one-question`, `review-round-three`.
- **`STATE.md` as a pointer**: the STATE lint reports a file above 12,000
  bytes (W8) and status paragraphs beside the current one (W9). Both are
  prompts and stop no skill. `reconcile` offers to move that history verbatim
  into `.ytstack/archive/` and, in a project with a technical spec, to
  archive the slice and task files of closed milestones.
- At the last slice of a milestone `reassess-roadmap` folds what still holds
  (changed behaviour, decisions in force, limits) into the area files of the
  spec before it names the archive offer.
- Eval cases `fresh-resume`, `fresh-bugfix`, `fresh-requirement`: three
  fresh-session tasks on one project snapshot whose history contradicts its
  present.
- **Coordinator mode** (issue #34), formats in
  `docs/ux/coordinator-format.md`:
  - `.ytstack/LANES.md`, one row per delegated lane, written through
    `bin/ytstack-frontier` (`list`, `claim`, `set`, `release`, `check`).
    Slice plans carry `**Blocked by:**`; the frontier is what is open,
    unblocked and unclaimed. `spawn-milestone-team` claims a lane before it
    dispatches and dispatches again when the frontier changes. Claiming a
    held lane is refused.
  - `bin/ytstack-brief render --kind implement|review|prepare`; the report
    gains `Status:` (complete, partial, blocked), `Uncommitted:` and `Next:`.
  - `bin/ytstack-finish-lane` and the skill `finish-lane`: commit what a lane
    left (junk and out-of-scope files are refused), push, open the pull
    request, wait until the host shows the head, review pinned to that
    commit, gates read from the host, merge at the reviewed commit. GitHub
    through `gh`. Who merges is `merge_by:` in `PREFERENCES.md`, `human` by
    default.
  - The skill `handover-step` with `bin/ytstack-handover`: a step only the
    human may perform becomes one staged script with read-only checks, a
    confirmation before every change and a receipt. The agent checks it
    statically and never runs it.
  - `.ytstack/questions/` with `bin/ytstack-questions`: one file per question
    for the human, states open, asked, answered. A question is asked once.
    `reassess-roadmap` carries a gate that needs a verdict as a question
    file.
  - `.ytstack/STANDING.md` for instructions that hold beyond the task at
    hand.
  - The skill `coordinate` for the session that owns a plan and delegates all
    of it: start from files after every context loss, host facts read fresh
    and stamped with their read time, questions one at a time, bounded loops,
    rotation through a handoff. `bin/ytstack-watch` polls pull requests
    outside the model and prints a line only when something changed.
  - The skill `lane-retro`: a sample of finished lanes in six fixed
    categories; an accepted candidate becomes a check or a pointer, never
    only new prose.
  - `systematic-debugging` gets a flake disposition; the handoff gets a
    "Suggested skills" section.
  - Eval case `coordinator-resume`.
  - Not exercised yet: nothing of coordinator mode has run against a real
    pull request host or in a real multi-lane run; the suites use a stand-in
    for `gh`.

### Changed

- `resume-session`, `handoff-session` and the closing line of the
  SessionStart injection name `spec/SPEC.md` instead of restating how the
  system behaves.
- The SessionStart injection cuts the "Next action" excerpt to what fits
  under the host's cap instead of replacing it with "omitted".
- Evidence is a check on a commit in an environment. The verifier still makes
  the independent run, once per commit; neither it nor
  `verification-before-completion` repeats a check for the same commit and
  environment because the context is new. The summary's Verification line
  records the commit and the environment.
- The TDD wrapper says which changes get a new test (logic, bug fixes) and
  which do not (a rename, a constant, a text, a config value).
- ytstack's own entry documents agree with the repository again
  (`PROJECT.md`, `KNOWLEDGE.md`, `ROADMAP.md`, `AGENTS.md`, the wrapper and
  suite counts in README, QUICKSTART, NOTICE and `docs/concept.md`).

### Fixed

- `bin/ytstack-spec impact` reads git's path records NUL-delimited, so a
  source with a space or a non-ASCII byte in its name counts as changed,
  committed or not.
- `bin/ytstack-brief` reads a planned path with a space inside its backticks,
  so the brief names the area file that covers it.

### Upgrade notes

- Existing projects have no spec yet. Run `/ytstack:adopt-brownfield` once:
  it proposes the areas, asks one question and writes `.ytstack/spec/`. No
  other artifact is touched.
- Task plans written before this release have no `## Spec impact` section.
  `summarize-task` then works the impact out at closure instead of refusing.

## [0.5.0] - 2026-11-11

### Added

- **Status line segment** (`bin/ytstack-status`, issue #31): one compact
  line for a status line script. With an optional `progress` block in the
  `STATE.md` frontmatter (`label`, `done`, `total`, `waiting_on`) it shows
  label, percentage, done/total and the waiting item; without it the active
  slice's task count from the slice plan checkboxes; in both cases the
  current task pointer. Plan progress is read from the default branch when
  the checkout is on another branch (linked worktrees), the pointer from the
  checkout. Local refs only, no network. Integration in `docs/statusline.md`.
  The default ref is `origin/<default>`, or the local `<default>` when it
  contains the remote one; the two are compared by ancestry.
- `yt_progress_parse` in the shared library and STATE lint finding W7 for a
  malformed `progress` block; a malformed block prints nothing.
- `summarize-task` and `quick-task` update the `progress` block when they
  advance STATE.

### Changed

- Docs only: CONTRIBUTING release checklist (fetch + merge before the
  release commit, push `main` before the tag, pushed tags are immutable),
  QUICKSTART note on gstack's `./setup` side effects, KNOWLEDGE gotchas,
  ROADMAP M020 candidates, REVIEW-NOTES item on Codex's
  `additionalContextLimit`.

## [0.4.2] - 2026-11-07

### Fixed

- `yt_find_artifacts` on Linux: GNU `stat -f %m FILE` prints filesystem
  info to stdout before failing, so "Recent tasks" and the layout-tolerant
  lookups carried garbage lines and the git-ctx suite failed on
  ubuntu-latest. The lib now tries GNU `stat -c %Y` first, BSD `stat -f %m`
  second. `tests/run-all.sh --linux` is green again.
- `.github/workflows/ci.yml`: `ytstack-check` exit 2 (warnings only) no
  longer fails the job, matching `plugin-check.yml`.

## [0.4.1] - 2026-11-07

The 0.4.0 tag was pushed before the Codex support that had landed on
`origin/main` in October (PR #23) was merged; 0.4.1 is 0.4.0 plus that merge.

### Added

- **Codex plugin support** (PR #23, 2026-10-13): `.codex-plugin/plugin.json`
  + `.agents/plugins/marketplace.json` self-marketplace, `bin/ytstack-codex`
  runs the shared skill blocks and the three lifecycle hooks (SessionStart /
  PreCompact / SessionEnd) with the existing environment contract,
  `codex/adapter.md` maps tools and shell blocks, `docs/codex.md`,
  `.github/workflows/plugin-check.yml`. `tests/codex_plugin_test.py` asserts
  the 0.2.0+ contract (out-of-tree handoff and journal, repo-key user scope,
  compaction guidance on stdout). Host context a non-Claude adapter prepends
  is not counted against Claude Code's 10,000-char SessionStart cap.

### Fixed

- `hooks/session-start`, `reconcile`, `spawn-milestone-team`: a
  `grep -c . || echo 0` produced `0\n0` when nothing matched and broke the
  integer test ("Milestones in progress") in projects without an
  in-progress roadmap.

## [0.4.0] - 2026-11-07

Three milestones in one release: brownfield import (M010), ceremony scaling
(M018) and the 2026 skill bar (M019: `metadata:` frontmatter, trigger-only
descriptions, evals, CI, six lifecycle skills, worktree-subagent execution
model). Research basis: `docs/research/2026-11-07-modernisierung-best-practices.md`.

### Added

- **Six lifecycle skills** (M019-S03, absorbs M011): `code-review`
  (superpowers requesting + receiving-code-review on the task's commit
  range), `finish-branch` (superpowers finishing-a-development-branch,
  gated on every task of the slice having a real summary, never touches
  `.ytstack`), `grill` (superpowers brainstorming before plan-milestone;
  design notes into `M###-CONTEXT.md` or `GRILL-<slug>.md`), and the
  gstack-backed `retro` (`M###-RETRO.md` from the task summaries), `ship`
  (gstack release flow, no merge without instruction) and
  `document-release` (CHANGELOG + release notes from the summaries since the
  last tag). `using-ytstack` routes to them; `session-start` prints the
  lifecycle hint after a closed slice (reassess -> finish-branch / ship) or
  milestone (retro -> document-release -> plan-milestone).
- **Eval suite** (`evals/`, M019-S02) for `claude plugin eval`: 13 cases
  (one per lifecycle skill) with `fixture.sh` scaffolds, a `skill-fired`
  grader and a free outcome grader each; `evals/README.md` has the run
  command; `evals/results/` gitignored.
- **CI workflow** (`.github/workflows/ci.yml`): shell suites +
  `ytstack-check` on ubuntu and macOS; README badge.
- **Advisory `Stop` hook** (`hooks/stop`): one-line `systemMessage` when
  the agent stops with an unsummarized active task; never blocks.

### Changed

- **Execution model** (M019-S04, DECISIONS 2026-11-07 M019 context):
  `spawn-milestone-team` 0.2.0 is an orchestrator that never edits source:
  one `ytstack:implementer` subagent per slice with `isolation: worktree`
  on branch `ytstack/M###-S##`, one `ytstack:verifier` subagent per
  finished branch, merge owned by the orchestrator (`STATE.md` from its
  side). Agent Teams are an opt-in via PREFERENCES `team: on` (new key,
  default `off`; `init-project` writes it). `agents/implementer.md` and
  `agents/verifier.md` carry `isolation: worktree`, `memory: project`,
  `maxTurns`; `architect` gets `memory: project`; `skills:` documented as
  a preload. `bin/ytstack-check` validates `isolation` / `memory` and warns
  on fields plugin subagents ignore.
- **Skill frontmatter** (M019-S01): ytstack's own keys `tier`, `version`,
  `kind`, `triggers` live under `metadata:` (Agent Skills spec; unknown
  top-level keys hard-error on packaging/upload). `bin/ytstack-check`
  parses the nested map, reads `metadata.*` first and warns on the legacy
  form.
- **Descriptions** (M019-S01): all 31 skills carry trigger-only
  descriptions (third person, what + when + when-not, longest 449 chars);
  `bin/ytstack-check` fails descriptions over 1,024 chars, warns on
  procedure-summary phrases and on `kind: directive|reference` without an
  explicit `user-invocable` flag. Reference skills are `user-invocable:
  true`.

### Removed

- **`web-design` plugin dependency** (DECISIONS 2026-11-07 "No hard plugin
  dependencies"): an unsatisfied dependency disables ytstack at load time,
  which made `claude plugin eval` and clean-machine `--plugin-dir` fail;
  nothing in ytstack calls web-design. It stays a recommended companion in
  the README. The self-marketplace drops `allowCrossMarketplaceDependenciesOn`.

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

### Notes

- `/plugin update` to 0.4.0. New gstack-backed skills (`retro`, `ship`,
  `document-release`) need the same gstack install as the planning wrappers;
  everything else runs without it.
- `.ytstack/PREFERENCES.md` of existing projects: add the `## Ceremony`
  block (`granularity`, `autonomy`, `quick_lane`, `minimal_code`, `team`) or
  accept the defaults (task / loop / on / on / off).

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

[0.5.0]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.5.0
[0.4.2]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.4.2
[0.4.1]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.4.1
[0.4.0]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.4.0
[0.3.0]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.3.0
[0.2.0]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.2.0
[0.1.6]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.1.6
[0.1.5]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.1.5
[0.1.0]: https://github.com/Yesterday-AI/ytstack/releases/tag/v0.1.0
[#16]: https://github.com/Yesterday-AI/ytstack/issues/16
[#18]: https://github.com/Yesterday-AI/ytstack/issues/18
[#19]: https://github.com/Yesterday-AI/ytstack/issues/19
[#20]: https://github.com/Yesterday-AI/ytstack/issues/20
[#21]: https://github.com/Yesterday-AI/ytstack/issues/21
[#22]: https://github.com/Yesterday-AI/ytstack/issues/22

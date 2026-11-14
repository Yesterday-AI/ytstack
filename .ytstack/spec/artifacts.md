---
area: artifacts
status: implemented
paths:
  - skills/init-project/**
  - skills/adopt-brownfield/**
  - skills/plan-milestone/**
  - skills/slice-milestone/**
  - skills/plan-task/**
  - skills/summarize-task/**
  - skills/quick-task/**
  - skills/handoff-session/**
  - skills/reconcile/**
sources:
  - docs/ux/skill-structure.md
  - docs/ux/spec-format.md
  - docs/ux/coordinator-format.md
  - docs/ux/review-policy-format.md
  - docs/ux/runtime-format.md
  - docs/ux/signal-format.md
  - docs/statusline.md
verified_at: 4d1ac7a
---

# artifacts

## Purpose

The `.ytstack/` artifact model: the Markdown files that hold a project's memory and its position in the milestone, slice and task hierarchy, who writes each of them, and what may be moved. The area ends at the files. The procedures that produce them are described in [skills.md](skills.md). The `status` values are defined in `docs/ux/skill-structure.md` ("Artifact states"), the `progress` block in `docs/statusline.md`, the technical spec (`spec/SPEC.md`, `spec/<area>.md`) and its maintenance rules in `docs/ux/spec-format.md`.

## Behavior

### Location and scope

- `yt_resolve_yt_dir` in `hooks/lib/git-ctx.sh` picks the directory: `<toplevel>/.ytstack` if it exists (project scope, tracked in git), otherwise `~/.ytstack/projects/<repo key>` (user scope), otherwise none. The repo key is a hash of the git common dir, so all worktrees of a repository share one user-scope directory.
- `init-project` asks for project, user or both and records the answer as `scope:` in the `PROJECT.md` frontmatter. `both` writes identical files to both directories; the resolver then reads the project one. `adopt-brownfield` always uses project scope.
- In project scope a linked worktree has its own copy of `.ytstack/` at its branch's state.
- Skills write a flat layout: every file directly in the directory, except `quick/`, `codebase/`, `backlog/` and `archive/`. Readers that go through `yt_find_artifacts` also find files under `milestones/`, `decisions/`, `backlog/` and `quick/`.

### Files and writers

| File | Created by | Changed afterwards by |
|---|---|---|
| `PROJECT.md`, `PREFERENCES.md` | `init-project` or `adopt-brownfield` | the user; no skill step edits them |
| `RUNTIME.md` | `init-project` or `adopt-brownfield`, with the headings "Run", "Release" and "Signals" and one line of free text each | the user; key lines in the three sections follow `docs/ux/runtime-format.md` and are read only through `bin/ytstack-runtime`; `adopt-brownfield` writes a key line only for a command a document or script of the project states and names that source. "Release" is run by `bin/ytstack-watch release`, "Signals" by `signal-intake` and `incident` |
| `spec/REVIEW.md` | a person (optional), linked from `SPEC.md` | a person; four sections (Always a person, Never low, Lenses, Size); a change to it always goes to a person |
| `evidence/<lane>/<short sha>/<lens>/` with `MANIFEST` (`evidence_dir` of `PREFERENCES.md`) | `visual-review`, in the main checkout of the repository; `bin/ytstack-risk manifest` writes hash and name per image | -- ; a process record; committing it is the project's choice |
| `signals/F###-<slug>.md` | `bin/ytstack-signals new` (from `signal-intake`) | `bin/ytstack-signals new` (a second sighting: count, last seen), `set` (state, ref); format `docs/ux/signal-format.md` |
| `incidents/<date>-<slug>.md` | `bin/ytstack-signals incident new` (from `incident`) | `incident`: facts with read times, the timeline (append-only), hypotheses, mitigations with their handover scripts, the person's decisions in own words |
| `DECISIONS.md` | `init-project` or `adopt-brownfield` | appends by `plan-ceo-review`, `plan-eng-review`, `systematic-debugging`, `code-review`, `retro`, `grill`, `reassess-roadmap` |
| `KNOWLEDGE.md` | `init-project` or `adopt-brownfield` | appends by `systematic-debugging`, `test-driven-development`, `code-review`, `retro` |
| `STATE.md` | `init-project` or `adopt-brownfield` | see "STATE.md" |
| `OFFICE-HOURS.md` in the repository root, `OFFICE-HOURS-<slug>.md` once `.ytstack/` exists | `office-hours` | moved into `.ytstack/` by `init-project` and `adopt-brownfield`; annotated by `plan-ceo-review` and `plan-eng-review` |
| `GRILL-<slug>.md` | `grill`, when no milestone is current | -- |
| `M###-CONTEXT.md` | `plan-milestone` | `grill` (decisions), `reassess-roadmap` (reassessment note, backlog sweep, note for `shipped-informally`) |
| `M###-ROADMAP.md` | `plan-milestone` | `slice-milestone` (slice names), `plan-task` and `summarize-task` (`status`), `reassess-roadmap` (slices, checkboxes, counts, `status`), `plan-ceo-review`, `reconcile` (`status`) |
| `M###-S##-PLAN.md` | `slice-milestone` | `summarize-task` (checkbox, count, `status`), `plan-eng-review`, `hooks/task-completed` (checkbox) |
| `M###-S##-T##-PLAN.md` | `plan-task` | notes by `test-driven-development` and `systematic-debugging` |
| `M###-S##-T##-SUMMARY.md` | `summarize-task`; a draft stub by `hooks/post-tool-use-bash`; an auto summary by `hooks/task-completed` | `summarize-task` replaces a stub; `reconcile` may mark it `closed: abandoned` |
| `M###-RETRO.md` | `retro` | -- |
| `quick/Q###-PLAN.md`, `quick/Q###-SUMMARY.md` | `quick-task` | `quick-task` (`status`) |
| `codebase/{stack,architecture,conventions,concerns}.md`, `backlog/README.md` | `adopt-brownfield` | refreshed by deleting the file and running the skill again |
| `spec/SPEC.md`, `spec/<area>.md` | `init-project` (every area `planned`), `adopt-brownfield` (pointer-only over existing documents; also for a project that has `.ytstack/` and no spec) | the task that changes the area, in its own commits; `reassess-roadmap` sets `verified_at` when it answers the drift report |
| `HANDOFF.md` | `handoff-session` | the user; no hook writes it |
| `LANES.md` | `bin/ytstack-frontier claim` (first claim) | `bin/ytstack-frontier` (`set`, `release`), one row per call; called by `spawn-milestone-team`, `coordinate`, `finish-lane` |
| `questions/Q###-<slug>.md` | `bin/ytstack-questions new` (from `coordinate`, `reassess-roadmap`, and from `bin/ytstack-upkeep --question`, which keeps at most one open or asked file titled `Upkeep found ...`) | the agent fills Context, Options, Recommendation; `ask` and `answer` change the state; the answer text is the human's |
| `STANDING.md` | `coordinate`, when the human gives an instruction that holds beyond the task | appended; an overtaken line is struck through and dated, not removed |
| `handover/<date>-<slug>.sh` and its receipt | `handover-step` through `bin/ytstack-handover new`; the receipt by the script when the human runs it | a script that ran is not edited |
| `retro/LANES-<date>.md` | `lane-retro` | appended on a second run of the same day |
| `archive/<date>/`, `archive/INDEX.md`, `RECONCILE-<date>.md` | `reconcile` | -- |
| `ROADMAP.md` (all milestones), `REVIEW-NOTES.md` | no skill and no hook creates them | skills edit the milestone rows of `ROADMAP.md` when a `status` changes |

The frontmatter and section template of each file is in the `SKILL.md` of the skill that creates it.

### STATE.md

`STATE.md` is the pointer. Its frontmatter template is in `skills/init-project/SKILL.md`; the accepted values are what `yt_state_lint` checks.

| Field | Written by |
|---|---|
| `current_milestone` | `plan-milestone` |
| `active_slice` | `plan-task` sets it, `summarize-task` clears it when the slice is complete, `reassess-roadmap` moves it to the next open slice |
| `active_task` | `plan-task` sets it, `summarize-task` clears it |
| `last_updated` | every skill that edits the file, including `quick-task` |
| `tracker` | the user; `plan-milestone` and `reassess-roadmap` read it and keep issue-level work out of milestones |
| `progress` (optional block) | the user adds it; `summarize-task` and `quick-task` add 1 to `done` when they close a counted item |

- `active_slice` and `active_task` hold `all` when `granularity` is coarser than `task`.
- In non-interactive mode the three skills skip the pointer fields (see [skills.md](skills.md)). After a parallel run the orchestrator sets the pointer by hand.
- Hooks read `STATE.md` and never write it.
- `yt_progress_parse` is the only parser of the `progress` block. No skill creates the block.
- `yt_state_lint` reports the findings listed in the comment above the function. `hooks/session-start` and `resume-session` show them. `plan-task` and `summarize-task` stop on a malformed field and on a slice or task set while the milestone is `none`.
- `hooks/session-start` and `hooks/pre-compact` read the first lines under `## Next action` in the body.

### States and closure

- `status` in milestone, slice and task frontmatter: see `docs/ux/skill-structure.md` ("Artifact states") for the values and their writers.
- A task plan is written with `status: planned` and no skill changes that field. A task is closed by its summary file and the checked box in the slice plan.
- A slice plan goes from `planned` to `done`. A quick plan goes from `in-progress` to `done`.
- `closed:` in a summary holds a timestamp, `draft` (hook stub) or `abandoned` (`reconcile`). A draft is not a closure: `yt_state_lint`, `hooks/stop`, `finish-branch` and `ship` treat the task as open.
- A task plan has a `## Spec impact` section: one line per area the task changes, or `none` with a reason. `plan-task` works it out from the area files; it does not ask.
- A task plan's `## Verification` section holds the command and a line `Runs: <n>. Environment: <where>.`, with `Sample:` and a reason when the check covers a sample. A summary's Verification line records the check, the commit it ran on and the environment, and is followed by `Not checked:`.
- `## Gates` in a slice plan or task plan holds one line per gate: `- [ ] G## -- <what> | decides: <who> | how: <how> | lapses: <when>`. `- [x]` with `| given: <date> <who>` is a gate a person gave, `- [-]` with `| lapsed: <date> <reason>` one that lapsed. Only `reassess-roadmap` changes the box, and only to what the human answered.
- `**Blocked by:**` under a slice plan's goal (and optionally under a task plan's summary) names what has to be finished first; `bin/ytstack-frontier` reads it.
- `## Review` in a task plan (in a slice plan for a slice lane) holds one line per review round: `- Round <n>: <base>..<head> -- <verdict>; blocking: <n>; follow-ups: <n>; risk: <class>; invariants: none | <text>; by: <reviewer>`, and one line per lens: `- Lens <name>: <head> -- pass | fail | not run; by: <reviewer>; evidence: <dir> (<n> images) | none`. `code-review` and `finish-lane` append them; `code-review` counts the round lines, `bin/ytstack-risk route` reads the newest of each (`docs/ux/review-policy-format.md`, "Records"). A line without the three new fields is a round without a stated risk.
- An area file may carry `auto_merge: none | low | normal`, the highest class that may merge into the area without a person; no field is `none`.
- `summarize-task` runs `bin/ytstack-spec impact` in its preamble. A named area is satisfied when its area file or one of its `sources` changed in the task's commits or the working tree. Otherwise the task is not closed. The summary records the result under `## Spec`. A plan that says `none` closes without a spec edit. With the spec in user scope, an area file lies outside the repository: `impact` reports it as unverifiable (exit 4) with its modification time against the task's first commit, and `summarize-task` records that line when the file was modified after that commit, or asks the person once.

### Commits and tasks

- A task's commits start their subject with the task ref `M###-S##-T##:`; a quick task's with `Q###:`. A project overrides the pattern with `commit_ref_pattern` in `PREFERENCES.md`; `yt_commit_ref_pattern` renders it.
- `summarize-task` owns the link. `yt_task_commits` lists the commits whose subject matches the pattern; if none match, the commits on the current branch since its merge-base with the default branch; otherwise none. The summary's `## Commits` section says which source was used.
- `hooks/post-tool-use-bash` writes a draft summary once, after a successful `git commit` whose subject carries the active task's ref. It never rewrites the file and keeps no commit list.
- `code-review` finds the task's commits the same way.

### Volatile state, out of tree

Automatic handoffs and the session journal are not artifacts. `hooks/pre-compact` writes `HANDOFF.auto.md` and refreshes a `latest-handoff` link per worktree; `hooks/session-end` appends to `session.jsonl`. Both live under `yt_state_base`, per repository, worktree and session. When that base is not writable they fall back to `.ytstack/.local/`, which `yt_ensure_gitignore` ignores (`init-project`, `adopt-brownfield`, `reconcile`). `hooks/session-start` and `resume-session` read `HANDOFF.md` and the latest automatic handoff.

### STATE.md is a pointer; host facts are not stored

- `yt_state_lint` reports a `STATE.md` above `YT_STATE_MAX_BYTES` and status paragraphs beside the current one. Both are prompts; no skill stops on them. What needs a row per item (lanes, questions) has its own file.
- The files of coordinator mode record what the coordinator did and identifiers (a branch, a pull request number, the reviewed commit). The state of a pull request, of its checks or of a deployed build is read from the host when it is needed and is not written into `.ytstack/` as current (`docs/ux/coordinator-format.md`).

### Ownership and cleanup

- Every file under `.ytstack/` is user-owned. Skills, agents and hooks do not delete, move, truncate or revert it.
- `reconcile` is the only path that moves artifacts. It lists the leftovers by class (draft stubs, unfilled hook drafts, milestones planned and never sliced, untracked files, a `.local` directory that is not ignored, history inside `STATE.md`, slice and task files of closed milestones) and asks per class: close, archive or keep.
- The history class moves earlier status paragraphs of `STATE.md` verbatim to `archive/<date>/STATE-history.md` and leaves the frontmatter, the current status, "Next action" and "Open decisions". It is the only edit to the body of `STATE.md` that `reconcile` makes, and only after its question was answered with yes. The closed-milestone class exists only in a project with a technical spec and keeps each milestone's `CONTEXT` and `ROADMAP` in place.
- At the last slice of a milestone `reassess-roadmap` folds what still holds into the area files (changed behaviour, decisions in force, limits) and names the archive offer; it moves nothing.
- Archiving moves files to `archive/<date>/` inside `.ytstack/` (`git mv` when tracked) and adds a line to `archive/INDEX.md`. `reconcile` edits only `status:` and `closed:` fields and `ROADMAP.md` rows, never runs `rm`, never edits the `STATE.md` pointer, and logs to `RECONCILE-<date>.md`.
- `init-project` stops when `.ytstack/` exists. `adopt-brownfield` stops when `.ytstack/` and `spec/SPEC.md` exist; with `.ytstack/` and no spec it writes only `spec/` and the codebase map files that are missing. It does not overwrite a file under `.ytstack/`.
- An area file is rewritten when its area changes; it carries no history. The other artifacts are appended to or advanced.

## Invariants and security boundaries

- `DECISIONS.md` is append-only; a reversal is a new entry.
- `HANDOFF.md` is written by a person or by `handoff-session`, never by a hook.
- Hooks write into `.ytstack/` in two cases only: the draft summary stub, and the auto summary with its checkbox for an Agent Teams task.
- No state lives in `~/.ytstack/.<name>` sentinel files. An ask-once answer is recorded in the artifact it concerns (`docs/ux/skill-structure.md`, "Ask-once answers").
- `RUNTIME.md` written by `adopt-brownfield` records environment variable names, never values. The three sections of `RUNTIME.md` hold names of credentials, never values; `bin/ytstack-runtime check` fails on a token-looking string there. In those sections only list lines are read; a section without a list line counts as absent.
- The commands under "Release" and "Signals" of `RUNTIME.md` only read. No skill and no script runs a command that changes a target; a mitigation is a handover script a person runs.
- A change to `spec/REVIEW.md`, `DECISIONS.md`, `STANDING.md`, `PREFERENCES.md`, an instruction file, the frontmatter of an area file (a `verified_at` stamp on its own excepted) or its sections "Invariants and security boundaries" and "Decisions that apply now" always goes to a person (`bin/ytstack-risk floor`).
- `## Decisions` of an incident record holds only what a person ordered, in own words.

## Error behavior

- `.ytstack/` without `STATE.md`: `hooks/session-start` injects a repair message; the hooks that write into `.ytstack/` exit without writing.
- Malformed pointer: `plan-task` and `summarize-task` print the lint line and stop.
- Active task without a plan file: `summarize-task` stops and asks for a manual repair.
- Malformed `progress` block: `bin/ytstack-status` prints nothing and the lint reports it.

## Known limits

- `ROADMAP.md` and `REVIEW-NOTES.md` have no template. Unknown -- the row format of `ROADMAP.md` that the status mirroring expects.
- With `granularity: slice` or `milestone`, `yt_commit_ref_pattern` called with an empty task renders the default pattern as `^M###-S##-:`, not `^M###-S##:`. The shorter form in `skills/summarize-task/SKILL.md` has to be built by hand.
- User scope has no git history for the directory: the stale-timestamp finding stays silent, and `bin/ytstack-status` reads plan progress from disk. No test suite exercises user-scope resolution.
- Scope `both` keeps two copies with no sync between them.
- `plan-milestone` and `plan-task` do not read `codebase/`, the pitch or `GRILL-<slug>.md`; other skills' reports say they do.
- The `Current status` section of `PROJECT.md` and the `Recent summaries` section of `STATE.md` are in the templates; no skill step updates them.

## Where implemented

- Templates: `skills/init-project/SKILL.md` and `skills/adopt-brownfield/SKILL.md` (the core files, `codebase/`, `backlog/`), `skills/plan-milestone/SKILL.md`, `skills/slice-milestone/SKILL.md`, `skills/plan-task/SKILL.md`, `skills/summarize-task/SKILL.md`, `skills/quick-task/SKILL.md`, `skills/handoff-session/SKILL.md`.
- Cleanup: `skills/reconcile/SKILL.md`. States `dropped` and `shipped-informally`: `skills/reassess-roadmap/SKILL.md`.
- Technical spec: scaffolds in `skills/init-project/SKILL.md` (Step 7) and `skills/adopt-brownfield/SKILL.md` (Steps 2 and 7); "Spec impact" in `skills/plan-task/SKILL.md` (Step 7); the closure check in `skills/summarize-task/SKILL.md` (preamble and Step 8); the tool `bin/ytstack-spec`; this repository's own spec under `.ytstack/spec/`.
- `hooks/lib/git-ctx.sh`: `yt_resolve_yt_dir`, `yt_state_lint`, `yt_progress_parse`, `yt_commit_ref_pattern`, `yt_task_commits`, `yt_find_artifacts`, `yt_state_base`, `yt_state_dir`, `yt_ensure_gitignore`.
- Hooks that touch artifacts: `hooks/post-tool-use-bash`, `hooks/task-completed`. Out-of-tree writers: `hooks/pre-compact`, `hooks/session-end`.
- Tests: `tests/git-ctx.test.sh` (scope resolution, state dirs, commit discovery, lint, `progress`, gitignore block), `tests/skill-preambles.test.sh` (`reconcile` classes, `Q###` numbering, tracker, handoff lookup), `tests/post-tool-use-bash.test.sh` (stub once, ref match), `tests/pre-compact.test.sh` (`HANDOFF.md` untouched), `tests/ytstack-status.test.sh` (`progress` block).

## How to verify

- `bash tests/git-ctx.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/skill-preambles.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/post-tool-use-bash.test.sh`: exit 0, last line `RESULT: <n> passed, 0 failed`.
- `bash tests/pre-compact.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/ytstack-status.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash -c '. hooks/lib/git-ctx.sh; yt_git_ctx "$PWD"; yt_resolve_yt_dir >/dev/null; echo "$YT_SCOPE $YT_DIR"'` from the repository root: prints `project` and the path of `.ytstack`.
- `bash tests/ytstack-spec.test.sh`: exit 0, last line `<n> passed, 0 failed` (format, drift, closure check).
- `bash bin/ytstack-spec lint`: `0 failure(s)` for this repository's own spec.
- `bash tests/run-all.sh`: last line `ALL SUITES PASSED`.

## Decisions that apply now

- DECISIONS.md -- "2026-11-13: Whether a person looks at a change is decided per change: a floor from the diff, the class an independent reviewer states, a ceiling per area, lenses per kind of change (M025)" (`REVIEW.md`, `auto_merge`, the extended review lines, the evidence directory)
- DECISIONS.md -- "2026-11-13: `RUNTIME.md` has three sections with a fixed line format, read only through `bin/ytstack-runtime` (M025-S01)"
- DECISIONS.md -- "2026-11-13: Production findings and incidents are skill work on read-only access; a mitigation is a handover script a person runs (M027)" (`signals/`, `incidents/`)
- DECISIONS.md -- "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)"
- DECISIONS.md -- "2026-11-13: Verification, review and orchestration work are bounded like code (M023, issue #35)" (the `Runs:` line, `## Gates`, `## Review`, the evidence fields of a summary)
- DECISIONS.md -- "2026-11-13: `STATE.md` is a pointer with a size bound; history leaves it through `reconcile`, a closed milestone is folded into the spec (M022-S03)"
- DECISIONS.md -- "2026-11-13: Coordinator mode keeps lanes, questions and standing instructions in files and reads host facts fresh (M024, issue #34)" (the lanes table is not part of `STATE.md`, which narrows the proposal in issue #34)
- DECISIONS.md -- "2026-04-23: `.ytstack/` location is user-chosen (project vs user vs both)"
- DECISIONS.md -- "2026-05-31: active_slice is plan-task-owned and team-member-guarded (M012 / issue #21-RC1)"
- DECISIONS.md -- "2026-05-31: post-tool-use-bash is stub-once; summarize-task owns commit-to-task linking (M015 / issue #22)"
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree" (extends the stub-once entry to all hooks; ends hook writes to `HANDOFF.md` and the in-tree journal; user scope is keyed by the repo key, which narrows the slug path in the 2026-04-23 entry)
- DECISIONS.md -- "2026-11-07: Ceremony scales with the change -- granularity, autonomy, quick lane and minimal-code guard are project preferences with loud defaults" (artifact states, `Q###` artifacts, `reconcile`, user-owned artifacts)
- DECISIONS.md -- "2026-11-07: Brownfield adoption is a reference-first distillation, never a pitch" (existing documents stay the source of truth; `.ytstack/` links to them)
- DECISIONS.md -- "2026-11-11: Status line progress is one optional `progress` block in STATE.md, read by a plugin script (M021, issue #31)"

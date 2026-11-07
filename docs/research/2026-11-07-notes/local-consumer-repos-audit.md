# ytstack in the wild -- audit of 17 local consumer repos

Date: 2026-11-07. Scope: every `.ytstack/` directory under `~/Sync/home/alex/Code/WebDev` except the
plugin itself and the four `_deprecated/*` scaffolds (counted only). Method: read-only `git`
(`status`, `log`, `ls-files`, `check-ignore`, `worktree list`, `show`), `ls`, `grep`, `jq` over
`journal/sessions.jsonl`, plus the project `CLAUDE.md`/`AGENTS.md`, `.ytstack/*-NOTES.md`,
`DECISIONS.md`, `KNOWLEDGE.md` and the matching `~/.claude/projects/*/memory/` directories.
Plugin reference read for the artifact model: `README.md`, `hooks/hooks.json`, `hooks/session-start`,
`hooks/session-end`, `hooks/pre-compact`, `hooks/post-tool-use-bash`, `skills/init-project`,
`skills/summarize-task`, `skills/handoff-session`, `skills/resume-session`, `CHANGELOG.md`
(installed consumer version everywhere: 0.1.6).

Nothing in any consumer repo was modified. Two observations are time-sensitive: meinkontext's
untracked `M034-S04-T05-SUMMARY.md` stub was present when the collection script ran and gone
~20 minutes later (a parallel session cleaned it); llm-wiki has a session in flight (25 dirty files).

---

## 1. Per-repo table

Legend: `yt commits / all` = commits touching `.ytstack/` vs. total; `C/R/S/T/Σ` = count of
`M###-CONTEXT`, `M###-ROADMAP`, `M###-S##-PLAN`, `M###-S##-T##-PLAN`, `M###-S##-T##-SUMMARY`;
`last yt / last any` = date of last commit touching `.ytstack/` vs. last commit overall.

| Repo | Adopted | yt commits / all | C/R/S/T/Σ | Highest M | STATE pointer (M/S/T) | STATE `last_updated` | last yt / last any | In sync? |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| custom-agent-team | 2026-06-26 (greenfield scaffold) | 1 / 39 | 0/0/0/0/0 | -- | none/none/none | 2026-06-26 | 06-26 / 06-26 | scaffold only, never used |
| lx-0/agent-rpg | 2026-05-25 | 230 / 390 | 22/22/64/44/105 | M022 | M022/none/none | 2026-06-20 | 06-21 / 06-21 | in sync, project dormant since June; M022 planned, never sliced |
| lx-0/llm-wiki | 2026-05-02 (brownfield-retro) | 746 / 1348 | 24/24/78/211/221 | M034 (gap M008-M017) | M034/S06/T07 | 2026-10-16 | 10-16 / 10-17 | in sync, active |
| lx-0/risk-ai | 2026-07-04 | 37 / 136 | 4/4/20/**0/0** | M004 | `M004 (done)`/none/none | 2026-07-12 | 07-12 / 07-12 | in sync; slice-level only, no task ceremony |
| lx-0/screen-assistant | 2026-05-29 | 73 / 83 | 4/4/9/30/30 | M004 | M004/none/none | 2026-06-02 | 06-02 / 06-02 | in sync; M004 planned 06-02, never sliced |
| lx-0/SunoFlow | 2026-05-15 (brownfield import) | 125 / 1513 | 6/6/21/57/62 | M006 | M006/none/none (`status: complete`) | 2026-10-23 | 10-28 / 10-28 | in sync, active (BAU outside milestones) |
| sol/mantis | 2026-10-17 | 58 / 68 | 1/1/9/24/21 | M001 | M001/S03/T01 | `2026-10-17T23:51:00.971642+00:00` | 10-18 / 10-18 | in sync; whole project = 1 milestone, 9 slices in 36 h |
| ya/_sandbox/skills-mcp | 2026-07-04 | 69 / 102 | 4/4/12/57/67 | M004 | none/none/none | 2026-07-06 | 07-06 / 07-06 | frozen (absorbed into meinkontext 07-18); 8 dirty files since July |
| ya/agentic-ui (Luma) | 2026-10-19 (explicit import) | 22 / 65 | 1/1/5/22/21 | M001 | M001/S04/T04 | 2026-10-24 | 10-26 / 10-26 | in sync; STATE body is a PR worklog |
| ya/clawrag | 2026-05-30 (reconstructed) | 6 / 354 | 0/0/0/0/0 | -- | `none (reconstructed brownfield — …)` | 2026-05-30 | 06-18 / 06-18 | memory layer only; "decide first milestone" open since May |
| ya/fast-agent | 2026-08-21 | 63 / 160 | 3/2/8/19/**5** | M003 (dropped) | M003/none/none | 2026-10-02 | 10-31 / 10-31 | in sync; M002 shipped without summaries, M003 plans on disk with "Do NOT execute" |
| ya/fast-agent-wt-yreview (worktree) | copy of above | 63 / 163 | same | M003 | same | same | 10-31 / 10-31 | clean; no journal |
| ya/meinkontext (context-mcp) | 2026-07-18 | **1092 / 1945** | 39/37/94/104/212 | **M040** | **M034/S04/T05 (stale)** | 2026-11-05 | 11-06 / 11-06 | in sync as dashboard; pointer 6 milestones behind |
| ya/moderation-tools | 2026-07-11 | 22 / 68 | 4/2/3/**0/0** (+4 `M00X-SUMMARY.md`) | M004 | M004/none/none | `2026-08-28T00:00:00Z` | 08-28 / 08-28 | 4 milestones in 90 min, then 6 weeks of polish via wrapup only |
| ya/openclaw/openclaw-fleet | 2026-05-25 (brownfield) | 143 / 4060 | 4/4/6/**0/0** | M005 (M004 never written) | M005/none/none | 2026-09-13 | 10-29 / 10-29 | KNOWLEDGE/docs live; milestone loop barely used |
| ya/skills | 2026-05-08 | 12 / 36 | 2/2/4/1/0 | M002 | M002/S03/none | **2026-05-22** (body dated 2026-10-14) | 10-14 / 10-14 | `last_updated` abandoned; M002 open since May |
| ya/yesterday-skills | 2026-05-08 | 16 / 82 | 0/0/0/0/0 | -- | none/none/none | **2026-05-26** (body dated 2026-09-14) | 10-03 / 10-13 | 10-day lag; never planned a milestone |
| snippets/prompts/personas/test | 2026-06-20 (subdir of `snippets/prompts` repo) | **0** / 7 | 1/1/0/0/0 | M001 | M001/S01/none | 2026-06-20 | never / 2025-01-01 | all 10 files untracked; work logged as "iter 13..24" in STATE body |

Deprecated scaffolds (counted, not audited): `_deprecated/{yastack,yopstack,ystacks-internal,ystacks}`,
each 4 files (PROJECT/DECISIONS/KNOWLEDGE/STATE), no milestone.

User-level: `~/.ytstack/` holds 19 pairs of `.init-project-<slug>-{completed,scope-prompted}`
sentinels keyed by folder basename, including `my-context-mcp` (the pre-rename of meinkontext),
`luma` (agentic-ui), `prompts` (the test subdir) and two April smoke tests, plus a stale `journal/`.

### 1b. Hook artifacts per repo

| Repo | HANDOFF.md | HANDOFF tracked? / history | journal lines (tracked / ignored) | distinct ids / `unknown` | lines with task=none | draft stubs (`source: post-tool-use-bash-draft`, `closed: draft`) | `.ytstack` dirt in `git status` right now | `.gitignore` covers HANDOFF / journal |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| custom-agent-team | none | -- | 1 (untracked) | 1 / 0 | 1/1 | 0 | `?? journal/` | no / no |
| agent-rpg | pre-compact 06-21 | ignored since 05-31 (4 historic commits, then "chore: untrack hook-generated HANDOFF.md") | 49 (ignored) | 25 / 16 (all pre-06-01) | 41/49 | 0 | `M DECISIONS.md`, `M KNOWLEDGE.md`, `?? OFFICE-HOURS-emergent-agent-society.md` (user edits, since June) | yes / yes |
| llm-wiki | pre-compact 10-17 | ignored | 164 (ignored) | 56 / 96 (all pre-06-01) | 152/164 | **23** (20 still draft: 19 committed M003 stubs + 1 untracked M034-S06-T07; 3 M025 filled but keep the marker) | 25 files (session in flight) incl. `?? M034-S06-T07-SUMMARY.md` | yes / yes |
| risk-ai | none | -- | 7 (**tracked**, 1 unstaged append) | 5 / 0 | 7/7 | 0 | `M journal/sessions.jsonl` | no / no |
| screen-assistant | pre-compact 05-30 | untracked, not ignored | 4 (untracked) | 4 / 1 | 4/4 | 0 | `?? HANDOFF.md`, `?? journal/` | no / no |
| SunoFlow | pre-compact 10-28 | **tracked, 14 commits**; committed version is `event: manual`, 67 lines (09-02); working copy = auto 32 lines | 77 (ignored) | 54 / 18 (2 after 06-01) | 77/77 | 0 | `M HANDOFF.md` (hand-written handoff overwritten) | listed on line 62 but file already tracked, so ineffective / yes |
| mantis | pre-compact 10-17 | untracked, not ignored | 3 (untracked) | 1 / 0 | 2/3 | 0 | `?? HANDOFF.md`, `?? journal/`, `?? M001-S02-T02-PLAN.md` | no / no |
| skills-mcp | pre-compact 07-06, `project: unknown` | untracked, not ignored | 2 (untracked) | 2 / 0 | 2/2 | **2** (M001-S01-T06, M001-S03-T06, both orphaned) | 8 files: `M DECISIONS/KNOWLEDGE/STATE`, `?? HANDOFF.md`, 2 stubs, `?? journal/` | no / no |
| agentic-ui | pre-compact 10-26 with `current_milestone: none` although STATE says M001/S04/T04 | untracked, not ignored | 1 (untracked) | 1 / 0 | 1/1 | 0 | `?? HANDOFF.md`, `?? journal/` | no / no |
| clawrag | none | -- | 7 (ignored) | 3 / 5 | 7/7 | 0 | clean | no / yes (journal only) |
| fast-agent | pre-compact 10-15 | **tracked (1 commit)**; committed = `event: wrapup`, 47 lines (08-28); working copy = auto 32 lines | 2 (untracked) | 2 / 0 | 2/2 | 0 | `M HANDOFF.md`, `?? journal/` | no / no |
| fast-agent-wt-yreview | wrapup 08-28 (committed version intact) | tracked | none | -- | -- | 0 | clean | no / no |
| meinkontext | `event: manual` 11-05, 51 lines | **tracked, 8 commits**: 5 auto pre-compact versions committed 07-19..09-12, then 3 manual on 11-05 | 55 (**tracked**, last commit 09-12; 169 hook-appended lines stripped per #26) | 40 / 0 | 44/55 | 1 (`M034-S04-T05`, untracked at audit start, gone 20 min later; byte-identical copy in rescue worktree `.worktrees/main-hook-files-1105`) | at start: `?? M034-S04-T05-SUMMARY.md`; later clean | no / no |
| moderation-tools | pre-compact 07-11 | **tracked (1 commit)**, auto artifact committed as noise | 15 (**tracked**, 2 unstaged appends) | 14 / 0 | 15/15 | 0 | `M journal/sessions.jsonl` | no / no |
| openclaw-fleet | pre-compact 10-29 | **tracked, 7 commits**, every version an auto pre-compact | 85 (ignored) | 45 / 35 (all pre-06-01) | 85/85 | 0 | `M HANDOFF.md`, `?? handoffs/hermes-agent-toolkit-0.1.0-rc.2/*.tar.gz` (release tarballs inside `.ytstack`) | no / yes (journal only) |
| skills | pre-compact 10-14 | ignored | 11 (ignored) | 2 / 9 | 11/11 | 0 | clean | yes / yes |
| yesterday-skills | **`event: user-triggered` 06-09, 104 lines** (the only genuine `handoff-session` output found) | ignored (survives only because of that) | 11 (ignored) | 5 / 6 | 11/11 | 0 | clean | yes / yes |
| snippets test | none | -- | 3 (untracked) | 2 / 0 | 3/3 | 0 | everything untracked (27 files) | no / no |

Journal position distribution, top buckets: meinkontext `M001/S01/T02` 9, `M001/S01/none` 9,
`M027/none/none` 7; llm-wiki `M004/none/none` 30, `none/none/none` 29; SunoFlow `M004/S02/none` 29,
`M005/none/none` 27; fleet `none/none/none` 37. Mass session-end bursts: on 2026-10-29 six repos
received session-end lines within the same seconds (10:40:13..25 UTC and 13:37:51..13:38:24 UTC),
i.e. a harness restart closing idle sessions, not work. `session_id: unknown` (#21) is gone after
2026-06-01 everywhere (3 stragglers in early June).

### 1c. Worktrees

| Repo | `git worktree list` | Uses `.worktrees/`? | `.ytstack` divergence inside worktrees |
| --- | --- | --- | --- |
| meinkontext | **119** worktrees, all under `.worktrees/` (operator rule 2026-10-27; a 10-27 inventory found 120, 49 under `/private/tmp`, 103 for merged PRs) | yes, mandated | 18 worktrees with `.ytstack` dirt: 4 with hook-appended `journal/sessions.jsonl`, `glitchtip-plan` has `UU .ytstack/STATE.md` (merge conflict on the shared pointer), `review-pr1110-current-1105` has 46 staged `.ytstack` files, `av04-teams-pr` 34, others carry untracked `changelog/entries/*` and `decisions/*`. STATE copies sampled in 4 worktrees are byte-identical to main (M034, 2026-11-05): the pointer is global, never per branch. The rescue worktree `main-hook-files-1105` holds exactly the #26 pollution (HANDOFF 12 lines changed, journal +169, the misattributed stub). |
| agentic-ui | 56: 28 live under `.worktrees/`, 28 prunable under `/private/tmp` | yes | STATE in main says "Continue in `.worktrees/production-cutover-acceptance`"; HANDOFF written with `current_milestone: none` while main STATE says M001/S04/T04 (hook resolved a different `.ytstack`) |
| llm-wiki | 8: main + 2 prunable `/private/tmp` + 6 `.claude/worktrees/*` (EnterWorktree default) | no (`.claude/worktrees/`) | not sampled (worktrees are tool-generated) |
| agent-rpg | 1 now; M005, M018-M021 were built in sibling worktrees `../agent-rpg-m0NN` | no (siblings) | memory: "the ytstack skills pin to CLAUDE_PROJECT_DIR = main, so author worktree files by hand"; STATE merge conflicts "almost always just the append-style .ytstack docs" |
| SunoFlow | 3: main + 2 prunable `/private/tmp`; `.worktrees/` dir exists | partly | n/a |
| clawrag | 3: main + 2 prunable `/private/tmp` | no | n/a |
| fast-agent | 2: main + sibling `fast-agent-wt-yreview` | no | identical `.ytstack` after merge from main; no journal in worktree |
| yesterday-skills | 2: main + `../.worktrees/yesterday-skills-synthetic-users-panel` (collection-dir level) | sibling | n/a |
| all others | 1 | no | -- |

---

## 2. Evidence quotes (verbatim, with path)

### Hooks polluting trees / destroying handoffs

- ytstack issue #26 (meinkontext, 2026-11-05): `git status` on main showed
  `M .ytstack/HANDOFF.md`, `M .ytstack/journal/sessions.jsonl`, `?? .ytstack/M034-S04-T05-SUMMARY.md`;
  "HANDOFF.md had been replaced with an automatic pre-compaction breadcrumb", "sessions.jsonl
  contained 169 additional records from multiple sessions", "The summary was an unfilled automatic
  draft ... referring to an older unrelated commit."
- Rescue copy `meinkontext/.worktrees/main-hook-files-1105/.ytstack/M034-S04-T05-SUMMARY.md`:
  "First commit of this task: `8b6d1d09` -- ops(prod): resume service after the 0117 maintenance
  window (RELEASE-0117) (#617) (2026-10-28T10:31:21Z)". The STATE pointer (M034/S04/T05, plan last
  touched 2026-10-19) was six milestones behind the real work (M040-CONTEXT created 2026-10-26).
- `meinkontext/AGENTS.md:110`: "**Agents never write in the shared main checkout (operator
  2026-10-17):** every change — code, tests, docs, planning, `.ytstack` files — goes through a
  worktree off `origin/main` ... Files left uncommitted in that checkout block everyone's pulls, and
  nobody can tell whose they are".
- `fast-agent`: `git log -1 -- .ytstack/HANDOFF.md` = `988eea8 docs: wrapup - CLAUDE.md, CHANGELOG
  0.1.0, roadmap/state/decisions/knowledge` (committed `event: wrapup`, 47 lines);
  `git diff --stat` today: `17 insertions(+), 32 deletions(-)` -- the pre-compact hook replaced it.
- `SunoFlow`: committed `event: manual`, 67 lines ("docs: land the session in STATE, DECISIONS, the
  roadmap and a real handoff", 2026-09-02); working copy `event: pre-compact` 32 lines;
  `.gitignore:62 .ytstack/HANDOFF.md` is present but ineffective because the file was tracked first.
- `agent-rpg/.gitignore:20-27`: "# ytstack hook-generated artifacts / These are overwritten each
  session by pre-compact / session-end hooks; not useful to commit. If a handoff needs to survive,
  the user writes it via /ytstack:handoff-session which writes to the same path — and if they want
  that one in git, remove it from this ignore manually for that commit." Commit `fb5ff38 chore:
  untrack hook-generated HANDOFF.md (already in .gitignore)` and `12683b6 chore: apply expanded
  ignore rules; untrack hook-generated session journal`.
- `skills/.gitignore:28`, `yesterday-skills/.gitignore:28`, `SunoFlow/.gitignore:60`,
  `llm-wiki/.gitignore:66`: identical hand-written block "# ytstack runtime artifacts (per-install
  session journal — never tracked)". `skills/init-project/SKILL.md` contains no `gitignore`,
  `journal` or `HANDOFF` handling (grep: 0 hits), so every consumer re-invents this.
- `openclaw-fleet` memory `feedback_worktree_escape_push_recovery.md:32`: "RTK garbled `git status`
  ... showed a stale single-file `M HANDOFF.md`" -- the auto-handoff is so routinely dirty that it
  serves as the baseline of a broken status output.

### Draft stubs and their deletion

- `llm-wiki` memory `feedback_never_delete_ytstack_artifacts.md`: "On 2026-05-03 I deleted 13
  untracked auto-draft SUMMARY files ... AND `git checkout HEAD --`'d two more, calling them 'pure
  ytstack-ceremony, kein content'. User reaction: 'WARUM LOESCHEN DU IDIOT' ... 'MACH SOWAS NIE NIE
  NIE NIE WIEDER'." and "The auto-draft SUMMARY files exist because the user wants them as commit
  anchors / triage markers". 19 of those M003 stubs are committed today, still `closed: draft`.
- `agent-rpg/.ytstack/KNOWLEDGE.md:482-495` "## WATCH — ytstack workflow friction": "The
  `post-tool-use-bash` hook auto-creates `M###-S##-T##-SUMMARY.md` stubs ... and leaves them
  UNTRACKED. A worktree branches from a COMMIT → untracked files are invisible there (the M005
  gotcha: had to `cp` CONTEXT/ROADMAP into the worktree)." and "**Two agent sessions in ONE main tree
  collide on `.ytstack`.**"
- `llm-wiki/.ytstack/KNOWLEDGE.md:1396`: "these drafts are first-class artifacts of the user's
  process, NOT noise".

### Ceremony skipped / autonomy demanded

- `screen-assistant/.ytstack/DECISIONS.md:66-70` "## 2026-05-30: Auto-chain the ytstack task loop
  ('Ralph-loop')": "**Context:** User found invoking each `/ytstack:` skill per task too much
  friction." Same block in `agent-rpg/.ytstack/PREFERENCES.md:23` and autonomous mode in
  `risk-ai/.ytstack/PREFERENCES.md:21`.
- `skills/.ytstack/STATE.md`: "**Recovery note:** much of S01/S02/S04 landed informally during the
  recovery push (not via per-task summarize ceremony) on user's 'mach weiter' + frustration with
  ceremony overhead. Slice checkboxes NOT all flipped" and "**M001 (done):** ... Executed directly
  (no formal slice/task pass) on explicit user instruction."
- `fast-agent/.ytstack/STATE.md`: "M002 (agent fleet + operational hardening) delivered feature by
  feature straight to production" and "Do NOT execute the `M003-S0x-PLAN.md` files — M003 was dropped."
- `openclaw-fleet/.ytstack/STATE.md`: "**Note:** M004 (cross-org A2A delivery) was never formally
  closed — it shipped in 0.1.68–0.1.70 but has no CONTEXT/ROADMAP files."
- `moderation-tools`: `M001-CONTEXT.md` 16:14, `M004-SUMMARY.md` 17:44 on 2026-07-11 -- four
  milestones with CONTEXT + milestone-level SUMMARY inside 90 minutes, no slice/task artifacts;
  afterwards six weeks of hotfixes recorded by the `wrapup` skill only.
- `risk-ai`: 20 slice plans, zero task plans; last commit "chore(ytstack): verification policy — one
  bounded delta-scoped reviewer per slice (not zero, not bloated)".
- `llm-wiki` memory `feedback_backlog_by_default.md`: user 2026-05-13: "das sollte default sein damit
  nichts vergessen wird!!" (file deferred items to `.ytstack/backlog/` without asking).

### Brownfield

- `SunoFlow/.ytstack/DECISIONS.md:17-25` "## 2026-05-15: ytstack initialised on existing codebase
  (brownfield import)": options "A) Pretend it's greenfield ... B) Skip ytstack ... C) Brownfield
  import"; "**Reason:** Pitch validation on an already-shipped product is theater."
- `SunoFlow/.ytstack/FRICTION-NOTES.md` (10 items, "Captured live during `ytstack:init-project`"):
  "#3 The 'office-hours first' guidance becomes anti-advice in brownfield ... Skill becomes worse than
  nothing for mature projects." "#7 No way to record 'this project's issue-level execution lives
  somewhere else' (Linear, GitHub Projects, Paperclip, Jira) ... Two parallel trackers, or one
  abandoned tracker." "#8 Sentinel `~/.ytstack/.init-project-<slug>-completed` is keyed by
  `basename(cwd)`, not by repo remote URL." "#9 The skill enforces an `AskUserQuestion` for scope even
  when the answer is overdetermined."
- `SunoFlow/.ytstack/PREFERENCES.md:26-27`: "**Never duplicate `docs/` content into `.ytstack/`** —
  link out instead." "**Paperclip SUNAA is the issue-level execution layer.** Don't re-implement issue
  tracking inside ytstack milestones for BAU work. Reserve milestones for discrete initiatives."
- `openclaw-fleet/.ytstack/DECISIONS.md:24`: "office-hours was intentionally skipped — the premise is
  already validated by a running production product, not a fresh pitch." and `:38`: "ytstack
  `knowledge/` is a *distillation + navigation layer* over docs/ (NOT a replacement); sources stay."
- `llm-wiki/.ytstack/DECISIONS.md:26-29` "Skip plan-ceo-review (concept mode) for initial
  scaffolding ... the project is brownfield-retro".
- `agentic-ui/.ytstack/KNOWLEDGE.md:91`: "The installed init skill has a known existing-project import
  gap (ytstack #18). This repository's memory was explicitly imported from existing behavior and
  operator decisions. Missing historical milestone files are not evidence that Luma is a new project;
  do not fabricate past plans or replay a greenfield interview."
- `clawrag/.ytstack/STATE.md`: `current_milestone: none (reconstructed brownfield — no ytstack
  milestone tracked yet)`; memory `ytstack-brownfield-reconstruction.md`: "there was no
  `OFFICE-HOURS.md` pitch".

### Worktrees, parallel sessions, single global pointer

- `agentic-ui/.ytstack/KNOWLEDGE.md:89`: "Git worktrees have a `.git` file; use `git rev-parse`, not
  a directory-only `.git` check. Installed ytstack preambles currently misidentify this case and
  derive a task-directory slug. Do not initialize a second project from that name. The
  `summarize-task` commit-discovery failure is reported as ytstack #24".
- `agent-rpg` memory `m005-parallel-worktree.md`: "Plan + slice ... authored straight into the
  worktree's `.ytstack/` (the ytstack skills pin to CLAUDE_PROJECT_DIR = main, so author worktree
  files by hand)" and "do NOT co-work the same milestone in the same main tree as another active
  session ... Result: total double-work + collision."
- `llm-wiki` memory `feedback_ytstack_drift_hook_quirk.md`: "the hook scopes edits against the SINGLE
  global `active_task` in STATE.md, so a CONCURRENT session's edits get false-blocked against another
  session's task ... A single global active_task can't represent per-session scope" (#19, fixed in
  0.1.5 by making the hook advisory; the single-pointer model itself is unchanged).
- `mantis/.ytstack/KNOWLEDGE.md:50`: "reassess-roadmap 0.1.6 erwartet active_slice, obwohl
  summarize-task sie nach der letzten Aufgabe auf none setzt ... Zusätzlich produziert
  `grep -c ... || echo 0` bei null Treffern zwei Nullzeilen und scheitert beim Integervergleich."
  `:29`: "Slice-Erkennung des installierten ytstack-Skills verlangt wörtlich `S## -- (to be
  planned)`. M001 hatte bereits beschriebene Slices, aber keine PLAN-Dateien".
- `mantis/AGENTS.md:22`: "Keine Hooks oder automatisches Journaling als aktiv behaupten, ohne es
  überprüft zu haben." `mantis/.ytstack/DECISIONS.md:29` "## 2026-10-17: Keine globalen
  ytstack-Marker ... Alex lehnt die Erstellung der globalen Initialisierungsmarker ausdrücklich ab".
- `meinkontext/AGENTS.md:131`: "`decisions/` (append-only, ONE file per decision ... a PR adds its
  own file, never a shared list — `DECISIONS.md` is only the pointer older citations use, never add
  an entry there)"; `:137`: "No committed file is a generated copy that every release rewrites — such
  a copy conflicts across concurrent PRs".

### Praise / things that work

- `skills` memory `MEMORY.md:3`: "Project state, architectural decisions, and conventions live in the
  repo's git-tracked `.ytstack/` (STATE, DECISIONS, KNOWLEDGE, PROJECT, M0##-*) — injected each
  session by the SessionStart hook. This index holds only what is NOT in the repo."
- `skills/AGENTS.md:35-40`, `yesterday-skills/AGENTS.md:37-42`, `agentic-ui/AGENTS.md:5`,
  `mantis/AGENTS.md:5`, `agent-rpg/CLAUDE.md:18`, `meinkontext/AGENTS.md:3` ("Read `.ytstack/STATE.md`
  FIRST in every session — it is the project dashboard"), `openclaw-fleet/CLAUDE.md:3` ("an
  opinionated index into the ADRs (`.ytstack/docs/DECISIONS.md`) and the distilled knowledge base
  (`.ytstack/knowledge/`)") -- every active repo routes agents to `.ytstack` as the memory layer.
- `llm-wiki/.ytstack/DECISIONS.md:22`: "The project is long-horizon (months of iteration ahead) and
  ytstack's STATE / slice-task discipline is exactly what an unstructured follow-up backlog lacks."
- `SunoFlow` memory `feedback_pitch_artifacts_go_in_ytstack.md`: "office-hours / plan artifacts
  belong in .ytstack/, never docs/plans/; 'no milestone mid-flight' does not mean 'stay out of
  .ytstack'".

---

## 3. Synthesis

### 3.1 What works (used consistently, kept current)

1. **The memory trio (DECISIONS / KNOWLEDGE / STATE) is the real product.** In every active repo the
   last `.ytstack` commit coincides with the last commit overall (meinkontext 1092 of 1945 commits
   touch `.ytstack`, llm-wiki 746 of 1348; SunoFlow KNOWLEDGE 1027 lines, DECISIONS 976; agent-rpg
   DECISIONS 985, KNOWLEDGE 871). Project `AGENTS.md` files in 9 repos tell agents to read `.ytstack`
   first; the `skills` memory index explicitly dedups against it.
2. **Append-only decision logs survive team scale.** meinkontext moved to one-file-per-decision
   (239 files) and one-file-per-changelog-entry (153) precisely because the pattern worked and the
   shared-list file did not.
3. **`backlog/` as a first-class folder** (llm-wiki: 84 open, 49 shipped, 7 rejected; operator: "das
   sollte default sein"), `reviews/`, `research/`, `archive/` -- consumers extend the directory and
   the extensions are stable.
4. **The M/S/T loop does work -- for greenfield, single-session, auto-chained projects.**
   screen-assistant 30 task plans = 30 summaries, mantis 24/21, skills-mcp 57/67, llm-wiki 211/221.
   All of these run with "Ralph-loop"/autonomous mode; none of them is a repo where the human types
   `/ytstack:` per step.
5. **Brownfield "distillation layer" adoption** (fleet, SunoFlow, clawrag, agentic-ui) works when the
   user invents it: `.ytstack/knowledge/` as index over `docs/`, "never duplicate docs into
   `.ytstack`". The plugin did not provide this; the users did, four times, and filed #18.
6. **Fixed bugs stayed fixed.** `session_id: unknown` (#21) is absent after 2026-06-01 in all
   journals; no summary anywhere has duplicate commit lines (#22); the drift hook no longer blocks
   (#19 memories are marked RESOLVED).

### 3.2 What fails

1. **Hooks write into the tracked tree.** 12 of 17 repos have `.ytstack` dirt right now that is
   caused by hooks alone (HANDOFF overwritten in SunoFlow, fast-agent, fleet; journal untracked or
   appended in 8 repos; orphan stubs in 3). Four hand-written handoffs were destroyed
   (`event: wrapup` fast-agent, `event: manual` SunoFlow and meinkontext twice). Twenty-seven
   commits across fleet (7), SunoFlow (14), meinkontext (5) and moderation-tools (1) exist only to
   commit an auto breadcrumb. Only the four repos that hand-wrote `.gitignore` rules are clean;
   `init-project` never writes them. Issues #26/#27 are the meinkontext instance of a pattern visible
   in every repo.
2. **The session journal has no consumer and almost no signal.** 100 % of lines have `task: none`
   in fleet, SunoFlow, moderation-tools, clawrag, skills, yesterday-skills; 93 % in llm-wiki, 80 % in
   meinkontext. Six repos received synchronized session-end lines twice on 2026-10-29 (harness
   restart). `resume-session` does not read it; the pre-compact text still says "(written by
   session-end hook, future)".
3. **The STATE pointer drifts from the real work.** meinkontext points at M034/S04/T05 while M040 is
   six slices in; the hook then attributed a production-maintenance commit to M034-S04-T05.
   `last_updated` is abandoned in skills (05-22 vs body 10-14) and yesterday-skills (05-26 vs
   09-14). Machine fields carry prose (`M004 (done)`, `none (reconstructed brownfield — …)`,
   `post-M001 (live-mode interim, no formal milestone yet)`), a Python `isoformat` timestamp
   (mantis), a date-only value (moderation-tools) and a 258-line frontmatter of `#` status
   comments (agent-rpg). Everything downstream (journal, handoff, stub hook, `reassess-roadmap`
   integer compare) parses these fields.
4. **One global `active_task` vs. many parallel sessions.** meinkontext runs 119 worktrees and
   agentic-ui 56 against a single STATE pointer; all sampled worktree STATE copies are identical to
   main; one worktree has `UU .ytstack/STATE.md`. agent-rpg's M006 collision, llm-wiki's #19
   false-blocks and the "author worktree files by hand because skills pin to CLAUDE_PROJECT_DIR"
   recipe are the same defect. #24 (slug derived from worktree dir) is its init-time twin.
5. **Ceremony is skipped under delivery pressure, and the skip is invisible.** fast-agent 19 task
   plans / 5 summaries, fleet 0 task plans in 4060 commits, risk-ai 0, moderation-tools 0, skills
   "frustration with ceremony overhead", M004 in fleet never written, M003 in fast-agent dropped with
   plans left on disk and a prose warning not to run them. The artifact model has no state for
   "shipped without summaries", "dropped", or "worked at slice granularity".
6. **Milestones planned and never progressed.** screen-assistant M004 (planned 06-02, never sliced),
   agent-rpg M022 (planned, superseded by an untracked OFFICE-HOURS pivot), skills M002/S03 (since
   May), clawrag "decide the first milestone" (since May), custom-agent-team and yesterday-skills
   (never a milestone), the `snippets/prompts` test (M001 roadmap, work tracked as "iter 13..24").
7. **Orphan draft stubs are committed as if they were summaries.** llm-wiki carries 19 committed
   `closed: draft` M003 stubs since May plus 3 filled summaries that still say
   `source: post-tool-use-bash-draft`; skills-mcp has 2 untracked since July. No skill lists or
   reconciles them. The one agent that cleaned up got "WARUM LOESCHEN DU IDIOT".
8. **The flat `M###-S##-T##` namespace does not scale.** meinkontext has ~2000 tracked files in one
   directory, ~300 of them with non-ytstack refs (`WP-03-T45-PLAN.md`, `PBH-*`, `CTX-PG-*`, `MAA-*`,
   `PROD-*`), a bundled `M015-S01-T-SUMMARY.md` (`task: T01-T06`), and milestone-level
   `M00X-SUMMARY.md` in moderation-tools, `AD-HOC-*-SUMMARY.md` in llm-wiki. `summarize-task`
   discovers commits with `git log --grep "^M###-S##-T##:"`; repos using conventional commits or
   squash-merge `(#NNN)` titles (SunoFlow, meinkontext, agentic-ui) get an empty list (#24).
9. **Brownfield is the majority case and still unsupported.** 7 of 17 repos (SunoFlow, llm-wiki,
   clawrag, fleet, agentic-ui, meinkontext's absorb, skills) started with existing code and docs;
   four wrote a DECISIONS entry justifying skipping office-hours; #18 with a complete spec
   (`FRICTION-NOTES.md`) has been open since 2026-05-15.
10. **User-level sentinels** in `~/.ytstack` are keyed by folder basename: `my-context-mcp` vs
    `meinkontext`, `luma` vs `agentic-ui`, `prompts` for a subdirectory experiment; one user
    (mantis) refused them outright in DECISIONS and PREFERENCES.
11. **Duplicates and leftovers.** skills-mcp's `.ytstack` is frozen with 8 dirty files since the
    repo was absorbed; the absorbed copy lives again under
    `meinkontext/.ytstack/research/skills-mcp-import/ytstack/`; fast-agent's worktree carries a
    second full `.ytstack`; fleet keeps 2 release tarballs under `.ytstack/handoffs/`.

### 3.3 Recommendations for the plugin (ranked)

1. **Take session-volatile state out of the tracked tree** (#26, #27; 12/17 dirty repos, 4 destroyed
   handoffs, 27 noise commits). Write pre-compact handoffs and the journal to a gitignored
   `.ytstack/.local/` (or `$XDG_STATE_HOME/ytstack/<repo>/`), resolve the target from
   `git rev-parse --show-toplevel` of the hook's cwd (never `CLAUDE_PROJECT_DIR` when it differs),
   refuse to overwrite a `HANDOFF.md` whose `event` is not `pre-compact`, and have `init-project`
   append the `.gitignore` block that four consumers already wrote by hand. `resume-session` reads
   both locations.
2. **Retire the journal or give it a reader.** With 80-100 % `task: none` and harness-restart bursts
   it is noise; if kept, make it per-session, local, and consumed by `resume-session` ("last 3
   sessions touched M040/S02"). Drop the "future" note from the pre-compact template.
3. **Validate and lint the STATE pointer.** Enforce `M###|none` / `S##|none` / `T##|none` and ISO
   timestamps on write; in `session-start`, warn when `current_milestone` is older than the newest
   `M###-CONTEXT.md` (meinkontext M034 vs M040), when `last_updated` is older than the newest
   `.ytstack` commit (skills, yesterday-skills), or when frontmatter exceeds N lines (agent-rpg).
   This single check would have prevented the misattributed stub in #26.
4. **Make the active task per worktree/branch, not per repo.** Store the pointer in the local state
   dir keyed by branch (or derive it from the branch name / commit prefix) and let skills resolve
   `YT_DIR` from the current worktree. Evidence: 119 + 56 worktrees on one pointer, `UU STATE.md`,
   agent-rpg's hand-copy recipe, llm-wiki's #19 facet, agentic-ui's #24.
5. **Only stub when the commit carries the task ref.** The stub hook should require the commit
   subject to contain the active `M###-S##-T##` (or a configured ref pattern) instead of trusting the
   pointer; and `summarize-task` should accept a configurable commit-ref pattern (`(#NNN)`,
   `WP-03-T45`, Linear keys) or branch-based discovery (#24, SunoFlow/meinkontext/agentic-ui).
6. **Ship brownfield-import (#18).** Seven of seventeen consumers are brownfield; the spec exists in
   `SunoFlow/.ytstack/FRICTION-NOTES.md` (detection probe, backfill from README/docs/package.json,
   link-not-copy KNOWLEDGE, `external_issue_tracker` preference). Add the "too mature for greenfield
   ceremony" anti-pattern to `init-project` and stop recommending `office-hours` when
   `BROWNFIELD_SIGNALS >= 2`.
7. **Make granularity a preference, and make skipping explicit.** Add
   `granularity: milestone|slice|task` (risk-ai and fleet work at slice/milestone level,
   moderation-tools writes `M00X-SUMMARY.md`, meinkontext bundles `T01-T06`), accept slice- and
   milestone-level summaries in `summarize-task`/`reassess-roadmap`, and add milestone states
   `dropped` / `shipped-informally` so fast-agent's "Do NOT execute the M003 plans" and fleet's
   missing M004 become data instead of prose. Document "Ralph-loop" auto-chaining as the default
   mode -- three repos enabled it in PREFERENCES and the repos that did not skipped the loop instead.
8. **Add a reconcile step.** A `reassess-roadmap` (or new `ytstack:reconcile`) pass that lists
   `closed: draft` summaries (llm-wiki 20, skills-mcp 2), filled summaries still marked
   `source: post-tool-use-bash-draft` (3), planned-but-never-sliced milestones (screen-assistant
   M004, agent-rpg M022), and untracked `.ytstack` files, and offers close/archive/delete with the
   user's consent. Pair it with a sentence in `using-ytstack` that `.ytstack` artifacts are
   user-owned and never deleted or reverted by an agent (llm-wiki incident).
9. **Support a scalable layout.** Officially allow `milestones/M0NN/`, `decisions/<date>-<slug>.md`,
   `changelog/entries/`, `backlog/{,shipped,rejected}/` (all already in use in meinkontext and
   llm-wiki) and teach `session-start`/`resume-session`/`summarize-task` to find artifacts there.
   Shared-list files (`DECISIONS.md`, `STATE.md`) are the merge-conflict hot spot in every
   multi-session repo.
10. **Drop the `~/.ytstack` basename sentinels** (FRICTION #8, mantis refusal, `my-context-mcp` vs
    `meinkontext`, `luma`, `prompts`). Record init state in `PROJECT.md` frontmatter; default scope
    to project-level when a git remote exists (FRICTION #9).
11. **Fix the small preamble bugs consumers patched locally**: `grep -c ... || echo 0` double zero
    (mantis KNOWLEDGE:50), slice detection requiring the literal `S## -- (to be planned)`
    (mantis KNOWLEDGE:29), `reassess-roadmap` expecting `active_slice` after `summarize-task` reset it
    to `none`, HANDOFF written with `project: unknown` / `current_milestone: none` when the hook
    resolves a different `.ytstack` than the one the skills use (skills-mcp, agentic-ui).

---

## Appendix A -- raw counts used above

- Repos with any `.ytstack` dirt caused by hooks at audit time: custom-agent-team, risk-ai,
  screen-assistant, SunoFlow, mantis, skills-mcp, agentic-ui, fast-agent, meinkontext (at start),
  moderation-tools, openclaw-fleet, llm-wiki = 12. Clean: agent-rpg (hook files ignored; dirt is user
  edits), clawrag, skills, yesterday-skills, fast-agent-wt-yreview. Not applicable: snippets test
  (nothing tracked).
- `.gitignore` coverage: HANDOFF + journal in agent-rpg, llm-wiki, skills, yesterday-skills; journal
  only in clawrag, openclaw-fleet; SunoFlow lists both but HANDOFF is tracked; none in the other 10.
- HANDOFF `event` values seen: `pre-compact` (12 repos), `manual` (meinkontext, SunoFlow committed
  version), `wrapup` (fast-agent committed version), `user-triggered` (yesterday-skills only).
- Commits whose only `.ytstack/HANDOFF.md` content is an auto pre-compact breadcrumb: openclaw-fleet
  7, meinkontext 5, moderation-tools 1, SunoFlow part of 14 (not individually inspected).
- Task-plan vs. summary counts: screen-assistant 30/30, mantis 24/21, skills-mcp 57/67, llm-wiki
  211/221, meinkontext 104/212 (summaries without M### plans are bundled or non-M refs), SunoFlow
  57/62, agentic-ui 22/21, agent-rpg 44/105, fast-agent 19/5, risk-ai 0/0, moderation-tools 0/0,
  openclaw-fleet 0/0, skills 1/0.
- Journal `task: none` ratio: fleet 85/85, SunoFlow 77/77, moderation-tools 15/15, llm-wiki 152/164,
  meinkontext 44/55, agent-rpg 41/49, risk-ai 7/7, skills 11/11, yesterday-skills 11/11.
- `~/.ytstack`: 38 sentinel files (19 slugs), `journal/` from 2026-04-25.

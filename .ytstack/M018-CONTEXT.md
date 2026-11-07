---
milestone: M018
project: ytstack
created: 2026-11-07T16:00:00Z
size: M
---

# M018 -- Context

## Goal

ytstack's ceremony fits the work instead of the other way round: a project declares its `granularity`, one-sentence changes take a quick lane, autonomous task chaining is a documented default, STATE's pointer cannot silently drift, draft stubs and never-sliced milestones get reconciled with consent, and an always-on minimal-code guard (ponytail-style YAGNI ladder) keeps agents from gold-plating. Audit evidence: 3 repos invented Ralph-loop autonomy, meinkontext's pointer sat at M034 while M040 was live, fast-agent dropped M003 with plans on disk, llm-wiki carries 19 committed draft stubs.

## Exit criteria

- `PREFERENCES.md` (template + `yt_pref <yt_dir> <key> [default]` in the lib) supports `granularity: milestone|slice|task` (default `task`), `autonomy: step|loop` (default `loop` = chain plan-task -> TDD -> verify -> summarize without per-step check-ins, stop at slice boundaries), `quick_lane: on|off` (default `on`), `minimal_code: on|off` (default `on`); `plan-task`, `slice-milestone`, `summarize-task` read them: `granularity: slice` means one PLAN/SUMMARY per slice (no T## files), `granularity: milestone` means one per milestone.
- Milestone/slice/task states in frontmatter: `planned | in-progress | done | dropped | shipped-informally`; `reassess-roadmap` offers `dropped` / `shipped-informally` for a milestone with plans on disk but no execution, and writes the state instead of prose.
- Quick lane: `ytstack:quick-task` -- for a change describable in one sentence: one `Q###-PLAN.md`+`SUMMARY` pair under `.ytstack/quick/`, verification required, no pitch, no review; `using-ytstack` routes one-sentence fix/tweak intents there when `quick_lane: on`.
- STATE pointer lint: `session-start` warns (in the injected block) when `current_milestone` is older than the newest `M###-CONTEXT.md`, when `active_task` points at a task whose SUMMARY already exists, when `last_updated` is older than the newest `.ytstack` commit, or when a frontmatter field is not `M###|S##|T##|none|<ISO>`; `yt_state_lint <yt_dir>` in the lib (tests).
- `ytstack:reconcile` -- lists `closed: draft` summaries, filled summaries with `source: post-tool-use-bash-draft`, planned-never-sliced milestones, untracked `.ytstack` files, orphan `.ytstack/.local`; per group AskUserQuestion close / archive (`.ytstack/archive/`) / keep; never deletes without consent; `using-ytstack` says `.ytstack` artifacts are user-owned and agents never delete or revert them.
- Minimal-code guard: `skills/minimal-code/SKILL.md` (`kind: directive`, always-on via `session-start` when `minimal_code: on`): six-rung ladder (needed at all? exists in codebase? stdlib? dependency? one line? minimum that passes the test), never-cut list (validation, security, accessibility, error handling at boundaries), `shortcut:` debt comments, one small test for non-trivial logic; under 60 lines; attribution to ponytail's idea in NOTICE (concept, own prose).
- Scalable layouts recognised by `session-start`/`resume-session`/`summarize-task`: `milestones/M###/`, `decisions/*.md`, `backlog/{,shipped,rejected}/` (read-side only; writing stays flat).
- Tests for `yt_pref`, `yt_state_lint`, quick-task/reconcile/minimal-code preambles; docs (README workflows, QUICKSTART "Dialing ceremony up or down", concept §3); CHANGELOG `[Unreleased]`; no version bump (0.4.0 together with M019).

## Size

M -- 3 slices, ~12 tasks.

## Decisions locked in discuss phase

- 2026-11-07: see DECISIONS "Ceremony scales with the change" (granularity + autonomy + quick lane + minimal-code guard as preferences with loud defaults).
- 2026-11-07: per-worktree `active_task` is deferred to M019's execution-model work (orchestrator + worktree subagents own the pointer); M018 only lints the single pointer.
- 2026-11-07: M010 lands from the worktree agent before S02 (session-start / init-project edits) to avoid conflicts; S01 touches only new files and plan-task/slice-milestone/summarize-task.

## Open questions

- Quick-task numbering `Q###` vs reusing `M###` with `granularity: milestone`: `Q###` chosen for grep-ability; revisit if consumers object.

## Research basis

`docs/research/2026-11-07-modernisierung-best-practices.md` point 5; `docs/research/2026-11-07-notes/local-consumer-repos-audit.md` §3.2; `developer-skills-landscape.md` (ponytail ladder, Kiro Quick Spec, BMAD 6.12 "Build sizes its ceremony").

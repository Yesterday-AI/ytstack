---
milestone: M018
slice: S01
project: ytstack
created: 2026-11-07T16:00:00Z
status: planned
task_count: 4
completed_tasks: 1
---

# M018-S01 -- Slice Plan

**Goal:** A project can dial ceremony down declaratively and take one-sentence changes through a quick lane, and milestones can be closed honestly (`dropped`, `shipped-informally`) instead of lingering.

## Tasks

- [x] T01 -- `yt_pref <yt_dir> <key> [default]` in `hooks/lib/git-ctx.sh` (reads `key: value` lines from `PREFERENCES.md`, frontmatter or body, quotes stripped, default when absent) + `yt_prefs` convenience that sets `YT_PREF_GRANULARITY`, `YT_PREF_AUTONOMY`, `YT_PREF_QUICK_LANE`, `YT_PREF_MINIMAL_CODE` with defaults `task|loop|on|on`; PREFERENCES template in `init-project` gains a "## Ceremony" block with the four keys and one-line explanations; tests in `tests/git-ctx.test.sh`.
- [ ] T02 -- `plan-task` / `slice-milestone` / `summarize-task` honour `granularity` and `autonomy`: preambles echo `GRANULARITY` and `AUTONOMY`; with `granularity: slice` plan-task writes `M###-S##-PLAN.md` body sections instead of a `T##-PLAN`, summarize-task writes `M###-S##-SUMMARY.md`; with `granularity: milestone` the same at milestone level; with `autonomy: loop` each skill's Terminal State says "continue with the next step without asking" until the slice boundary; the skill-preambles suite asserts the echoes.
- [ ] T03 -- States: `reassess-roadmap` gets a step "Milestones with plans but no execution" offering `dropped` / `shipped-informally` / `keep` and writes `status:` into `M###-ROADMAP.md` + the global ROADMAP row; `plan-milestone` writes `status: planned`; `summarize-task` flips the milestone to `done` when the last slice closes; `session-start` lists milestones in `in-progress`; docs/ux/skill-structure.md documents the enum.
- [ ] T04 -- `skills/quick-task/SKILL.md`: preamble (resolver + `yt_prefs`), HARD-GATE (`quick_lane: off` -> route to plan-task; `.ytstack` missing -> init), one AskUserQuestion-free flow: write `.ytstack/quick/Q###-PLAN.md` (one sentence, files, verification command), do the change with TDD, run verification, write `Q###-SUMMARY.md` (commit list via `yt_task_commits` with pattern `^Q###:`), no pitch/review; `using-ytstack` routes "fix/tweak/rename/bump X" one-sentence intents to it when `quick_lane: on`; added to the skill-preambles suite; `ytstack-check` passes.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`. Slice-level check: `tests/run-all.sh` green; a fixture with `granularity: slice` makes plan-task's preamble echo `GRANULARITY: slice`.

## Notes

- No edits to `init-project` beyond the PREFERENCES template block and to `session-start` beyond none (M010 agent touches both); if the M010 branch lands first, rebase mentally: re-apply on top.

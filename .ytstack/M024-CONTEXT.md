---
milestone: M024
project: ytstack
created: 2026-11-13T16:40:00Z
size: L
---

# M024 -- Context

## Goal

One session can own a plan with dozens of lanes, delegate all of it, lose its context and continue from files: who works on what, what may start, what waits for the human and what the human asked for once and for all are on disk, and a lane reaches a merge only through gates read from the host.

## Exit criteria

- With five slices and blocking edges, `bin/ytstack-frontier` lists exactly the ready ones; claiming a held lane is refused and names the holder.
- A session that resumes after a compaction lists every lane with its next action from `.ytstack/` alone (eval case `coordinator-resume`).
- A status that states a host fact carries the time it was read; nothing about a pull request's state is stored in `.ytstack/` as current (`coordinate`, `finish-lane`, `bin/ytstack-watch --once`).
- A worker's report has `Status:` with the values complete, partial and blocked, plus `Uncommitted:` and `Next:`; the checker rejects a report with a missing field or an inconsistent status.
- `bin/ytstack-finish-lane`: a stale host head starts no review; a head that moved after the review blocks the merge; a body that names a removed test is flagged; a merge happens at the reviewed commit or not at all, and only the human merges unless the project says otherwise.
- A human-only step is one staged script: it passes `bash -n`, every changing command sits behind a confirmation, it ends with a receipt, and the agent never runs it (`bin/ytstack-handover check`).
- A question that a decision or an answered question file answers is not asked; no question is asked twice (`bin/ytstack-questions`, states open, asked, answered).
- A lane retro lists candidates by category with evidence; an accepted one is a check or a pointer, never only new prose (`lane-retro`).
- `bash tests/run-all.sh` passes on macOS and in the Linux container; `bin/ytstack-check` reports no failure; no file under `vendor/` changed.

## Size

L -- 4 slices. See `M024-ROADMAP.md` for slice breakdown.

## Planning input

GitHub issue #34 (seven proposals and two smaller ones, written by the coordinator session of a long migration), the comment of 13 November 2026 on #35 with three measured points for the coordinator (context growth and compactions, polling inside the model, standing instructions lost in a compaction), and the operator's instruction of the same day to build all of the plan in `ROADMAP.md` ("Planned 2026-11-13"), this part included.

## Decisions locked in discuss phase

2026-11-13: The lanes table is its own file, `.ytstack/LANES.md`, linked from `STATE.md`. Issue #34 proposed a table inside `STATE.md`; M022-S03 makes `STATE.md` a pointer with a size bound, and a table with one row per lane would break it.

2026-11-13: Formats first, in one document (`docs/ux/coordinator-format.md`): lanes, blocking edges, the frontier, lane kinds, the report, questions, standing instructions. Skills and scripts point at it.

2026-11-13: Host facts are never stored as current. `.ytstack/` records what the coordinator did and identifiers; a status re-reads the host and says when.

2026-11-13: The lane contract of #34 item 3 is the brief and the report of M023. This milestone adds only lane kinds (`implement`, `review`, `prepare`) and three report labels (`Status`, `Uncommitted`, `Next`).

2026-11-13: The decision queue of #34 item 6 is `.ytstack/questions/`, one file per question. The gate lines of M023 stay; a gate that needs a verdict points at its question file through `blocks`. `reassess-roadmap` remains the place where all open ones go out in one message.

2026-11-13: Who merges is a project preference, `merge_by: human | coordinator`, default `human`. The pipeline script can merge; the skill does not call it without that preference. A merge is the one step of the pipeline that cannot be taken back.

2026-11-13: The finishing pipeline supports GitHub through `gh` and nothing else. Other hosts stop after the commit step.

2026-11-13: The handover script template is ytstack's own text. The idea of a staged script comes from a public skill collection (see issue #34); no text was taken, so NOTICE names the concept only.

2026-11-13: Polling runs in a script (`bin/ytstack-watch`) that prints a line only when something changed. The coordinator does not loop over status reads in the conversation.

2026-11-13: Rotation is a handoff plus current files, triggered after the first compaction or by the host's context indicator. No hook is added for it: `hooks/hooks.json` has no event that fits, and the files make the rotation work on any host.

2026-11-13: Lane retros are a native skill (`lane-retro`). The milestone retro stays the wrapped one.

## Open questions

- Nothing in this milestone ran against a real pull request host or in a real multi-lane run. The first consumer that coordinates with it is the test.
- Whether the host offers an event at subagent start (to inject a claim check there) is still open from M023.

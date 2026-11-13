---
milestone: M022
project: ytstack
created: 2026-11-13T15:10:00Z
size: L
---

# M022 -- Context

## Goal

A fresh session finds what applies now for an area, where it is implemented and how a change is verified, in one spec file per area, without reading plans and history.

## Exit criteria

- `init-project` scaffolds `.ytstack/spec/SPEC.md` and the area files from the pitch and the engineering review, every area `planned` and unverified; `adopt-brownfield` builds them over the existing documents and its codebase maps, pointer-only where a document exists.
- ytstack has its own `.ytstack/spec/` (six areas), and its entry documents agree with the repository: `PROJECT.md`, `KNOWLEDGE.md`, `ROADMAP.md`, `AGENTS.md`.
- The task-plan template has a "Spec impact" section naming the area and section a task changes, or `none`.
- A task whose plan names a spec impact is not summarized unless the area file or one of its `sources` changed with the task, checked from the files; a fix that restores the described behaviour, a refactoring and a trivial edit close with `none`.
- `bin/ytstack-spec drift` lists an area whose `paths` changed after its description was last touched, stays silent for an untouched one and after `verified_at` was set; `bin/ytstack-check` runs `lint` and `drift` on ytstack's own spec.
- `code-review` and the verifier read the touched area against the change and nothing beyond it.
- `resume-session`, `handoff-session` and the SessionStart injection name `spec/SPEC.md` instead of restating it.
- S03, after M020: `yt_state_lint` warns when `STATE.md` exceeds a size bound or carries history; the SessionStart injection shows "Next action" again; closing a milestone folds what still holds into the area files and offers its plans and summaries for archiving through `reconcile`; three fresh-session cases (resume, bug fix, new requirement) compare current against revised instructions.
- `bash tests/run-all.sh` passes and `bin/ytstack-check` reports no failure.

## Size

L -- 3 slices. See `M022-ROADMAP.md` for slice breakdown.

## Planning input

GitHub issue #36, the comments of 13 November 2026 on it, and the operator's instruction of the same day to implement the plan in `ROADMAP.md` ("Planned 2026-11-13"). Milestone number M022 because M020 (Kimi adapter) is planned in the main checkout and not committed, and M021 is the status line segment.

## Decisions locked in discuss phase

2026-11-13: The technical spec gets artifacts of its own (`.ytstack/spec/`), and they come first (operator). Issue #36 as written says "do not mandate a new folder tree"; its author withdrew that wording to this extent in the review comment of the same day. What the issue protects stays: an existing document keeps its authority and nothing is copied (pointer-only).

2026-11-13: A documentation impact is satisfied by a change to the area file or to a source it names. A pointer that is still correct is not edited to close a task (review comment, point 1).

2026-11-13: The drift report is a prompt to look, not a finding. "Contract unchanged" is answered by setting `verified_at`; a change to a source counts like a change to the area file. The report compares against the last commit that touched the description, not against the stamp, so a stamp that a squash merge orphaned cannot break it (review comment, point 2).

2026-11-13: A scaffold from a pitch is `status: planned`, `verified_at: none`. The spec never states deployment or acceptance (review comment, point 3).

2026-11-13: One script `bin/ytstack-spec` with the modes `lint`, `drift`, `impact`, `areas` instead of the planned `bin/yt-spec-drift`: three of the four functions were needed, and the repository's scripts carry the `ytstack-` prefix.

2026-11-13: Section names and order of an area file are fixed; four sections are required (Purpose, Where implemented, How to verify, Decisions that apply now). The other seven are written when the area has something to say, replaced by a link to the source, or left out. Eleven mandatory sections would have produced filler in pointer-only files.

2026-11-13: Size bounds: an area file 200 lines, `SPEC.md` 80 lines, both as lint warnings.

2026-11-13: The codebase maps of `adopt-brownfield` (`.ytstack/codebase/`) stay beside the spec. `SPEC.md` links to them; folding them in would have moved user-owned files.

2026-11-13: Areas are proposed by the skill (from the pitch, or from the architecture map) and confirmed by the human in one question; three to eight per project.

2026-11-13: The one-line pointer to `spec/SPEC.md` in the SessionStart injection is built in S02, not S03. Without it the route to the spec depends on a skill being invoked. The line sits in the closing sentence of the injection, away from the output mode M020 adds.

2026-11-13: The work runs on the branch `spec-and-bounded-work` in a worktree of its own; the plan section was carried over from the shared main checkout as a patch (review comment, point 4).

## Open questions

- S03 waits for M020 (`hooks/session-start`, `STATE.md`). The size bound for `STATE.md` and the fold step are designed then.
- How many runs per case the fresh-session comparison needs and what it may cost (S03).

---
milestone: M024
slice: S01
task: T01
project: ytstack
closed: 2026-11-13T16:50:00Z
verification: passed_with_caveats
---

# M024-S01-T01 -- Summary

## Commits

- The commit that carries this file (`M024-S01-T01: coordinator formats and the decision entry`).

## Outcome

`docs/ux/coordinator-format.md` was written first and the scripts and skills of M024 were built to it. It defines `LANES.md`, the `**Blocked by:**` line and the frontier, the lane kinds, the report, `questions/`, `STANDING.md` and the list of mechanical checks. `DECISIONS.md` gained the entry "2026-11-13: Coordinator mode keeps lanes, questions and standing instructions in files and reads host facts fresh (M024, issue #34)". `M024-CONTEXT.md`, `M024-ROADMAP.md` and the four slice plans were written.

## Deviations from plan

- Issue #34 proposed the lanes table inside `STATE.md`. It is its own file, `.ytstack/LANES.md`, linked from `STATE.md`: M022-S03 made `STATE.md` a pointer with a size bound, and one row per lane would break it.
- The paragraph on the frontier states three rules that go beyond the first brief of `bin/ytstack-frontier`: a `merged` row counts as done, a `blocked` row is listed as blocked, and a lane named under `blocks:` of an open or asked question is blocked. They are recorded with M024-S01-T02.

## Follow-ups

- Nothing in M024 ran against a real pull request host or in a real multi-lane run. The first consumer project that coordinates with these formats is the test (`M024-CONTEXT.md`, "Open questions").
- Not built: a hook or host event at subagent start that checks a claim. Whether the host offers such an event is still open from M023.

## Spec

- artifacts: `docs/ux/coordinator-format.md` (a source of `.ytstack/spec/artifacts.md`); the area file -- Behavior ("Files and writers", "STATE.md is a pointer; host facts are not stored"), Decisions that apply now
- checks-and-evals: `docs/ux/coordinator-format.md` (a source of `.ytstack/spec/checks-and-evals.md`); the area file -- Behavior ("The coordinator scripts"), Decisions that apply now
- skills: `.ytstack/spec/skills.md` -- Behavior ("Coordinating many lanes"), Decisions that apply now

The area files were uncommitted when the closure check ran: nothing on this branch is committed before the operator saw the whole change. Their statements for this task are committed with M024-S04-T04.

## Verification

Command: `bash bin/ytstack-spec lint; python3 bin/ytstack-check` -- passed at the working tree on top of `f4f54ab` in the local checkout (macOS, bash 3.2). `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`, exit 0; the checker exited 2 with `OK (with 27 warning[s])` and no `[fail]` line.

Not checked: no check reads the content of the document. The two commands show that it exists where the area files point and that the tree is well-formed; that the scripts follow the formats is what the suites of T02, T03 and of S02 to S04 show. The checker does not scan `docs/` for the em-dash character; a count over the file gave 0.

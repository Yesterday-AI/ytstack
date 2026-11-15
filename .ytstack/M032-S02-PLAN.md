---
milestone: M032
slice: S02
project: ytstack
created: 2026-11-15T01:40:00Z
status: in-progress
task_count: 2
completed_tasks: 1
---

# M032-S02 -- Slice Plan

**Goal:** One shared step, the skill `ytstack:lesson`, classifies an incident in one line, routes its lesson to a machine check first and a knowledge entry or a proposal second, records it with `ytstack-signals lesson new`, and `incident`, `systematic-debugging`, `finish-lane` and `coordinate` end with it.

**Blocked by:** S01

## Tasks

- [x] T01 -- `skills/lesson/SKILL.md` (preamble with the open lessons and incidents, class line, route, record, put in place, one question for a proposal, check and report) and every listing that names skills: `using-ytstack`, `docs/concept.md`, `docs/codex.md`, `docs/kimi.md` (skill count), `evals/README.md`, the `skills` area file; the preamble case in `tests/skill-preambles.test.sh`; the eval case `evals/lesson/`.
- [ ] T02 -- The four callers end with `ytstack:lesson`: `incident` (after mitigation, `--incident`; closing needs the lesson), `systematic-debugging` (wrapper text only, after the root cause), `finish-lane` (a review that requested changes, a lens that failed, a red check), `coordinate` (a red `main`). Terminal States allow it; `metadata.version` bumps; assertions in `tests/skill-preambles.test.sh`; the `skills` area file.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Open question 1 of `M032-CONTEXT.md` (own skill or a section): own skill, called by name, so the four paths stay short and an eval can trigger it.
- README and QUICKSTART are edited by another worker in parallel; the proposed text goes into the slice report.

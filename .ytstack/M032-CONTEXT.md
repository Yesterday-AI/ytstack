---
milestone: M032
project: ytstack
created: 2026-11-15T00:45:00Z
size: M
---

# M032 -- Context

## Goal

Every incident of any class (production, CI, evidence and receipts, review-caught defects, process slips of agents or the coordinator) ends in the same lesson loop: classify, route the lesson to a machine check first and a knowledge entry second, record it, and surface repeats, as a shared step no skill path can skip.

## Exit criteria

- One shared step (a skill or a section the paths call) that `incident` (after mitigation), `systematic-debugging` (after the root cause), `finish-lane` (when a review blocked or a check went red) and `coordinate` (on a red `main`) end with. It classifies the incident in one line, routes the lesson (test, guard, CI step or alert first; otherwise a `KNOWLEDGE.md` entry or the lane contract; never one more sentence in AGENTS.md or CLAUDE.md) and records it.
- Incidents and their lessons are records with a class and a target (reusing the signals ledger where it fits, `kind: incident` or a sibling), so a repeated class raises a count instead of a new record; a check (`ytstack-signals check` or `ytstack-lessons check`) fails when a recorded incident has no lesson with a target.
- `coordinate` shows the open-lessons count in its status; a lesson that is only a proposal goes to the person with the daily question; lesson lanes can be dispatched through the frontier.
- `retro` reports incidents per class and repeats for the window.
- Docs, CHANGELOG; all suites, checker, spec lint/drift, Codex and Kimi tests, plugin validation; an eval case for the shared step.

## Size

M -- 3 slices.

## Planning input

Issue #53 and its scope clarification: learning from incidents in general, as a standing behaviour, not only production incidents; ideally a shared step the existing skills call so no path can skip it. Eight such incidents in one coordinator day in context-mcp, several repeats of the same class.

## Decisions locked in discuss phase

2026-11-15: Machine check before knowledge entry; a new rule sentence in an instruction file is never the lesson (matches the `coordinate` anti-pattern).

2026-11-15: Reuse the signals ledger and `review-lessons` patterns (class key, count, state) before adding a new record type.

## Open questions

- Shared step as its own skill (`lesson`) or as a section in an existing one? Plan: own skill, called by name, so the paths stay short and an eval can trigger it.
- Where the dated retro record lives: `.ytstack/signals/` next to the other kinds, or `.ytstack/archive/<date>/incident-retro.md` as the issue proposes.

---
milestone: M018
project: ytstack
size: M
created: 2026-11-07T16:00:00Z
status: planned
total_slices: 3
completed_slices: 0
---

# M018 Roadmap

**Goal:** ceremony scales with the change -- preferences (`granularity`, `autonomy`, `quick_lane`, `minimal_code`), quick lane, states incl. `dropped`/`shipped-informally`, STATE pointer lint, reconcile pass, minimal-code guard, scalable layouts.

**Exit criteria:** see `M018-CONTEXT.md`.

## Slices

- [ ] S01 -- Preferences + states + quick lane: `yt_pref`, PREFERENCES template fields, `granularity`/`autonomy` honoured by plan-task / slice-milestone / summarize-task, state enum incl. `dropped`/`shipped-informally` in reassess-roadmap, `ytstack:quick-task` (4 tasks)
- [ ] S02 -- Pointer lint + reconcile + minimal-code guard: `yt_state_lint` + session-start warnings, `ytstack:reconcile`, `skills/minimal-code` directive + injection, user-owned-artifacts rule in using-ytstack (4 tasks; after M010 merge)
- [ ] S03 -- Scalable layouts read-side + docs + tests + CHANGELOG (3 tasks)

## Run order

S01 now (no overlap with the M010 worktree agent); merge M010; S02; S03. After each slice, `ytstack:reassess-roadmap`.

## How to update this file

- Flip slice checkbox `[ ]` -> `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` -> `status: done` and update global ROADMAP.md

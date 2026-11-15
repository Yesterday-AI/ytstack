---
milestone: M034
project: ytstack
size: M
created: 2026-11-15T12:00:00Z
status: planned
total_slices: 3
completed_slices: 0
---

# M034 Roadmap

**Goal:** An operator who switches between agent sessions sees at a glance what each session is doing: the current todo item and n of m done stay visible in the host's status line on every host that has one, with optional herdr and terminal-title sinks.

**Exit criteria:** see `M034-CONTEXT.md`.

## Slices

Slice detail lives in per-slice `M034-S##-PLAN.md` files, created by `ytstack:slice-milestone`.

- [ ] S01 -- A todo reader per host: Claude Code task files, Codex plan, Kimi to-dos (find each source, record fixtures, degrade to nothing), one output form.
- [ ] S02 -- `ytstack-status` shows the todo state as its first line and optional extra lines, fast; Codex `task-progress` and per-host wiring in `docs/statusline.md` and QUICKSTART.
- [ ] S03 -- Optional sinks fed by a ytstack hook after the todo tools: herdr pane metadata and the terminal title, off by default in `~/.ytstack/config`.

## Run order

S01 first (S02 and S03 read through it); S02 and S03 can run in parallel. After each slice, `ytstack:reassess-roadmap` checks if the plan still fits.

## How to update this file

- Flip slice checkbox `[ ]` to `[x]` when its tasks are all `summarize-task`-confirmed
- Update `completed_slices` count
- On milestone completion, flip `status: planned` to `status: done` and update global ROADMAP.md

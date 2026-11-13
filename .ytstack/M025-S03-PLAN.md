---
milestone: M025
slice: S03
project: ytstack
created: 2026-11-13T18:09:00Z
status: planned
task_count: 5
completed_tasks: 4
---

# M025-S03 -- Slice Plan

**Goal:** A kind of change can require a second, independent review with its own evidence; a user interface gets a visual one.

**Blocked by:** S01, S02

## Tasks

- [x] T01 -- Lenses in `bin/ytstack-risk`: required lenses from `applies`, lens lines in `route`, the manifest check for `evidence: visual`.
- [x] T02 -- `bin/ytstack-brief render --kind review --lens <name>`: the lens line, its documents and the evidence rules in the brief.
- [x] T03 -- The skill `visual-review`: the reviewer starts the product itself, operates it in a browser, takes its own screenshots, writes manifest and record, never edits.
- [x] T04 -- `code-review` and `finish-lane` dispatch the required lenses and record them.
- [ ] T05 -- Eval cases, README, concept, CHANGELOG, `using-ytstack`, the area files, DECISIONS and KNOWLEDGE; close M025.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

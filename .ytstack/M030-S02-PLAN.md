---
milestone: M030
slice: S02
project: ytstack
created: 2026-11-14T15:30:00Z
status: planned
task_count: 2
completed_tasks: 0
---

# M030-S02 -- Slice Plan

**Goal:** Projects declare their own reviewers in `REVIEW.md`, and escapes are recorded and counted as signals of `kind: review`.

## Tasks

- [ ] T01 -- `## Own reviewers` in `REVIEW.md`: one line per role, `<role> | marker: <text the role's findings carry> | lessons: <path of the role file> | bots: <comma list of logins, optional>`; format in `docs/ux/review-policy-format.md`, validation in `bin/ytstack-risk check` (paths exist, markers unique), read by `bin/ytstack-review-escapes`.
- [ ] T02 -- `kind: review` in `docs/ux/signal-format.md` and `bin/ytstack-signals`: key `review:<role>:<class-slug>`, the sighting block quotes the bot thread URL, file, lines and severity; rejected findings are never recorded. Tests in the existing signals suite.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

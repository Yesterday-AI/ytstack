---
milestone: M021
project: ytstack
created: 2026-11-11T10:25:52Z
size: M
---

# M021 -- Context

## Goal

Any status line script can append one compact ytstack segment that shows project progress and the current task of the directory it runs in, read from `.ytstack/STATE.md` without per-project scraping.

## Exit criteria

- With a `progress` block in the `STATE.md` frontmatter, `bin/ytstack-status` prints label, percentage and done/total; with `waiting_on` set it also prints that item, truncated.
- Without the block it prints the active slice's task count taken from the checkboxes in `M###-S##-PLAN.md`.
- Outside a ytstack project it prints nothing and exits non-zero.
- In a linked worktree the plan progress comes from the default branch and the task pointer from the worktree's own `STATE.md`.
- A malformed block prints nothing; `yt_state_lint` reports it (integers, `done <= total`, short label).
- `summarize-task` and `quick-task` keep the block current when they advance STATE.
- `docs/statusline.md` documents the block, the two-line integration and a stable script location that survives plugin updates; README and CHANGELOG point at it.
- `bash tests/run-all.sh` passes and `bin/ytstack-check` reports no new failures.

## Size

M -- 2 slices. See `M021-ROADMAP.md` for slice breakdown.

## Planning input

GitHub issue #31 and the user's instruction to implement it. Milestone number M021 because M020 (Kimi adapter, issue #30) is planned in the main checkout and not committed yet.

## Decisions locked in discuss phase

2026-11-11: Exactly one `progress` track with `label`, `done`, `total` and optional `waiting_on`, as the issue proposes. Several named tracks and a `done`/`open` pair (the issue's open questions) stay out until a project needs them; the single block can be extended to a list later without breaking readers.

2026-11-11: One parser for the block lives in `hooks/lib/git-ctx.sh` and serves both the status script and the STATE lint, so the two cannot disagree about what is malformed.

2026-11-11: No network and no `gh` in the status script. The default branch is read from local refs only.

## Open questions

(none)

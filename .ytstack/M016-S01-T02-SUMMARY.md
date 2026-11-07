---
milestone: M016
slice: S01
task: T02
project: ytstack
closed: 2026-11-07T11:31:18Z
verification: passed
---

# M016-S01-T02 -- Summary

## Commits

- `31057df` -- M016-S01-T02: plan pre-compact rewrite
- `d1a99fc` -- M016-S01-T02: pre-compact writes auto handoff out-of-tree, never touches HANDOFF.md, emits compaction instructions

## Outcome

`hooks/pre-compact` sources `hooks/lib/git-ctx.sh`, reads the PreCompact payload, resolves the checkout from `cwd` (hook cwd when no payload; never `CLAUDE_PROJECT_DIR`) and exits silently when no `.ytstack` resolves. It writes `HANDOFF.auto.md` (frontmatter: event, trigger, timestamp, session_id, project, M/S/T, worktree, main_toplevel, linked_worktree, ytstack_dir; body: position, STATE's Next action trimmed to 5 lines x 400 chars, reading list) into the per-session state dir and refreshes `<worktree-state>/latest-handoff` via create-beside-then-rename. `.ytstack/HANDOFF.md` is never opened for writing and never created. stdout carries compaction guidance (what to preserve, which paths to re-read), capped at 9,000 chars; exit is always 0.

## Deviations from plan

The plan's fallback "last `cwd` recorded by `post-tool-use-bash`" was dropped as circular (the state dir is keyed by the very `cwd` we would be looking up); the fallback is the hook's own `$PWD`, which Claude Code sets to the session cwd. Test 7 (fallback into `.ytstack/.local`) is included as planned.

## Follow-ups

- `resume-session` and `session-start` must read `latest-handoff` (S01-T05, S02-T04).
- The compaction guidance quotes STATE's Next action; repos with paragraph-length Next-action sections (this one) get 5 x 400 chars. Consider a `## Next action` style rule in `docs/ux` later (not M016).

## Verification

Command: `bash -n hooks/pre-compact && /bin/bash tests/pre-compact.test.sh` -- passed (39/39). `/bin/bash tests/git-ctx.test.sh` 46/46, `bash tests/post-tool-use-bash.test.sh` 10/10.

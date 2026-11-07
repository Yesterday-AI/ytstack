---
milestone: M016
slice: S02
task: T03
project: ytstack
closed: 2026-11-07T12:17:53Z
verification: passed
---

# M016-S02-T03 -- Summary

## Commits

- `1589699` -- M016-S02-T03: plan gitignore block + sentinel retirement
- `e6a67c5` -- M016-S02-T03: init-project writes .ytstack/.local gitignore block, records init/scope in PROJECT.md; sentinels retired

## Outcome

`hooks/lib/git-ctx.sh` gained `yt_ensure_gitignore <toplevel>`: idempotently appends a marked block (`# ytstack local state ...` + `.ytstack/.local/`) to `<toplevel>/.gitignore`, on its own line even when the file lacks a trailing newline, and reports `YT_GITIGNORE=written|unchanged|skipped`; it never ignores `.ytstack/HANDOFF.md`. `init-project` Step 6 calls it (skipped for user-only scope), the checklist and process flow say "Write `.gitignore` block", the `PROJECT.md` template carries `init_completed:` and `scope:`, and the `~/.ytstack/.init-project-*` sentinels are gone; `plan-milestone` dropped its `.milestone-size-*-prompted` hint. `grep -rn '~/.ytstack/\.' skills/` is empty. git-ctx suite 65 cases.

## Deviations from plan

None.

## Follow-ups

- `init-project` still shows `_PROJECT_SLUG` for display; fine.
- S02-T05 adds the `ytstack-check` rule that keeps sentinel paths out for good.

## Verification

Command: `/bin/bash tests/git-ctx.test.sh && /bin/bash tests/skill-preambles.test.sh` -- passed (65 / 187). `grep -rn '~/.ytstack/\.' skills/` empty. `bin/ytstack-check` 0 fails.

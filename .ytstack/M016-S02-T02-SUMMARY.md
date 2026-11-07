---
milestone: M016
slice: S02
task: T02
project: ytstack
closed: 2026-11-07T12:09:03Z
verification: passed
---

# M016-S02-T02 -- Summary

## Commits

- `5c6a4aa` -- M016-S02-T02: plan configurable commit discovery + branch fallback
- `ec0cea2` -- M016-S02-T02: shared commit-ref pattern + task commit discovery with branch fallback (lib, summarize-task, hook)

## Outcome

`hooks/lib/git-ctx.sh` gained `yt_commit_ref_pattern <yt_dir> <M> <S> <T>` (reads `commit_ref_pattern` from `PREFERENCES.md`, strips surrounding quotes, renders `M###`/`S##`/`T##`/`{task}`, default `^M###-S##-T##:`) and `yt_task_commits <toplevel> <pattern>` (ERE grep over history; if empty, commits since the merge-base with `origin/HEAD`/`origin/main`/`origin/master`/`main`/`master`; sets `YT_COMMITS`, `YT_COMMITS_SOURCE=task-ref|branch|none`, `YT_COMMITS_BASE`). `summarize-task` uses both when the lib is loaded (inline ERE grep otherwise), echoes `COMMIT_PATTERN`, `TASK_COMMITS_SOURCE`, `TASK_COMMITS_BASE`, and Step 8 writes the `## Commits` section by source: task-ref list, branch list with the base named, or an honest "no commits found" that no longer guesses "shipped uncommitted". `post-tool-use-bash` calls the shared pattern function (19 tests unchanged). git-ctx suite now 55 cases.

## Deviations from plan

None. One test expectation had an escaping mistake (fixed in the test).

## Follow-ups

- Live check on this repo: with `origin/main` 50+ commits behind, the branch fallback lists everything since the last push; acceptable (it only triggers when no subject matches), but the docs should say that the fallback is "since the default-branch merge-base", so a long-unpushed main yields a long list.

## Verification

Command: `/bin/bash tests/git-ctx.test.sh && /bin/bash tests/post-tool-use-bash.test.sh && /bin/bash tests/skill-preambles.test.sh` -- passed (55 / 19 / 187). All other suites green (pre-compact 39, session-end 32, hooks-readonly 37, hooks-json 45). `bin/ytstack-check` 0 fails.

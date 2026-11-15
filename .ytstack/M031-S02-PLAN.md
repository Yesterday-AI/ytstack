---
milestone: M031
slice: S02
project: ytstack
created: 2026-11-14T23:45:00Z
status: done
task_count: 3
completed_tasks: 3
---

# M031-S02 -- Slice Plan

**Goal:** `ytstack-risk route` reads the review round from the host, so a repository with a head-bound review gate can still route `unattended`.

## Tasks

- [x] T01 -- `bin/ytstack-risk route --pr N [--repo OWNER/NAME]`: the round and lens lines come from the reviews of the pull request (GitHub reviews API: `commit_id`, `user.login`, `author_association`, `state`, `body`), the plan is the fallback when no review carries a line, and `--plan` becomes optional with `--pr`. A review counts only from an owner, member or collaborator, not pending, not dismissed; its line must name the commit the host tied the review to. A failed read, a mismatch or a change request routes to a person. Red fixture test of the context-mcp case first (issue #54 comment, context-mcp #1715). Files: `bin/ytstack-risk`, `tests/ytstack-risk.test.sh`, `docs/ux/review-policy-format.md`. Verify: `/bin/bash tests/ytstack-risk.test.sh`.
- [x] T02 -- `bin/ytstack-finish-lane route --pr N`: passes the pull request on, routes a lane without a plan file from the host's reviews, names the pull request in its first line. Files: `bin/ytstack-finish-lane`, `tests/ytstack-finish-lane.test.sh`. Verify: `/bin/bash tests/ytstack-finish-lane.test.sh`.
- [x] T03 -- The writing side: `finish-lane` Step 7 and 8 post the round line and the lens lines in the review body, Step 9 passes `--pr`; `code-review` posts its lines on the open pull request of the branch; spec areas `checks-and-evals` and `skills`, skill versions. Files: `skills/finish-lane/SKILL.md`, `skills/code-review/SKILL.md`, `.ytstack/spec/checks-and-evals.md`, `.ytstack/spec/skills.md`. Verify: `bin/ytstack-check; bash bin/ytstack-spec lint; bash bin/ytstack-spec drift; bash tests/run-all.sh`.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Field case: in context-mcp agents may not write in the main checkout, and a ruleset counts only reviews on the current head. The round line had to be committed on the pull request's branch, which moved the head: the host's review no longer counted, and the plan in the main checkout had no line. Every route ended `person`.
- Not in scope: counting rounds from the host. The round number stays the lane's `Round` cell; the host carries the record of each round.

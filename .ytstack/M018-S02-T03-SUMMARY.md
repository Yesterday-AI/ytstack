---
milestone: M018
slice: S02
task: T03
project: ytstack
closed: 2026-11-07T13:38:04Z
verification: passed
---

# M018-S02-T03 -- Summary

## Commits

- `2b012b7` -- M018-S02-T03/T04: plan reconcile skill + minimal-code guard
- `5ae81df` -- M018-S02-T03: reconcile skill (consent-based cleanup of .ytstack leftovers, archive never delete); using-ytstack: artifacts are user-owned

## Outcome

`skills/reconcile/SKILL.md` finds five leftover classes read-only in its preamble (draft stubs, unfilled auto-drafts, planned-never-sliced milestones, untracked `.ytstack` files, `.local` without gitignore), echoes counts and lists, and asks one AskUserQuestion per non-empty class (close / archive to `.ytstack/archive/<date>/` / keep; stage for untracked; gitignore for `.local`), applies moves only inside `.ytstack/`, never deletes, and writes `RECONCILE-<date>.md`. `using-ytstack` now states that `.ytstack/` artifacts are user-owned and that `reconcile` is the only sanctioned cleanup (the llm-wiki deletion incident). Skill-preambles suite 249 cases (fixture with one stub, one planned-never-sliced roadmap, three untracked files).

## Deviations from plan

None.

## Follow-ups

- Docs (S03-T02): README/QUICKSTART mention reconcile.

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && bin/ytstack-check` -- passed (249/249; checker 0 fails, 19 warnings).

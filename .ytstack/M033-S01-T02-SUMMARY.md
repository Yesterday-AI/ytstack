---
milestone: M033
slice: S01
task: T02
project: ytstack
closed: 2026-11-15T01:10:00Z
verification: passed
---

# M033-S01-T02 -- Summary

## Commits

- The commit that carries this file (`M033-S01-T02: the upstream feedback channel in docs/ux and using-ytstack`).

## Outcome

`docs/ux/upstream-feedback.md` defined the channel: the four kinds (`bug`, `gap`, `proposal`, `evidence`) with an example each, when each goes upstream (at the moment, at the end of `retro` and `lane-retro`, in `lesson`, in `review-lessons`), the three values of `upstream_feedback` and why `file` is opt-in, the steps with `bin/ytstack-upstream` and `gh`, the five rules, what stays out (the project's own bugs, wishes without a run, a dispatched worker on its own) and what a machine checks. `using-ytstack` (0.3.0) replaced "Reporting ytstack issues" with "Feeding ytstack upstream": what goes upstream, the setting, `ytstack-upstream mode` for the value and the path of the rules, and "never work around a ytstack bug silently". `ytstack-upstream mode` printed `rules:` with the path of the document in the plugin. The `PREFERENCES.md` templates of `init-project` (0.2.2, `## Ceremony` block) and `adopt-brownfield` (0.3.1) carried `upstream_feedback: suggest` with a comment naming the three values.

## Deviations from plan

- none

## Follow-ups

- `review-lessons` is named in the document as a source of proposals but its procedure was not changed: the exit criteria name only `retro`, `lane-retro` and `lesson` for skill changes.

## Spec

- skills: written in T04

## Verification

Command: `bash tests/ytstack-upstream.test.sh && bash tests/hooks-readonly.test.sh && bin/ytstack-check` -- `68 passed, 0 failed`, `70 passed, 0 failed` (fixture injection 9,188 characters), checker exit 2 `OK (with 12 warning[s])`, no `[fail]` (nine known section warnings, three spec drift warnings closed in T04). The SessionStart injection of this checkout measured 9,760 characters with the new paragraph (9,665 before), under the 10,000 cap. At the working tree on top of `d6cb145`, local checkout (macOS, bash 3.2).

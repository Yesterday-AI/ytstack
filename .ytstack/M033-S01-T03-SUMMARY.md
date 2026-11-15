---
milestone: M033
slice: S01
task: T03
project: ytstack
closed: 2026-11-15T01:30:00Z
verification: passed
---

# M033-S01-T03 -- Summary

## Commits

- The commit that carries this file (`M033-S01-T03: Upstream sections in retro and lane-retro, the ytstack route in lesson`).

## Outcome

`retro` (1.3.0), `lane-retro` (0.2.0) and `lesson` (0.2.0) printed `UPSTREAM_FEEDBACK` (the effective mode from `bin/ytstack-upstream mode`, or `unavailable`) and `UPSTREAM_TOOL` in their preambles. `retro` got step 13 "Upstream" and a `## Upstream` section that is always kept in `M###-RETRO.md`; `lane-retro` got Step 10 "Upstream" and a `## Upstream` section in `LANES-<date>.md`; both list what concerns ytstack itself with kind and evidence, then follow the setting: `off` sends and suggests nothing, `suggest` drafts and checks and sends nothing (the line ends with the draft path), `file` files or comments (the line ends with the issue number, or `not sent:` with the check's problem). `lesson` routed a class that is a behaviour of the plugin to its new Step 8 in addition to the project's own target, with an `Upstream:` line in its report. In non-interactive mode nothing is sent under any setting. None of the three repeats the rules; each points at `docs/ux/upstream-feedback.md`, which now also says that work in the ytstack repository itself does not go through the channel.

## Deviations from plan

- Found while adding the cases: the M032 `retro` checks in `tests/skill-preambles.test.sh` sat in a second `retro)` branch of the outer `case`, after the `office-hours|...|retro|...` branch, so they never ran. They were moved into the reachable inner `retro` branch (with a fresh preamble run first) and pass.

## Follow-ups

- none

## Spec

- skills: written in T04

## Verification

Command: `bash tests/skill-preambles.test.sh && bin/ytstack-check` -- `663 passed, 0 failed`; checker exit 2, no `[fail]` line. Red first against the skills of `a0d4f55`: `645 passed, 18 failed` (the six `upstream_checks` cases for each of the three skills). At the working tree on top of `a0d4f55`, local checkout (macOS, bash 3.2).

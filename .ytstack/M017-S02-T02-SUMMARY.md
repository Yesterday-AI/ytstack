---
milestone: M017
slice: S02
task: T02
project: ytstack
closed: 2026-11-07T13:06:53Z
verification: passed
---

# M017-S02-T02 -- Summary

## Commits

- `14f90bc` -- M017-S02-T02: plan gstack wrappers on Skill invocation
- `903fc0c` -- M017-S02-T02: gstack wrappers run precheck + Skill-tool invocation of the installed gstack skill; no cat-inlining of vendor/gstack

## Outcome

`office-hours`, `plan-ceo-review` and `plan-eng-review` no longer inline `vendor/gstack/*/SKILL.md`. Their render-time preambles call `yt_gstack_ctx` and echo `GSTACK_AVAILABLE`, `GSTACK_DIR`, `GSTACK_VERSION`, `GSTACK_PIN_OK`, `GSTACK_SKILL_OK`, `BUN_OK`, `GSTACK_INSTALL_CMD` (or `unknown` when the lib is not loaded); a `## HARD-GATE: gstack installed?` section stops with the one-line pinned install command when gstack is missing (mode abort first for the two review wrappers), warns on an older install or missing bun, and never improvises the procedure; `## Procedure` invokes the installed gstack skill through the Skill tool (answering its "which plan" question from the detected mode) and then applies the unchanged ytstack post-processing; `## Checklist` and `## Terminal State` sections satisfy the UX contract now that no vendor text fills them. Descriptions and intros say "installed gstack ... pinned v1.96.0.0, needs bun >= 1.4.2". `tests/skill-preambles.test.sh` (210 cases) checks the precheck flags with an empty HOME and with a fake install and asserts no `vendor/gstack` reference remains. `bin/ytstack-check` warnings fell from 109 to 19 because the gstack sibling-skill refs disappeared.

## Deviations from plan

The checker's required-section rule now applies fully to these wrappers (previously masked by the inlined vendor text), so `## Terminal State` headings were added; office-hours' inline "**Terminal State:**" became a heading.

## Follow-ups

- Live validation of the Skill-tool route against a real install: S02-T04.
- `claude plugin validate` and the two review wrappers' `allowed-tools` should include `Skill` if the host enforces it -- verify in T04 (the Skill tool is always available to skills today).

## Verification

Command: `/bin/bash tests/skill-preambles.test.sh && bin/ytstack-check` -- passed (210/210; checker 0 fails, 19 warnings). `grep -c 'vendor/gstack'` on the three wrappers: 0 (only "not vendored" prose remains).

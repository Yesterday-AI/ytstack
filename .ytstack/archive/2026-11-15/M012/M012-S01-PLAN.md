---
milestone: M012
slice: S01
project: ytstack
created: 2026-05-31T08:18:35Z
status: planned
task_count: 2
completed_tasks: 0
---

# M012-S01 -- Slice Plan

**Goal:** `verification-before-completion` preamble runs without a bash parse error -- the executable block contains no literal triple-backtick (issue #20).

**Files (exclusive to this slice):** `skills/verification-before-completion/SKILL.md`

## Tasks

- [ ] T01 -- Replace the literal-fence parsing in the ` ```! ` preamble block. Generate the fence at runtime (`_FENCE=$(printf '\140\140\140')`) and rewrite the Verification-section extraction (awk over `## Verification` ... `## ` range, then toggle in/out of a fenced block by PREFIX-matching the fence, `index($0,f)==1`, NOT exact equality) so no literal ` ``` ` ever appears inside the executable block. Prefix-match is required because opening fences in task plans carry a language tag (e.g. ` ```bash `), which an exact `$0==f` test would miss. Eng-review edge-case 2026-05-31.
- [ ] T02 -- Verify: run the rewritten preamble against a sample task-plan that has a fenced command under `## Verification`; confirm it extracts the command and prints `VERIFICATION_CMD_FOUND: yes` with no `parse error`. Confirm the skill still passes the UX-contract checks (frontmatter keys, required sections, no em-dash). Grep the other five ` ```! ` skills to confirm none regressed / none share the pattern.

## Done when

All tasks marked `[x]` and verified via `ytstack:summarize-task`.

## Notes

- Root cause confirmed this session at `skills/verification-before-completion/SKILL.md:31` -- literal ` ``` ` in the `sed` pattern terminates block extraction early. Environment-independent.
- Verified isolated: no other ` ```! ` skill (test-driven-development, systematic-debugging, plan-ceo-review, office-hours, plan-eng-review) parses fences out of markdown.
- `skills/` is a ytstack wrapper (NOT `vendor/`) -- editing is allowed.

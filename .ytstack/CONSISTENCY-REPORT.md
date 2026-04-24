---
generated: 2026-04-24T22:22:00Z
generator: check-consistency v0.2.0 (manual run, post brownfield+debugging infographics)
authoritative_source: README.md
---

# ytstack Consistency Report

## Summary

- Total checks: 9
- PASS: 8
- WARN: 1 (2 meta-reference em-dashes in CLAUDE.md, not drift)
- FAIL: 0
- Overall: **OK**

## Check 1: Skill count drift

Status: PASS

- README.md:212 says "16 skills", README.md:226 says "16 skill packages".
- Disk: 16 directories under `skills/`.
- All three surfaces agree.

## Check 2: Wrapped-skill claims vs on-disk

Status: PASS

All six wrapped skills in `docs/concept.md` §3.1 exist on disk: plan-ceo-review, plan-eng-review, office-hours, test-driven-development, systematic-debugging, verification-before-completion.

## Check 3: Native-skill claims vs on-disk

Status: PASS

All ten native skills in `docs/concept.md` §3.4 exist on disk: init-project, plan-milestone, slice-milestone, plan-task, summarize-task, reassess-roadmap, handoff-session, resume-session, spawn-milestone-team, using-ytstack.

10 native + 6 wrapped = 16 total, matches disk.

## Check 4: Explicit-skip claims

Status: PASS

README mentions `investigate` (gstack) and `writing-plans` (superpowers) as skipped. Both appear in `docs/concept.md` §3.2 with matching rationale. No other explicit skips on record.

## Check 5: Skill descriptions cover README examples (no trigger-map)

Status: PASS

- `skills/using-ytstack/SKILL.md` contains no `## Trigger` or `## Greenfield flow` sections (per DECISIONS 2026-04-24 "Skill selection is semantic, not keyword-based"). Verified via grep.
- README's "What a session feels like" examples ("let's plan what's next", "this task is done", "something's broken find it", "where were we", "describe a feature you're not sure about", "let's do a handoff") each route to a skill whose `description:` field semantically covers the intent. Spot-checked: office-hours' description "Use as the first step when a new project, feature, or initiative has not yet been validated" covers "describe a feature you're not sure about"; systematic-debugging's description "Use when hitting a bug, test failure, or unexpected behavior" covers "something's broken find it"; etc.

## Check 6: Hook inventory

Status: PASS

- `hooks/hooks.json` registers 8 hooks: PostToolUse, PreCompact, PreToolUse, SessionEnd, SessionStart, TaskCompleted, TaskCreated, TeammateIdle.
- 8 scripts on disk match 1:1: post-tool-use-bash, pre-compact, pre-tool-use-edit, session-end, session-start, task-completed, task-created, teammate-idle.
- `docs/concept.md` §3.4 hook list includes all 8.

## Check 7: Artifact list vs init-project

Status: PASS

`docs/concept.md` §3.4 lists 6 core artifacts (PROJECT, DECISIONS, KNOWLEDGE, RUNTIME, STATE, PREFERENCES). `skills/init-project/SKILL.md` Step 5 writes all 6 via explicit `#### <NAME>.md` sections.

## Check 8: Workflow skill references

Status: PASS

- `docs/concept.md` §5 (three flows) references `ytstack:office-hours` (and others inline) -- all resolve.
- `QUICKSTART.md` references all 15 ytstack skills (office-hours through verification-before-completion) -- every `/ytstack:<name>` slash-command resolves to `skills/<name>/SKILL.md`.

## Check 9: Em-dash punctuation hygiene

Status: WARN (2 meta-reference hits, not drift)

Scan: README.md, QUICKSTART.md, CLAUDE.md, docs/concept.md, .ytstack/PROJECT.md.

- README.md: 0 hits ✓
- QUICKSTART.md: 0 hits ✓
- docs/concept.md: 0 hits ✓
- .ytstack/PROJECT.md: 0 hits ✓
- **CLAUDE.md: 2 hits (both meta-references)**
  - L68: `- No em-dashes (\`—\` U+2014) in prose per \`docs/ux/writing-style.md\` (autocorrect hazard)`
  - L109: `The em-dash rule (\`—\` → \`--\`) is the only mechanically-enforced punctuation rule`

Both hits are inside backtick-quoted teaching phrases that describe the em-dash character itself. Same false-positive pattern as the exempt files (`docs/ux/writing-style.md`, `.ytstack/KNOWLEDGE.md`, `.ytstack/REVIEW-NOTES.md`, `.ytstack/DECISIONS.md`). Not prose drift.

**Recommendation:** either add `CLAUDE.md` to the meta-reference exemption list in `.claude/skills/check-consistency/SKILL.md` Check 9, OR replace the two literal `—` with `U+2014` by-name references. Low priority; not blocking.

## Actions suggested (human decides)

- (optional) Exempt `CLAUDE.md` from Check 9 em-dash scan, OR replace the 2 literal `—` in L68 + L109 with named references. Not a drift.

## Next steps

No blocking drift. Tree is consistent with README as source of truth + DECISIONS as locked choices.

Post-run delta (2026-04-24T22:22:00Z): README Workflows section now embeds three collapsible `<details>` blocks, one per workflow, each referencing its own excalidraw PNG: `docs/ytstack-greenfield-flow.png`, `docs/ytstack-brownfield-flow.png`, `docs/ytstack-debugging-flow.png`. All three `.excalidraw` sources + rendered PNGs exist on disk. No new skills, hooks, or artifacts — purely documentation/visual additions; does not affect checks 1-8. Check 9 (em-dash) status unchanged (2 meta-refs in CLAUDE.md).

Re-run `/check-consistency` after the next substantial doc or skill change.

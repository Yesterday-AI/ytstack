---
project: ytstack
slug: ytstack
last_updated: 2026-04-25T16:00:00Z
current_milestone: review + post-M009-patches (M010 + M011 planned)
active_slice: none
active_task: none
---

# State

**Status:** Full build cycle complete + post-M009 patches landing + plugin landscape architecture locked. 38/39 roadmap tasks done; 1 deferred (v0.1.0 tag + push -- user action). End-of-cycle review in progress. First interactive smoke-test of `init-project` done 2026-04-24 (partial; surfaced multiple items -- see REVIEW-NOTES). Three workflow infographics now in README as visual reference for upcoming brownfield + debug live-tests. Sibling-plugin landscape (`ystacks` catalog + `yastack` public + `ydstack` / `yastack-internal` subdirs) shipped 2026-04-25 (afternoon).

**Post-M009 patches since 2026-04-23:** using-ytstack skill + session-start hook behavior-priming rewrite; 3 subagent definitions (architect / implementer / verifier); `docs/ux/agent-structure.md` contract; git init + initial scaffold commit; superpowers + gstack subtrees added.

**Session 2026-04-24 additions:**
- `docs/concept.md` (DRAFT, not yet user-approved) -- condensed reference paper synthesized from README + DECISIONS + methodology. README remains authoritative until explicit sign-off.
- `.ytstack/VENDOR-INVENTORY.md` -- full inventory of 43 gstack skills + 14 superpowers skills, grounds future "what exists upstream?" questions.
- `.claude/skills/check-consistency/SKILL.md` -- project-meta audit skill (NOT plugin-shipped). Runs 9 checks (skill-count drift, wrapped/native vs disk, hook inventory, artifact list, workflow refs, em-dash, skip-claims, and skill-description quality via semantic-selection hints). Note: the earlier "trigger-map coverage" and "banned-words" checks are retired per DECISIONS 2026-04-24 "Skill selection is semantic" + "drop banned-vocabulary list".
- `CLAUDE.md` -- "Read first" pointer added (concept → DECISIONS → VENDOR-INVENTORY before architectural proposals).
- `REVIEW-NOTES.md` -- 4+ new entries: pathname-confound, Denglisch-leak (policy: skills stay consistently English), greenfield-flow-first-skill-miss (open design point), skill-count-drift candidate for check-consistency.

**Session 2026-04-25 additions:**
- Three workflow infographics shipped: `docs/ytstack-greenfield-flow.{excalidraw,png}` (existing), `docs/ytstack-brownfield-flow.{excalidraw,png}` (new), `docs/ytstack-debugging-flow.{excalidraw,png}` (new). README Workflows section embeds all three via `<details>` blocks; greenfield is `<details open>` (default expanded) per DECISIONS 2026-04-25.
- Tagline change: "Working memory for AI coding agents." → "An opinionated OS for AI coding agents. Plan like a PM, execute like a senior eng." -- README header + docs/concept.md §1.1 synced. See DECISIONS 2026-04-25.
- Consistency check re-run 2026-04-25T00:22Z: 8 PASS, 1 WARN (2 meta-em-dashes in CLAUDE.md teaching phrases, not drift), 0 FAIL. Report at `.ytstack/CONSISTENCY-REPORT.md`.
- KNOWLEDGE.md gains three lessons: Excalidraw esm.sh version pin (`@0.18.0`), dark mode is `appState.exportWithDarkMode = true` (not color-swap), GFM `<details open>` for default-expanded collapsibles.
- GitHub repo metadata edits in flight (user-action): description aligned with new tagline; topics suggested `claude-code claude-code-plugin claude-code-skills ai-agents agentic-workflow anthropic developer-tools project-management tdd yesterday-ai` -- pending user save.

**Session 2026-04-25 (afternoon) -- plugin landscape architecture:**
- Locked 5-plugin family under `Yesterday-AI/ystacks` (private monorepo + catalog hybrid): `ytstack` (engineering), `ydstack` (daily-work), `yastack` (public agent core), `yastack-internal` (yesterday-bundle), `ycstack` (consulting separate-track).
- Three new DECISIONS entries (2026-04-25, merged via PR #1): "Lifecycle-phase as the curation heuristic", "Marketplace consolidates on Yesterday-AI/ystacks (monorepo + catalog hybrid)" (supersedes 2026-04-24 §3.5), "Vendored-preamble drift accepted for wrapped skills".
- README + QUICKSTART now show ystacks as primary install path; legacy self-marketplace path moved to a collapsed `<details>` block.
- New repos shipped: `Yesterday-AI/ystacks` (private, monorepo + catalog) and `Yesterday-AI/yastack` (public, scaffold). Both have own minimal `.ytstack/` (PROJECT + DECISIONS + STATE) for dogfooding.
- `agentic-foundation` identified as source pool for future ydstack + yastack skill migration (14 + 15 skills). Post-migration purpose of agentic-foundation undecided (archive vs repurpose).
- Naming convention locked: `y{c}stack` (yt/yd/yc/ya) + `-internal` suffix for yesterday-bundles. yastack autonomy framing corrected to Levels-of-AGI 3-4 (Collaborator / Expert), not 4-5.
- `docs/concept.md` §3.5 rewritten to reflect the new architecture (was deferred from PR #1 by design; landed in this STATE-refresh PR).
- Two new milestones surface as next substantive work:
  - **M010 Workflow Reorder + Brownfield-Without-.ytstack** -- covers the original M010 greenfield-reorder per DECISIONS 2026-04-24 PLUS adds the new "user runs ytstack inside an existing repo that has no `.ytstack/` yet" case as a third workflow alongside greenfield + brownfield-with-.ytstack.
  - **M011 Post-Summarize Lifecycle** -- 5-skill cherry-pick across gstack (`ship`, `document-release`) and superpowers (`finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review`). Scope locked 2026-04-25 after re-reading the comparison articles cited in `docs/concept.md`; full rationale in DECISIONS 2026-04-25 "M011 scope -- 5-skill cherry-pick from gstack + superpowers". Excludes `land-and-deploy`, `canary`, `qa` (different skill-class, deferred).

  Both planned but not started; entries in `.ytstack/ROADMAP.md`.

```
Progress:  [####################]  37/39 tasks (95%)
M001 Foundation                  [######] 6/6  DONE
M002 Lifecycle Hooks             [###]    3/3  DONE
M003 Project-OS Skills           [#######] 7/7 DONE
M004 Planning Cherry-Picks       [####]   4/4  DONE (vendor-add deferred)
M005 Execution Cherry-Picks      [####]   4/4  DONE (vendor-add deferred)
M006 Agent Teams Integration     [####]   4/4  DONE
M007 Quality Gates               [###]    3/3  DONE
M008 Publishing & Marketplace    [##..]   2/4  DONE (2 user-action)
M009 Docs & Community            [####]   4/4  DONE
```

## Next action

**Plan + start M010 (Workflow Reorder + Brownfield-Without-.ytstack)** OR **Plan + start M011 (Post-Summarize Lifecycle)** -- both planned, neither started. M010 is the unfinished item from 2026-04-24; M011 is new from 2026-04-25 and depends on the lifecycle-heuristic landed today.

Background items still open:
1. **Review DRAFT `docs/concept.md`** -- approve, amend, or reject. Until approved, README remains the sole source of truth. §3.5 was rewritten 2026-04-25 (afternoon) to reflect ystacks consolidation.
2. **Re-do init-project smoke-test in a neutral sandbox path** (avoid "ytstack" substring to isolate the directive-effect from pathname-confound -- see REVIEW-NOTES 2026-04-24).
3. **Tag v0.1.0 + push tag** (M008 user-action). Command: `git tag -a v0.1.0 -m "v0.1.0: full build cycle complete + plugin landscape architecture locked" && git push origin v0.1.0`.
4. **Save GitHub repo topics** (user-action). Suggested topics: `claude-code claude-code-plugin claude-code-skills ai-agents agentic-workflow anthropic developer-tools project-management tdd yesterday-ai`. Suggested description: "An opinionated OS for AI coding agents. Plan like a PM, execute like a senior eng." (matches README tagline).
5. **Live-test brownfield + debugging workflows** using the new infographics as visual reference. Was previous session's "Next action"; deferred behind the architecture work but still relevant.
6. **Eventual public marketplace listing** (M008 deferred): when ytstack visibility flips from private to public, list it in a public marketplace (e.g. anthropic-skills marketplace, or a future `Yesterday-AI/y-oss`).
4. **Save GitHub repo topics** (user-action; see Session 2026-04-25 additions for suggested list).

**Full-cycle review.** See `.ytstack/REVIEW-NOTES.md` for the batch of items flagged during the build. Review categories:

- Blockers before v0.1 publication (interactive-mode test, CI tool, git init, etc.)
- UX issues to revisit (init-project fallbacks, sentinel cleanup, etc.)
- Architecture decisions deferred
- Cross-cutting concerns
- Findings per milestone (M001, M002, M003)

After review, remaining user-action to close M008:
- T33 -- ~~Create GitHub repos~~ **done 2026-04-24**: `Yesterday-AI/ytstack` created (private, self-marketplaced; no separate marketplace repo per DECISIONS 2026-04-24).
- T35 -- `git init` + initial commits + push: **done 2026-04-24**. Remaining: tag v0.1.0 + push tag.

## Completed milestones

All 9 milestones achieved. See ROADMAP.md for per-milestone detail.

## What ships in v0.1.0

**Skills (15):**

- `init-project` (M001) -- bootstrap `.ytstack/` artifacts
- `plan-milestone`, `slice-milestone`, `plan-task`, `summarize-task`, `reassess-roadmap`, `handoff-session`, `resume-session` (M003) -- Project-OS lifecycle
- `plan-ceo-review`, `office-hours`, `plan-eng-review` (M004) -- gstack planning wrappers
- `test-driven-development`, `systematic-debugging`, `verification-before-completion` (M005) -- superpowers execution wrappers
- `spawn-milestone-team` (M006) -- Agent Teams dispatch
- `using-ytstack` (post-M009) -- auto-injected directive that drives agent-side skill selection from natural-language intent. Adapted from superpowers' `using-superpowers` pattern.

**Subagent definitions (3, post-M009):**

- `agents/architect.md` -- plan-review, approve-to-implement gate (read-only). Used by `spawn-milestone-team` for the optional architect-lead role.
- `agents/implementer.md` -- executes one slice via the `plan-task → TDD → verify → summarize` cycle. Bounded to slice scope.
- `agents/verifier.md` -- evidence-before-assertions, runs plan's verification command from cold context, passes/fails task closure.

These are referenced by `skills/spawn-milestone-team/SKILL.md` as the default teammate-role types. Previously the skill named them without providing definitions (gap surfaced during behavior-priming audit).

**Hooks (8):**

- `session-start` (M002) -- inject project state on startup/resume/clear/compact
- `pre-compact` (M002) -- write HANDOFF.md before context compression
- `session-end` (M002) -- finalize STATE.md, append session journal
- `teammate-idle` (M006) -- keep teammates claiming open tasks
- `task-created` (M006) -- scope-drift check against milestone roadmap
- `task-completed` (M006) -- auto-draft T##-SUMMARY.md
- `pre-tool-use-edit` (M007) -- scope + schema drift check before file edits
- `post-tool-use-bash` (M007) -- auto-append commit to task summary

**Docs:**

- `README.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `QUICKSTART.md`, `LICENSE`, `NOTICE`
- `docs/ux/askuserquestion-format.md`, `writing-style.md`, `skill-structure.md`
- `docs/references.md`, `docs/methodology.md`
- `vendor/README.md`

**Dogfood artifacts:** `.ytstack/PROJECT.md`, `ROADMAP.md`, `STATE.md`, `DECISIONS.md` (8 entries), `KNOWLEDGE.md`, `RUNTIME.md`, `PREFERENCES.md`, `REVIEW-NOTES.md` (~35 items)

**Plugin config:** `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`

## Open decisions

None currently. See DECISIONS.md (8 entries) for locked choices.

## Recent summaries

M003-M009 work tracked above. `ytstack:summarize-task` will format per-task summaries going forward.

---
project: ytstack
slug: ytstack
last_updated: 2026-05-31T10:37:54Z
current_milestone: M015
active_slice: none
active_task: none
---

# State

**Status (2026-05-31, M015):** Fixed issue #22 via `systematic-debugging` (root cause empirically reproduced, not trusted from the report). The `post-tool-use-bash` hook is now **stub-once** (creates the draft `T##-SUMMARY.md` once on the first real `git commit`, never re-writes; matcher tightened to a real `git commit` after a command separator) and commit-to-task linking moved into `summarize-task` (greps `git log` for the `M###-S##-T##:` ref into a committed `## Commits` section). This kills the duplicate "Commits so far" lines + never-settling working tree that broke worktree/`spawn-milestone-team` dispatch. New regression test `tests/post-tool-use-bash.test.sh` (10 cases, all green). Version bumped 0.1.5 -> **0.1.6**. DECISIONS entry "post-tool-use-bash is stub-once" + KNOWLEDGE gotcha added. **NOT yet committed/pushed** (awaiting diff review + explicit "commit"/"push"). **NOT released, issue #22 NOT closed** (awaiting authorization). Cache caveat: live for users only after `/plugin update` to 0.1.6.

**Prior status:** M012 DONE + RELEASED as **v0.1.5** (tagged + pushed). All 4 slices landed on `main` and pushed to origin. Executed via worktree-isolated swarm (3 general-purpose teammates in `Agent(isolation:'worktree')` + 1 verifier; the ytstack:implementer/verifier agent types crashed on spawn ON issue #20 itself -- live proof it was P0). Commits: `015f988` #19, `da41845` #20, `b7a5695` #21-RC1+#16, `2af326e` #21-RC2. Independently re-verified 2026-05-31: #19/#20/#21-RC2 behavior-tested; #21-RC1 bash+guard verified (frontmatter-write is prose, exercised only when the skill runs live). plan-eng-review locked 3 decisions: active_slice plan-task-owned + team-member-guarded; swarm commit discipline; ytstack encourages git worktree isolation (-> M013). **CACHE CAVEAT:** fixes go live for users after `/plugin update` to 0.1.5; in THIS session the cached 0.1.4 is still active (so #20 still reproduces here). **M012 numbering collision:** a prior uncommitted plan in the `claude/thirsty-bhabha-a03490` worktree had named the vendor-symlink work "M012" -- reserved as **M014** (separate, to be planned). Queued: M010, M011, M013, M014. See `M012-ROADMAP.md` + DECISIONS.md.

**Prior status (full build cycle):** Full build cycle complete + post-M009 patches landing + plugin landscape architecture locked. 38/39 roadmap tasks done; 1 deferred (v0.1.0 tag + push -- user action). End-of-cycle review in progress. First interactive smoke-test of `init-project` done 2026-04-24 (partial; surfaced multiple items -- see REVIEW-NOTES). Three workflow infographics now in README as visual reference for upcoming brownfield + debug live-tests. Sibling-plugin landscape (`ystacks` catalog + `yastack` public + `ydstack` / `yastack-internal` subdirs) shipped 2026-04-25 (afternoon).

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

**Session 2026-04-25 (evening) -- marketplace split + service-plugin shipping:**
- Marketplace architecture revised again -- split into TWO catalogs by visibility (DECISIONS 2026-04-25 "Marketplace architecture split into ystacks (public) + ystacks-internal (private)" -- merged via PR #3, supersedes the earlier same-day "monorepo + catalog hybrid" decision).
  - `Yesterday-AI/ystacks` -- PUBLIC catalog, hosts ydstack as monorepo subdir, lists yastack + yopstack via github source.
  - `Yesterday-AI/ystacks-internal` -- PRIVATE catalog (renamed from old ystacks), hosts yastack-internal + yopstack-internal as monorepo subdirs, lists ytstack (cross-listed while private) + service-plugins via github source. Has `allowCrossMarketplaceDependenciesOn: ["ystacks"]` so bundle plugins can dep on yastack/yopstack from public catalog.
  - **Per-plugin own repos** for plugins with real architectural surface (ytstack, yastack, yopstack). Bundle plugins + skill collections (ydstack, yastack-internal, yopstack-internal) live as monorepo subdirs because no separate DECISIONS history needed.
- New plugin: `Yesterday-AI/yopstack` (public) -- 4 ops-layer skills (`opentofu` migrated from yastack + 3 gstack-wrappers planned: `land-and-deploy`, `canary`, `setup-deploy`). yastack skill count adjusted 15 -> 14.
- Six service-plugin PRs shipped + merged today, all to support yopstack-internal + yastack-internal bundle deps:
  - `agent-calendar` (PR #48 + #49 follow-up that was closed) -- includes a sync-script-path fix in SKILL.md.
  - `agent-services` (PR #89 + #90 follow-up that was closed).
  - `cloud` (PR #17).
  - `llm-gateway` (PR #55).
  - `clawrag` (PR #103) -- noisy review: bugbot found 3 real upstream content bugs in scripts/. Two fixed in scope (`sources.sh` deleted -- redundant + had hardcoded dev API key); 1 deferred (`ingest.sh` `/tmp/clawrag_response.json` race). PR also went through a force-push squash (with `--force-with-lease`) after confused commit history -- lesson learned: ALWAYS `git pull main` before `git checkout -b new-branch`, otherwise diff-vs-current-main includes accidental reverts of others' work.
  - `fleet` (PR #144) -- 3 skills (a2a-client, fleet-manager, self-diagnosis).
- Initial scaffold attempt added explicit `"skills": ["./skills/<name>/"]` field to all manifests for "no leakage" safety, but reverted across-the-board after upstream issue [alirezarezvani/claude-skills#538](https://github.com/alirezarezvani/claude-skills/issues/538) showed real-world reliability problems with explicit `skills` field paths. Default auto-discovery is the safer pattern. Plus user noted: explicit `skills` field only replaces default `skills/` scan -- `bin/`, `commands/`, `agents/`, `hooks/` etc. are still auto-discovered regardless, so "pin skills explicitly" was never the right safety boundary against unwanted plugin content; naming-convention + code-review is.
- Plus PR #4 (this PR's predecessor): one-line README install-section fix -- ystacks is PUBLIC, not "canonical" + no auth required for the public catalog.
- Cross-repo consistency audit (Explore agent, end-of-day): 2 critical fixes landed (yastack `skills/README.md` count 15 -> 14; ytstack README install-section wording). All other audit dimensions clean: naming convention, no internal-name leakage in public ystacks, agentic-foundation migration mentions consistent, logo/assets consistent.
- Bundle deps now fully resolvable: `yastack-internal` (yastack@ystacks + yopstack-internal + clawrag + agent-calendar -- all listed) and `yopstack-internal` (yopstack@ystacks + agent-services + cloud + llm-gateway -- all listed).
- This PR (the one introducing this STATE block) also rewrites `docs/concept.md` §3.5 to reflect the post-split architecture. The earlier rewrite (PR #2) described the now-superseded monorepo+catalog hybrid; this version describes the two-marketplace split + per-plugin-own-repos model.

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

**Issue #22 -- DONE (M015), pending review.** Fix implemented + tested (see Status above). Immediate to-dos before this is truly closed:
1. **Review the diff** (hook + summarize-task + tests + artifacts + version bump), then commit (path-scoped, `M015-S01-T01:` message) -- awaiting explicit go.
2. **Push** + (optionally) tag v0.1.6 -- awaiting explicit "push"/"release".
3. **Close issue #22** with the commit ref -- awaiting authorization.
4. `/plugin update` to 0.1.6 to make it live (cached older plugin still active in-session).

**Then queued:** M010 (brownfield = #18), M011 (post-summarize lifecycle), M013 (worktree mode), M014 (vendor symlink), agentic-foundation migration.

---

**M012 shipped (v0.1.5, pushed). Issues #16/#19/#20/#21 closed. Workflow infographics regenerated (premium hand-drawn) + pushed.** Remaining / queued:
1. **`/plugin update`** to 0.1.5 in any active session to make the fixes live (cached 0.1.4 still active here).
2. **Cross-repo marketplace sync** (NOT done -- needs separate authorization): the `ystacks-internal` catalog lists ytstack; confirm it picks up v0.1.5 (per the "Plugin-Marketplace-Aenderung = README-Update" rule). Out of this repo's scope.
3. **M014 -- vendor symlink dereferencing for RemotePluginSync** (separate): uncommitted draft + README "Desktop + SSH" workaround live in the `claude/thirsty-bhabha-a03490` worktree; salvage or re-plan separately. Worktree intentionally left in place (holds the only copy).
4. Queued milestones: M010 (brownfield = issue #18), M011 (post-summarize lifecycle), M013 (spawn-milestone-team worktree mode), M014 (vendor symlink). Plus agentic-foundation migration.

---

**Previously queued (still open, after M012):**

**agentic-foundation skill migration** -- user-confirmed as next (2026-04-25 evening). 32 skills total to migrate: 14 -> ydstack, 14 -> yastack, 4 -> yopstack (incl. opentofu + 3 gstack-wrappers via vendor/gstack subtree-add). Eigene session pro plugin sinnvoll. Once migration completes, agentic-foundation goes obsolete (per user 2026-04-25 evening: "agentic-foundation wird obsolete sein -- baldigst").

After migration: M010 + M011 are queued. M010 = Workflow Reorder + Brownfield-Without-.ytstack (unfinished from 2026-04-24). M011 = Post-Summarize Lifecycle (5-skill cherry-pick, scope locked).

Background items still open:
1. **Review DRAFT `docs/concept.md`** -- approve, amend, or reject. Until approved, README remains the sole source of truth. §3.5 was rewritten twice today (PR #2 wave + this PR -- now reflects the two-marketplace split + per-plugin-own-repos model).
2. **Re-do init-project smoke-test in a neutral sandbox path** (avoid "ytstack" substring to isolate the directive-effect from pathname-confound -- see REVIEW-NOTES 2026-04-24).
3. **Tag v0.1.0 + push tag** (M008 user-action). Command: `git tag -a v0.1.0 -m "v0.1.0: full build cycle complete + plugin landscape architecture locked" && git push origin v0.1.0`.
4. **Live-test brownfield + debugging workflows** using the new infographics as visual reference. Was previous session's "Next action"; deferred behind the architecture work but still relevant.
5. **Eventual public marketplace listing** (M008 deferred): when ytstack visibility flips from private to public, list it in the public ystacks catalog (today only listed in private ystacks-internal as cross-listed).
6. **Skill content cleanup queue** (in `Yesterday-AI/ystacks-internal/.ytstack/STATE.md`): clawrag `ingest.sh` `/tmp` race condition + agent-calendar SKILL.md sync-script-path. Per user 2026-04-25 evening: skip upstream backports to agentic-foundation since the repo will become obsolete soon (skill migration absorbs all relevant content).

GitHub repo topics + description -- DONE 2026-04-25 (user-action).

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
- `post-tool-use-bash` (M007; stub-once since M015) -- creates a draft T##-SUMMARY.md once on a task's first commit; commit-to-task linking lives in `summarize-task`

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

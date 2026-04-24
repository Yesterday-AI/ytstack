---
last_updated: 2026-04-23T17:55:00Z
review_cadence: end-of-full-cycle
next_review_gate: after M009 complete, before v0.1 publication (M008 final gate)
---

# Review Notes

Running list of items to verify, revisit, or polish at end-of-cycle review. Added proactively as findings surface during M001-M009 build. Resolved or re-categorized at the final review gate.

**Convention:** Each entry is a markdown checkbox with one-line context and the milestone/task where it surfaced. Don't try to fix items inline unless they block current work -- note and move on.

---

## Blockers before v0.1 publication

(Must fix or explicitly defer before going public via marketplace in M008.)

- [ ] **Interactive-mode smoke test.** Verify `ytstack:init-project` invokes via the `Skill` tool in a real non-headless Claude session. Headless `-p` mode fell back to SKILL.md-as-prompted-instructions. End result correct, but registration path unclear. (surfaced: M001 T05)
- [x] **LICENSE file** (MIT). Shipped in initial scaffold commit (dc5b005, 2026-04-24).
- [x] **NOTICE file** with attributions: superpowers (MIT), gstack (MIT, source confirmed `github.com/garrytan/gstack`), external methodology inspired-by. Shipped + updated post-subtree-add.
- [ ] **`ytstack-skill-check` CI tool.** Validator for UX contracts (frontmatter, checklist, flow graph, preamble flags, AskUserQuestion format, banned-words). Referenced across docs. **Now Phase-1 priority -- agents/ addition + post-M009 audit surfaced real conformance gaps that a validator would have caught.**
- [x] **Git init the ytstack repo.** Done 2026-04-24; initial commit `dc5b005` + two subtree commits for superpowers + gstack.

## UX issues to revisit

- [ ] **`init-project` non-interactive fallback for open-ended questions.** When `YTSTACK_NON_INTERACTIVE=1` is set and prompt doesn't include name + one-liner, skill has no defined behavior. Fallback: use `PROJECT_SLUG` as name, placeholder one-liner with warning. (surfaced: M001 T05)
- [ ] **`both` scope split rules.** Currently writes all 6 artifacts to both project-level and user-level locations. Later skills should split (team-facts → project, private → user). Define split rules when M003 skills implement writes. (surfaced: M001 T02 init-project design)
- [ ] **`ROADMAP.md` not in init-project's artifact list.** We added it ad-hoc for ytstack's own dogfood. Decide: update skill template to include, or keep as optional project-level convention. (surfaced: M001 T03)
- [x] **`ytstack forget <marker>` command.** Resolved 2026-04-24: removed all references from skills (`init-project`, `plan-milestone`) and `docs/ux/askuserquestion-format.md`. Re-ask anchor now simply says "delete `~/.ytstack/.<marker>`" directly. Command itself can be built as a convenience later in v0.2.
- [ ] **Sentinel file accumulation.** `~/.ytstack/.*-prompted` files accumulate indefinitely. No cleanup strategy. Consider: `ytstack sentinel-list` / `ytstack sentinel-clear --older-than X`. (surfaced: M001 T05)

## Architecture decisions deferred

- [ ] **Min Claude Code version enforcement.** We target v2.1.32+ for Agent Teams (M006). Plugin manifest may not support version constraints directly. Check `plugins-reference` for alternatives (preflight hook? README warning? fail-early bash check in preamble?).
- [ ] **`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` surfacing.** How do users learn they need to set it? Session-start hook could detect + inject warning in bootstrap.
- [ ] **`tier` field validation.** Custom ytstack frontmatter field (core/task/background), Claude Code ignores it. Drift risk until `ytstack-skill-check` validates.
- [ ] **Skill category organization.** superpowers uses `Testing | Debugging | Collaboration | Meta`. We're currently flat. Decide when skill count exceeds ~8.
- [ ] **ytstack naming vs ycstack.** User flagged: if our approach diverges significantly from external-methodology influences, `ycstack` might be more honest. Re-evaluate at M009 when full scope is visible.

## Cross-cutting concerns

- [ ] **Cross-platform hook scripts.** All scripts are bash. Windows users need Git Bash / WSL. Document platform requirements in README + plugin.json keywords.
- [ ] **Hook timeouts.** superpowers uses `async: false` for session-start. Default timeout unclear from docs. Set explicitly in `hooks/hooks.json` during M002.
- [ ] **`explain_level` propagation.** PREFERENCES.md has `explain_level: default`. How does SessionStart hook read + apply it? Define mechanism during M002.
- [ ] **`YTSTACK_NON_INTERACTIVE` envelope.** Today: `$YTSTACK_NON_INTERACTIVE` or `$OPENCLAW_SESSION` or `$CLAUDE_AGENT_TEAM_MEMBER`. Verify all three actually get set by their respective environments -- the last one is assumed based on Agent Teams docs.

## Open tooling

- [ ] **`ytstack-skill-check`.** (see Blockers)
- [x] **`ytstack forget <marker>`.** (references removed; see UX. Convenience command itself is v0.2 future-work.)
- [ ] **`ytstack sentinel-*` subcommands.** (see UX)
- [ ] **How do users "update" ytstack?** Plugin install + `/plugin update <name>`? Or `git subtree pull` for self-cloned installs? Document in M009.

## Conformance to own rules (audit tasks)

- [x] **Banned-words grep.** Resolved via `bin/ytstack-check` (added 2026-04-24). Currently reports zero banned-word hits across the tree.
- [x] **Em-dash cleanup pass.** Resolved 2026-04-24. Bulk-replaced 288 em-dash (`—`) occurrences → `--` (ASCII) across 40 files. Re-ran `bin/ytstack-check`: zero em-dash warnings remain. Root cause documented in KNOWLEDGE.md (macOS autocorrect). Future prevention via `bin/ytstack-check` CI gate.
- [ ] **Outcome-framing audit.** Review every AskUserQuestion body for outcome-framing (pain / delight / forcing) vs implementation-framing. Manual review in M008.
- [ ] **Self-reference audit.** Grep for any surviving explicit source names (author names, URLs to specific people) per the "no naming" user directive. Should be zero outside `docs/references.md` (where upstream repos ARE named intentionally).
- [ ] **`kind: directive` documented in skill-structure.md.** Currently implemented in `bin/ytstack-check` as a bypass for structural checks (Checklist / Terminal State) on meta-primer skills like using-ytstack. Not yet documented in the contract. Add note in skill-structure.md.
- [ ] **Recommended-sections coverage.** `ytstack-check` warns when a skill lacks `## Process Flow` / `## Preamble` / `## Procedure` / `## Anti-Pattern`. Several existing skills (handoff-session, resume-session, reassess-roadmap, some wrappers) miss one or two of these. Decide: tighten the docs (make them all required) or accept the warning as informational.

## M004-M009 findings (added 2026-04-23, end of build)

### M004 -- Planning Cherry-Picks

- [x] **Vendor subtree-add is deferred.** -- Resolved 2026-04-24. `git subtree add --prefix=vendor/gstack https://github.com/garrytan/gstack.git main --squash`. All 3 wrapper-target skills (`plan-ceo-review`, `office-hours`, `plan-eng-review`) verified present at expected paths.
- [x] **gstack vendor source URL unknown.** -- Resolved: `https://github.com/garrytan/gstack`.
- [ ] **Wrapper skills assume vendored preamble is skippable.** Each wrapper says "Do not inherit gstack's preamble". But gstack preambles emit state flags the vendored skill's body may depend on. Verify this assumption holds in interactive test.
- [ ] **Outcome application in wrappers.** plan-ceo-review wrapper Step 6 says "translate review conclusions into ytstack file edits" but doesn't specify the translation format. May need a convention: "if gstack emits `MODE: SCOPE_EXPANSION`, edit ROADMAP slices + CONTEXT exit criteria".

### M005 -- Execution Cherry-Picks

- [x] **superpowers subtree-add.** Resolved 2026-04-24. All 3 wrapper-target skills (`test-driven-development`, `systematic-debugging`, `verification-before-completion`) verified present at `vendor/superpowers/skills/<name>/SKILL.md`.
- [ ] **superpowers interactive-prompt-blocking-input caveat not yet reproduced.** tentenco article flagged this. Wrappers set `YTSTACK_NON_INTERACTIVE=1` pre-emptively -- but we haven't verified superpowers actually respects this env var. Possible that we need a different propagation mechanism.
- [ ] **`test-driven-development` wrapper assumes superpowers has stable tool-name conventions.** If superpowers' `test-driven-development/SKILL.md` shifts in a subtree-pull, our wrapper's "follow vendored procedure" may break silently.
- [ ] **Code-review gap: wrap superpowers' `requesting-code-review` + `receiving-code-review` in v0.2.** Surfaced 2026-04-24 during pre-smoke-test plugin-scope discussion. ytstack v0.1 covers plan-review (plan-ceo-review, plan-eng-review) and pre-commit-verification (verification-before-completion) but NOT PR-level code-review. superpowers has both skills at `vendor/superpowers/skills/requesting-code-review/` and `vendor/superpowers/skills/receiving-code-review/` -- already vendored, just not wrapped. Decided: wrap from superpowers (our existing vendored source), do NOT recommend separate Anthropic `code-review` plugin (fragmentation). Scope: 2 new wrapper SKILL.md files at `skills/requesting-code-review/` + `skills/receiving-code-review/`. Add trigger entries to `using-ytstack`'s trigger-map. Update README comparison-table row. v0.2 scope.

### M006 -- Agent Teams

- [ ] **Agent Teams TaskCreated/TaskCompleted event payload schema.** Hooks assume `tool_input.subject` and `tool_input.description` fields. Claude Code docs don't explicitly confirm these field names for these events -- reverse-engineered from PreToolUse docs. Verify in integration test.
- [ ] **`spawn-milestone-team` emits natural-language prompt, doesn't invoke Teams directly.** By design (Claude owns the Teams API). Verify this handoff pattern works -- agent may not execute the team-spawn instruction reliably without explicit "go" flag.
- [ ] **Task-completed hook's slice-plan-checkbox flip uses plain `sed`.** If the task description contains regex metacharacters, could fail silently. Harden with explicit escape.
- [ ] **Task-created hook's file-path extraction regex is rough.** `.ts|.tsx|.js|.jsx|.py|.rs|.go|.md|.json|.yaml|.yml|.html|.css|.scss|.sql|.sh` -- doesn't cover every language. Accept drift-false-negatives in exchange for avoiding drift-false-positives.

### M007 -- Quality Gates

- [ ] **`pre-tool-use-edit` file-path match uses `grep -qF`** on the relative path. This matches substrings -- a file `foo/bar.ts` in plan would match a hook-target `bar.ts` in any directory. Probably fine (most false-positives prevent drift), but worth explicit test.
- [ ] **Schema-drift heuristic is narrow.** Only catches `*models.py`, `schema.prisma`, `schema.sql`. Doesn't catch Django migrations, Rails migrations, Ecto, etc. Extend over time as real patterns surface.
- [ ] **`post-tool-use-bash` regex matches any `git commit`** including `--amend`, `--dry-run`. Amend case may double-log. Check + fix.
- [ ] **Hooks that use `sed -i`** must handle BSD vs GNU. Session-end handles it explicitly. pre-tool-use and post-tool-use-bash use `sed` -- audit.

### M008 -- Publishing

- [ ] **User action needed:**
  - `git init` ytstack repo
  - Create `yesterday-ai/ytstack` GitHub repo
  - Create `yesterday-ai/ytstack-marketplace` GitHub repo (separate)
  - Commit marketplace.json to the marketplace repo
  - Tag v0.1.0 on ytstack repo
  - Push both
- [ ] **Marketplace.json fields may be incomplete.** Used inference from `plugins-reference` docs; verify against an existing marketplace manifest (e.g. obra/superpowers-marketplace).
- [ ] **LICENSE text is standard MIT.** Verify Yesterday uses MIT specifically (not Apache-2.0) for this repo.

### M009 -- Docs & Community

- [ ] **QUICKSTART.md uses "imagine building a CLI tool" as worked example.** Swap for a real, testable example once v0.1 is live.
- [ ] **CONTRIBUTING.md references `ytstack-skill-check`** as a CI tool. Doesn't exist yet (deferred to M008 pre-release). Remove reference or build it.
- [ ] **docs/methodology.md** is careful about naming -- but verify no named references leaked in.
- [ ] **README.md doesn't mention M006's dependency on `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`** prominently enough. Users may try spawn-milestone-team without setting it and get cryptic errors.

### Cross-milestone observations

- [ ] **Greenfield-flow first-skill is wrong (2026-04-24).** Current `skills/init-project/SKILL.md` bundles infra setup (scope decision + artifact skeletons) with PM questions (name, one-liner). It is also wired as the first skill a greenfield user hits (the using-ytstack trigger-map entry "new project" → init-project, plus init-project's Terminal State points at plan-milestone). Both are miss: (1) infra and PM must be separated -- PM content (name, one-liner, target user, MVP, non-goals) must come out of `office-hours` / `plan-ceo-review` and then populate PROJECT.md, NOT be asked cold during infra setup; (2) the intended greenfield entry is `office-hours` → `plan-ceo-review` → [optional `plan-eng-review`] → infra setup → `plan-milestone`. Fix requires: split init-project into infra-only (scope + skeletons, no PM questions), update using-ytstack trigger-map to route greenfield natural-language intent to `office-hours` first, have `office-hours` (or the infra step that follows it) write the validated pitch into PROJECT.md, adjust init-project Terminal State and README Quickstart accordingly. Tracked in `docs/concept.md` §5 "Open design point". Needs DECISIONS entry before implementation.
- [ ] **Skill-template language consistency (2026-04-24).** First interactive smoke-test surfaced a rendered scope-question in mixed English+German. Root cause: half of the prompt-text inside `init-project/SKILL.md` Step 3 (and similar steps) is in English, half leaks through as German after the agent's on-the-fly translation. Decided policy: **skill-template files stay consistently in English.** Agent's rendering language is not constrained by ytstack. Action: audit all `skills/*/SKILL.md` files and ensure every user-facing prompt string (AskUserQuestion bodies, example text, recommendation lines) is English. No runtime rules added.
- [ ] **Smoke-test pathname-confound (2026-04-24).** First interactive smoke test ran in `/tmp/ytstack-test-projects/ytstack-smoke-readme-link-check`. Agent correctly auto-invoked `ytstack:init-project` on a natural-language prompt ("baue mir eine cli..."), but its explanation cited the **pathname itself** ("Dies ist ein ytstack-Smoke-Test-Projekt siehe Pfad...") as reason. This is confounded: we cannot distinguish "trigger fired because `HAS_YTSTACK=no` + using-ytstack directive primed the behavior" from "trigger fired because the word `ytstack` appears in the cwd path". Re-test required with a neutral sandbox path (e.g. `/tmp/readme-link-check`) to isolate the directive's effect. Agent still invoked the right skill -- so the happy path works either way -- but we cannot yet claim the directive is what caused it.
- [ ] **No smoke test for any skill except `init-project`.** Of 14 shipped skills, only 1 was tested end-to-end. Must gate v0.1 publication on at least one smoke-test per skill.
- [ ] **No integration test for hooks in a real Claude Code session.** Hooks are standalone-tested (exit 0 / JSON valid), but never verified they actually fire in-session with proper inputs. Integration test before publication.
- [ ] **Sentinel file hygiene.** `~/.ytstack/.*-prompted` files accumulate. No list/clean commands. Mildly annoying for power users.
- [ ] **No `ytstack-skill-check` tool.** Hand-written skills conform to docs/ux/ -- but drift is certain once count grows. Build validator before accepting community PRs.
- [ ] **ytstack doesn't enforce its own UX contracts on itself.** We authored 14 skills "by eye" from the contracts. Running ytstack-skill-check on ytstack's own skills is a must-pass gate before v0.1.

## M003 findings (added 2026-04-23)

- [ ] **Skills not smoke-tested individually.** Only `init-project` (M001 T05) was tested via headless claude. The other 7 M003 skills are written-but-untested. First interactive smoke-test gate in M008 before marketplace publication.
- [ ] **slice-milestone template variable substitution.** In Step 7, the ROADMAP.md template uses `{#if SIZE == "M" or SIZE == "L"}` pseudo-conditional syntax. Claude needs to interpret this as "emit these lines based on SIZE value", not literal templating. Verify in a real run that Claude handles it correctly; otherwise replace with explicit English: "if SIZE is M or L, also add S02 and S03 lines".
- [ ] **`compgen -G` portability.** Used in plan-task + summarize-task + resume-session preambles. Works in bash but not necessarily in sh/zsh. Verify on macOS default shells.
- [ ] **Frontmatter `sed` portability.** `sed -i` vs `sed -i ''` (BSD vs GNU) handled in session-end hook but NOT in the skills that Edit STATE.md / CONTEXT.md via Claude's Edit tool. Since Claude uses its own Edit tool (not sed), this probably isn't an issue -- but verify.
- [ ] **Summary file naming.** `M###-S##-T##-SUMMARY.md` is long. Consider shortening to `T##-SUMMARY.md` within milestone dirs if we add dir-per-milestone structure. (deferred to M008 cleanup)
- [ ] **`reassess-roadmap` major-rethink branch.** If user picks "C: major rethink" we recommend rerunning `plan-milestone`. But `plan-milestone` auto-increments the milestone number. Need a "reuse same M###" flag, or guidance to manually delete the old files first.
- [ ] **No CI for template conformance yet.** Wrote 7 skills matching the UX contract by hand. `ytstack-skill-check` tool (M008) needs to validate all of them -- expected to surface drift.
- [ ] **`plan-task` Step 7 wording.** We ask the user to self-sanity-check whether the task fits one context window. If they pick B (borderline), we proceed but flag it. Consider: should we REQUIRE splitting on borderline, not just flag?
- [ ] **Empty "M###-S##-T##-PLAN.md" detection.** `plan-task` preamble scans for tasks without a `-PLAN.md` file to find the next unplanned one. If a user manually creates an empty T##-PLAN.md, we'd skip it. Add existence-and-non-empty check.

## M002 findings (added 2026-04-23)

- [ ] **Hook integration test.** Hooks are standalone-tested but not yet verified with a real `claude --plugin-dir <path>` session. Need to confirm: (a) SessionStart-injection reaches the agent's context, (b) PreCompact fires before `/compact`, (c) SessionEnd fires on `/exit` / session-close. (surfaced: M002 T07-T09)
- [ ] **`CLAUDE_SESSION_ID` env availability.** session-end hook references `CLAUDE_SESSION_ID` but docs don't confirm this env var exists. If unset, journal entries log `session_id: unknown`. Verify in integration test or read the hooks input JSON via stdin instead.
- [ ] **PreCompact no-stdout rationale.** Decided PreCompact writes only side-effects (HANDOFF.md), doesn't emit additionalContext. But: could emitting a brief "state-preserved-at-X" context reminder at the next turn help? Revisit after M006 when compaction frequency is observable.
- [ ] **HANDOFF.md overwritten each pre-compact.** By design for now. If historical handoffs prove useful, redirect to `journal/handoffs/<timestamp>.md`. (deferred)
- [ ] **`jq` vs `python3` fallback path.** Hook scripts prefer jq, fall back to python3, then error. Neither is guaranteed on all Claude-Code hosts. Verify both are commonly available; consider bundling a pure-bash JSON emitter as last resort.
- [ ] **Hook file executability.** Scripts invoked via `bash <path>` so `chmod +x` not needed. But if users git-clone without preserving +x, and someone tries `./hooks/session-start` directly, fails. Decide: document that hooks are invoked via bash, or add chmod to a `./setup` step.
- [ ] **PreCompact / SessionEnd matcher field.** We omitted `matcher` for both (based on docs inference). Verify via integration test that hooks fire correctly without matcher.

## Documentation gaps

- [ ] **CONTRIBUTING.md.** Planned M009. Key rules already in CLAUDE.md but CONTRIBUTING is user-facing.
- [ ] **QUICKSTART.md.** Planned M009.
- [ ] **Method attribution writeup.** Planned M009. How we adapted tier-based context, artifact-as-memory, playbook-based skills -- without naming sources.
- [ ] **Verify every claim in README.** After full build, audit README against shipped reality (e.g. don't promise M006 features in v0.1 README).

---

## How to use this file

- **During M002-M009:** append entries as findings surface. Don't triage.
- **At end of M009:** before starting M008 publication tasks, batch-review this file. For each entry: resolve / defer to v0.2 / explicit skip.
- **At v0.1 release:** items remaining must be annotated with target version (v0.1.1, v0.2, etc.) or closed as "intentionally out of scope."

**File is append-only within a milestone.** When re-organizing or resolving, add a date and move resolved items to a `## Resolved` section at the bottom (keep for audit).

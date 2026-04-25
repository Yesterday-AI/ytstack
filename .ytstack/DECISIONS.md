# Decisions

Append-only architectural and product decisions for ytstack. Never rewrite past entries. If a decision is reversed, add a new entry that supersedes.

Format for each entry:

## YYYY-MM-DD: \<Short title\>

**Context:** what forced the decision
**Options considered:** A, B, C
**Chose:** selected option
**Reason:** why
**Supersedes:** link to earlier entry if this reverses a prior decision

---

## 2026-04-23: Don't rebuild GSD as TypeScript runtime

**Context:** GSD v2 is a substantial TypeScript application (CLI, SQLite, IPC, TUI). Rebuilding all of it inside ytstack is months of work.

**Options considered:**
- A) Full rebuild as ytstack-runtime
- B) Vendor GSD as optional external tool alongside ytstack
- C) Replicate GSD's artifact-discipline + context-management via skills + hooks, skip the runtime

**Chose:** C

**Reason:** Claude Code's native Agent Teams feature already provides fresh 200k-context-per-task and shared task list with file-locking -- the core value GSD's runtime adds. Combined with hooks (SessionStart/TeammateIdle/TaskCompleted) and skill-managed `.ytstack/` artifacts, we replicate ~95% of GSD's value without a runtime app. User explicitly ruled out B ("zusaetzlich installieren, das wird zu viel").

---

## 2026-04-23: Don't vendor third-party methodology content, only adapt concepts

**Context:** External AI-first methodology material (German-language, proprietary/copyrighted) contains compelling concepts (three-tier context model, component breakdown, skill-playbook structure, skill catalog) relevant to ytstack's design.

**Options considered:**
- A) Vendor the source material with attribution
- B) Only adapt concepts, re-implement in own prose, no source naming
- C) Skip external influence entirely

**Chose:** B

**Reason:** User explicit: "bitte nichts [...] 1:1 kopieren (keine binaries)" and later "namentliche Referenz [...] entfernen". Concepts aren't copyrightable, the source's text/images/graphics are. We take the structural ideas (tier-based context, artifact-as-memory, playbook-based skill creation), write our own prose, credit generically via NOTICE as "inspired by external AI-first methodology work" without naming the source.

---

## 2026-04-23: Skills-based plugin, not Agent SDK library

**Context:** ytstack could be (1) a Claude Code plugin with skills/hooks/commands, or (2) an Agent SDK-based library that replaces parts of Claude Code.

**Options considered:**
- A) Skills-based plugin (current approach)
- B) Agent SDK library with custom orchestrator
- C) Hybrid (plugin for skills, optional SDK for headless use)

**Chose:** A

**Reason:** Lower barrier to adoption (one-line install vs SDK integration). Claude Code plugins are the native extension point; fight the platform less. Keeps ytstack shareable via marketplace. Option C can be added later if demand appears.

---

## 2026-04-23: UX contracts enforced by CI, not convention

**Context:** superpowers and gstack each have their own UX patterns that feel consistent, but neither validates them mechanically. Drift happens.

**Options considered:**
- A) Codify UX rules in docs only, rely on contributor discipline
- B) Codify + write a `ytstack-skill-check` CI tool that validates every skill
- C) Generator-based approach (skill templates with substitution, like gstack's SKILL.md.tmpl)

**Chose:** B

**Reason:** gstack uses C and it works, but adds a build step and mental model complexity. B is simpler: write skills as plain markdown, validator enforces contract on commit. Can upgrade to C later if skill count grows past ~30.

---

## 2026-04-23: `.ytstack/` location is user-chosen (project vs user vs both)

**Context:** Where should project memory artifacts live? In the repo (git-tracked) or in user-home (private)?

**Options considered:**
- A) Project-only (./.ytstack/ in repo, committed)
- B) User-only (~/.ytstack/projects/<slug>/)
- C) User chooses per project (init-project asks)

**Chose:** C with A as the recommended default.

**Reason:** Different projects have different needs (open-source shareable vs solo secret project). Asking costs ~10 seconds, making the wrong default costs data loss or accidental public commits. Project-level recommended because most builders want team-shared context and survival-against-hardware-failure.

---

## 2026-04-23: Accept Agent Teams experimental status as known risk

**Context:** Claude Code's Agent Teams feature is the core mechanism we rely on for fresh-context-per-task (replacing what GSD's TypeScript runtime does). It is marked experimental, requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, and needs v2.1.32+. Documented limitations: no session resume with in-process teammates, task-status-lag, no nested teams, no session transfer of lead role.

**Options considered:**
- A) Wait for stable release before building M006
- B) Build on experimental API, pin version, document risk
- C) Build without Agent Teams, use regular subagents (reduced parallelism)

**Chose:** B

**Reason:** Waiting for stable could be months; the feature is core to our value prop. Pinning Claude Code version in our plugin manifest + a prominent README warning + graceful fallback to subagents (M006) if teams are unavailable mitigates most risk. Experimental APIs moving under us is the price of being early.

**How to apply:** M006 skills MUST detect `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` and Claude Code version in preamble, emit clear guidance if missing, fall back to subagent-based workflow if teams unavailable.

---

## 2026-04-23: Cherry-pick prioritization based on production evidence

**Context:** superpowers and gstack each offer many skills. Vendoring all of them bloats the plugin, conflicts with other plugins, and increases maintenance. We need a triage.

**Options considered:**
- A) Vendor everything, disable via config
- B) Vendor only the skills with documented production-value evidence
- C) Vendor nothing, write all skills from scratch

**Chose:** B

**Reason:** Production evidence from independent comparison articles flagged specific skills as highest-value: `plan-ceo-review` (gstack) as "most valuable" for forcing requirement clarification; `test-driven-development` (superpowers) for measurable regression reduction; `systematic-debugging` and `verification-before-completion` as execution foundations. Start with these 5-6, add more only when a real use case appears.

**How to apply:** M004 and M005 wrapper skills target only the proven set. Other skills from upstream stay vendored (for git-subtree sync simplicity) but ytstack does not surface them until there's a case.

---

## 2026-04-23: Known risk -- superpowers interactive prompts may block Claude Code input

**Context:** An independent comparison article reported that superpowers' interactive prompts (within its brainstorming/writing-plans flow) can block Claude Code's input during builds. We haven't reproduced it in a controlled test. This is documented as a known risk, not a settled bug.

**Options considered:**
- A) Reproduce the bug before building anything with superpowers skills
- B) Build wrappers that sidestep the interactive pattern (our wrappers invoke superpowers in non-interactive mode where possible)
- C) Skip superpowers execution skills entirely

**Chose:** B, with a verification task scheduled in M005.

**Reason:** The skills are too valuable to skip, but we must not inherit the bug. Our wrappers will pass `YTSTACK_NON_INTERACTIVE=1` or equivalent to downstream superpowers invocations when running inside an Agent-Teams teammate or inside an automated workflow. M005 includes an explicit verification task to reproduce and characterize the original bug before we ship.

**How to apply:** Every superpowers wrapper MUST explicitly set non-interactive mode for orchestrated contexts. Verification task in M005 reproduces + documents the original failure mode.

---

## 2026-04-24: Add `using-ytstack` skill + SessionStart-hook-injected directive for agent-driven skill selection

**Context:** Initial M002 SessionStart hook injected only project state (milestone / slice / task position + recent summaries). It did NOT tell the agent it should auto-invoke ytstack skills. Result: ytstack behaved as a slash-command menu the user had to drive manually. superpowers' magic is that their SessionStart hook reads the full `using-superpowers/SKILL.md` content and injects it as a forceful directive -- the agent then proactively reaches for skills based on natural-language user intent.

**Options considered:**
- A) Rely on Claude Code's native skill-description matching. Every ytstack skill already has a `description` field -- Claude should pick up on them based on context.
- B) Add a `using-ytstack` skill with a trigger map (phrase → skill), Red Flags anti-rationalization table, and EXTREMELY-IMPORTANT directive. Update SessionStart hook to inject its content alongside project state.
- C) Add slash-command aliases for common phrases (e.g. auto-map "where were we" to `/ytstack:resume-session` via a preprocessor).

**Chose:** B.

**Reason:** M001 T05 smoke test already revealed Claude Code's native skill-description matching does NOT reliably trigger in headless mode (Skill-tool-invocation errored as "not registered in the harness"). superpowers' pattern proves the injected-directive approach works -- their ~40 skills reliably auto-fire because `using-superpowers` primes the agent with compliance pressure ("1% chance a skill applies → invoke"). Option A alone is not strong enough. Option C would surface user-level string-matching that conflicts with Claude Code's own slash-command-parser. Option B follows the proven superpowers pattern.

**How to apply:**
- `skills/using-ytstack/SKILL.md` contains the trigger map (natural-language phrase → ytstack skill), EXTREMELY-IMPORTANT directive, and anti-rationalization Red Flags.
- `hooks/session-start` reads and injects its full content as `additionalContext` JSON, wrapped in an `<EXTREMELY_IMPORTANT>` envelope, BEFORE the project state block.
- Total injected context per session start is ~8.5KB -- non-trivial but within Claude Code's context budget.
- The README reframes ytstack as agent-driven: user talks naturally, agent auto-fires skills; slash-commands are the steering override for non-happy-path cases.

---

## 2026-04-24: User-facing skill count is flat, one SKILL.md = one skill

**Context:** `/check-consistency` 2026-04-24 flagged that README.md contradicts itself and disk on the skill count. README:131 said "15 skills", README:145 said "14 skill packages", disk has 16 directories under `skills/`. `docs/concept.md` §9 had pre-flagged this drift. Root cause: `using-ytstack` lives as a `SKILL.md` under `skills/` but carries `kind: directive` and description "Not meant for direct user invocation", which opens a semantic question whether it should count as "a skill ytstack ships".

**Options considered:**
- A) Flat count -- every SKILL.md under `skills/` counts as one skill. README says "16 skills".
- B) Role-split count -- README says "15 user-invocable skills + 1 internal directive".
- C) Restructure -- move `using-ytstack` out of `skills/` into `hooks/` so it is not a skill at all. Breaks 1:1 parallelity with superpowers' `using-superpowers`.

**Chose:** A.

**Reason:** User-facing README numbers answer "how big is this thing"; one number is the useful answer. The directive-vs-action distinction lives in the skill's own frontmatter (`kind: directive`) and description, which is sufficient for internal tooling. Option C was rejected after checking `vendor/superpowers/hooks/session-start` (2026-04-24): superpowers uses the exact same shape we do (SKILL.md read via `cat`, injected as `additionalContext` JSON), and the pattern rides on an officially documented Claude Code API (SessionStart hook + `additionalContext`). Deviating from the proven pattern to paper over a Claude-Code-side feature gap (no manifest flag for `invocable: false`) would force a reverse migration the moment Anthropic ships such a flag. Option B surfaces internal semantics in user-facing prose for no reader benefit.

**How to apply:**
- Every directory under `skills/` that contains a `SKILL.md` counts as one skill in user-facing docs.
- README.md currently at "16 skills" (§Status) and "16 skill packages" (§Repo layout); `/check-consistency` enforces this on every run.
- `docs/concept.md` §9 drift bullet removed; the live `/check-consistency` run is now the enforcement surface.
- If Claude Code later ships `invocable: false` or equivalent in the plugin manifest, revisit this decision via a superseding entry and consider surfacing the directive/invokable split in README prose.

---

## 2026-04-24: ytstack self-marketplaces, no separate `-marketplace` repo

**Context:** Original M008 planning assumed a two-repo design: `Yesterday-AI/ytstack` (plugin source) plus a separate `Yesterday-AI/ytstack-marketplace` (marketplace manifest pointer). Research against Claude Code's official plugin-marketplace docs (2026-04-24) confirmed `.claude-plugin/marketplace.json` inside the plugin repo is natively supported as a "self-marketplace" -- no separate marketplace repo required. Keeping two repos would be duplicate maintenance for zero user benefit.

**Options considered:**
- A) Two-repo design: `Yesterday-AI/ytstack` + `Yesterday-AI/ytstack-marketplace`. Marketplace.json only in the marketplace repo.
- B) Self-marketplace: one repo (`Yesterday-AI/ytstack`) holds both `plugin.json` and `marketplace.json` under `.claude-plugin/`, with the marketplace entry's `source` pointing at the same repo (`"./."`).

**Chose:** B.

**Reason:** Officially documented in Claude Code's plugin-marketplaces reference; removes one repo's worth of maintenance + sync overhead; collapses install to a single reference (`/plugin marketplace add Yesterday-AI/ytstack && /plugin install ytstack@ytstack-marketplace`). No downside surfaced during research. Applied in-session: README, QUICKSTART, docs/references.md, .ytstack/ROADMAP.md, RUNTIME.md, REVIEW-NOTES.md, STATE.md all reconciled; marketplace.json rewritten with `source: "./."` and stale `$note` removed.

**How to apply:**
- Install command everywhere: `/plugin marketplace add Yesterday-AI/ytstack` (plugin repo itself, not a separate marketplace repo), followed by `/plugin install ytstack@ytstack-marketplace` (marketplace name from the json).
- `.claude-plugin/marketplace.json` uses `"source": "./."` for self-reference.
- If a future decision adds community-maintained marketplaces (e.g. a Yesterday-wide or Anthropic-official marketplace listing), they can also reference ytstack -- this decision only commits that the primary, vendor-owned marketplace lives in-repo.

---

## 2026-04-24: Skill-level path fallbacks must fail-fast, not hardcode absolute Alex-only paths

**Context:** Six plugin skills (test-driven-development, systematic-debugging, office-hours, plan-eng-review, verification-before-completion, plan-ceo-review) and one project-meta skill (check-consistency) used `${CLAUDE_PLUGIN_ROOT:-/Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack}` as the vendor-skill path resolution pattern. The fallback was Alex's machine-local absolute path, which would break on any other machine if the env var was unset.

**Options considered:**
- A) Leave hardcoded absolute fallback.
- B) Fail-fast with `${CLAUDE_PLUGIN_ROOT:?msg}` for plugin skills; portable fallback `${CLAUDE_PROJECT_DIR:-$PWD}` for project-meta skills.
- C) Derive plugin root from the running script via `$0` / `BASH_SOURCE`.

**Chose:** B.

**Reason:** Plugin skills only ever run inside Claude Code, where `CLAUDE_PLUGIN_ROOT` is set by the harness. If it's ever missing, the right behavior is an explicit error, not silent wrong-path execution against someone else's filesystem. Option C is brittle because SKILL.md bash blocks don't have a reliable `$0` from Claude Code's execution context. Project-meta skills (only check-consistency so far) use `CLAUDE_PROJECT_DIR` with `$PWD` fallback, matching the existing pattern in other ytstack preambles.

**How to apply:**
- Plugin skills: `"${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/..."`
- Project-meta skills (under `.claude/skills/`): `"${CLAUDE_PROJECT_DIR:-$PWD}"`
- Never reintroduce absolute user-machine paths as fallbacks.

---

## 2026-04-24: Marketplace name equals plugin name

**Context:** Follow-up to earlier 2026-04-24 "ytstack self-marketplaces". The marketplace.json `"name"` field was still `"ytstack-marketplace"`, a leftover from the original two-repo plan. Produced the confusing install command `/plugin install ytstack@ytstack-marketplace` -- readers asked where the `-marketplace` suffix came from when there is no separate marketplace repo.

**Research:** Checked upstream convention via `vendor/superpowers/.claude-plugin/marketplace.json` -- superpowers uses `"superpowers-dev"` (plugin name + channel suffix, not `-marketplace`). Official Claude Code docs do not mandate a naming convention; reserved names exist but third-party marketplaces pick freely.

**Options considered:**
- A) `"ytstack"` -- match the plugin name. Install: `ytstack@ytstack`.
- B) Keep `"ytstack-marketplace"`. Misleading now that no separate marketplace repo exists.
- C) `"ytstack-dev"` -- mimic superpowers, implies a dev channel. We do not have stable-vs-dev channels.

**Chose:** A.

**Reason:** Simplest, no implied channel distinction, no stale `-marketplace` suffix. The install command reads as "plugin ytstack from marketplace ytstack" -- redundant but unambiguous. Matches the self-marketplace spirit: one repo, one marketplace, minimum naming overhead.

**Supersedes:** the "How to apply" bullet in "2026-04-24: ytstack self-marketplaces, no separate `-marketplace` repo" that specified `ytstack@ytstack-marketplace`. New install: `/plugin install ytstack@ytstack`.

---

## 2026-04-24: Skill selection is semantic (description-based), not keyword-based

**Context:** The initial `using-ytstack/SKILL.md` included a trigger-map table mapping explicit user phrasings (`"baue mir X"`, `"build me X"`, `"new project"`, ...) to ytstack skills, plus a "Greenfield flow" section encoding a specific 6-step chain. Both were added by the agent during the using-ytstack authoring pass on 2026-04-24 (documented in the "Add `using-ytstack` skill" decision earlier today) as a defensive workaround for headless-mode skill-tool registration failures observed in M001 T05.

Review 2026-04-24 revealed two problems:
1. Phrase-matching is an antipattern. Every new user phrasing (German, paraphrase, domain-specific word) needs an explicit table entry; otherwise the agent silently misses. Fragile by construction. User feedback: "ich glaube den workflow an phrasen zu matchen ist ein unkontrollierbares antipattern."
2. Other Claude-Code plugins (superpowers, claude-md-management, code-review, security-guidance) do NOT use trigger-map tables. They rely on the `description:` field in each skill's frontmatter, which Claude Code's model matches semantically against user intent. Docs confirm: "description - What the skill does and when to use it. Claude uses this to decide when to apply the skill."
3. The M001 T05 headless-mode evidence that motivated the trigger-map did not apply to interactive-mode: superpowers has ~40 skills in production use without a trigger-map. The workaround was applied to the wrong layer.

**Options considered:**
- A) Keep trigger-map (status quo). Pro: explicit routing for known phrasings. Con: brittle, requires maintenance per new phrasing, fragile-by-construction.
- B) Remove trigger-map entirely, rely on skill `description:` semantic matching + using-ytstack directive pressure (the superpowers pattern). Pro: matches documented Claude Code mechanism, handles unknown phrasings naturally, less maintenance. Con: requires each skill to have a rich, context-rich description; testing is LLM-judgment-based rather than deterministic.
- C) Hybrid: keep trigger-map as "fast path", fall back to description-matching. Pro: both paths available. Con: two codepaths to maintain; the trigger-map path becomes an authoritative-seeming-but-incomplete list that drifts out of sync with descriptions.

**Chose:** B.

**Reason:** The trigger-map is the mechanism that superpowers deliberately does not have. Description-matching is how Claude Code skills are meant to be selected per documentation. Adding a phrase-list on top is scope-creep (same pattern as the banned-words list that was rolled back in the previous DECISIONS entry). It also reduces context-budget pressure on every session start because the directive becomes smaller.

**How to apply:**
- `skills/using-ytstack/SKILL.md` rewritten without the trigger-map table and greenfield-flow section. Kept: SUBAGENT-STOP, EXTREMELY-IMPORTANT, instruction priority, the rule (now description-first), skill priority (process / structural / execution), Red Flags table, process flow DOT. Version bumped to 0.2.0.
- Five skill `description:` fields sharpened to encode greenfield-vs-milestone context + ordering (office-hours, init-project, plan-ceo-review, plan-eng-review, plan-milestone). Each description now states situational when-to-use that semantically covers expected user phrasings without listing keywords.
- Added `using-ytstack/SKILL.md` version bump (0.1.0 -> 0.2.0) reflecting the structural change.
- Added a design principle to README.md: "Skill selection via semantic descriptions, not keyword matching."

**Supersedes:** the trigger-map and greenfield-flow portions of "2026-04-24: Add `using-ytstack` skill + SessionStart-hook-injected directive for agent-driven skill selection". The SessionStart-hook-injection pattern and 1%-rule directive stand. The trigger-map portion is retired.

---

## 2026-04-24: Greenfield-flow reorder -- office-hours → plan-ceo-review → [plan-eng-review] → init-project → plan-milestone

**Context:** Smoke test 2026-04-24 in a greenfield dir with marketplace-installed plugin exposed the greenfield-flow first-skill miss concretely. Prompt "baue mir eine cli die csv-files liest und in postgres laedt" auto-invoked `ytstack:plan-milestone` (semantically matched "plan a milestone" / "what's next" rows) instead of any project-validation or infra-setup entry. Four combined root problems:

1. Trigger map: init-project triggers only on literal "init ytstack" / "new project" phrasings, missing natural build-intent like "baue mir X" / "build me X".
2. Skill ordering: plan-ceo-review + plan-eng-review are milestone-scoped (read `M###-CONTEXT.md` + `M###-ROADMAP.md`), cannot validate a project concept before any milestone exists.
3. init-project mixes infra-setup (scope decision, skeleton files) with PM content (name, one-liner) -- forces the user to invent pitch cold during infra-setup.
4. Even the currently-documented greenfield flow (QUICKSTART: init-project → plan-milestone → [optional plan-ceo-review]) is not reliably matched by agent behavior after the marketplace install.

REVIEW-NOTES 2026-04-24 "Greenfield-flow first-skill is wrong" and docs/concept.md §5.1 "Open design point" already proposed the target flow:

    office-hours (concept validation)
      → plan-ceo-review (premise + scope challenge)
      → [optional] plan-eng-review (architecture review)
      → init-project (infra-only: scope decision + skeleton files)
      → plan-milestone

**Options considered:**
- A) Surface-fix only: extend init-project trigger-map for build-intent phrasings ("baue mir X", "build me X"). Fastest. Leaves ordering, init-project split, and plan-ceo-review concept-mode unresolved.
- B) Partial: add dual-mode (concept + milestone) to plan-ceo-review + plan-eng-review; update trigger map for greenfield entry; leave init-project unchanged. Half-measure.
- C) Full: (1) dual-mode plan-ceo-review + plan-eng-review (concept + milestone), (2) init-project refactor -- PM questions removed, PROJECT.md name/one-liner populated from office-hours output instead, (3) office-hours' Terminal State points at plan-ceo-review, which points at plan-eng-review (optional) or init-project, which points at plan-milestone, (4) using-ytstack trigger map rewritten for greenfield routing, (5) README.md / QUICKSTART.md / docs/concept.md §5.1 updated for the new flow.

**Chose:** C.

**Reason:** Workflow orchestration is the foundational value of ytstack, not a deferrable polish. Shipping A or B would lock in the wrong default: every greenfield user lands in plan-milestone (or init-project with cold PM questions) before the project premise is validated -- contradicting ytstack's own methodology. The REVIEW-NOTES proposal is already the target; we simply haven't paid the implementation cost yet. User explicit 2026-04-24: "die orchestrierung des workflows ist die GRUNDLAGE fuer dieses plugin, das KOENNEN WIR NICHT AUFSCHIEBEN".

**How to apply:**
- New milestone **M010 "Greenfield Flow Reorder"** planned next via `ytstack:plan-milestone`, sliced via `ytstack:slice-milestone`.
- Artifacts in scope: `skills/office-hours/`, `skills/plan-ceo-review/`, `skills/plan-eng-review/`, `skills/init-project/`, `skills/using-ytstack/` (trigger map), `README.md`, `QUICKSTART.md`, `docs/concept.md` §5.1.
- Out of scope: no changes to downstream lifecycle skills (plan-milestone, slice-milestone, plan-task, summarize-task, reassess-roadmap, handoff-session, resume-session).
- Exit criterion: re-run same greenfield smoke test ("baue mir eine cli...") routes to `office-hours` first (not plan-milestone), and the documented flow in QUICKSTART matches observed agent behavior.
- Supersedes: the implicit ordering in QUICKSTART.md §1-6 and docs/concept.md §5.1. Those files are updated as part of M010 execution.

---

## 2026-04-24: Wrapper mechanism = shell-exec inject + cross-ref check

**Context:** Audit 2026-04-24 revealed that existing ytstack "wrappers" (`plan-ceo-review`, `plan-eng-review`, `office-hours`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`) mix prose indirection ("read vendor file and follow it") with partial adaptation / fork of vendor content. Worst case: `verification-before-completion` is 97% the size of the vendored original -- quasi-copy, not wrapper. Three of the six are thin (5-7% of vendor size), but even those use prose indirection rather than any CC-native mechanism. Both approaches violate the vendor-as-single-source-of-truth rule and will drift on upstream updates.

**Options considered:**
- A) Shell-exec content injection: wrapper body ends with `` `!`cat ${CLAUDE_PLUGIN_ROOT}/vendor/.../SKILL.md` `` to inline the vendor procedure verbatim at render time, with ytstack-specific context prepended. Documented CC feature.
- B) plugin.json `"skills"` as array pointing at vendor/ dirs. Unverified whether the schema supports arrays, and no context-injection possible before vendor-procedure runs.
- C) Stop wrapping -- ytstack ships only Project-OS skills, users install superpowers + gstack separately as their own plugins. Contradicts the README "one install" claim; loses ytstack-context-aware invocation.
- D) Symlinks in `skills/` pointing to `vendor/<name>/`. Works but offers no context-injection hook.
- paperclip `metadata.sources[]` + `usage: referenced`: spec-level wrap-vocabulary (agentcompanies.io/specification#external-references-and-pinning) but Claude Code has no native runtime that fetches / inlines / merges these references. Would require custom build tooling.

**Chose:** A.

**Reason:** Only A enforces vendor-as-SSOT (automatic flow-through of `./sync-upstream.sh` updates) while preserving the ytstack-context-injection we need (milestone file paths, STATE.md values, post-process instructions like "log scope decisions to DECISIONS.md"). D solves SSOT but loses context hook. B+C are either unverified or contradict positioning. `metadata.sources` is attractive conceptually but requires building our own runtime, which is out of scope for the current milestone. User explicit 2026-04-24: "shell inject kommt dem am naechsten, dann koennen wir anders als bei symlinks noch ein paar meta directives geben".

**How to apply:**
- Every wrapper SKILL.md becomes a thin file containing: minimal frontmatter (name + description + allowed-tools), a preamble ```` ```! ```` block that loads ytstack context (`_YT_DIR`, `_CURRENT_MILESTONE`, relevant artifact paths), a prose "ytstack invocation notes" section with milestone-specific context + post-process instructions, ending with ```` ```! \ncat "${CLAUDE_PLUGIN_ROOT:?}/vendor/<src>/SKILL.md"\n``` ```` to inline the vendored procedure.
- Wrappers rewritten in scope of this change: `plan-ceo-review`, `plan-eng-review`, `office-hours` (vendor/gstack), `test-driven-development`, `systematic-debugging`, `verification-before-completion` (vendor/superpowers/skills).
- Cross-ref check: extend `bin/ytstack-check` with a new validator that parses each vendored SKILL.md referenced by a wrapper, finds skill-name mentions inside the vendor text, and flags any reference that resolves to neither a ytstack-shipped skill nor a wrapped vendor skill. Output: REVIEW-NOTES drop-in with exact file:line of the dangling reference, so the human can decide (ship-additional-wrapper / rewrite-vendor-ref / accept-gap).
- Scope impact on M010: merged into the greenfield-flow-reorder milestone as "Part 1: Wrapper refactor (6 skills thin-wrapped + cross-ref check added)", "Part 2: Greenfield-flow reorder (office-hours first, dual-mode ceo/eng, init-project split)".

---

## 2026-04-25: Tagline -- "An opinionated OS for AI coding agents. Plan like a PM, execute like a senior eng."

**Context:** Original tagline ("Working memory for AI coding agents.") captured only the GSD-inspired persistence layer and undersold the other two pillars (curation of gstack + superpowers; execution discipline via TDD / systematic-debugging / verification gates). User flagged: "ist 'Working memory for AI coding agents.' wirklich die beste tagline?"

**Options considered:**
- A) Keep "Working memory for AI coding agents." -- punchy, memorable, but lopsided.
- B) "An opinionated OS for AI coding agents." -- covers all three pillars, generic on its own.
- C) "Plan like a PM, execute like a senior eng -- with AI agents." -- plakativ, already in the README body as a claim.
- D) Compound: "An opinionated OS for AI coding agents. Plan like a PM, execute like a senior eng." -- positioning + framing in two sentences.

**Chose:** D.

**Reason:** The compound form is the only one that lands all three positioning angles (curation, memory, discipline) without dropping the punch. Two short sentences read fine in the README header `<em>` slot and in `docs/concept.md` §1.1. Em-dash dropped per writing-style.md (the original `--` candidate `Plan like a PM, execute like a senior eng -- with AI agents` had a dangling redundancy with the leading "AI coding agents" phrase, which D eliminates).

**How to apply:**
- README.md header `<p><em>...</em></p>` updated.
- `docs/concept.md` §1.1 (What) updated to keep concept paper in sync.
- Future external surfaces (GitHub repo description, marketplace.json description, social previews) should mirror this exact phrasing or its short form ("An opinionated OS for AI coding agents.").
- `marketplace.json` description currently reads "Yesterday Technologies Stack -- opinionated software-development OS for AI agents." which is consistent in spirit; do not edit defensively, but next time it touches, align fully.

---

## 2026-04-25: README workflow diagrams use collapsible `<details>` blocks; greenfield expanded by default

**Context:** The three workflow infographics (greenfield, brownfield, debugging) are large PNGs. Embedding all three inline pushes the README's body content (Install / Compared-to / How-it-works) below the fold and overwhelms first-time readers.

**Options considered:**
- A) Inline all three PNGs (status quo before this decision).
- B) Collapse all three behind `<details>` -- cleanest, but hides the primary visual on first load.
- C) Expand greenfield (the canonical "what is this?" diagram) by default, collapse brownfield + debugging.

**Chose:** C.

**Reason:** Greenfield is the on-ramp for first-time readers and matches the README's sequencing (Why -> What it does -> Workflows -> Install). Brownfield + debugging are reference material for users who already know ytstack's shape, so collapsing them keeps the page scannable without burying the primary diagram. User explicit: "kannst du das greenfield standard ausgeklappt machen?"

**How to apply:**
- `<details open>` for the greenfield section, summary text reads "click to collapse".
- Plain `<details>` for brownfield + debugging, summary text reads "click to expand".
- All three `summary` lines use `<strong>` for visibility.
- This convention applies to README only. QUICKSTART.md and concept.md don't embed images.

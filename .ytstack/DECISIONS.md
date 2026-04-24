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

**Reason:** Claude Code's native Agent Teams feature already provides fresh 200k-context-per-task and shared task list with file-locking — the core value GSD's runtime adds. Combined with hooks (SessionStart/TeammateIdle/TaskCompleted) and skill-managed `.ytstack/` artifacts, we replicate ~95% of GSD's value without a runtime app. User explicitly ruled out B ("zusaetzlich installieren, das wird zu viel").

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

## 2026-04-23: Known risk — superpowers interactive prompts may block Claude Code input

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

**Context:** Initial M002 SessionStart hook injected only project state (milestone / slice / task position + recent summaries). It did NOT tell the agent it should auto-invoke ytstack skills. Result: ytstack behaved as a slash-command menu the user had to drive manually. superpowers' magic is that their SessionStart hook reads the full `using-superpowers/SKILL.md` content and injects it as a forceful directive — the agent then proactively reaches for skills based on natural-language user intent.

**Options considered:**
- A) Rely on Claude Code's native skill-description matching. Every ytstack skill already has a `description` field — Claude should pick up on them based on context.
- B) Add a `using-ytstack` skill with a trigger map (phrase → skill), Red Flags anti-rationalization table, and EXTREMELY-IMPORTANT directive. Update SessionStart hook to inject its content alongside project state.
- C) Add slash-command aliases for common phrases (e.g. auto-map "where were we" to `/ytstack:resume-session` via a preprocessor).

**Chose:** B.

**Reason:** M001 T05 smoke test already revealed Claude Code's native skill-description matching does NOT reliably trigger in headless mode (Skill-tool-invocation errored as "not registered in the harness"). superpowers' pattern proves the injected-directive approach works — their ~40 skills reliably auto-fire because `using-superpowers` primes the agent with compliance pressure ("1% chance a skill applies → invoke"). Option A alone is not strong enough. Option C would surface user-level string-matching that conflicts with Claude Code's own slash-command-parser. Option B follows the proven superpowers pattern.

**How to apply:**
- `skills/using-ytstack/SKILL.md` contains the trigger map (natural-language phrase → ytstack skill), EXTREMELY-IMPORTANT directive, and anti-rationalization Red Flags.
- `hooks/session-start` reads and injects its full content as `additionalContext` JSON, wrapped in an `<EXTREMELY_IMPORTANT>` envelope, BEFORE the project state block.
- Total injected context per session start is ~8.5KB — non-trivial but within Claude Code's context budget.
- The README reframes ytstack as agent-driven: user talks naturally, agent auto-fires skills; slash-commands are the steering override for non-happy-path cases.

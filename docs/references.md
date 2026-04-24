# References

Sources consulted while designing ytstack. Contributors should read these before proposing architectural changes. Newest at top within each section.

## Upstream skill frameworks

### superpowers

- **Repo:** https://github.com/obra/superpowers
- **Maintainer:** Jesse Vincent (obra)
- **What we take:** execution-discipline skills (test-driven-development, systematic-debugging, verification-before-completion). Their SessionStart-hook pattern (injecting `using-superpowers` SKILL.md content via `additionalContext`) is the template for our own bootstrap mechanism.
- **What we deliberately leave:** most of their methodology skills (brainstorming, writing-plans, executing-plans) -- they conflict with our milestone/slice/task model. Their contributor rules explicitly reject "compliance" rewrites of their skill content; we respect that by vendoring read-only.
- **Rules we inherit:** "don't modify carefully-tuned content without eval evidence." We enforce: vendor is read-only, wrap-don't-edit.

### gstack

- **Upstream:** Garry Tan's framework, distributed via `./setup` into `~/.claude/skills/gstack/` as symlinks per skill folder.
- **What we take:** planning/decision skills (plan-ceo-review, office-hours, plan-eng-review). Their AskUserQuestion-format contract (Re-ground + Simplify + RECOMMENDATION + Options-with-Completeness-score) is the strongest UX pattern in the Claude Code skill ecosystem and is the direct basis for `docs/ux/askuserquestion-format.md`.
- **What we deliberately leave:** the preamble-tier/`bun run gen:skill-docs` generator pattern -- too heavy for our use case. We write SKILL.md directly and validate via our own `ytstack-skill-check` tool (planned M001).
- **UX ideas we adopt:** sentinel-files-for-ask-once, cascading-binary-questions, spawned-session-detection, outcome-framing, jargon-gloss-list, banned-words enforcement. All in `docs/ux/`.

### GSD v2

- **Repo:** https://github.com/gsd-build/gsd-2
- **What it is:** A standalone TypeScript application that orchestrates Claude Code sessions. Spawns fresh Claude processes per task, persists state to SQLite, maintains `.gsd/` artifact hierarchy (`PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `M###-ROADMAP.md`, `S##-PLAN.md`, `T##-PLAN.md`, `T##-SUMMARY.md`, `STATE.md`, and more).
- **What we take:** the artifact hierarchy (project → milestone → slice → task with corresponding `.md` files), the phase workflow (discuss → plan → execute → verify → ship), the quality gates (verification commands, retry budgets, slice-discussion-gate, milestone-validation-gate).
- **What we deliberately leave:** the TypeScript runtime, SQLite, event-log JSONL, TUI, multi-worker IPC, parallel/worktrees management, cost tracking. Explicit decision in `.ytstack/DECISIONS.md` (2026-04-23). We replicate the 80/20 essence via Claude Code's native Agent Teams + our skills + hooks.
- **v1 repo:** https://github.com/gsd-build/get-shit-done (reference only, we target v2 concepts)

### External AI-first methodology

- **What we take:** conceptual framework (three-tier context model, component-based system thinking, skill-playbook-based skill creation). Referenced generically in our artifacts -- not by source name -- per user direction.
- **What we deliberately leave:** verbatim prose, images, enumerated catalogs. Concepts only.
- **Attribution:** via `NOTICE` (M008) as "inspired by external AI-first methodology work" -- no name, no URL.

## Comparison articles

These two independent articles shaped our cherry-pick decisions and our architectural philosophy.

### "A Claude Code Skills Stack: How to Combine Superpowers, gstack, and GSD without the Chaos" (dev.to, imaginex)

- **URL:** https://dev.to/imaginex/a-claude-code-skills-stack-how-to-combine-superpowers-gstack-and-gsd-without-the-chaos-44b3
- **Key insight:** Treat the three frameworks as a three-layer system -- gstack is decision, superpowers is execution, GSD is context/specs. Sequential use beats parallel use.
- **Key quote:** "Stop asking: 'Superpowers or gstack?' Ask: _Am I missing decision, context, or execution?_"
- **Relevance:** confirmed our architecture: ytstack handles decision (via gstack wrappers) + execution (via superpowers wrappers) + context/specs (native skills + hooks). GSD stays uninstalled; we replicate its layer natively.

### "Superpowers, GSD, and gstack: What Each Claude Code Framework Actually Constrains" (Medium, tentenco)

- **URL:** https://medium.com/@tentenco/superpowers-gsd-and-gstack-what-each-claude-code-framework-actually-constrains-12a1560960ad
- **Key insights:**
  - Superpowers constrains development methodology; GSD constrains environmental health (context rot); gstack constrains decision roles.
  - Author's production-team evidence: `/plan-ceo-review` is the single most valuable gstack skill. TDD in superpowers meaningfully reduces regressions but costs tokens. GSD's context isolation holds quality on 50+-file projects through hour three.
  - Documented friction: "Superpowers' interactive prompts blocking Claude Code's input during builds" -- prevents seamless integration. This is a known risk we mitigate via non-interactive mode in wrappers (see `.ytstack/DECISIONS.md`).
- **Relevance:** production evidence drove our cherry-pick priority list (plan-ceo-review first; TDD second; verification-before-completion third).

## Claude Code platform features

We leaned on Claude Code's official docs to map GSD features to native capabilities.

### Central index

- **All docs index:** https://code.claude.com/docs/llms.txt
- **Overview:** https://code.claude.com/docs/en/overview

### Features directly relevant to ytstack

| Feature | URL | How ytstack uses it |
|---|---|---|
| Hooks (SessionStart, PreCompact, SessionEnd, PreToolUse, PostToolUse, Stop) | /docs/en/hooks | M002 lifecycle + M007 quality gates |
| Agent Teams (experimental) | /docs/en/agent-teams | M006 fresh-context-per-task (replaces GSD runtime) |
| Subagents | /docs/en/sub-agents | Fallback when Agent Teams unavailable |
| Skills | /docs/en/skills | Core unit of extension |
| Plugins | /docs/en/plugins | ytstack ships as plugin |
| Plugin marketplaces | /docs/en/plugin-marketplaces | M008 distribution |
| Channels | /docs/en/channels | Future: external trigger integration |
| Routines | /docs/en/routines | Future: cloud-scheduled autonomous runs |
| Checkpointing | /docs/en/checkpointing | State recovery, reduces need for custom crash-recovery |
| Sessions (continue/resume/fork) | /docs/en/agent-sdk/sessions | Handoff mechanism foundation |
| Memory / CLAUDE.md | /docs/en/memory | Project instructions layer above ytstack |
| MCP (Model Context Protocol) | /docs/en/mcp | Custom tool integration path |
| Agent SDK | /docs/en/agent-sdk/overview | Deferred -- ytstack is plugin-first, not SDK-based |

### Hook events we plan to use

From https://code.claude.com/docs/en/hooks.md (and the Agent Teams extension at /docs/en/agent-teams#enforce-quality-gates-with-hooks):

- `SessionStart` (matcher: `startup|clear|compact`) -- M002
- `PreCompact` -- M002
- `SessionEnd` -- M002
- `PreToolUse` (matchers: Edit|Write|MultiEdit, Bash) -- M007
- `PostToolUse` -- M007
- `TeammateIdle` -- M006
- `TaskCreated` -- M006
- `TaskCompleted` -- M006

## Internal context

- **User direction:** ytstack is "Yesterday Technologies Stack" -- ESD-focused (Enterprise Software Development), enterprise-capable but equally useful for solo dev.
- **yesterday-os project:** exploratory scratch folder, NOT a separate product. Contains material we used to understand agent-OS patterns. ytstack does not merge with it.
- **User scope-discipline rule:** never modify files outside current project directory without asking. See repo root `CLAUDE.md` (contributor guide).
- **Related Yesterday repos:** `Yesterday-AI/agentic-foundation` (sibling AI-foundation library, some skills installed as symlinks separately from ytstack).

## Not sources (clarifications)

- **gstack-marketplace** -- we do NOT publish to or depend on gstack's marketplace. ytstack self-marketplaces: `.claude-plugin/marketplace.json` lives in the plugin repo itself (`Yesterday-AI/ytstack`), no separate marketplace repo. See DECISIONS 2026-04-24.
- **superpowers-marketplace** -- same. We install superpowers as a git-subtree VENDOR, not as an installed plugin that users need separately.
- **claude-plugins-official** -- Anthropic's official marketplace, source of the superpowers plugin we originally installed before deciding to vendor it into ytstack.

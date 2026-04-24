---
last_updated: 2026-04-24
source: live scan of vendor/gstack/skills/ + vendor/superpowers/skills/ via Explore agents
purpose: full inventory of upstream skills so ytstack design decisions are grounded in reality, not in assumptions about what each vendor contains
---

# Vendor Skill Inventory

Complete list of every skill in both vendored upstreams. Maintained as a reference so that planning decisions ("where does this belong?", "is there already a skill for X?") can be made against actual upstream content instead of half-remembered summaries.

**Architecture reference:** ytstack's wrapped-skill scope and cherry-pick rationale are locked in `docs/concept.md` + `.ytstack/DECISIONS.md`. This inventory exists to ground future "does skill X exist upstream?" questions in reality, not to re-debate what belongs in ytstack.

---

## gstack (43 skills)

Garry Tan's opinionated full-stack framework. Vendored at `vendor/gstack/`.

### Planning & Strategy

| Skill | Purpose | When |
|---|---|---|
| `office-hours` | Product context gathering. Interviews the user about product, market, users, differentiators; captures "memorable thing" + competitive positioning. | Before a pitch exists; user has a product/idea already in mind and needs it articulated. |
| `autoplan` | Auto-review pipeline. Reads all CEO/design/eng/DX review skills, runs them sequentially with auto-decisions, surfaces taste decisions at a final approval gate. One command → fully reviewed plan. | When a plan exists and needs the full review gauntlet automatically. |
| `plan-ceo-review` | Strategic CEO review (plan mode). Validates premises, explores alternatives, evaluates scope completeness. | A plan exists and you want to challenge its premises / scope before building. |
| `plan-design-review` | Design review for plans. Evaluates design mockups / decisions in the plan context before implementation. | Plan contains visual / UX decisions and you want a design-expert pass. |
| `plan-eng-review` | Engineering review for plans. Architecture, test strategy, performance validation before coding starts. | Plan is written, now vet the engineering approach. |
| `plan-devex-review` | DX review for plans. Getting-started time, API ergonomics, error messages. | Plan includes public API / developer surface. |
| `plan-tune` | Plan optimization. Refines scope, sequencing, and risk before implementation. | Plan is reviewed but needs tightening before handoff. |

### Design (visual + system)

| Skill | Purpose | When |
|---|---|---|
| `design-consultation` | Design system creation. Researches competitive landscape, proposes complete aesthetic + typography + color + spacing + motion. Creates DESIGN.md. | At the start of a visual project; need a system. |
| `design-shotgun` | Visual design variants. Generates multiple AI design directions, browser-based comparison board, iterate. | Exploring visual direction; need options. |
| `design-html` | Pretext-native HTML engine. Produces production-quality HTML from approved mockups or plans; text reflow, computed heights. | Turning an approved design into production HTML. |
| `design-review` | Live design audit & fix. Finds inconsistency, spacing issues, hierarchy, AI-slop patterns on live sites. Iteratively fixes, commits atomically, before/after screenshots. | Post-ship design QA. |

### Execution & Implementation

| Skill | Purpose | When |
|---|---|---|
| `ship` | Create PR with structure. Bumps VERSION, writes CHANGELOG from commits, generates PR body, pre-merge safety checks. | Work is done, creating the PR. |
| `land-and-deploy` | Merge + deploy + verify. Merges PR, waits for CI/deploy, canary-checks prod, offers revert on health issues. | PR approved; ready to merge + deploy in one go. |
| `document-release` | Post-ship docs update. Reads docs, cross-refs diff, updates README / ARCHITECTURE / CLAUDE.md / CHANGELOG / VERSION. | After a release, before the next task. |

### QA & Testing

| Skill | Purpose | When |
|---|---|---|
| `qa` | Test execution with teardown. Runs suite, compares to baseline, flags regressions, generates regression test for failures. | Full test pass with fix loop. |
| `qa-only` | Test runner without code changes. | Just wants results, no auto-fix. |
| `review` | Code review with pass/fail gate. Independent diff review: architecture, edges, tests, security. | Pre-merge diff review. |
| `codex` | OpenAI Codex CLI wrapper. Three modes: review (pass/fail), challenge (adversarial), consult (session-continuity Q&A). | Want a second opinion from a different model. |

### Monitoring & Post-Deploy

| Skill | Purpose | When |
|---|---|---|
| `browse` | Fast headless browser for QA. Navigate, interact, verify page state, screenshots. ~100ms per command. | Any live-browser verification. |
| `benchmark` | Performance regression detection. Establishes baselines, compares before/after on every PR. | Performance-sensitive changes. |
| `canary` | Post-deploy visual monitor. Watches live app for console errors, perf regressions, broken links. | After deploy, watch for regressions. |

### Debugging & Health

| Skill | Purpose | When |
|---|---|---|
| `investigate` | Systematic debugging. Four phases: investigate / analyze / hypothesize / implement. Iron Law: no fixes without root cause. | Any bug or unexplained behavior. |
| `health` | Code quality dashboard. Wraps type-checker, linter, test runner, dead-code detector, shell linter. Composite 0-10 score, trend tracking. | Quality snapshot / drift detection. |

### Security & Safety

| Skill | Purpose | When |
|---|---|---|
| `cso` | Chief Security Officer audit. Infra-first security: secrets archaeology, deps supply chain, CI/CD, LLM security, OWASP, STRIDE. Two modes (daily / comprehensive). | Security audit / pre-launch gate. |
| `careful` | Warns before destructive commands (rm -rf, DROP, force-push, reset --hard, kubectl delete). User can override. | Touching risky state. |
| `freeze` | Restrict Edit/Write to a directory. | Working in prod-adjacent areas. |
| `guard` | Combines careful + freeze for max safety. | Maximum-caution sessions. |

### Knowledge & Context

| Skill | Purpose | When |
|---|---|---|
| `learn` | Manage project learnings. Review, search, prune, export across sessions. | Capturing lessons. |
| `context-save` | Save working context. Captures git state, decisions, remaining work for cross-session resume. | End of a session / handoff. |
| `context-restore` | Restore saved context across branches. | Start of a new session / picking up. |

### Infrastructure & DevOps

| Skill | Purpose | When |
|---|---|---|
| `setup-deploy` | Configure deployment URL, workflow, health checks. Saves to CLAUDE.md. | First-time deploy setup. |
| `setup-gbrain` | Authenticates gstack's AI learning system. | Bootstrap gbrain integration. |
| `setup-browser-cookies` | Imports cookies/auth for live testing on sites requiring login. | Live-testing auth'd flows. |
| `landing-report` | Version-queue dashboard. Read-only snapshot of which VERSION slots are claimed by open PRs. | Release coordination. |

### Reporting

| Skill | Purpose | When |
|---|---|---|
| `make-pdf` | Publication-quality PDFs from markdown (1in margins, curly quotes, optional cover + TOC, DRAFT watermark). | Finished-artifact PDFs, not drafts. |

### Skill Management

| Skill | Purpose | When |
|---|---|---|
| `gstack-upgrade` | Upgrade gstack. Detects global vs vendored, runs upgrade, shows what's new. | Upgrading the framework itself. |

### OpenClaw-Nested (4 skills)

Nested variants of ceo-review / investigate / office-hours / retro specifically for the OpenClaw agent-runtime. Not directly relevant for ytstack users unless they're also on OpenClaw.

---

## superpowers (14 skills)

Jesse Vincent's (obra) metacognition-focused skills. Vendored at `vendor/superpowers/`.

### Planning & Exploration (!!)

| Skill | Purpose | When |
|---|---|---|
| `brainstorming` | Explores user intent, requirements, design through dialogue. Presents 2-3 approaches with trade-offs. Gets approval before implementation. Produces a spec in `docs/superpowers/specs/*.md`. | Before ANY creative work. Pre-idea / idea-exploration phase. |
| `writing-plans` | Creates comprehensive implementation plans: bite-sized tasks (2-5 min each), exact file paths, complete code, test commands. Assumes zero codebase context in the executor. | After a spec exists, before touching code. |

**NOTE:** Both of these are planning-phase skills, in the "execution" vendor. See "Architecture implications" below.

### Execution

| Skill | Purpose | When |
|---|---|---|
| `test-driven-development` | RED-GREEN-REFACTOR discipline. Failing test first, watch it fail, minimum code to pass, refactor. Exceptions only with human-partner approval. | Any feature or bugfix implementation. |
| `systematic-debugging` | Root-cause before fix. Four phases: root-cause investigation / pattern analysis / hypothesis testing / implementation. | Any bug, test failure, unexpected behavior, perf problem, build failure, integration issue -- especially under time pressure. |
| `verification-before-completion` | Evidence-based claims. Requires running verification commands and confirming output before any success / completion assertion. | Before claiming work is complete, fixed, or passing -- every time. |
| `dispatching-parallel-agents` | Delegates independent tasks to specialized subagents concurrently. Requires isolation (no shared state, no sequential deps). | 2+ independent failures / tasks that can be understood in isolation. |
| `executing-plans` | Loads plan, reviews critically, executes all tasks with verification checkpoints, reports completion. Fresh session. | Have a written plan, run it in a clean session. |
| `subagent-driven-development` | Executes a plan by dispatching a fresh subagent per task. Two-stage review (spec compliance, then quality). Same session, continuous progress. | Executing a plan with independent tasks in the current session. |
| `requesting-code-review` | Dispatches specialized code-reviewer subagent with crafted context. Review early, review often. | After each task; before merge; stuck. |
| `receiving-code-review` | Handles review feedback with rigor: verify before implementing, clarify unclear, push back with technical reasoning where appropriate. Zero performative agreement. | When receiving review feedback. |

### Post-Execution

| Skill | Purpose | When |
|---|---|---|
| `finishing-a-development-branch` | Verifies tests, presents integration options (merge local / create PR / keep as-is / discard), cleans up worktree. | Implementation complete, all tests pass, decide how to integrate. |

### Meta

| Skill | Purpose | When |
|---|---|---|
| `using-superpowers` | Metacognitive primer. Establishes skill priority, tool usage, instruction hierarchy. Auto-injected by SessionStart hook. | Session start; primer for the agent. |
| `writing-skills` | TDD discipline applied to docs. RED (baseline scenario), GREEN (write skill), REFACTOR (close loopholes). | Creating / editing skills. |
| `using-git-worktrees` | Creates isolated git worktrees for parallel work on multiple branches without context-switching. | Feature work needing isolation; before executing plans. |

---

## How to use this inventory

- When proposing a new skill / workflow change: **check this file first** to see what already exists upstream and where it lives.
- When classifying a new ytstack skill (planning vs execution vs other): use this inventory as the reference, not a guess.
- When upstream is updated via `git subtree pull`, re-run the Explore agents that produced this inventory and update the lists.

<div align="center">
  <img src="assets/ytstack-logo.svg" width="88" alt="ytstack" />

  <h1>ytstack</h1>

  <p><em>An opinionated OS for AI coding agents. Plan like a PM, execute like a senior eng.</em></p>

  <p>
    A Claude Code plugin that turns multi-session, multi-week projects into something your agent can actually hold onto. Project memory on disk, curated skill set, parallel execution via native Agent Teams. One install, one namespace, no stack to maintain.
  </p>

  <p>
    <a href="./LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
    <img alt="version" src="https://img.shields.io/badge/version-0.1.0-FC4E14">
    <img alt="Claude Code" src="https://img.shields.io/badge/Claude%20Code-plugin-0A0A0A">
    <img alt="skills" src="https://img.shields.io/badge/skills-21-FC4E14">
    <img alt="hooks" src="https://img.shields.io/badge/hooks-8-FC4E14">
  </p>

  <table>
    <tr>
      <td align="center"><strong>1</strong><br/>install</td>
      <td align="center"><strong>0</strong><br/>separate runtimes</td>
      <td align="center"><strong>21</strong><br/>curated skills</td>
      <td align="center"><strong>MIT</strong><br/>open source</td>
    </tr>
  </table>
</div>

> Open Claude Code tomorrow. The agent already knows which milestone you're in, which task is open, what the last three tasks shipped, which decisions are locked. No "remind me what we were working on" ritual. You just start.

Enterprise-capable. Equally useful for solo dev.

---

## What a session feels like

Open a project that uses ytstack. Before your first message, a SessionStart hook has already injected two things into your agent's context: (1) a directive that tells the agent to reach for ytstack skills whenever your intent matches one, and (2) a state snapshot that tells it where you are:

```
[ytstack active -- scope: project]
Project: csv-importer
Current: M002 / S01 / T04
Last updated: 2026-04-23T19:30:00Z
Recent tasks: T01 (added CLI flag parsing), T02 (streaming CSV reader), T03 (row validation)
Next action: finish argon2 integration in src/auth/signup.ts:47
```

From there, you just talk to the agent. **You rarely type slash-commands.** The agent maps your natural-language requests to the right skill:

- Say "let's plan what's next" → agent fires `ytstack:plan-milestone` or `plan-task` based on where you are
- Say "this task is done" → agent fires `ytstack:summarize-task`, writes the outcome, flips the checkbox
- Say "something's broken, find it" → agent fires `ytstack:systematic-debugging` (root-cause required, no symptom patches)
- Say "where were we" → agent fires `ytstack:resume-session`, produces a 3-paragraph briefing
- Describe a feature you're not sure about → agent fires `ytstack:office-hours` for forcing questions

**Slash-commands are for steering**, not driving. Type `/ytstack:<name>` when you want to override the skill the agent would have picked, skip a step, or trigger an unusual workflow (e.g. running `ytstack:plan-ceo-review` on a milestone you already sliced, to challenge the premise again). For the happy path, natural language is enough.

Stepping away for a week? Say "let's do a handoff" -- agent fires `ytstack:handoff-session`, writes a rich handoff file. You or a teammate pick up from the file without re-explanation.

## Why it exists

AI coding agents are excellent inside a single session and fall apart between them. Long projects rot: context-window pressure makes the agent forget early decisions by the time it reaches late ones. You re-explain architecture every morning.

Three existing tools each solve it from a different angle and overlap in the middle:

- **[gstack](https://github.com/garrytan/gstack)** (Garry Tan) -- broad builder toolkit. Strongest on strategy and decision rigor: CEO / eng-manager / office-hours reviews that force real thinking before code. Also ships execution skills (`investigate` for systematic debugging, `qa`, `review`, `ship`) and session-level context save/restore. What it lacks: explicit TDD enforcement, and a structured milestone / slice / task artifact hierarchy that survives beyond "notes from the last session."
- **[superpowers](https://github.com/obra/superpowers)** (Jesse Vincent) -- methodology toolkit. Strongest on execution discipline: TDD, systematic debugging, verification-before-completion. Also ships planning skills (brainstorming, writing-plans, executing-plans). What it lacks: business-strategy reviews (no CEO / founder-mode diagnostics, no YC-office-hours forcing questions), and on-disk project memory that persists across sessions.
- **[GSD](https://github.com/gsd-build/gsd-2)** (get-shit-done) -- project management done right. Milestones, slices, tasks, artifact-as-memory, cross-session continuity. What it requires: a separate TypeScript runtime with its own CLI and TUI that fights Claude Code's native extension points.

gstack and superpowers overlap heavily in scope -- both ship planning, both ship debugging -- but each has a distinctive strength the other lacks. GSD has what neither has (structured artifact memory) but ships as a runtime. Combining all three by hand produces friction: skill conflicts, redundant planning flows, 50+ skill descriptions in every system prompt.

Install all three and you get friction: interactive prompts blocking each other, skill overlap, 50+ skills flooding every system prompt, a separate runtime to maintain. See the combining articles on [dev.to](https://dev.to/imaginex/a-claude-code-skills-stack-how-to-combine-superpowers-gstack-and-gsd-without-the-chaos-44b3) and [Medium](https://medium.com/@tentenco/superpowers-gsd-and-gstack-what-each-claude-code-framework-actually-constrains-12a1560960ad) for the full diagnosis.

**ytstack is the curation.** One plugin. We cherry-pick the _non-overlapping best_: gstack's strategy-review skills (CEO / eng / office-hours), superpowers' discipline skills (TDD / systematic-debugging / verification). We skip the overlap: gstack's `investigate` duplicates superpowers' `systematic-debugging`, superpowers' `writing-plans` conflicts with our milestone / slice / task flow, etc. GSD's project-memory discipline is re-implemented natively as skills + hooks -- no separate runtime. Claude Code's native Agent Teams handle parallel execution.

## What you get

**Agent-driven, not user-driven.** A SessionStart hook injects a "using ytstack" directive on every session start that tells the agent to map your natural-language intent to the right ytstack skill and invoke it before responding. You talk in plain language; the agent fires skills in the background. Slash-commands (`/ytstack:<name>`) exist for explicit steering -- they're the escape hatch, not the normal path.

**Never lose context across sessions.** Every ytstack project gets a `.ytstack/` directory with `PROJECT.md`, `DECISIONS.md`, `KNOWLEDGE.md`, `STATE.md`, and a milestone / slice / task hierarchy. Files are git-tracked Markdown. The same SessionStart hook injects the relevant state on every session start. The agent always knows where it is.

**Plan like a PM, execute like a senior eng.** Cherry-picked skills from gstack (CEO-review, office-hours, eng-review) lock the plan before code lands. Cherry-picked skills from superpowers (TDD, systematic-debugging, verification-before-completion) lock the code before it ships.

**Parallel execution without a custom runtime.** `ytstack:spawn-milestone-team` dispatches a Claude Code Agent Team where each teammate works on a slice in its own fresh 200k context. Replicates GSD's fresh-subprocess-per-task model using Claude Code's native experimental feature. No separate CLI, no SQLite, no TUI to babysit.

**One vendored stack, one namespace.** Skills appear as `/ytstack:<name>` -- no conflicts with other plugins. `vendor/` holds read-only subtrees of superpowers and gstack, pulled via `git subtree`. Upstream updates land cleanly; we never modify their content.

## Workflows

ytstack covers three workflows. The `SessionStart` hook injects the `using-ytstack` directive once per session; skill selection after that is semantic -- the agent matches user intent against each skill's `description:` field, not a phrase list.

### 1. Greenfield -- new project, no `.ytstack/` yet

From raw idea to shipped task. Each process step (orange) produces an artifact on disk (green) that the next step reads as a contract.

<details open>
<summary><strong>Greenfield flow diagram</strong> (click to collapse)</summary>

![ytstack greenfield flow -- office-hours -> plan-ceo-review -> init-project -> plan-milestone -> slice -> task-loop (plan-task -> TDD -> verify -> summarize) -> reassess-roadmap at slice boundaries](docs/ytstack-greenfield-flow.png)

Source: [`docs/ytstack-greenfield-flow.excalidraw`](docs/ytstack-greenfield-flow.excalidraw) (single source of truth).

</details>

### 2. Brownfield -- existing `.ytstack/`, continuing or starting new work

SessionStart hook injects `STATE.md` + the `using-ytstack` directive before your first message. Natural-language routing:

```
<session start: state injected>
  -> "where were we"           -> ytstack:resume-session    (3-paragraph briefing)
  -> "let's plan what's next"  -> ytstack:plan-milestone    (if no active milestone)
                                  ytstack:plan-task        (if milestone is active)
  -> "this task is done"       -> ytstack:summarize-task    (close + flip checkbox)
  -> "let's do a handoff"      -> ytstack:handoff-session   (rich HANDOFF.md)
```

Continuing an open task:

```
plan-task -> test-driven-development -> verification-before-completion -> summarize-task
```

At each slice boundary: `ytstack:reassess-roadmap` to check the plan still fits reality.

**Parallel variant:** `ytstack:spawn-milestone-team` dispatches Claude Code Agent Teams (one teammate per slice, each in a fresh 200k context). Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` + Claude Code v2.1.32+.

<details>
<summary><strong>Brownfield flow diagram</strong> (click to expand)</summary>

![ytstack brownfield flow -- SessionStart hook injects directive + STATE snapshot, natural-language routing to resume-session / plan-milestone / plan-task / summarize-task / handoff-session, task-loop continuation, post-slice reassess and parallel-team variants](docs/ytstack-brownfield-flow.png)

Source: [`docs/ytstack-brownfield-flow.excalidraw`](docs/ytstack-brownfield-flow.excalidraw).

</details>

### 3. Brownfield debugging -- something is broken

```
"something's broken, find it"   -> ytstack:systematic-debugging
  Phase 1: root-cause investigation  (no fixes yet)
  Phase 2: pattern analysis
  Phase 3: hypothesis testing
  Phase 4: implementation
```

Iron rule: root cause required before any fix. Findings auto-log to `KNOWLEDGE.md` (pattern) and `DECISIONS.md` (architectural shift).

Fix path merges back into the brownfield task loop: regression test first (`test-driven-development`) -> `verification-before-completion` -> `summarize-task`. Same task skeleton as feature work, not a separate "debug mode".

<details>
<summary><strong>Debugging flow diagram</strong> (click to expand)</summary>

![ytstack debugging flow -- systematic-debugging 4-phase procedure (investigate / analyze / hypothesize / implement) with iron-rule root-cause gate, KNOWLEDGE + DECISIONS logs, and merge-back into the task loop via test-driven-development / verification-before-completion / summarize-task](docs/ytstack-debugging-flow.png)

Source: [`docs/ytstack-debugging-flow.excalidraw`](docs/ytstack-debugging-flow.excalidraw).

</details>

## Compared to using each framework alone

| Need | gstack alone | superpowers alone | GSD alone | **ytstack** |
|---|---|---|---|---|
| CEO / founder-mode strategy review | ✅ | -- | -- | ✅ (via wrapper) |
| YC-office-hours forcing diagnostics | ✅ | -- | -- | ✅ (via wrapper) |
| Engineering plan / architecture review | ✅ | partial (brainstorming) | -- | ✅ (via wrapper) |
| TDD as enforced discipline | -- | ✅ | -- | ✅ (via wrapper) |
| Systematic debugging with root-cause gate | ✅ (`investigate`) | ✅ | -- | ✅ (superpowers wrapper) |
| Verification-before-completion gate | partial (via `ship`) | ✅ | ✅ | ✅ (via wrapper) |
| Structured milestone / slice / task artifacts | -- | -- | ✅ | ✅ (native) |
| Cross-session project memory | light (`context-save`) | -- | ✅ | ✅ (native) |
| Agent Teams for parallel fresh-context work | -- | -- | via subprocess | ✅ (native) |
| SessionStart-hook state injection | -- | ✅ (for its own skills) | -- | ✅ (for project state) |
| No separate runtime to install | ✅ | ✅ | ❌ | ✅ |
| One namespace, one install | plugin-level | plugin-level | n/a | ✅ |
| Skill conflicts when combined with others | medium | medium | n/a | none |

## Install

### Local dev (recommended for first try)

```bash
claude --plugin-dir /path/to/ytstack
```

Starts a fresh Claude Code session with ytstack loaded. Skills appear as `/ytstack:<skill-name>`. No marketplace registration needed. Reload after edits with `/reload-plugins`.

### Via marketplace (recommended for shared use)

ytstack is currently private and lives cross-listed in `Yesterday-AI/ystacks-internal` (Yesterday's PRIVATE plugin catalog). When ytstack flips public, it will list in `Yesterday-AI/ystacks` (the PUBLIC catalog).

```bash
# Today (private):
/plugin marketplace add Yesterday-AI/ystacks            # for cross-mp deps (skill-creator, web-design)
/plugin marketplace add Yesterday-AI/ystacks-internal   # for ytstack itself
/plugin install ytstack@ystacks-internal
```

ytstack declares cross-marketplace dependencies on:
- `skill-creator` + `web-design` from `Yesterday-AI/ystacks` (public)

Private-repo auth uses your existing `gh auth login` / git credential helper.

<details>
<summary><strong>Legacy: install via ytstack's self-marketplace</strong></summary>

ytstack also self-marketplaces from its own repo:

```bash
/plugin marketplace add Yesterday-AI/ystacks
/plugin marketplace add Yesterday-AI/ystacks-internal
/plugin marketplace add Yesterday-AI/ytstack
/plugin install ytstack@ytstack
```

The self-marketplace declares `allowCrossMarketplaceDependenciesOn: ["ystacks", "ystacks-internal"]` so cross-mp deps resolve here too. This path predates the consolidation onto `ystacks` and remains functional. New installs should prefer the `@ystacks-internal` (or `@ystacks` once public) path. See [`.ytstack/DECISIONS.md`](./.ytstack/DECISIONS.md) for the consolidation decision.

</details>

### Headless / CI

```bash
claude --plugin-dir /path/to/ytstack --permission-mode acceptEdits -p "<prompt>"
```

Without `--permission-mode acceptEdits`, Write operations stall on permission dialogs. Agent Teams require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. See `.ytstack/KNOWLEDGE.md` for the full gotcha list.

## Quickstart

**You talk in natural language; the agent fires skills automatically.** Slash-commands exist as an override path when you want to skip a step or re-run one. For the happy path you never type them.

**Greenfield** (empty project dir, no `.ytstack/` yet). Say something like "baue mir eine cli die X macht" / "let's build a tool that Y" / "I have an idea for Z". The agent matches your intent against each skill's `description:` semantically and walks the chain:

| You say / what happens | Agent fires | Artifact produced |
|---|---|---|
| "build me X" / "I have an idea for Z" | `ytstack:office-hours` | `OFFICE-HOURS.md` (pitch with `name:` + `one-liner:` frontmatter) |
| (after pitch is written) | `ytstack:plan-ceo-review` (concept mode) | annotation block prepended to pitch |
| (optional, if architecture needs sanity-check) | `ytstack:plan-eng-review` (concept mode) | annotation block prepended to pitch |
| (once pitch is locked) | `ytstack:init-project` | `.ytstack/` with 6 core files, `PROJECT.md` populated from pitch frontmatter |
| (after scaffolding) | `ytstack:plan-milestone` | `M001-CONTEXT.md` + `M001-ROADMAP.md` |
| "break this into slices" | `ytstack:slice-milestone` | `M001-S##-PLAN.md` per slice |
| (per task in the slice) | `plan-task` -> TDD -> verify -> `summarize-task` | `T##-PLAN.md` -> code + tests -> `T##-SUMMARY.md` |

**Brownfield** (ytstack already initialized). Say what you want in plain language:

- "where were we" -> `resume-session` produces a 3-paragraph briefing
- "let's plan what's next" -> `plan-milestone` (no active milestone) or `plan-task` (active milestone)
- "this task is done" -> `summarize-task` closes the task, flips the checkbox, updates `STATE.md`
- "something's broken, find it" -> `systematic-debugging` runs its 4-phase root-cause procedure (no symptom patches)
- "let's do a handoff" -> `handoff-session` writes `HANDOFF.md` for the next session

Type `/ytstack:<skill-name>` only when you want to override the auto-pick, skip a step, or explicitly re-run one (e.g. `/ytstack:plan-ceo-review` to re-challenge a milestone you already sliced). The using-ytstack directive loaded at session start enforces this model via the Skill tool.

See [QUICKSTART.md](./QUICKSTART.md) for the end-to-end worked example written in the same natural-language style.

## Who this is for

**Good fit:**

- Projects that span more than one Claude Code session
- Teams where multiple people (or agents) touch the same codebase
- Any workflow where "what was decided and why" matters a week later
- People who already use superpowers or gstack and want the other's strengths without the friction

**Poor fit:**

- One-shot scripts that ship in a single session
- Teams that don't want opinionated process
- Workflows already deeply invested in GSD's TypeScript runtime (use GSD directly; ytstack solves a different layer)

## Status

**v0.1.0 -- full build cycle complete.** 37/39 tasks done; 2 deferred to user-action (git init + push, GitHub repo creation).

Ships:

- 21 skills (project-OS lifecycle + gstack planning wrappers + superpowers execution wrappers + Agent Teams dispatch + `using-ytstack` directive + 5 engineering-OS additions migrated from agentic-foundation: `atomic-design`, `deutschland-stack-api`, `european-alternatives-api`, `oss-project`, `software-craftsmanship`)
- 8 hooks (SessionStart / PreCompact / SessionEnd / TeammateIdle / TaskCreated / TaskCompleted / PreToolUse-Edit / PostToolUse-Bash). SessionStart-hook now injects the using-ytstack directive + project state.
- Full docs (`CLAUDE.md`, `CONTRIBUTING.md`, `QUICKSTART.md`, UX contracts, references, methodology)
- Plugin manifest + marketplace manifest ready for publication

See `.ytstack/ROADMAP.md` for the task list, `.ytstack/STATE.md` for progress, `.ytstack/REVIEW-NOTES.md` for deferred items.

## Repo layout

```
ytstack/
├── .claude-plugin/              plugin manifest + marketplace
├── .ytstack/                    dogfood: ytstack tracks itself
├── hooks/                       8 hook scripts + hooks.json
├── skills/                      21 skill packages
├── vendor/                      read-only subtrees (superpowers, gstack)
├── docs/
│   ├── ux/                      mandatory skill-authoring contracts
│   ├── references.md            research sources
│   └── methodology.md           what we adapted, from where, how
├── CLAUDE.md                    contributor guide (for agents)
├── CONTRIBUTING.md              contributor guide (for humans)
├── QUICKSTART.md                worked example
├── README.md                    this file
├── LICENSE, NOTICE              MIT + attributions
└── .gitignore
```

## Design principles

1. **Intelligence in the system, not the agent.** Skills, hooks, and artifacts carry the logic. The agent is replaceable.
2. **Context discipline.** Core context (`PROJECT.md`, `STATE.md`) always loaded. Task-context and background context on-demand.
3. **Evidence before assertion.** Nothing counts as "done" without verification.
4. **One fact, one place.** No duplicate documentation across files.
5. **User sovereignty.** Explicit user decision gates before destructive or scope-expanding actions.
6. **Skill selection via semantic descriptions, not keyword matching.** Claude Code's model matches user intent against each skill's `description:` field. Phrase-lists, trigger-maps, and secret-word tables are brittle by construction -- every new phrasing (language, paraphrase, dialect) breaks them. Skills self-identify through rich when-to-use descriptions; the agent selects semantically. If selection misbehaves, sharpen the description, never add a keyword list.

## Documentation

| Document | Purpose |
|---|---|
| [QUICKSTART.md](./QUICKSTART.md) | End-to-end worked example |
| [CLAUDE.md](./CLAUDE.md) | Contributor guide for AI coding agents |
| [CONTRIBUTING.md](./CONTRIBUTING.md) | Contributor guide for humans |
| [docs/concept.md](./docs/concept.md) | Condensed reference paper -- what ytstack wraps, skips, adds |
| [docs/methodology.md](./docs/methodology.md) | What we adapted from gstack / superpowers / GSD, and how |
| [docs/references.md](./docs/references.md) | Sources consulted while designing ytstack |
| [docs/ux/](./docs/ux/) | Skill-authoring UX contracts (frontmatter, format, writing style) |
| [.ytstack/DECISIONS.md](./.ytstack/DECISIONS.md) | Append-only architectural decision log |
| [.ytstack/KNOWLEDGE.md](./.ytstack/KNOWLEDGE.md) | Patterns + gotchas learned while building ytstack |
| [.ytstack/ROADMAP.md](./.ytstack/ROADMAP.md) | Milestone plan |
| [.ytstack/STATE.md](./.ytstack/STATE.md) | Current status dashboard |

## Contributing

Read [CLAUDE.md](./CLAUDE.md) before modifying anything. See [CONTRIBUTING.md](./CONTRIBUTING.md) for PR rules and [docs/ux/](./docs/ux/) for the mandatory skill-authoring contracts.

Key rules:

- Never modify content in `vendor/**` (upstream superpowers / gstack trees -- wrap, don't edit)
- Never copy third-party methodology prose verbatim (concepts only)
- One logical change per commit
- Follow the AskUserQuestion 4-part format for any user-facing question

See [`docs/references.md`](./docs/references.md) for the full list of sources consulted while designing ytstack.

## License

MIT. See [LICENSE](./LICENSE). Attributions in [NOTICE](./NOTICE).

Inspired by [gstack](https://github.com/garrytan/gstack), [superpowers](https://github.com/obra/superpowers), and [GSD](https://github.com/gsd-build/gsd-2). Built on Claude Code.

---

Maintained by [Yesterday](https://github.com/Yesterday-AI).

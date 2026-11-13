---
area: host-adapters
status: implemented
paths:
  - .claude-plugin/**
  - .codex-plugin/**
  - .agents/**
  - codex/**
  - bin/ytstack-codex
  - hooks/hooks.json
sources:
  - docs/codex.md
verified_at: f4f54ab
---

# host-adapters

## Purpose

How one `skills/` tree and one set of hook scripts serve two hosts, Claude Code and Codex. The area covers the manifests, the marketplace entries, the per-host hook registration and the Codex runtime helper. Install steps, the first Codex session and the Codex support table live in `docs/codex.md`. This file adds the Claude Code side and the contract of the helper. What the hooks do is in the `hooks-and-state` area.

## Behavior

### Shared by both hosts

- Both hosts load the same `skills/` directory and run the same scripts under `hooks/`. There is no generated copy and no second skill tree.
- No `SKILL.md` names Codex outside a shell comment. Host-specific instructions live in `codex/adapter.md`.
- The scripts keep one environment contract: `CLAUDE_PLUGIN_ROOT`, `CLAUDE_SKILL_DIR`, `CLAUDE_PROJECT_DIR`. On Codex these are input names that the helper fills. No Claude executable is involved.
- Both manifests carry the same `name`, `version`, `author`, `repository` and `license`.

### Claude Code

- `.claude-plugin/plugin.json` holds metadata only. It names no component paths and no dependencies. The host loads `skills/`, `agents/` and `hooks/hooks.json` from their default locations.
- `.claude-plugin/marketplace.json` makes the repository its own marketplace: the marketplace is named like the plugin and its one entry points at the repository root.
- `hooks/hooks.json` registers nine hooks. Each entry runs `bash "${CLAUDE_PLUGIN_ROOT}/hooks/<name>"` synchronously with `shell: bash`. SessionStart also fires on `fork`.
- Plugin root: the host fills `${CLAUDE_PLUGIN_ROOT}` in hook commands. The hook scripts find the library relative to their own path. `hooks/session-start` falls back to its own parent directory when the variable is unset.
- Skill directory: the host substitutes `${CLAUDE_SKILL_DIR}` in skill text. Preambles reach the library and the vendored files through `${CLAUDE_SKILL_DIR}/../../`.
- Volatile state goes under `CLAUDE_PLUGIN_DATA` when the host sets it.
- `agents/*.md` and the Agent Teams events (TeammateIdle, TaskCreated, TaskCompleted) exist only on this host.

### Codex

- `.codex-plugin/plugin.json` names `./skills/` and `./codex/hooks.json` and adds an `interface` block with the display texts.
- `.agents/plugins/marketplace.json` makes the repository its own Codex marketplace with a local source at the repository root.
- `codex/hooks.json` registers three events: SessionStart, PreCompact, SessionEnd. Each runs `bin/ytstack-codex hook <name>` through `${PLUGIN_ROOT}`. SessionStart has no `fork` matcher and sets an `additionalContextLimit`.
- `bin/ytstack-codex` sets `CLAUDE_PLUGIN_ROOT` to its own parent directory, overriding an inherited value. It sets `CLAUDE_PROJECT_DIR` to the Git toplevel of the working directory, or to the working directory outside Git, and changes into it.
- `ytstack-codex hook <name>` accepts only the three registered names and no further arguments. For `session-start` it exports `YTSTACK_HOST_CONTEXT`: one line with the plugin root, then the text of `codex/adapter.md`. It then replaces itself with the shared hook script.
- `ytstack-codex skill <name>` accepts a lowercase slug whose `skills/<name>/SKILL.md` exists. It exports `CLAUDE_SKILL_DIR` and runs `bash` with the remaining arguments; the shell block arrives on stdin. The exit code of the block is the exit code of the helper.
- `codex/adapter.md` tells the agent to run each shell block of a skill through `ytstack-codex skill`, maps the Claude tool names to Codex tools, and stops `spawn-milestone-team` before its capability probe.
- A prompt that starts with `# Brief:` is a rendered brief (`bin/ytstack-brief render`): `codex/adapter.md` tells a Codex worker to follow it without loading a skill, to do only what its Kind section allows and to end with the report lines it asks for. An orchestrator on another host starts such a worker with `codex exec` in a worktree of its own. Unknown -- no live run has exercised this.
- Volatile state goes under `PLUGIN_DATA` when it is set, else under the remaining bases of `yt_state_base` in `hooks/lib/git-ctx.sh`.

### What a host loses

| Missing on the host | Effect |
|---|---|
| Hooks, or hooks not trusted | No injected directive and state, no automatic handoff, no session journal. The agent reads `codex/adapter.md` and `using-ytstack` itself and uses `resume-session` and `handoff-session`. |
| The six Claude-only hook events | No drift warning on edit, no draft summary on commit, no stop reminder, no team hooks. Task closure runs through `summarize-task` alone. |
| `AskUserQuestion` | The agent uses another input tool or asks in chat and waits. The question format stays. A missing question tool is not non-interactive mode and not consent. |
| Agent Teams and `agents/*.md` | `spawn-milestone-team` is not available. The adapter offers the sequential task flow. |
| `${CLAUDE_SKILL_DIR}` substitution, without the helper | The preamble takes its fallback branch: project scope only, no user scope, no repo key. The required block is in `docs/ux/skill-structure.md`. |

### Non-interactive mode

- It is an environment switch, not a host. A skill preamble reports `YTSTACK_NON_INTERACTIVE: true` when `YTSTACK_NON_INTERACTIVE`, `OPENCLAW_SESSION` or `CLAUDE_AGENT_TEAM_MEMBER` is non-empty. Any non-empty value turns it on.
- The rule for skills is in `docs/ux/askuserquestion-format.md` under "Spawned-Session Mode": skip the question, take the recommendation, log the pick.
- Seven skills implement the switch: `init-project`, `adopt-brownfield`, `plan-milestone`, `slice-milestone`, `plan-task`, `summarize-task`, `reassess-roadmap`.
- Neither a hook nor `bin/ytstack-codex` sets these variables.

## Interfaces and contracts

- Manifest fields: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`.
- Hook registration: `hooks/hooks.json` (Claude Code), `codex/hooks.json` (Codex).
- Helper usage and exit codes: `bin/ytstack-codex`. A usage error, an unknown hook name and an unknown or malformed skill name exit 2.
- Host context: `YTSTACK_HOST_CONTEXT`, read by `hooks/session-start`. Its length is not counted against the injection cap of that hook.
- Tool mapping and shell-block procedure for Codex: `codex/adapter.md`.
- Codex support table: `docs/codex.md`, section "Supported behavior".

## Invariants and security boundaries

- One source for skills and hook scripts. `tests/codex_plugin_test.py` fails when `codex/skills`, `codex/hooks` or `bin/build-codex` exist.
- The skill name passed to the helper cannot leave `skills/`: path separators and `..` are rejected before any path is built.
- Installing the plugin on Codex does not grant hook trust. The user grants it in the host.
- `allowed-tools` and other Claude frontmatter are hints on Codex, never grants. User instructions and the host's approval and sandbox rules rank above the adapter and the skills.
- `bin/ytstack-check` warns when the marketplace entry's version differs from `.claude-plugin/plugin.json`.

## Error behavior

- The helper prints its usage line on stderr and exits 2 before anything runs when the mode, the hook name or the skill name is not accepted.
- A failing shell block returns its exit code to the caller unchanged.
- The hook scripts themselves exit 0 on both hosts; see `hooks-and-state`.

## Runtime and deployment assumptions

- A local macOS or Linux environment with Bash, Git and either `jq` or `python3`. The tests need Python 3.
- Codex provides `${PLUGIN_ROOT}` to hook commands. Whether Codex sets `PLUGIN_DATA`: Unknown -- host behaviour, not checked.
- Claude Code provides `${CLAUDE_PLUGIN_ROOT}` and `CLAUDE_PLUGIN_DATA` to hook commands and substitutes `${CLAUDE_SKILL_DIR}` in skill text.

## Known limits

- On Codex the SessionStart injection is longer than the `additionalContextLimit` in `codex/hooks.json`: the adapter text plus the directive alone exceed it. What Codex does with the excess: Unknown -- host behaviour, not checked.
- Listing in the external catalog (`Yesterday-AI/skills`): Unknown -- it lives in another repository.
- The Codex package is a repository and local distribution, not a public directory submission.
- Native Windows shells and remote environments without the plugin files are not covered.
- Hosts other than Claude Code and Codex (Kimi, OpenCode, Vibe, Antigravity) are not supported.

## Where implemented

- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` -- Claude Code manifest and self-marketplace
- `hooks/hooks.json` -- Claude Code hook registration
- `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json` -- Codex manifest and self-marketplace
- `codex/hooks.json` -- Codex hook registration
- `codex/adapter.md` -- runtime instructions for the agent on Codex
- `bin/ytstack-codex` -- helper for shell blocks and hooks
- `hooks/session-start` -- reads `YTSTACK_HOST_CONTEXT`
- Tests: `tests/codex_plugin_test.py`, `tests/hooks-json.test.sh`, `tests/skill-preambles.test.sh`

## How to verify

Run from the repository root.

```bash
python3 -m unittest discover -s tests -p 'codex*_test.py'
bash tests/hooks-json.test.sh
bash tests/skill-preambles.test.sh
```

The first prints `OK` after the test count and exits 0. It copies the package into a temporary directory, fires the three Codex hook commands, runs every skill preamble through the helper and also through the Claude Code path. The two shell suites end with `<n> passed, 0 failed` and exit 0.

## Decisions that apply now

- DECISIONS.md -- "2026-10-13: Add Codex distribution alongside Claude Code". In force: the second host, its manifest and self-marketplace, the three-event registration, user-controlled hook trust, Claude-only teams, aligned manifest versions.
- DECISIONS.md -- "2026-10-13: Remove generated Codex copies; load the existing skills directly". It narrows the entry above: no per-skill adapter links, the adapter text reaches the session as host context, the helper supplies the `CLAUDE_*` inputs.
- DECISIONS.md -- "2026-05-31: ytstack ships via the yesterday-public-plugins catalog (Yesterday-AI/skills)". The self-marketplace stays as the secondary install path.
- DECISIONS.md -- "2026-11-07: No hard plugin dependencies". It narrows the catalog entry: no `dependencies` in the manifest, no `allowCrossMarketplaceDependenciesOn` in the marketplace.
- DECISIONS.md -- "2026-04-24: Marketplace name equals plugin name". The name rule holds; the catalog entry replaces its install command as the primary path.
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree" (state base order, including `PLUGIN_DATA`)
- DECISIONS.md -- "2026-11-13: Verification, review and orchestration work are bounded like code (M023, issue #35)" (a rendered brief is the same text for a worker on any host)
- DECISIONS.md -- "2026-11-13: Coordinator mode keeps lanes, questions and standing instructions in files and reads host facts fresh (M024, issue #34)" (lane kinds in the brief; the pipeline and the watcher support GitHub only)

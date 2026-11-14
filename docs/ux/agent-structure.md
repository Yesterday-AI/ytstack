# ytstack Agent Structure

Every ytstack agent definition (`agents/*.md`) MUST follow this structure. `ytstack-check` validates it at CI time (planned M008 pre-release). Agents that fail validation are not shipped.

Parallel in spirit to [skill-structure.md](./skill-structure.md), but scoped to subagent definitions -- the files in `agents/` that describe specialized roles (architect, implementer, verifier, etc.) used by `spawn-milestone-team` and as standalone Agent-tool subagents.

## Required frontmatter fields

```yaml
---
name: <agent-name>
description: |
  <multi-line description with <example> blocks showing when to dispatch>
model: inherit            # or a specific model
isolation: worktree       # OPTIONAL (M019-S04): own git worktree, Bash confined to it; implementer + verifier set it
memory: project           # OPTIONAL: .claude/agent-memory/<name>/ persists across runs (user | project | local)
maxTurns: 150             # OPTIONAL: turn cap; output marked partial and resumable when hit
tools:
  - <Tool1>
  - <Tool2>
skills:
  - ytstack:<skill-name>
  - ...
---
```

`hooks`, `mcpServers` and `permissionMode` are ignored for plugin subagents (platform rule); `bin/ytstack-check` warns when they appear. `isolation: worktree` branches from the repository's default branch, not from the orchestrator's HEAD: the brief's "Git" section re-bases the worker (`git checkout -B ytstack/M###-S## <orchestrator-branch>`), and the worktree is removed automatically when the agent changed nothing (verifiers never do).

### name

Kebab-case, matches the filename (`agents/architect.md` → `name: architect`). No spaces.

### description

Multi-line YAML block. MUST include at least one `<example>` block showing a concrete user request and the assistant's decision to dispatch this agent, with a `<commentary>` explaining why. This mirrors superpowers' pattern and is what Claude Code uses to auto-select the agent when spawning subagents.

Minimum two examples; more for ambiguous roles.

### model

`model: inherit` by default (teammate inherits the lead's model). Override only with clear justification (e.g. cost / speed / reasoning-depth tuning).

### tools

Explicit allowlist. Required. This IS enforced at runtime for both team-teammate and standalone-subagent contexts. Be restrictive:

- **architect** (read-only reviewer) → no `Edit`, no `Write`
- **implementer** (does the work) → `Read`, `Edit`, `Write`, `Bash`, `Grep`, `Glob`, `AskUserQuestion`
- **verifier** (runs checks) → `Read`, `Bash`, `Grep`, `Glob` (no `Edit` -- verifiers never patch)

If the role doesn't need a tool, don't list it. Tighter surfaces reduce accidental drift.

### skills

**Required for every ytstack agent.** For subagents dispatched through the Agent tool (the default execution model since M019-S04) `skills` is a **preload**: the full content of each listed skill is injected at startup (first 32 names; skills with `disable-model-invocation: true` cannot be preloaded), and the agent can still invoke unlisted skills through the Skill tool. For Agent Teams teammates (`team: on`) the field is ignored. Two reasons to keep it exact:

1. **Preload cost and intent.** Every listed skill lands in the subagent's context whether it is used or not; list what the role invokes, nothing more.
2. **Intent documentation.** Anyone reading the agent file sees immediately which ytstack skills this role is designed to invoke. Future behavior changes in Claude Code may begin enforcing `skills` for teammates too -- we want to be ready.

List every ytstack skill the agent is expected to invoke, fully-qualified (`ytstack:<name>`). Cross-check against the skill's Terminal State -- if a skill forbids downstream auto-invocation, don't include it in an agent that would chain to it automatically.

## Required body sections

```markdown
# <Agent Title>

<opening paragraph: one-line role summary + relationship to ytstack>

## <What the agent does>

<numbered or bulleted procedure / responsibilities>

## <What the agent does NOT do>

<explicit non-responsibilities, to prevent scope creep>

## Subagent context

<note about dispatch pattern, SUBAGENT-STOP behavior, whether the agent re-primes using-ytstack or relies on lead's injection>
```

### Opening paragraph

Role summary in ≤2 sentences. Reference ytstack explicitly -- this agent exists inside a ytstack Agent Team or Agent-tool dispatch.

### What the agent does

Numbered procedure or bulleted responsibilities. Should read like a job description. Reference the ytstack skills it invokes in order, matching the `skills:` frontmatter field.

### What the agent does NOT do

Explicit non-responsibilities. Prevents scope creep. Example (architect): "does not write code", "does not re-plan from scratch", "does not second-guess the milestone goal."

### Subagent context

Covers:

- Dispatch pattern (Agent-tool vs Agent-Teams teammate)
- Whether the agent re-reads `.ytstack/` artifacts at spawn (usually yes -- fresh context)
- Relationship to `using-ytstack`'s `SUBAGENT-STOP` directive -- typically: this agent is exempt from the "auto-detect intent and invoke" behavior because its task comes from the lead

## Consistency with referencing skills

For each agent, `ytstack-check` (M008) verifies:

- Every skill listed under `skills:` exists as `skills/<name>/SKILL.md`
- If the skill's SKILL.md has a `tier` or `allowed-tools` constraint, the agent's declarations don't violate it
- If a ytstack skill's Terminal State forbids auto-chaining, the agent definition doesn't imply chaining

Conversely, for each skill that references an agent type (e.g. `spawn-milestone-team` references `architect`/`implementer`/`verifier`):

- The named agent exists at `agents/<name>.md`
- The agent's `description` mentions the skill context (so auto-selection works when the skill suggests it)

## Agent vs. skill -- when to create which

| If the work is... | Create a... |
|---|---|
| A reusable process (1+ steps, used many times) | **Skill** (`skills/<name>/SKILL.md`) |
| A bounded role with tool/skill restrictions for parallel dispatch | **Agent** (`agents/<name>.md`) |
| Both -- a role that needs a process | **Agent** that invokes one or more skills |

Don't duplicate a skill's logic inside an agent body. The agent references the skill; the skill holds the logic.

## Agent file size

Target under **100 lines** (including frontmatter). An agent definition that exceeds 200 lines is a code smell -- it's probably duplicating logic from a skill that should live in a skill. Refactor.

## Validation checklist

`ytstack-check` enforces, and any PR reviewer checks manually until then:

- [x] Frontmatter has all required fields (`name`, `description`, `model`, `tools`, `skills`)
- [x] `name` matches filename
- [x] `description` includes at least 2 `<example>` blocks
- [x] `tools` is restrictive (role-appropriate)
- [x] `skills` references only existing ytstack skills
- [x] Body has "what it does" + "what it does NOT do" + "subagent context" sections
- [x] File is under 200 lines
- [x] No dependencies on agents outside `agents/` (no cross-plugin agent references)

Violations fail CI. No exceptions.

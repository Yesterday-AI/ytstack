# Running ytstack skills in Codex

Read this adapter before following a ytstack skill in Codex. It applies to
the shared skills and their vendored procedures; Claude Code keeps its native
tool and shell-injection behavior.

## Load skills and context

Use Codex's skill loader when available. Otherwise read the selected
`skills/<name>/SKILL.md` from this installed plugin and follow it. A reference
to `ytstack:<name>` or `/ytstack:<name>` means that skill, not a shell command.
Users can select it with `$ytstack:<name>` in Codex's skill picker; choose the entry
from ytstack if another plugin provides the same name.

The plugin root is two directories above the selected `SKILL.md` directory.
For this adapter it is three directories above `references/`. Resolve it from
the loaded file's actual location, not the project checkout or a guessed cache
version. `hooks/session-start` also reports the installed plugin root.

If the SessionStart hook did not provide project context, read the
`using-ytstack` skill and the project's `.ytstack/STATE.md`, `DECISIONS.md`, and
`KNOWLEDGE.md` when present. If project state is absent, check
`~/.ytstack/projects/<repo-basename>/`. No state does not prove an existing
codebase is a new project; follow the user's requested scope.

## Run shell blocks explicitly

Codex does not evaluate the shared skills' fenced `!` blocks as Claude dynamic
context. Execute those blocks explicitly, in order, using Bash from the target
project directory. Honor each hard gate before loading its vendored procedure.
Run ordinary Bash preambles the same way. Each block is a separate process;
use its printed values in subsequent prose steps.

For every block, use the bundled helper with the current skill name:

```bash
bash "/absolute/plugin/root/bin/ytstack-codex" skill plan-task <<'YTSTACK_BASH'
# Paste this skill's shell block here, without the Markdown fence.
YTSTACK_BASH
```

The helper derives `CLAUDE_PLUGIN_ROOT` and `CLAUDE_SKILL_DIR` from its own
installed location and sets `CLAUDE_PROJECT_DIR` to the Git repository root,
falling back to the working directory outside Git. It runs the block there. These names are compatibility inputs for the shared files, not a
requirement to install Claude. Use the helper again for every shell call that
needs them; exports from a previous tool call do not persist.

Read the entire output of the wrapper's vendor `cat` block, including any
referenced files needed for the task. Vendor files remain unchanged. Keep
ytstack's invocation notes, artifact paths, and terminal-state rules around
the upstream procedure. Missing gstack services or sibling skills are not
installed by this plugin; report an essential missing capability instead of
inventing a tool or installing a dependency silently.

## Map tools to the host

| Shared instruction | Codex behavior |
| --- | --- |
| `Skill` | Load/read the selected skill as described above. |
| `Bash`, `Read`, `Write`, `Edit`, `Grep`, `Glob` | Use available shell, file, patch, and search tools. |
| `TodoWrite` / checklist tasks | Use the host's plan tool if available, otherwise track the checklist in the conversation. |
| `AskUserQuestion` | Use an available user-input tool in its supported mode, otherwise ask in chat and wait. Keep the skill's question format. |
| `allowed-tools` / Claude-specific frontmatter | Capability hints, never grants of tool access or permission in Codex. |

A missing question tool does not imply non-interactive mode or consent.
Honor authorization already given in the conversation. User instructions and
the host's tool, approval, and sandbox rules take precedence over this adapter
and any shared or vendored skill instructions.

## Lifecycle and teams

Codex's manifest selects only SessionStart, PreCompact, and SessionEnd hooks.
They need a local host with hook support and explicit hook trust. Without
trusted hooks, use `resume-session` at startup and `handoff-session` before
leaving; do not claim automatic context injection or journaling ran.

Claude's edit/commit hooks and Agent Teams events are not registered in Codex.
Check task scope before editing, run the verification command, and use
`summarize-task` to close work; no automatic draft summary is created on commit.

`spawn-milestone-team` remains a Claude Code workflow. In Codex, stop before its
Claude capability probe or spawn procedure and explain that limitation.
Suggest the sequential `plan-task` -> implementation ->
`verification-before-completion` -> `summarize-task` flow. Do not pretend Codex
subagents provide Claude's shared team/task hooks or start another host.

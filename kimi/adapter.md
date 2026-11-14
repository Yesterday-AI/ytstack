# Running ytstack skills in Kimi Code

Read this adapter before following a ytstack skill in Kimi Code. Kimi and the
other supported hosts use the same skills and vendored procedures; this file
maps only Kimi's runtime conventions.

## Resolve skill identity

A reference to `ytstack:<name>` means the plugin skill. Invoke it through the
Skill tool with `skill="ytstack:<name>"`; users can select it explicitly with
`/skill:ytstack:<name>`. A bare `<name>` never selects an ytstack plugin skill.
Do not strip the `ytstack:` prefix and do not read a same-name project or user
skill as a substitute.

Kimi expands `${KIMI_SKILL_DIR}` to the loaded skill's actual directory. The
plugin root is two directories above that path. Resolve scripts and vendored
references from this managed plugin location, never from the target project or
a guessed version. `sessionStart.skill` loads `using-ytstack` as instructions;
it does not execute shell blocks.

Run a skill's fenced `!` blocks explicitly only when its procedure requires
them. Use the bundled helper from the target project, with the current skill
name:

```bash
bash "${KIMI_PLUGIN_ROOT}/bin/ytstack-kimi" skill plan-task <<'YTSTACK_BASH'
# Paste the selected skill's shell block here, without the Markdown fence.
YTSTACK_BASH
```

If `KIMI_PLUGIN_ROOT` is not present in the shell, use the resolved managed
plugin root from the loaded skill path. The helper supplies the shared
compatibility variables and working directory; their Claude-compatible names do
not require a Claude installation. Exports from one tool call do not persist,
so use the helper again for every block.

## gstack-derived skills

`office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship` and
`document-release` are self-contained ytstack skills adapted from gstack.
Invoke them as `ytstack:<name>` like every other plugin skill. They need no
separate gstack installation, extra skill directory or cross-plugin Skill
call. A same-name user or project skill is not part of ytstack and must not
replace the qualified plugin skill.

## State and capabilities

Kimi does not consume SessionStart hook stdout as model context. The native
`sessionStart.skill` supplies the static directive. SessionStart and PostCompact
prepare pending project context out of tree; UserPromptSubmit consumes it once
on the next real user prompt. PreCompact writes the automatic handoff and
SessionEnd appends the journal through the existing shared scripts.

If no pending context arrived, read `using-ytstack` and the project's
`.ytstack/STATE.md`, `DECISIONS.md`, and `KNOWLEDGE.md` when present. Do not
claim that lifecycle hooks or automatic persistence ran unless their effects
are observable. Web idle unload and some archive paths do not emit SessionEnd.

Claude-specific edit/commit hooks and Agent Teams workflows are not implied by
this adapter. Honor the host's available tools, permissions and user decisions.
A missing question tool does not imply non-interactive mode or consent.

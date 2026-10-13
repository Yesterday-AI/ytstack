# Use ytstack in Codex

ytstack ships a Codex plugin manifest alongside its Claude Code manifest. Claude
loads the existing `skills/` and `hooks/` unchanged. Codex loads a generated
package under `codex/`, with the same 21 skill names, adapted host instructions,
and three lifecycle hooks. Both use the unchanged vendored procedures.

## Install

With a Codex CLI that supports `codex plugin`:

```bash
codex plugin marketplace add Yesterday-AI/ytstack
codex plugin add ytstack@ytstack
```

Restart Codex or open a new session after installation. In the desktop Plugins
Directory, the marketplace is named **ytstack**. Select its ytstack plugin to
install or enable it. This repository's Codex self-marketplace does not depend
on changes to Yesterday's shared plugin catalog.

For a local checkout, replace the first command with:

```bash
codex plugin marketplace add /absolute/path/to/ytstack
codex plugin add ytstack@ytstack
```

The catalog at `.agents/plugins/marketplace.json` points to the checkout root.
Codex copies the package into its plugin cache. After changing local files,
refresh/reinstall the plugin and start a new session before testing.

Use a local macOS/Linux environment with Bash, Git, and either `jq` or Python 3
for lifecycle hooks. The artifact validator and tests use Python 3. Native
Windows shells and remote environments without these files are not covered.

## First session

Start Codex in the project you want to work on. Repository subdirectories work
as well: the helper resolves the Git root. Outside Git it uses the current directory.
Select **using-ytstack** from ytstack in the skill picker (`$ytstack:using-ytstack`),
then describe the task. To resume an initialized project, select
`$ytstack:resume-session`. Plugin skills with duplicate names are distinguished by
their ytstack origin in the picker.

On local hosts that support plugin hooks, review and trust ytstack's hooks
through Codex's hook controls. Installing the plugin does not grant hook trust.
Trusted SessionStart hooks inject the directive and state automatically,
including after compaction. Until hooks are trusted, explicit skill loading
works and the adapter reads state from disk.

Each generated skill links to the [Codex adapter](../codex/adapter.md).
`bin/ytstack-codex` runs its shell blocks with `YTSTACK_PLUGIN_ROOT`,
`YTSTACK_SKILL_DIR`, and `YTSTACK_PROJECT_DIR`. The generated package uses no
Claude environment variables. No Claude executable is needed. Codex-specific
instructions are confined to this package; Claude skills contain none of them.

## Supported behavior

| Capability | Codex support |
| --- | --- |
| Planning, reviews, TDD, debugging, verification, project artifacts | Generated skills with the Codex adapter. |
| SessionStart, PreCompact, SessionEnd | Registered in `codex/hooks.json`; require a local host with hook support and hook trust. |
| Resume and handoff without hooks | Explicit `resume-session` and `handoff-session` skills. No automatic journal. |
| Claude edit/commit quality hooks | Not registered. Follow task scope and verification explicitly; `summarize-task` owns task closure. |
| Claude Agent Teams and `agents/*.md` roles | Claude-only. `spawn-milestone-team` explains the limitation in Codex and suggests sequential execution. |
| Claude marketplace dependencies | Not installed by Codex. Optional design or gstack sibling tools must be available separately when needed. |

This is a repository/local plugin distribution. It is not a public OpenAI
directory submission; packages with lifecycle hooks require manual local
installation. Codex subagents are not presented as an equivalent to Claude's
Agent Teams coordination.

## Build and verify changes

`skills/` and `hooks/` remain the sources. After editing them, run
`python3 bin/build-codex` and commit the updated `codex/skills/` and
`codex/hooks/` files. Reference files and templates are copied with the skills.
The generator changes host paths, shell fences, and entry instructions; it
never edits `vendor/`. The Agent Teams entry becomes an explicit support-limit
notice. Changes to a host adaptation belong in `bin/build-codex` or
`codex/adapter.md`, not in generated files.

Generated files are committed so installation needs no build step. CI runs
`--check` to reject stale output and unknown Claude environment dependencies.

```bash
python3 bin/build-codex --check
python3 -m unittest discover -s tests -p 'codex_plugin_test.py' -v
bin/ytstack-check
bash tests/post-tool-use-bash.test.sh
```

`ytstack-check` returns 2 for warnings without failures. Existing warnings
about vendored sibling skills and gstack preambles are documented separately;
they do not mean those optional tools were installed.

The tests execute the configured hook commands against temporary projects,
exercise all six vendor imports from paths containing spaces, and verify
project/user state and journal behavior. Also use a clean Codex profile to
confirm marketplace discovery, installation, and the loaded skill list when
changing packaging.

## Platform references

- [OpenAI plugin packaging and marketplaces](https://developers.openai.com/plugins/build/plugins)
- [Codex hook events, trust, and payloads](https://learn.chatgpt.com/docs/hooks)
- [Claude plugin compatibility guidance](https://developers.openai.com/plugins/guides/submit-claude-plugin)

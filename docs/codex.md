# Use ytstack in Codex

Both plugin manifests load the same `skills/` directory. Skills, references,
templates, vendor files, and lifecycle scripts each have one source. Codex adds
its manifest, a three-event hook configuration, and a small runtime adapter.

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
On local hosts with hook support, review and trust ytstack's hooks through
Codex's hook controls. SessionStart then supplies the [runtime adapter](../codex/adapter.md),
the shared `using-ytstack` directive, and project state. Installing the plugin
does not grant hook trust.

Without trusted hooks, ask Codex to read `codex/adapter.md` from the installed
ytstack plugin first, then load `$ytstack:using-ytstack` or the desired skill.
This explicit bootstrap supplies the tool mappings and shell instructions that
the hook would otherwise provide. Use `$ytstack:resume-session` and
`$ytstack:handoff-session` for continuity; no automatic journal is promised.

`bin/ytstack-codex` runs shared shell blocks and hooks with their existing
`CLAUDE_PLUGIN_ROOT`, `CLAUDE_SKILL_DIR`, and `CLAUDE_PROJECT_DIR` inputs. These
names preserve the existing script contract, not a Claude runtime dependency.
Codex itself supplies plugin-root compatibility aliases for hooks; the helper
also resolves skill paths and the target repository root. No Claude executable
is needed. Codex-specific tool mappings stay in `codex/adapter.md`.

## Supported behavior

| Capability | Codex support |
| --- | --- |
| Planning, reviews, TDD, debugging, verification, project artifacts | Existing skills with the runtime adapter. |
| SessionStart, PreCompact, SessionEnd | Registered in `codex/hooks.json`; require a local host with hook support and hook trust. |
| Resume and handoff without hooks | Explicit `resume-session` and `handoff-session` skills. No automatic journal. |
| Claude edit/commit quality hooks | Not registered. Follow task scope and verification explicitly; `summarize-task` owns task closure. |
| Claude Agent Teams and `agents/*.md` roles | Claude-only. The runtime adapter stops this workflow before its capability probe and offers sequential execution. |
| Claude marketplace dependencies | Not installed by Codex. Optional design or gstack sibling tools must be available separately when needed. |

This is a repository/local plugin distribution. It is not a public OpenAI
directory submission; packages with lifecycle hooks require manual local
installation. Codex subagents are not presented as an equivalent to Claude's
Agent Teams coordination.

## Verify changes

Edit `skills/` and `hooks/` directly. There is no generated package or build step.
Test both hosts after changing a shared shell block or lifecycle script.

```bash
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

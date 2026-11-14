# Use ytstack in Kimi Code

The native Kimi manifest loads the same `skills/` tree and lifecycle scripts as
the other ytstack hosts. Kimi adds only a manifest, `kimi/adapter.md` and
`bin/ytstack-kimi`. There is no generated or copied host skill tree.

## Support status

| Environment | Evidence |
| --- | --- |
| Kimi 2.5.3 on local macOS | Native installation, every shared skill, pending lifecycle, compaction, resume and interactive SessionEnd verified. |
| Kimi 2.6.2 in fresh Linux/Node 24 | The same seven native live tests pass in Docker, including lifecycle and namespace handling. |
| Kimi 2.6.2 npm on local macOS | Not verified: operational commands exited 126 without diagnostics in the test environment. Use a working official binary or the documented Linux check instead. |

The tests use real Kimi processes with a controlled local model endpoint. They
do not use an external model or credentials. Semantic skill selection by a real
model is a separate operator smoke test, not a claim made by these fixtures.

## Install

For a reviewed local checkout, open Kimi in the target project and use:

```text
/plugins install /absolute/path/to/ytstack
/plugins reload
/plugins info ytstack
```

`plugins info` must report `state: ok`, 38 skills and five lifecycle hooks. Use
`/new` when a fresh session is required. The current session does not reliably
pick up every installation change by itself.

For a reviewed Git ref after native Kimi support has landed there, use Kimi's
GitHub installer with an explicit commit:

```text
/plugins install https://github.com/Yesterday-AI/ytstack/commit/<reviewed-commit>
```

Replace `<reviewed-commit>` with the actual reviewed SHA. A release tag URL is
also supported. Do not mistake a repository's latest release for proof that it
contains this adapter; check the ref's `.kimi-plugin/plugin.json` first.

Kimi installs per user, not per project. Local installations are copied into
`$KIMI_CODE_HOME/plugins/managed/ytstack/`; Kimi runs that managed copy. After
editing the original checkout, reinstall and reload. Repeating the installation
of the same reviewed Git ref is the update path; official plugins do not update
automatically.

Installing a plugin does not run its hooks by itself. They run only when the
plugin is enabled and their event occurs. Review the local scripts before
trusting them. Hooks are fail-open and are not a security barrier.

## First session and skill identity

Invoke ytstack skills through their qualified names:

```text
/skill:ytstack:resume-session
/skill:ytstack:plan-task
```

The model equivalent is `Skill(skill="ytstack:<name>")`. A bare name never
selects an ytstack plugin skill. Do not read a same-name user or project skill
as a substitute.

`sessionStart.skill` loads the static `using-ytstack` directive.
`systemPromptPath` contributes `kimi/adapter.md`. Both are authored content;
neither executes a project query by itself.

For shell blocks, run the bundled helper from the target project:

```bash
bash "${KIMI_PLUGIN_ROOT}/bin/ytstack-kimi" skill plan-task <<'YTSTACK_BASH'
# Paste the selected skill's block here, without its Markdown fence.
YTSTACK_BASH
```

If the variable is absent in a shell, resolve the managed plugin root from the
loaded skill's actual path. The helper supplies the existing compatibility
variables and target Git root. These names do not require a Claude installation.

## Lifecycle: what actually happens

Kimi does not consume SessionStart hook stdout as model context. ytstack uses a
small pending bridge instead of claiming otherwise:

| Event | Kimi behavior used by ytstack |
| --- | --- |
| SessionStart (`startup`, `resume`) | Shared SessionStart creates plain context and atomically stores it as pending out of tree. Its stdout is not the injection channel. |
| UserPromptSubmit | Consumes pending context once and emits it as plain stdout on the next real user prompt. Parallel calls cannot consume it twice. |
| PreCompact (`manual`, `auto`) | The existing hook writes `HANDOFF.auto.md` out of tree. Kimi ignores its return values. |
| PostCompact (`manual`, `auto`) | Rebuilds pending context after compaction; the next user prompt consumes it. |
| SessionEnd (`exit`, `archive`) | The existing hook appends `session.jsonl` when a supported close path actually delivers the event. |

Pending files, automatic handoffs and journals live under the existing
per-repository/worktree/session state tree, by default
`~/.local/state/ytstack/repos/<repo-key>/worktrees/<worktree-key>/sessions/<session-id>/`.
Nothing from this lifecycle is written into the target checkout or managed
plugin copy.

If no pending context arrived, read `using-ytstack` plus the project's
`.ytstack/STATE.md`, `DECISIONS.md` and `KNOWLEDGE.md` when present, or invoke
`ytstack:resume-session`. Never report automatic lifecycle behavior without an
observable effect.

### Close and headless boundaries

The verified normal close on 2.5.3 is interactive: resume the session, accept
the folder trust prompt and use the implemented **Ctrl+C twice** exit shortcut.
This produced SessionEnd with reason `exit` in the native test.

Headless `kimi -p` completion did not deliver SessionEnd on 2.5.3, matching
[upstream issue #4380](https://github.com/MoonshotAI/kimi-code/issues/4380).
Web idle unload does not emit SessionStart/SessionEnd, and the web archive and
shutdown probes used during development did not produce a journal. Do not treat
process termination, archive or an idle unload as a verified journal write.

Hooks can fail open. If journal persistence matters, inspect the per-session
`session.jsonl` after close instead of assuming the event fired.

## gstack-derived skills

`office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship` and
`document-release` are self-contained ytstack skills adapted from gstack. They
ship in the same plugin and use the same `ytstack:` namespace as every other
skill. No gstack installation, extra skill directory or cross-plugin invocation
is needed. Invoke `ytstack:<name>` so a same-name user or project skill cannot
replace the ytstack procedure.

## Supported behavior and exclusions

| Capability | Kimi support |
| --- | --- |
| All 38 ytstack skills and project artifacts | Native `ytstack:<name>` plugin skills and the shared helper. |
| Startup/resume context | Static plugin bootstrap plus pending context on the next user prompt. |
| Manual/auto compaction | Existing out-of-tree handoff plus pending rearm. |
| Session journal | Interactive close verified; headless and web limits above apply. |
| Six gstack-derived skills | Self-contained ytstack adaptations; no external installation or source-resolution fallback. |
| Claude edit/commit hooks and Agent Teams workflow | Not provided by this adapter. Use sequential planning and verification; do not pretend equivalent team events exist. |

## Verify the integration

Run the offline packaging and lifecycle suites:

```bash
python3 -m unittest discover -s tests -p 'kimi_plugin_test.py' -v
python3 -m unittest discover -s tests -p 'kimi_lifecycle_test.py' -v
```

Run the native installation and activation suite with an installed `kimi`:

```bash
python3 -m unittest discover -s tests -p 'kimi_live_test.py' -v
```

The suite skips clearly when Kimi is unavailable. `KIMI_BIN` can select an
explicit binary. No real provider is needed.

For the tested 2.6.2 Linux path, use a fresh container with the repository
mounted read-only:

```bash
docker run --rm -v "$PWD":/w:ro -w /w node:24-bookworm bash -c 'set -e; apt-get update -qq && apt-get install -y -qq python3 git jq >/dev/null; npm install --prefix /tmp/kimi-2.6.2 --no-audit --no-fund @moonshot-ai/kimi-code@2.6.2 >/dev/null; KIMI_BIN=/tmp/kimi-2.6.2/node_modules/.bin/kimi PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p "kimi_live_test.py" -v'
```

Also run the existing host suites and `bin/ytstack-check`. The checker returns
2 for warnings without failures; inspect the actual warning count rather than
calling that exit code a failed contract check.

## References

- [Kimi plugins](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/plugins.html)
- [Kimi skills](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/skills.html)
- [Kimi hooks](https://www.kimi.com/code/docs/en/kimi-code-cli/customization/hooks.html)
- [Headless SessionEnd issue #4380](https://github.com/MoonshotAI/kimi-code/issues/4380)
- [ytstack research and source evidence](research/2026-11-14-kimi-native-plugin-best-practices.md)

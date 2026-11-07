# Security

## Supported versions

Only the latest 0.x release receives fixes. Upgrade with `/plugin update` (plugin cache pins the version until the manifest bumps).

## Reporting

Use GitHub's private vulnerability reporting on `Yesterday-AI/ytstack`, or open an issue labelled `security` when the finding is not exploitable in itself (configuration pins, dependency advisories). State the ytstack version (`.claude-plugin/plugin.json`), the host (Claude Code / Codex), and whether a shared main checkout or a linked worktree was involved.

## What ytstack executes

- Bash hooks (`hooks/*`, bash 3.2 compatible) on Claude Code lifecycle events. They read the hook payload, `.ytstack/` files and git metadata, and write only to `.ytstack/` in the checkout the agent works in (deliberate artifacts) and to the plugin data directory (`${CLAUDE_PLUGIN_DATA}`, volatile session state). No network access, no `eval` of user data, `jq`/`python3` are used read-only on the payload.
- Skill preambles (shell blocks in `skills/*/SKILL.md`) that resolve the checkout and echo flags. Same write surface.
- `bin/ytstack-check` (Python 3, stdlib only) and `tests/*.test.sh` for contributors.

## Third-party runtime

- **superpowers** (MIT) is vendored read-only under `vendor/superpowers/` at a release tag (v7.0.2) and inlined as prose; nothing from it is executed by ytstack.
- **gstack** (MIT) is **not shipped**. Three skills invoke the gstack skills the user installed at `~/.claude/skills/gstack` (tested against v1.96.0.0, requires bun >= 1.4.2). gstack's own helpers (Bun scripts, optional browser binary, telemetry/update checks per its README) run under the user's install, outside ytstack's control; review gstack's `SECURITY.md` and `ETHOS.md` before installing.

## No build or runtime images from this repository

ytstack builds no container image and runs no CI runtime of its own; the only workflow is `.github/workflows/secret-scan.yml`. Issue #25 (Node.js CVE-2026-111497 "Node2Shell", Brotli decoder) concerned `vendor/gstack/.github/docker/Dockerfile.ci`, an upstream CI definition that was mirrored by the former gstack subtree and never built here; it left the tree in 0.3.0 together with the subtree. If you build images from a fork of this repo, pin Node to a patched line (>= 22.23.4 / 24.22.1 / 26.12.1 as of 2026-11), and note that Dependabot does not track `ENV NODE_VERSION` lines (Renovate custom managers do) and Trivy does not detect curl-installed Node (Syft/Grype do).

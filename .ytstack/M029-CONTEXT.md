---
milestone: M029
project: ytstack
created: 2026-11-14T12:00:00Z
size: M
---

# M029 -- Context

## Goal

ytstack users can switch on a PR watcher that tells the owning agent session about red CI, unresolved bot review threads and merge conflicts, without the agent having to monitor PRs itself.

## Exit criteria

- The engine (from the maintainer's local pr-watch) lives in `tools/pr-watch/` with its unit tests; state in `~/.ytstack/pr-watch/`; no machine-specific path, no internal repository name, runs on the system `python3` (3.9+).
- `bin/ytstack-pr-watch` exposes status, register, create, inspect, pause, resume, tick, install-worker / uninstall-worker (macOS launchd; other systems get a printed recipe) and migrate (copies an existing local state, changes nothing else).
- Claude Code and Codex hooks are registered by the plugin and exit at once unless `pr_watch=on` is set in `~/.ytstack/config`; with it on, they behave like the local install (registration on `gh pr create`, pull delivery on user prompts in Claude Code, direct delivery for Codex).
- `docs/pr-watch.md` documents enabling, the worker, migration from a local install, policy, limits; README, QUICKSTART, concept and CHANGELOG point at it.
- `bash tests/run-all.sh`, `bin/ytstack-check`, the Codex tests and `claude plugin validate .` pass.

## Size

M -- 3 slices.

## Planning input

The maintainer's question whether the local PR-watch hooks should ship with ytstack, and the decision that they are an optional tool for ytstack (DECISIONS 2026-11-14 "PR watch ships inside ytstack as an optional, opt-in tool").

## Decisions locked in discuss phase

2026-11-14: Opt-in key `pr_watch=on` in `~/.ytstack/config` (per user, all projects), checked in shell before any Python starts.

2026-11-14: `bin/ytstack-watch` keeps its role (on-demand reads and `release`); PR watch adds the always-on path. No merge of the two tools in this milestone.

2026-11-14: The live switch on the maintainer's machine (old LaunchAgent, old hooks in `~/.claude/settings.json`, Codex local plugin) is an explicit step after the release, with the maintainer's OK.

## Open questions

(none)

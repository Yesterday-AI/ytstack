---
milestone: M031
slice: S03
task: T03
project: ytstack
closed: 2026-11-15T10:25:00Z
verification: passed
---

# M031-S03-T03 -- Summary

## Commits

- The commit that carries this file (`M031-S03-T03: document factory-tool and version notices in spec, docs and DECISIONS`).

## Outcome

`hooks-and-state` describes `yt_factory_notices` and `yt_pr_watch_heartbeat`, the Factory tools block (startup and clear only, second to shrink at the cap), the `version-notice` hook with its two files under `sessions/<session-id>/`, and the limits (no Codex or Kimi registration, highest of several installs, GitHub origin as the PR watch condition). `checks-and-evals` names the uncounted ninth upkeep section and `ytstack-runtime sections`; `host-adapters` the new registration and its Claude-only scope. `docs/ux/runtime-format.md`, `docs/recipes/recurring-upkeep.md` and `docs/pr-watch.md` say what a person sees. DECISIONS 2026-11-15 records why SessionStart stays read-only; KNOWLEDGE has two gotchas (this repository's injection at the cap, a `jq` shim under a fixture `HOME`).

## Deviations from plan

- `host-adapters` and `dependencies` were added: `spec drift` named them after T01 and T02 (they cover `hooks/hooks.json` and `hooks/lib/git-ctx.sh`). `dependencies` needed no text change, only the stamp.

## Follow-ups

- None.

## Spec

- `.ytstack/spec/hooks-and-state.md`, `checks-and-evals.md`, `host-adapters.md`, `dependencies.md`.

## Verification

Command: `bash bin/ytstack-spec lint && bash bin/ytstack-spec drift && bin/ytstack-check` -- `spec lint: 6 area file(s), 0 failure(s), 0 warning(s)`; drift run after the commit is in the slice report; `ytstack-check` exit 2, `OK (with 9 warning[s])`, no `[fail]`.

Not checked: nothing beyond the commands above for this documentation task.

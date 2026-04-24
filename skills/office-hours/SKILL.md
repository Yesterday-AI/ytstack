---
name: office-hours
description: "YC Office Hours -- six forcing questions that expose demand reality, status quo, desperate specificity, narrowest wedge, observation, and future-fit. Thin ytstack wrapper around the vendored gstack office-hours procedure. Use before planning a milestone for a new product / feature / initiative, when you're not sure whether it's worth building."
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# ytstack:office-hours

Thin wrapper around the vendored gstack `office-hours` skill (`vendor/gstack/office-hours/SKILL.md`). Runs the six forcing questions verbatim, then writes the outcome as a ytstack artifact. Vendor is single source of truth.

## ytstack context (resolved at render time)

```!
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")
if [ -d "$PWD/.ytstack" ]; then _YT_DIR="$PWD/.ytstack";
elif [ -d "$HOME/.ytstack/projects/$_PROJECT_SLUG" ]; then _YT_DIR="$HOME/.ytstack/projects/$_PROJECT_SLUG";
else _YT_DIR=""; fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "YT_DIR: $_YT_DIR"
echo "CWD: $PWD"
```

## ytstack invocation notes

office-hours is valid both greenfield (no `.ytstack/` yet -- interrogating a pre-project idea) and brownfield (project exists, new feature being considered). The vendored procedure drives the six questions; the answers plus the compiled pitch are the artifact.

HARD-GATE: none. office-hours runs even without a ytstack project.

After the vendored procedure completes:
- If `HAS_YTSTACK=yes`: write the pitch output to `$YT_DIR/OFFICE-HOURS-<short-slug>.md` for referencing by downstream skills (plan-ceo-review, init-project, plan-milestone).
- If `HAS_YTSTACK=no`: write to `./OFFICE-HOURS.md` in the current directory. This becomes the seed for `ytstack:init-project` when the user is ready to commit.
- The pitch artifact is the canonical answer to "what is this project / feature and for whom"; subsequent ytstack skills (init-project's PROJECT.md population, plan-milestone's goal field) read from it.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/gstack/office-hours/SKILL.md"
```

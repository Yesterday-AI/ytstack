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

office-hours is the **greenfield entry point** for ytstack (per DECISIONS 2026-04-24 "Greenfield-flow reorder"). It is also valid brownfield (project exists, a new feature needs pitch validation). The vendored procedure drives the six questions; the answers plus the compiled pitch are the artifact.

HARD-GATE: none. office-hours runs with or without `.ytstack/`.

After the vendored procedure completes:

- If `HAS_YTSTACK=yes`: write the pitch output to `$YT_DIR/OFFICE-HOURS-<short-slug>.md`. The slug is a 2-4 word kebab-case summary of the pitch, derived from the pitch headline.
- If `HAS_YTSTACK=no`: write to `./OFFICE-HOURS.md` in the current directory. This becomes the seed for `ytstack:init-project` when the user is ready to commit.
- The pitch artifact's top of file MUST contain a `name:` frontmatter field (project-or-feature name) and a `one-liner:` frontmatter field (the `[noun] for [audience] that [verb + outcome]` sentence). Downstream skills read these keys to populate PROJECT.md without re-asking.

**Terminal State:** report the path of the written pitch artifact, then suggest the next step:

- If the pitch felt strong and the user is ready to commit: recommend `ytstack:plan-ceo-review` (concept mode) to stress-test premise + scope before scaffolding.
- If the pitch still feels soft: recommend refining it manually, or re-running office-hours on the weakest question.
- Once plan-ceo-review (and optionally plan-eng-review) has validated the pitch, recommend `ytstack:init-project` to scaffold the project with PROJECT.md pre-populated from the pitch.

Do NOT auto-invoke any downstream skill.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/gstack/office-hours/SKILL.md"
```

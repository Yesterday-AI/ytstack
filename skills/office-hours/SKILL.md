---
name: office-hours
description: "Use as the first step when a new project, feature, or initiative has not yet been validated, or whenever the premise needs a forcing-question test. Six forcing questions expose demand reality, status quo, desperate specificity, narrowest wedge, observation, and future-fit. Produces OFFICE-HOURS.md pitch artifact with name + one-liner frontmatter that downstream skills (plan-ceo-review concept-mode, init-project, plan-milestone) consume. Thin ytstack wrapper around the vendored gstack office-hours procedure."
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
# ytstack resolver (M016): checkout = where this shell runs, via the shared lib.
_LIB="${CLAUDE_SKILL_DIR}/../../hooks/lib/git-ctx.sh"
if [ -f "$_LIB" ]; then
  . "$_LIB"; yt_git_ctx "$PWD"; yt_resolve_yt_dir >/dev/null
  _PROJECT_DIR="$YT_TOPLEVEL"; _YT_DIR="$YT_DIR"; _YT_SCOPE="$YT_SCOPE"; _IS_GIT="$YT_IS_GIT"; _PROJECT_KEY="$YT_REPO_KEY"
else
  # Host did not substitute CLAUDE_SKILL_DIR (e.g. Codex adapter): project scope only.
  _IS_GIT=$([ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] && echo yes || echo no)
  _PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
  _YT_DIR=""; _YT_SCOPE=none; _PROJECT_KEY=""
  [ -d "$_PROJECT_DIR/.ytstack" ] && { _YT_DIR="$_PROJECT_DIR/.ytstack"; _YT_SCOPE=project; }
fi
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$_PROJECT_DIR")
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
cat "${CLAUDE_SKILL_DIR}/../../vendor/gstack/office-hours/SKILL.md"
```

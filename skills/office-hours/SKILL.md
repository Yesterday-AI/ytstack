---
name: office-hours
description: "Use as the first step when a new project, feature, or initiative has not yet been validated, or whenever the premise needs a forcing-question test. Six forcing questions expose demand reality, status quo, desperate specificity, narrowest wedge, observation, and future-fit. Produces OFFICE-HOURS.md pitch artifact with name + one-liner frontmatter that downstream skills (plan-ceo-review concept-mode, init-project, plan-milestone) consume. Thin ytstack wrapper around the installed gstack office-hours skill (pinned v1.96.0.0, needs bun >= 1.4.2)."
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# ytstack:office-hours

Thin wrapper around the **installed** gstack `office-hours` skill (`~/.claude/skills/gstack/office-hours`, ytstack tested against v1.96.0.0). Checks the install, invokes the gstack skill through the Skill tool so its six forcing questions run natively, then writes the outcome as a ytstack artifact. gstack is the single source of truth for the procedure; ytstack owns only the precheck and the artifact.

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
# gstack precheck (M017): installed dependency, not vendored
if command -v yt_gstack_ctx >/dev/null 2>&1; then
  yt_gstack_ctx >/dev/null
  echo "GSTACK_AVAILABLE: $YT_GSTACK_AVAILABLE"; echo "GSTACK_DIR: $YT_GSTACK_DIR"; echo "GSTACK_VERSION: ${YT_GSTACK_VERSION:-none}"
  echo "GSTACK_PIN_OK: $YT_GSTACK_PIN_OK (pin v$YT_GSTACK_PIN)"; echo "GSTACK_SKILL_OK: $(yt_gstack_skill_ok office-hours)"
  echo "BUN_OK: $YT_BUN_OK (${YT_BUN_VERSION:-none})"; echo "GSTACK_INSTALL_CMD: $YT_GSTACK_INSTALL_CMD"
else
  echo "GSTACK_AVAILABLE: unknown (shared lib not loaded)"
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "YT_DIR: $_YT_DIR"
echo "CWD: $PWD"
```

## ytstack invocation notes

office-hours is the **greenfield entry point** for ytstack (per DECISIONS 2026-04-24 "Greenfield-flow reorder"). It is also valid brownfield (project exists, a new feature needs pitch validation). The installed gstack skill drives the six questions; the answers plus the compiled pitch are the artifact.

HARD-GATE: none. office-hours runs with or without `.ytstack/`.

After the installed gstack `office-hours` skill completes:

- If `HAS_YTSTACK=yes`: write the pitch output to `$YT_DIR/OFFICE-HOURS-<short-slug>.md`. The slug is a 2-4 word kebab-case summary of the pitch, derived from the pitch headline.
- If `HAS_YTSTACK=no`: write to `./OFFICE-HOURS.md` in the current directory. This becomes the seed for `ytstack:init-project` when the user is ready to commit.
- The pitch artifact's top of file MUST contain a `name:` frontmatter field (project-or-feature name) and a `one-liner:` frontmatter field (the `[noun] for [audience] that [verb + outcome]` sentence). Downstream skills read these keys to populate PROJECT.md without re-asking.

## Terminal State

Report the path of the written pitch artifact, then suggest the next step:

- If the pitch felt strong and the user is ready to commit: recommend `ytstack:plan-ceo-review` (concept mode) to stress-test premise + scope before scaffolding.
- If the pitch still feels soft: recommend refining it manually, or re-running office-hours on the weakest question.
- Once plan-ceo-review (and optionally plan-eng-review) has validated the pitch, recommend `ytstack:init-project` to scaffold the project with PROJECT.md pre-populated from the pitch.

Do NOT auto-invoke any downstream skill.

## HARD-GATE: gstack installed?

This wrapper runs the gstack `office-hours` skill that is **installed** on this machine (`GSTACK_DIR` above; ytstack is tested against gstack v1.96.0.0, bun >= 1.4.2). gstack is not vendored any more (DECISIONS 2026-11-07 "Vendor strategy").

- If `GSTACK_AVAILABLE` is `no` (or `unknown`): stop. Tell the user that `ytstack:office-hours` needs gstack and print the one-line install command from `GSTACK_INSTALL_CMD`. Do not improvise the six questions from memory and do not loop on AskUserQuestion.
- If `GSTACK_PIN_OK` is `no`: continue, but say once that the installed gstack (`GSTACK_VERSION`) is older than the version ytstack was tested with.
- If `BUN_OK` is `no`: continue, but warn that gstack's helpers need bun >= 1.4.2 and may fail.

## Procedure

1. Invoke the Skill tool with `office-hours` (the installed gstack skill, not `ytstack:office-hours`). It runs its own preamble, sections and the six forcing questions. Follow it to completion.
2. Apply the ytstack post-processing from "ytstack invocation notes" above (pitch artifact with `name:` + `one-liner:` frontmatter, location by `HAS_YTSTACK`).
3. Report per the Terminal State above. Do NOT auto-invoke any downstream skill.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- resolver + gstack precheck flags
2. **HARD-GATE** -- stop with the install command when gstack is missing
3. **Invoke installed `office-hours`** via the Skill tool and follow it to completion
4. **Write the pitch artifact** per the invocation notes
5. **Report + return** -- path + next-step suggestion, no auto-chaining

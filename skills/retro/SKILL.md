---
name: retro
metadata:
  tier: task
  version: 0.1.0
description: "Milestone retrospective through the installed gstack retro skill, fed with the milestone's task summaries, deviations and follow-ups, written to M###-RETRO.md. Use after a milestone's last slice closed and reassess-roadmap ran, or when the user says retro, retrospective, what did we learn, lessons from this milestone. Not mid-milestone (reassess-roadmap) and not for closing a task (summarize-task)."
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# ytstack:retro

Thin wrapper around the **installed** gstack `retro` skill (`~/.claude/skills/gstack/retro`, ytstack tested against v1.96.0.0). Checks the install, invokes the gstack skill through the Skill tool, and writes the outcome as a ytstack artifact. gstack is the single source of truth for the procedure; ytstack owns only the precheck, the input (summaries) and the artifact.

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
  echo "GSTACK_PIN_OK: $YT_GSTACK_PIN_OK (pin v$YT_GSTACK_PIN)"; echo "GSTACK_SKILL_OK: $(yt_gstack_skill_ok retro)"
  echo "BUN_OK: $YT_BUN_OK (${YT_BUN_VERSION:-none})"; echo "GSTACK_INSTALL_CMD: $YT_GSTACK_INSTALL_CMD"
else
  echo "GSTACK_AVAILABLE: unknown (shared lib not loaded)"
fi
# Milestone to review: the current one, or the newest with a done roadmap.
_M=none; _SUMMARIES=0; _RETRO_FILE=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  if [ "$_M" != none ]; then
    _SUMMARIES=$(ls "$_YT_DIR"/$_M-S[0-9][0-9]-T[0-9][0-9]-SUMMARY.md 2>/dev/null | grep -c .)
    _RETRO_FILE="$_YT_DIR/$_M-RETRO.md"
  fi
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "MILESTONE: $_M"
echo "SUMMARIES: $_SUMMARIES"
echo "RETRO_FILE: $_RETRO_FILE"
echo "RETRO_EXISTS: $([ -f "$_RETRO_FILE" ] && echo yes || echo no)"
```

## ytstack invocation notes

retro closes the loop that `summarize-task` opens: the milestone's `M###-S##-T##-SUMMARY.md` files (Outcome, Deviations, Follow-ups, Verification) are the raw material; the installed gstack `retro` skill runs the retrospective; ytstack keeps the result next to the milestone.

HARD-GATE: `HAS_YTSTACK=no` or `MILESTONE=none`: stop with "no milestone to review; run resume-session". `SUMMARIES=0`: stop with "the milestone has no task summaries yet; retro runs after the last summarize-task".

Before invoking gstack, read every summary of `MILESTONE` plus `M###-CONTEXT.md` (goal, exit criteria) and hand them to the gstack skill as the material under review. After it completes, write `RETRO_FILE` with frontmatter (`milestone`, `project`, `created`) and the gstack output; copy lessons that generalize into `KNOWLEDGE.md` and decisions into `DECISIONS.md` (one entry each, never silently).

## Terminal State

Report `RETRO_FILE` and the number of KNOWLEDGE / DECISIONS entries added. Suggest `ytstack:plan-milestone` for the next milestone or `ytstack:ship` when the milestone is to be released. Do NOT auto-invoke any downstream skill.

## HARD-GATE: gstack installed?

This wrapper runs the gstack `retro` skill that is **installed** on this machine (`GSTACK_DIR` above; ytstack is tested against gstack v1.96.0.0, bun >= 1.4.2). gstack is not vendored (DECISIONS 2026-11-07 "Vendor strategy").

- If `GSTACK_AVAILABLE` is `no` (or `unknown`) or `GSTACK_SKILL_OK` is `no`: stop. Tell the user that `ytstack:retro` needs gstack and print the one-line install command from `GSTACK_INSTALL_CMD`. Do not improvise a retrospective from memory.
- If `GSTACK_PIN_OK` is `no`: continue, but say once that the installed gstack (`GSTACK_VERSION`) is older than the version ytstack was tested with.
- If `BUN_OK` is `no`: continue, but warn that gstack's helpers need bun >= 1.4.2 and may fail.

## Procedure

1. Invoke the Skill tool with `retro` (the installed gstack skill, not `ytstack:retro`), with the summaries and milestone context as its input. Follow it to completion.
2. Apply the ytstack post-processing from "ytstack invocation notes" (`RETRO_FILE`, KNOWLEDGE / DECISIONS entries).
3. Report per the Terminal State. Do NOT auto-invoke any downstream skill.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- resolver + gstack precheck + milestone summary count
2. **HARD-GATE** -- stop with the install command when gstack is missing; stop without summaries
3. **Read the material** -- every `M###-S##-T##-SUMMARY.md` + `M###-CONTEXT.md`
4. **Invoke installed `retro`** via the Skill tool and follow it to completion
5. **Write `M###-RETRO.md`** + KNOWLEDGE / DECISIONS entries
6. **Report + return** -- paths + next-step suggestion, no auto-chaining

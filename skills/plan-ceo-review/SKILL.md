---
name: plan-ceo-review
metadata:
  tier: core
  version: 0.1.0
description: "Challenges premise, scope and ambition of a pitch or a milestone through the installed gstack plan-ceo-review skill. Use right after office-hours on OFFICE-HOURS.md, or after plan-milestone and before slice-milestone on M###-CONTEXT.md and M###-ROADMAP.md; also when the user says CEO review, scope review, is this too big, is this too small. Not for technical feasibility (plan-eng-review)."
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
---

# ytstack:plan-ceo-review

Thin wrapper around the **installed** gstack `plan-ceo-review` skill (`~/.claude/skills/gstack/plan-ceo-review`, ytstack tested against v1.96.0.0). Detects the ytstack mode (milestone vs concept), checks the install, invokes the gstack skill through the Skill tool so its procedure runs natively, then applies the outcome to ytstack artifacts. gstack is the single source of truth for the procedure; upstream updates arrive with the install.

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
_CURRENT_MILESTONE=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
fi
_CONTEXT_FILE="$_YT_DIR/$_CURRENT_MILESTONE-CONTEXT.md"
_ROADMAP_FILE="$_YT_DIR/$_CURRENT_MILESTONE-ROADMAP.md"
# Concept-mode pitch discovery: greenfield OFFICE-HOURS.md, or brownfield .ytstack/OFFICE-HOURS-*.md
_PITCH=""
if [ -f "./OFFICE-HOURS.md" ]; then
  _PITCH="./OFFICE-HOURS.md"
elif [ -n "$_YT_DIR" ]; then
  _PITCH=$(ls "$_YT_DIR"/OFFICE-HOURS-*.md 2>/dev/null | head -1)
fi
# Mode detection
if [ "$_CURRENT_MILESTONE" != "none" ] && [ -f "$_CONTEXT_FILE" ] && [ -f "$_ROADMAP_FILE" ]; then
  _MODE=milestone
elif [ -n "$_PITCH" ] && [ -f "$_PITCH" ]; then
  _MODE=concept
else
  _MODE=abort
fi
# gstack precheck (M017): installed dependency, not vendored
if command -v yt_gstack_ctx >/dev/null 2>&1; then
  yt_gstack_ctx >/dev/null
  echo "GSTACK_AVAILABLE: $YT_GSTACK_AVAILABLE"; echo "GSTACK_DIR: $YT_GSTACK_DIR"; echo "GSTACK_VERSION: ${YT_GSTACK_VERSION:-none}"
  echo "GSTACK_PIN_OK: $YT_GSTACK_PIN_OK (pin v$YT_GSTACK_PIN)"; echo "GSTACK_SKILL_OK: $(yt_gstack_skill_ok plan-ceo-review)"
  echo "BUN_OK: $YT_BUN_OK (${YT_BUN_VERSION:-none})"; echo "GSTACK_INSTALL_CMD: $YT_GSTACK_INSTALL_CMD"
else
  echo "GSTACK_AVAILABLE: unknown (shared lib not loaded)"
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "MODE: $_MODE"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "CONTEXT_FILE: $_CONTEXT_FILE ($([ -f "$_CONTEXT_FILE" ] && echo yes || echo no))"
echo "ROADMAP_FILE: $_ROADMAP_FILE ($([ -f "$_ROADMAP_FILE" ] && echo yes || echo no))"
echo "PITCH: ${_PITCH:-none}"
```

## ytstack invocation notes

This wrapper runs in one of two modes, auto-detected above:

**Mode = milestone** (a ytstack milestone exists). The "plan" being CEO-reviewed is the current milestone's CONTEXT + ROADMAP. Read `_CONTEXT_FILE` and `_ROADMAP_FILE` when the gstack skill asks what plan to review. Do NOT prompt the user to identify the plan.

**Mode = concept** (no milestone yet; pitch artifact produced by `ytstack:office-hours` exists). The "plan" being CEO-reviewed is the pitch at `_PITCH`. Treat it as a project-concept: challenge premise, scope, target user, differentiation. Output the decision to proceed / rescope / kill. Concept-mode CEO review runs BEFORE `init-project`, per the locked greenfield flow (DECISIONS 2026-04-24 "Greenfield-flow reorder").

**Mode = abort.** If neither a milestone plan nor a pitch artifact exists, abort with: "Run `ytstack:office-hours` first to produce a pitch, or run `ytstack:plan-milestone` to produce a milestone plan. plan-ceo-review reviews an existing plan; it does not produce one." Do NOT invoke the gstack skill.

After the installed gstack `plan-ceo-review` skill completes:

- **Milestone mode:** apply the review outcome by editing `_ROADMAP_FILE` (add / reorder / remove slices per approval). Append any locked scope decision to `DECISIONS.md` in append-only format. Update `STATE.md` `last_updated` and next-action if slicing changed.
- **Concept mode:** write the review outcome as an annotation block at the top of `_PITCH` (e.g. `## CEO review 2026-04-24: hold / expand / reduce`, with reasoning). If the decision is "proceed", recommend `ytstack:plan-eng-review` (if not yet run) or `ytstack:init-project` to scaffold. If "kill" or "rescope", recommend re-running office-hours on the affected questions before any commit.

## HARD-GATE: gstack installed?

This wrapper runs the gstack `plan-ceo-review` skill that is **installed** on this machine (`GSTACK_DIR` above; ytstack is tested against gstack v1.96.0.0, bun >= 1.4.2). gstack is not vendored any more (DECISIONS 2026-11-07 "Vendor strategy").

- If `MODE` is `abort`: stop with the abort message from the invocation notes (this gate comes first because it needs no gstack).
- If `GSTACK_AVAILABLE` is `no` (or `unknown`): stop. Tell the user that `ytstack:plan-ceo-review` needs gstack and print the one-line install command from `GSTACK_INSTALL_CMD`. Do not improvise the CEO review from memory.
- If `GSTACK_PIN_OK` is `no`: continue, but say once that the installed gstack (`GSTACK_VERSION`) is older than the version ytstack was tested with.
- If `BUN_OK` is `no`: continue, but warn that gstack's helpers need bun >= 1.4.2 and may fail.

## Procedure

1. Invoke the Skill tool with `plan-ceo-review` (the installed gstack skill, not `ytstack:plan-ceo-review`). When it asks which plan to review, answer from `MODE`: milestone -> `CONTEXT_FILE` + `ROADMAP_FILE`; concept -> `PITCH`. Follow it to completion.
2. Apply the ytstack post-processing for the detected mode from "ytstack invocation notes" above.
3. Report the outcome and the recommended next skill. Do NOT auto-invoke any downstream skill.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- resolver, mode detection, gstack precheck flags
2. **HARD-GATE** -- abort without a plan; stop with the install command when gstack is missing
3. **Invoke installed `plan-ceo-review`** via the Skill tool, pointing it at the mode's plan files
4. **Post-process** -- roadmap edits + DECISIONS (milestone) or pitch annotation (concept)
5. **Report + return** -- outcome + next step, no auto-chaining

## Terminal State

Return control after reporting the review outcome (hold / expand / reduce / kill) and the recommended next skill: milestone mode -> `ytstack:slice-milestone` (or re-slice); concept mode -> `ytstack:plan-eng-review` or `ytstack:init-project` on "proceed", `ytstack:office-hours` on "kill / rescope". Abort paths (no plan, no gstack) return with the message only. Do NOT auto-invoke any downstream skill.

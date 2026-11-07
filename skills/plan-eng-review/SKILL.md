---
name: plan-eng-review
description: "Review execution approach for feasibility, architecture, data flow, edge cases, test coverage, performance, and security risks. Auto-detects mode: concept-mode reviews a pitch (OFFICE-HOURS.md) for technical feasibility before any scaffolding; milestone-mode reviews slice-plans (M###-S##-PLAN.md) before plan-task. Use concept-mode optionally after plan-ceo-review to sanity-check the pitched approach; use milestone-mode after slice-milestone to lock architecture before implementation. Thin ytstack wrapper around the installed gstack plan-eng-review skill (pinned v1.96.0.0, needs bun >= 1.4.2)."
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
---

# ytstack:plan-eng-review

Thin wrapper around the **installed** gstack `plan-eng-review` skill (`~/.claude/skills/gstack/plan-eng-review`, ytstack tested against v1.96.0.0). Detects the ytstack mode (milestone vs concept), checks the install, invokes the gstack skill through the Skill tool so its procedure runs natively, then applies the outcome to ytstack artifacts. gstack is the single source of truth for the procedure; upstream updates arrive with the install.

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
_SLICE_PLANS=""
if [ -n "$_CURRENT_MILESTONE" ] && [ "$_CURRENT_MILESTONE" != "none" ] && [ -d "$_YT_DIR" ]; then
  _SLICE_PLANS=$(ls "$_YT_DIR"/$_CURRENT_MILESTONE-S[0-9][0-9]-PLAN.md 2>/dev/null | tr '\n' ' ')
fi
_PITCH=""
if [ -f "./OFFICE-HOURS.md" ]; then
  _PITCH="./OFFICE-HOURS.md"
elif [ -n "$_YT_DIR" ]; then
  _PITCH=$(ls "$_YT_DIR"/OFFICE-HOURS-*.md 2>/dev/null | head -1)
fi
if [ -n "$_SLICE_PLANS" ]; then
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
  echo "GSTACK_PIN_OK: $YT_GSTACK_PIN_OK (pin v$YT_GSTACK_PIN)"; echo "GSTACK_SKILL_OK: $(yt_gstack_skill_ok plan-eng-review)"
  echo "BUN_OK: $YT_BUN_OK (${YT_BUN_VERSION:-none})"; echo "GSTACK_INSTALL_CMD: $YT_GSTACK_INSTALL_CMD"
else
  echo "GSTACK_AVAILABLE: unknown (shared lib not loaded)"
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "MODE: $_MODE"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "SLICE_PLANS: ${_SLICE_PLANS:-none}"
echo "PITCH: ${_PITCH:-none}"
```

## ytstack invocation notes

Two modes, auto-detected above:

**Mode = milestone** (slice-plans exist). The "plan" being engineering-reviewed is the current milestone's slice-plans. Read those files when the gstack skill asks what to review. Architecture, data flow, edge cases, test coverage, performance.

**Mode = concept** (no slice-plans yet; pitch artifact produced by `ytstack:office-hours` exists). The "plan" being engineering-reviewed is the pitch at `_PITCH`. Focus the review on feasibility + architectural risk of the pitched approach BEFORE any infra is scaffolded: is the target tech stack viable, are there hidden integration complexities, are the perf/scale expectations realistic, are there obvious security / data-handling gaps. Output the feasibility verdict + top 3 risk items. Concept-mode eng review is OPTIONAL per the locked greenfield flow (DECISIONS 2026-04-24); office-hours + plan-ceo-review can proceed to init-project without it.

**Mode = abort.** If neither slice-plans nor a pitch artifact exist, abort with: "Run `ytstack:office-hours` first (concept-mode review) or `ytstack:slice-milestone` first (milestone-mode review). plan-eng-review reviews existing plan content; it does not produce it." Do NOT invoke the gstack skill.

After the installed gstack `plan-eng-review` skill completes:

- **Milestone mode:** apply review outcomes by editing the affected slice-plans (add edge cases, adjust tests, tighten scope). Append any locked architectural decision to `DECISIONS.md` in append-only format.
- **Concept mode:** append the feasibility verdict + risk-item list as an annotation block at the top of `_PITCH`. If "go", recommend `ytstack:init-project`. If "stop / rescope", recommend revisiting office-hours on the affected question.

## HARD-GATE: gstack installed?

This wrapper runs the gstack `plan-eng-review` skill that is **installed** on this machine (`GSTACK_DIR` above; ytstack is tested against gstack v1.96.0.0, bun >= 1.4.2). gstack is not vendored any more (DECISIONS 2026-11-07 "Vendor strategy").

- If `MODE` is `abort`: stop with the abort message from the invocation notes (this gate comes first because it needs no gstack).
- If `GSTACK_AVAILABLE` is `no` (or `unknown`): stop. Tell the user that `ytstack:plan-eng-review` needs gstack and print the one-line install command from `GSTACK_INSTALL_CMD`. Do not improvise the engineering review from memory.
- If `GSTACK_PIN_OK` is `no`: continue, but say once that the installed gstack (`GSTACK_VERSION`) is older than the version ytstack was tested with.
- If `BUN_OK` is `no`: continue, but warn that gstack's helpers need bun >= 1.4.2 and may fail.

## Procedure

1. Invoke the Skill tool with `plan-eng-review` (the installed gstack skill, not `ytstack:plan-eng-review`). When it asks what to review, answer from `MODE`: milestone -> the files in `SLICE_PLANS`; concept -> `PITCH`. Follow it to completion.
2. Apply the ytstack post-processing for the detected mode from "ytstack invocation notes" above.
3. Report the outcome and the recommended next skill. Do NOT auto-invoke any downstream skill.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- resolver, mode detection, gstack precheck flags
2. **HARD-GATE** -- abort without plan content; stop with the install command when gstack is missing
3. **Invoke installed `plan-eng-review`** via the Skill tool, pointing it at the mode's plan files
4. **Post-process** -- slice-plan edits + DECISIONS (milestone) or pitch annotation (concept)
5. **Report + return** -- outcome + next step, no auto-chaining

## Terminal State

Return control after reporting the feasibility verdict and the recommended next skill: milestone mode -> `ytstack:plan-task` (or `ytstack:spawn-milestone-team`); concept mode -> `ytstack:init-project` on "go", `ytstack:office-hours` on "stop / rescope". Abort paths (no plan content, no gstack) return with the message only. Do NOT auto-invoke any downstream skill.

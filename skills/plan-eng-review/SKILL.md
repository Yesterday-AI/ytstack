---
name: plan-eng-review
description: "Engineering-manager-mode plan review. Locks in execution plan: architecture, data flow, edge cases, test coverage, performance. Thin ytstack wrapper that injects slice-plan context into the vendored gstack plan-eng-review procedure. Run after plan-ceo-review (if used) and before plan-task."
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
---

# ytstack:plan-eng-review

Thin wrapper around the vendored gstack `plan-eng-review` skill (`vendor/gstack/plan-eng-review/SKILL.md`). Injects ytstack slice-plan context, then inlines the vendored procedure verbatim. Vendor is single source of truth.

## ytstack context (resolved at render time)

```!
cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")
if [ -d "$PWD/.ytstack" ]; then _YT_DIR="$PWD/.ytstack";
elif [ -d "$HOME/.ytstack/projects/$_PROJECT_SLUG" ]; then _YT_DIR="$HOME/.ytstack/projects/$_PROJECT_SLUG";
else _YT_DIR=""; fi
_CURRENT_MILESTONE=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
fi
_SLICE_PLANS=""
if [ -n "$_CURRENT_MILESTONE" ] && [ "$_CURRENT_MILESTONE" != "none" ] && [ -d "$_YT_DIR" ]; then
  _SLICE_PLANS=$(ls "$_YT_DIR"/$_CURRENT_MILESTONE-S[0-9][0-9]-PLAN.md 2>/dev/null | tr '\n' ' ')
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "YT_DIR: $_YT_DIR"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "SLICE_PLANS: ${_SLICE_PLANS:-none}"
```

## ytstack invocation notes

You are invoked inside a ytstack project. The "plan" being engineering-reviewed is the current milestone's slice-plans (paths listed above). When the vendored procedure below asks what plan to review, read those files; do NOT prompt the user to identify a plan.

HARD-GATE: if `HAS_YTSTACK=no` or `CURRENT_MILESTONE=none` or `SLICE_PLANS=none`, abort with: "Run `ytstack:init-project`, `ytstack:plan-milestone`, and `ytstack:slice-milestone` first." Do not invoke the vendored procedure.

After the vendored procedure completes:
- Apply review outcomes by editing the affected slice-plans (add edge cases, adjust tests, tighten scope).
- Append any locked architectural decision to `DECISIONS.md` in append-only format.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/gstack/plan-eng-review/SKILL.md"
```

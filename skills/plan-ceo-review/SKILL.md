---
name: plan-ceo-review
description: "CEO / founder-mode plan review. Challenges premise, scope, and ambition of the current milestone. Four modes: SCOPE EXPANSION, SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION. Thin ytstack wrapper that injects milestone context into the vendored gstack plan-ceo-review procedure. Use before locking a milestone plan."
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
---

# ytstack:plan-ceo-review

Thin wrapper around the vendored gstack `plan-ceo-review` skill (`vendor/gstack/plan-ceo-review/SKILL.md`). Injects ytstack milestone context, then inlines the vendored procedure verbatim so it runs without adapt / fork drift. Vendor is single source of truth; upstream updates flow through.

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
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "YT_DIR: $_YT_DIR"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "CONTEXT_FILE: $_YT_DIR/$_CURRENT_MILESTONE-CONTEXT.md"
echo "ROADMAP_FILE: $_YT_DIR/$_CURRENT_MILESTONE-ROADMAP.md"
echo "CONTEXT_EXISTS: $([ -f "$_YT_DIR/$_CURRENT_MILESTONE-CONTEXT.md" ] && echo yes || echo no)"
echo "ROADMAP_EXISTS: $([ -f "$_YT_DIR/$_CURRENT_MILESTONE-ROADMAP.md" ] && echo yes || echo no)"
```

## ytstack invocation notes

You are invoked inside a ytstack project. The "plan" being CEO-reviewed is the current milestone's CONTEXT + ROADMAP (paths above). When the vendored procedure below asks what plan to review, read those two files; do NOT prompt the user to identify a plan.

HARD-GATE: if `HAS_YTSTACK=no` or `CURRENT_MILESTONE=none` or either file does not exist, abort with: "Run `ytstack:init-project` and `ytstack:plan-milestone` first." Do not invoke the vendored procedure.

After the vendored procedure completes:
- Apply the review outcome by editing `$CURRENT_MILESTONE-ROADMAP.md` (add / reorder / remove slices per approval).
- Append any locked scope decision to `DECISIONS.md` in append-only format: `## YYYY-MM-DD: <title>` / Context / Options / Chose / Reason.
- Update `STATE.md` `last_updated` and next-action if slicing changed.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/gstack/plan-ceo-review/SKILL.md"
```

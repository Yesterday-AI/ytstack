---
name: plan-ceo-review
description: "CEO/founder-mode plan review. Reads the current milestone's CONTEXT + ROADMAP and challenges premise, scope, and ambition. Four modes: SCOPE EXPANSION, SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION. Delegates to vendored gstack plan-ceo-review while keeping ytstack context-aware. Use before locking a milestone plan."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
triggers:
  - plan-ceo-review
  - review milestone plan
  - think bigger
  - expand scope
  - ceo review
---

# plan-ceo-review

A founder-mode review of the current milestone's plan. Challenges premise, scope, and ambition before execution locks in. This is a **wrapper** around the vendored gstack plan-ceo-review skill -- the review logic is theirs, the ytstack context-awareness is ours.

## When to run

- After `ytstack:plan-milestone` and `ytstack:slice-milestone`, before `plan-task`
- When a milestone feels "small" or "obvious" (CEO review often finds it's bigger than assumed)
- When re-scoping mid-milestone (paired with `reassess-roadmap`)

## Anti-Pattern: "I already know the scope"

That's exactly when CEO review catches the most. This skill exists to challenge assumptions you're not aware you made. If you think you don't need it, you probably do.

## Checklist

1. **Run preamble** -- detect milestone + context
2. **HARD-GATE** -- milestone must be planned
3. **Load vendored skill** -- read `vendor/gstack/plan-ceo-review/SKILL.md`
4. **Inject ytstack context** -- pass current CONTEXT.md + ROADMAP.md as the subject
5. **Follow vendored procedure** with ytstack-aware framing
6. **Apply review outcome** -- edit ROADMAP / CONTEXT as the review recommends
7. **Log decision to `DECISIONS.md`** if scope materially changed
8. **Report + return**

## Preamble

```bash
_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")
if [ -d "$_PROJECT_DIR/.ytstack" ]; then _YT_DIR="$_PROJECT_DIR/.ytstack";
elif [ -d "$HOME/.ytstack/projects/$_PROJECT_SLUG" ]; then _YT_DIR="$HOME/.ytstack/projects/$_PROJECT_SLUG";
else _YT_DIR=""; fi
_HAS_YTSTACK=$([ -n "$_YT_DIR" ] && echo yes || echo no)

_CURRENT_MILESTONE=none
if [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
fi

_CONTEXT_FILE="$_YT_DIR/$_CURRENT_MILESTONE-CONTEXT.md"
_ROADMAP_FILE="$_YT_DIR/$_CURRENT_MILESTONE-ROADMAP.md"

# Vendored gstack skill path (plugin-root relative)
_VENDOR_SKILL="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/gstack/plan-ceo-review/SKILL.md"
_VENDOR_EXISTS=$([ -f "$_VENDOR_SKILL" ] && echo yes || echo no)

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "CONTEXT_FILE: $_CONTEXT_FILE"
echo "ROADMAP_FILE: $_ROADMAP_FILE"
echo "VENDOR_SKILL: $_VENDOR_SKILL"
echo "VENDOR_EXISTS: $_VENDOR_EXISTS"
```

## Procedure

**Step 2 HARD-GATE.**

- `HAS_YTSTACK=no` → abort "run init-project first"
- `CURRENT_MILESTONE=none` → abort "run plan-milestone first"
- `VENDOR_EXISTS=no` → abort "gstack not vendored yet. Run `./scripts/sync-upstream.sh` (M008) or manually add the subtree. See `vendor/README.md`."

**Step 3 -- Load vendored skill.** Read `{VENDOR_SKILL}` in full. Follow its instructions, EXCEPT:

- Do not re-implement file-reading or project detection -- our preamble already emitted the state
- Do not inherit gstack's preamble (it expects gstack-specific config at `~/.gstack/`)
- Use ytstack artifact paths: `{CONTEXT_FILE}` and `{ROADMAP_FILE}` are the "plan" being reviewed

**Step 4 -- Inject ytstack subject.** When the vendored skill asks "what are we reviewing?", provide:

> Reviewing milestone **{CURRENT_MILESTONE}** of project **{PROJECT_NAME}**.
>
> Goal: (from `{CONTEXT_FILE}` Goal section)
> Exit criteria: (from `{CONTEXT_FILE}` Exit criteria section)
> Slices: (from `{ROADMAP_FILE}` Slices section)

Tell the vendored skill to treat the milestone as the "plan" it's reviewing. Mode detection (SCOPE EXPANSION / HOLD SCOPE / etc.) proceeds per gstack's original logic.

**Step 5 -- Follow vendored procedure.** Execute the vendored skill's procedure step by step. Its AskUserQuestion blocks work as-is. Its mode-selection logic drives what comes next.

**Step 6 -- Apply outcome.** When the review concludes with recommendations:

- If the user accepts changes: use Edit tool on `{ROADMAP_FILE}` to patch slices (add/split/remove as specified)
- If the user accepts new exit criteria: use Edit tool on `{CONTEXT_FILE}` Exit criteria section
- If the review went HOLD SCOPE with no changes: note that in CONTEXT.md's "Reassessment" section

**Step 7 -- Log decision.** If scope materially changed (SCOPE EXPANSION or SCOPE REDUCTION), append to `{YT_DIR}/DECISIONS.md`:

```markdown
## {ISO_TIMESTAMP}: CEO-review of {CURRENT_MILESTONE}

**Context:** Ran `ytstack:plan-ceo-review` on milestone {CURRENT_MILESTONE}.
**Outcome:** {mode-chosen} -- {one-line summary of changes}
**Reason:** {user-reasoning-from-review}
```

**Step 8 -- Report + return.**

> CEO review complete on **{CURRENT_MILESTONE}**. Mode: {MODE}.
>
> Changes applied:
> - {list, or "none -- HOLD SCOPE ruled no changes needed"}
>
> DECISIONS.md updated: {yes/no, with link if yes}.
>
> Next step: if ROADMAP.md changed, re-run `/ytstack:slice-milestone` for affected slices. Otherwise proceed to execution.

## Terminal State

Return after applying review outcomes. Do NOT auto-invoke `slice-milestone`, `plan-task`, or any follow-up skill.

## Why a wrapper

The gstack plan-ceo-review skill is exceptionally well-tuned for what it does. Per gstack's own maintainers, modifying it requires eval evidence -- we don't have that budget and don't need it. Our wrapper does three things the vendored original doesn't:

1. **Subject injection.** Pass ytstack artifacts as the thing being reviewed, not gstack's own `~/.gstack/` state.
2. **Outcome application.** Translate review conclusions into ytstack file edits (ROADMAP.md, CONTEXT.md).
3. **Decision logging.** Append a DECISIONS.md entry when scope changes materially, so the reasoning survives.

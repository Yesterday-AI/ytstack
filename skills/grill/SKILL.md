---
name: grill
metadata:
  tier: core
  version: 0.1.0
description: "Relentless questioning of an idea before it becomes a milestone, through the vendored superpowers brainstorming procedure with ytstack's pitch, project one-liner and decisions injected; writes the agreed design into the milestone context. Use between office-hours and plan-milestone, when a feature request is bigger than one sentence, or when the user says grill me, poke holes in this, let's think this through, design before we plan. Not for one-sentence changes (quick-task) and not for slicing or task plans (slice-milestone, plan-task)."
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# ytstack:grill

Thin wrapper around the vendored superpowers `brainstorming` skill (`vendor/superpowers/skills/brainstorming/SKILL.md`). Injects what ytstack already knows (project one-liner, pitch, recent decisions, current milestone), inlines the vendored procedure verbatim, and routes its output into ytstack artifacts instead of a free-floating design doc.

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
_M=none; _ONE_LINER=""; _PITCH=none; _DECISIONS=0
if [ -n "$_YT_DIR" ]; then
  [ -f "$_YT_DIR/STATE.md" ] && _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  [ -f "$_YT_DIR/PROJECT.md" ] && _ONE_LINER=$(sed -n 's/^one-liner: *//p' "$_YT_DIR/PROJECT.md" | head -1)
  _PITCH=$(ls -t "$_YT_DIR"/OFFICE-HOURS*.md 2>/dev/null | head -1); _PITCH=${_PITCH:-none}
  [ -f "$_YT_DIR/DECISIONS.md" ] && _DECISIONS=$(grep -c '^## ' "$_YT_DIR/DECISIONS.md")
fi
[ "$_PITCH" = none ] && [ -f ./OFFICE-HOURS.md ] && _PITCH=./OFFICE-HOURS.md
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "CURRENT_MILESTONE: $_M"
echo "ONE_LINER: ${_ONE_LINER:-none}"
echo "PITCH: $_PITCH"
echo "DECISIONS_COUNT: $_DECISIONS"
echo "DESIGN_TARGET: $([ "$_M" != none ] && [ -n "$_YT_DIR" ] && echo "$_YT_DIR/$_M-CONTEXT.md" || echo "${_YT_DIR:-.}/GRILL-<slug>.md")"
```

## ytstack invocation notes

You are invoked to question an idea until it is small and clear enough to plan. The vendored procedure's "Look Before You Ask" step starts from `PITCH` (the office-hours artifact), `ONE_LINER` and the last entries of `DECISIONS.md`: never re-ask what those already answer.

HARD-GATE: none. grill runs with or without `.ytstack/`; without it, the design notes go to `./GRILL-<slug>.md` and the next step is `ytstack:office-hours` or `ytstack:init-project`.

Where the vendored text says "design doc", write to `DESIGN_TARGET`:

- `CURRENT_MILESTONE` set: append the agreed approach and the rejected alternatives under "Decisions locked in discuss phase" in `M###-CONTEXT.md` (one dated bullet per decision, `YYYY-MM-DD: decided X because Y`), and a one-line pointer in `DECISIONS.md` only for choices that outlive the milestone.
- Otherwise: `GRILL-<slug>.md` (2-4 word kebab slug) with the same sections; `ytstack:plan-milestone` reads it as the milestone's goal source.

Where the vendored text says to invoke `superpowers:writing-plans`, the ytstack equivalent is `ytstack:plan-milestone` followed by `ytstack:slice-milestone`; do not invoke them automatically, name them as the next step. The vendored "spike" is fine; a spike's code never lands without a task plan.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/brainstorming/SKILL.md"
```

## Namespace note (ytstack)

The text above is upstream superpowers content (v7.0.2) rendered inside ytstack. Read `superpowers:<skill>` as `ytstack:<skill>`; `superpowers:writing-plans` has no ytstack skill of that name and maps to `ytstack:plan-milestone` + `ytstack:slice-milestone` (see the invocation notes). Relative links such as `visual-companion.md` and `builder-check-prompt.md` resolve under `vendor/superpowers/skills/brainstorming/` in the ytstack plugin directory (`${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/brainstorming/`); read them from there when the procedure asks for them. The `scripts/` directory there belongs to the visual companion and is optional.

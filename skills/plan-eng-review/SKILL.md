---
name: plan-eng-review
description: "Engineering-manager-mode plan review. Locks in execution plan: architecture, data flow, edge cases, test coverage, performance. Run after plan-ceo-review (if used) and before plan-task, to catch architecture issues before implementation. Wrapper around vendored gstack plan-eng-review."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
triggers:
  - plan-eng-review
  - engineering review
  - architecture review
  - lock in the plan
  - ytstack eng review
---

# plan-eng-review

Eng-manager-mode review of the current milestone's execution plan. Where plan-ceo-review challenges scope and ambition, plan-eng-review challenges architecture and execution details. Wrapper around vendored gstack.

## When to run

- After `plan-milestone` + `slice-milestone` produce concrete slice-plans
- After `plan-ceo-review` if scope was expanded (new architectural implications)
- Before the first `plan-task`, so architecture decisions land before code does
- When you suspect the slicing is structurally wrong (circular dependencies, missing infra)

## Anti-Pattern: "We'll figure out architecture during execution"

Architecture decisions get baked into the first three files touched. By the time you notice the pattern is wrong, it's replicated across the slice. Eng review is the last cheap moment to catch this.

## Checklist

1. **Run preamble** -- state + slice-plans inventory
2. **HARD-GATE** -- current milestone is sliced (at least one `M###-S##-PLAN.md` exists)
3. **Load vendored skill**
4. **Inject slice-plan subject** -- pass the current slice-plan(s) as the subject
5. **Run vendored procedure** -- its edge-case, test-coverage, perf, architecture checks
6. **Apply changes to slice-plans** if review recommends
7. **Log decision to DECISIONS.md** if architecture shifted
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
[ -f "$_YT_DIR/STATE.md" ] && _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)

# List slice-plans for the current milestone
_SLICE_PLANS=""
if [ -n "$_CURRENT_MILESTONE" ] && [ -d "$_YT_DIR" ]; then
  _SLICE_PLANS=$(ls "$_YT_DIR"/$_CURRENT_MILESTONE-S[0-9][0-9]-PLAN.md 2>/dev/null | tr '\n' ' ')
fi

_VENDOR_SKILL="${CLAUDE_PLUGIN_ROOT:-/Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack}/vendor/gstack/plan-eng-review/SKILL.md"
_VENDOR_EXISTS=$([ -f "$_VENDOR_SKILL" ] && echo yes || echo no)

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "SLICE_PLANS: ${_SLICE_PLANS:-none}"
echo "VENDOR_EXISTS: $_VENDOR_EXISTS"
```

## Procedure

**Step 2 HARD-GATE.**

- `HAS_YTSTACK=no` → abort
- `CURRENT_MILESTONE=none` → abort "run plan-milestone first"
- `SLICE_PLANS=none` → abort "run slice-milestone first"
- `VENDOR_EXISTS=no` → abort "gstack not vendored; see vendor/README.md"

**Step 3 -- Load vendored.** Read `{VENDOR_SKILL}` in full.

**Step 4 -- Inject subject.** Build a subject summary from slice-plans:

> Reviewing execution plan for milestone **{CURRENT_MILESTONE}** of project **{PROJECT_NAME}**.
>
> Slices:
> {For each slice-plan:}
> - **{SLICE_ID}:** {slice goal} -- {N} tasks
>   Files touched across tasks: {union of Files sections}
>
> Architecture concerns to evaluate: data flow across slices, dependency order, shared state, test coverage, performance hot-spots.

Tell the vendored skill to take this as the plan under review.

**Step 5 -- Run vendored procedure.** Execute per gstack's eng-review logic: architecture diagram, edge cases, test coverage gaps, performance concerns, security surface. Its AskUserQuestion prompts run as-is.

**Step 6 -- Apply changes.** If the review recommends changes to specific slice-plans or task-plans:

- For slice-plan edits: use Edit tool on `{CURRENT_MILESTONE}-{SLICE_ID}-PLAN.md` per recommendation
- For new tasks added: append to the slice's Tasks section (respect 1-7 rule -- if it pushes past 7, flag and recommend running `slice-milestone` to add a new slice)
- For new slices: note the need and recommend user run `slice-milestone` after (not automatic)

**Step 7 -- Log decision.** If architecture shifted materially, append to `DECISIONS.md`:

```markdown
## {ISO_TIMESTAMP}: Eng-review of {CURRENT_MILESTONE}

**Context:** Ran `ytstack:plan-eng-review` on milestone {CURRENT_MILESTONE} slice-plans.
**Outcome:** {what changed architecturally}
**Reason:** {user-reasoning}
```

**Step 8 -- Report + return.**

> Engineering review complete on **{CURRENT_MILESTONE}**.
>
> Changes applied:
> - {list, or "none -- plan held up"}
>
> DECISIONS.md updated: {yes/no}.
>
> Next step: if changes were structural, re-run `/ytstack:slice-milestone` for affected slices. Otherwise proceed to `/ytstack:plan-task` for the first task.

## Terminal State

Return after applying review. Do NOT invoke `slice-milestone`, `plan-task`, or other downstream skills automatically.

---
name: systematic-debugging
description: "Root-cause debugging in four phases: investigate, analyze, hypothesize, implement. Iron Law -- no fixes without root cause. Wraps vendored superpowers:systematic-debugging with ytstack-aware logging (findings go to KNOWLEDGE.md, decisions to DECISIONS.md). Use when hitting a bug, test failure, or unexpected behavior."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - AskUserQuestion
triggers:
  - debug this
  - fix this bug
  - why is this broken
  - systematic debugging
  - root cause analysis
  - ytstack debug
---

# systematic-debugging

Wrap the vendored superpowers systematic-debugging skill. Adds ytstack integration: findings get persisted to `KNOWLEDGE.md` (pattern / gotcha), decisions to `DECISIONS.md` (architectural shift from the fix). Prevents the "fixed it, no notes" pattern.

## Iron Law (from vendored)

**No fixes without root cause.** A symptom going away is not evidence the bug is fixed -- it's evidence the symptom moved. The four-phase process (investigate → analyze → hypothesize → implement) exists to force root-cause identification before any code changes.

## When to run

- Test suite failure, especially intermittent
- 500 error, stack trace, unexpected exception
- "It was working yesterday"
- Performance regression with no obvious cause
- NOT for feature work -- use TDD or direct execution

## Anti-Pattern: "I can see what's wrong, just fix it"

Sometimes true, often not. The vendored skill's anti-pattern list is real. Read it. If you're certain you've identified root cause without running the four phases, you're probably wrong -- and if you're right, the phases take 5 extra minutes. Cheap insurance.

## Checklist

1. **Run preamble** -- state + vendored skill
2. **HARD-GATE** -- vendored skill present
3. **Capture symptom** -- user describes what's broken
4. **Run vendored 4-phase process**
5. **After fix: capture root cause** to KNOWLEDGE.md if generalizable
6. **If architectural shift** → DECISIONS.md entry
7. **Report + return**

## Preamble

```bash
_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")
if [ -d "$_PROJECT_DIR/.ytstack" ]; then _YT_DIR="$_PROJECT_DIR/.ytstack";
elif [ -d "$HOME/.ytstack/projects/$_PROJECT_SLUG" ]; then _YT_DIR="$HOME/.ytstack/projects/$_PROJECT_SLUG";
else _YT_DIR=""; fi
_HAS_YTSTACK=$([ -n "$_YT_DIR" ] && echo yes || echo no)

_VENDOR_SKILL="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/superpowers/skills/systematic-debugging/SKILL.md"
_VENDOR_EXISTS=$([ -f "$_VENDOR_SKILL" ] && echo yes || echo no)

_CURRENT_MILESTONE=none; _ACTIVE_TASK=none
if [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _ACTIVE_TASK=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "VENDOR_EXISTS: $_VENDOR_EXISTS"
echo "CONTEXT: milestone=$_CURRENT_MILESTONE, task=$_ACTIVE_TASK"
```

## Procedure

**Step 2 HARD-GATE.** Abort if `VENDOR_EXISTS=no`. `HAS_YTSTACK=no` is OK -- debugging can happen outside a tracked project; we just skip the KNOWLEDGE.md/DECISIONS.md persistence then.

**Step 3 -- Capture symptom.** Use AskUserQuestion (open-ended):

> What's broken? Be specific. Include:
> - Exact error message or behavior
> - What triggers it (steps to reproduce)
> - What you expected vs what happened
> - When it started (if known)
>
> One paragraph minimum. Vague symptoms make vague debugging.

Remember as `_SYMPTOM`.

**Step 4 -- Run vendored.** Read `{VENDOR_SKILL}` in full and follow its four-phase procedure. Pass `_SYMPTOM` as the initial problem statement. The vendored skill handles:
- **Investigate:** gather evidence, don't theorize yet
- **Analyze:** pattern-match the evidence against known bug shapes
- **Hypothesize:** propose root causes, pick the most likely, design a test
- **Implement:** write the fix, confirm the test pattern confirms root cause

Let the skill's anti-rationalization patterns drive ("don't stop at first plausible fix" etc.).

**Step 5 -- Capture root cause to KNOWLEDGE.md.** If `HAS_YTSTACK=yes` AND the root cause is generalizable (pattern, gotcha, convention violation), append to `{YT_DIR}/KNOWLEDGE.md`:

Under "Lessons learned":
```markdown
- **{short lesson title}:** {one-line pattern statement}. Surfaced debugging: {symptom-summary}. Root cause: {root-cause-summary}. Fix: {fix-summary}.
```

Under "Gotchas":
```markdown
- **{gotcha title}:** {one-line gotcha}. Seen in: {file:line or area}. Triggers when: {condition}.
```

If root cause is one-off (e.g. typo in a specific commit), skip KNOWLEDGE.md. The git history already has it.

**Step 6 -- If architectural shift → DECISIONS.md.** If the fix changes a design decision (e.g. "switched from lock-based to optimistic concurrency because of deadlocks"), append to `{YT_DIR}/DECISIONS.md`:

```markdown
## {ISO_TIMESTAMP}: {decision title}

**Context:** Systematic debugging on {symptom}. Root cause: {root-cause}.
**Options considered:** {alternatives}
**Chose:** {chosen}
**Reason:** {why}
```

Not every fix is a decision -- only architectural ones. One-line style-fixes don't count.

**Step 7 -- Report + return.**

> Bug fixed. Root cause: {root-cause-summary}.
>
> Fix: {fix-summary}.
>
> Verification: {how we confirmed the root cause is addressed, not just the symptom}.
>
> Notes:
> - KNOWLEDGE.md updated: {yes/no}
> - DECISIONS.md updated: {yes/no}
>
> Next step:
> - If this unblocked an active ytstack task: consider running `/ytstack:summarize-task` when done
> - If the bug suggests a test gap: consider adding it to a future task
> - If the fix revealed scope creep: consider `/ytstack:reassess-roadmap`

## Terminal State

Return after debugging complete. Do NOT invoke `summarize-task` unless the user explicitly says "mark task done" -- debugging and task-completion are separate lifecycles.

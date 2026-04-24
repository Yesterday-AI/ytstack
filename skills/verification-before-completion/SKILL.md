---
name: verification-before-completion
description: "Run verification commands and confirm output before claiming work is complete. Evidence before assertions. Use before commit, before PR, before summarize-task, before any 'done' claim. Wrapper around vendored superpowers:verification-before-completion with ytstack-aware verification-command discovery from task-plan."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
triggers:
  - verify before completion
  - check before commit
  - evidence before assertions
  - ytstack verify
---

# verification-before-completion

Enforce the evidence-before-assertions rule. Before any "done" claim, run the verification commands, capture the output, confirm success. Wrapper around vendored superpowers skill. Auto-discovers the verification command from the active task's `T##-PLAN.md` if available.

## Iron law (from vendored)

**Run verification commands. Confirm output. Only then claim done.** Untested claims of done are the #1 source of "it worked on my machine" debt.

## When to run

- Before `ytstack:summarize-task` (make sure the task is actually done)
- Before creating a PR or pushing
- Before telling the user "this is ready"
- After any non-trivial code change

## Anti-Pattern: "The tests passed a minute ago"

A minute ago was a different codebase. Run them again now. The vendored skill's anti-rationalization list covers this and other patterns.

## Checklist

1. **Run preamble** -- state + task-plan verification command
2. **HARD-GATE** -- vendored skill present
3. **Determine verification command(s)**:
   a. If `ACTIVE_TASK` exists → read its `T##-PLAN.md`, use its Verification section
   b. Otherwise → ask user for verification command
4. **Run vendored procedure** with the command(s)
5. **Confirm output matches expectations**
6. **Report** -- pass / fail / pass-with-caveats

## Preamble

```bash
_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || basename "$(pwd)")
if [ -d "$_PROJECT_DIR/.ytstack" ]; then _YT_DIR="$_PROJECT_DIR/.ytstack";
elif [ -d "$HOME/.ytstack/projects/$_PROJECT_SLUG" ]; then _YT_DIR="$HOME/.ytstack/projects/$_PROJECT_SLUG";
else _YT_DIR=""; fi
_HAS_YTSTACK=$([ -n "$_YT_DIR" ] && echo yes || echo no)

_CURRENT_MILESTONE=none; _ACTIVE_SLICE=none; _ACTIVE_TASK=none
if [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _ACTIVE_SLICE=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
  _ACTIVE_TASK=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi

_TASK_PLAN="$_YT_DIR/$_CURRENT_MILESTONE-$_ACTIVE_SLICE-$_ACTIVE_TASK-PLAN.md"
_HAS_TASK_PLAN=$([ -f "$_TASK_PLAN" ] && echo yes || echo no)

# Extract verification command from task-plan if it exists
_VERIFICATION_CMD=""
if [ "$_HAS_TASK_PLAN" = "yes" ]; then
  _VERIFICATION_CMD=$(awk '/^## Verification/{flag=1; next} /^## /{flag=0} flag' "$_TASK_PLAN" | grep -E '^```' -A 100 | sed -n '/^```bash/,/^```$/{/^```/d; p}' | head -5)
fi

_VENDOR_SKILL="${CLAUDE_PLUGIN_ROOT:-/Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack}/vendor/superpowers/skills/verification-before-completion/SKILL.md"
_VENDOR_EXISTS=$([ -f "$_VENDOR_SKILL" ] && echo yes || echo no)

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "ACTIVE_TASK: $_CURRENT_MILESTONE-$_ACTIVE_SLICE-$_ACTIVE_TASK"
echo "HAS_TASK_PLAN: $_HAS_TASK_PLAN"
echo "HAS_VERIFICATION_CMD: $([ -n "$_VERIFICATION_CMD" ] && echo yes || echo no)"
echo "VENDOR_EXISTS: $_VENDOR_EXISTS"
```

## Procedure

**Step 2 HARD-GATE.** Abort if `VENDOR_EXISTS=no`.

**Step 3 -- Determine verification command.**

- If `HAS_VERIFICATION_CMD=yes`: use it. Show to user: "Verifying task **{ACTIVE_TASK}**. Command from task-plan: `{cmd}`"
- Else use AskUserQuestion (open-ended):

> What command(s) should I run to verify this work is done?
>
> Concrete command, not "manual test". Examples: `bun test test/auth.test.ts`, `curl -X POST http://localhost:3000/api/ping | jq .status`, `npm run lint && npm run typecheck`.
>
> Multiple commands? List them one per line.

Remember as `_CMDS`.

**Step 4 -- Run vendored.** Read `{VENDOR_SKILL}`. Follow its procedure with `_CMDS` as the verification commands. Its logic handles:
- Running the commands
- Capturing stdout + stderr + exit code
- Comparing against expected success signal
- Deciding pass / fail

**Step 5 -- Confirm.** For each command, report:
- Exit code
- Pass signal match
- Any unexpected output (warnings, flaky indicators)

If all pass cleanly: mark VERIFIED.
If exit 0 but output suggests issues (warnings, deprecations, "skipped N tests"): mark PASS_WITH_CAVEATS.
If any fail: mark FAILED.

**Step 6 -- Report.**

> Verification for **{ACTIVE_TASK / whatever}**: **{VERIFIED / PASS_WITH_CAVEATS / FAILED}**.
>
> Commands run:
> {For each command:}
> - `{cmd}` -- exit={code}, {pass/fail/caveats}: {one-line outcome}
>
> {If FAILED:} Do NOT claim done. Return to debugging / implementation.
> {If PASS_WITH_CAVEATS:} Evidence of issues: {list}. Decide: is this acceptable to ship, or do we fix first?
> {If VERIFIED:} Evidence before assertion confirmed. Safe to call task done.
>
> Next step:
> - VERIFIED → proceed to `/ytstack:summarize-task` (if in an active task)
> - PASS_WITH_CAVEATS → user decides; flag in summary's Deviations if shipping anyway
> - FAILED → return to task, do not close

## Terminal State

Return after reporting verification outcome. Do NOT invoke `summarize-task` automatically -- verification pass enables, it doesn't mandate, summary writing.

---
name: test-driven-development
description: "RED-GREEN-REFACTOR: write a failing test, watch it fail, write minimal code, watch it pass, commit. Invokes vendored superpowers:test-driven-development with ytstack context (active task scope). Use during task execution."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - AskUserQuestion
triggers:
  - tdd
  - test-driven development
  - red-green-refactor
  - ytstack tdd
---

# test-driven-development

Wrap the vendored superpowers TDD skill. Adds ytstack-aware context: reads current `T##-PLAN.md` to know file paths and verification command, passes them into the TDD flow.

## When to run

- During task execution, AFTER `plan-task` has written the task-plan
- When implementing any feature or bugfix that should have test coverage
- NOT for one-off scripts, docs-only changes, config tweaks

## Anti-Pattern: "I'll write tests after I know the shape of the code"

Superpowers' maintainers explicitly reject this. Tests that come after the code test what was built, not what was wanted. Write the failing test first. If that feels wrong, read the vendored skill's opening section.

## Checklist

1. **Run preamble** -- detect active task + verification command
2. **HARD-GATE** -- active task exists, vendored skill present
3. **Inject task context** -- pass T##-PLAN's Files + Verification to the vendored skill
4. **Run vendored RED-GREEN-REFACTOR loop**
5. **Commit per vendored skill's guidance** -- atomic commits per cycle
6. **Report + return** -- suggest `summarize-task` if the task is done

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

_VENDOR_SKILL="${CLAUDE_PLUGIN_ROOT:-/Users/alex/Sync/home/alex/Code/WebDev/projects/yesterday-ai/ytstack}/vendor/superpowers/skills/test-driven-development/SKILL.md"
_VENDOR_EXISTS=$([ -f "$_VENDOR_SKILL" ] && echo yes || echo no)

# If running under Agent Teams or headless orchestrator, force non-interactive on superpowers too
_SUPERPOWERS_NON_INTERACTIVE=false
if [ -n "$YTSTACK_NON_INTERACTIVE" ] || [ -n "$OPENCLAW_SESSION" ] || [ -n "$CLAUDE_AGENT_TEAM_MEMBER" ]; then
  _SUPERPOWERS_NON_INTERACTIVE=true
fi

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "ACTIVE_TASK: $_CURRENT_MILESTONE-$_ACTIVE_SLICE-$_ACTIVE_TASK"
echo "HAS_TASK_PLAN: $_HAS_TASK_PLAN"
echo "VENDOR_EXISTS: $_VENDOR_EXISTS"
echo "SUPERPOWERS_NON_INTERACTIVE: $_SUPERPOWERS_NON_INTERACTIVE"
```

## Procedure

**Step 2 HARD-GATE.**

- `HAS_YTSTACK=no` → abort "run init-project first"
- `ACTIVE_TASK=none` → abort "no active task. Run `/ytstack:plan-task` first"
- `HAS_TASK_PLAN=no` → abort "task-plan missing at {TASK_PLAN}. Repair before TDD"
- `VENDOR_EXISTS=no` → abort "superpowers not vendored. See vendor/README.md"

**Step 3 -- Inject task context.** Read `{TASK_PLAN}`, extract:
- Files section (list of paths)
- Verification section (command)

Pass to the vendored skill as:

> Current ytstack task: **{ACTIVE_TASK}**.
>
> Files this task touches (scope boundary -- don't edit outside):
> {file list from plan}
>
> Verification command (the test must make this command pass):
> ```
> {verification command}
> ```
>
> Task body: {task-plan's "What this does" section}

If `SUPERPOWERS_NON_INTERACTIVE=true`, also inject:

> Running in non-interactive mode. Do not prompt for decisions that have a sensible default. Use the task-plan's stated files and verification command as the authoritative spec.

**Step 4 -- Run vendored.** Read `{VENDOR_SKILL}` in full and follow its procedure step by step:
- Write failing test
- Run it, confirm it fails in the expected way
- Write minimal implementation
- Run test, confirm pass
- Refactor if needed
- Commit atomically

Let the vendored skill's anti-patterns (testing-anti-patterns reference) drive what's OK vs not.

**Step 5 -- Commit per vendored guidance.** Vendored skill recommends commit per GREEN phase. Honor that -- one commit per RED-GREEN-REFACTOR cycle.

Commit message format (ytstack convention):
```
{ACTIVE_TASK}: <short description>
```

e.g. `M003-S01-T10: add failing test for argon2 hash`

**Step 6 -- Report + return.**

> TDD cycle complete for **{ACTIVE_TASK}**. Commits: {count}.
>
> Verification command: `{cmd}` -- {passed / still failing}.
>
> Next step:
> - If verification passes and task is done: run `/ytstack:summarize-task`
> - If more code is needed: continue another RED-GREEN-REFACTOR cycle (re-run this skill)

## Terminal State

Return after TDD cycle completes. Do NOT auto-invoke `summarize-task` -- the user confirms the task is fully done before summarizing. Do NOT invoke `plan-task` for a new task.

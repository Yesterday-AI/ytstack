---
name: plan-task
description: "Turns the next task of the current slice into M###-S##-T##-PLAN.md with exact files and a verification command, and sets STATE active_task. Use after slice-milestone, before executing a task, or when the user says plan the task, next task, detail the task. Not for one-sentence changes (quick-task) and not for closing a task (summarize-task)."
metadata:
  tier: core
  version: 0.1.0
  triggers:
    - plan task
    - detail next task
    - ytstack plan task
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# plan-task

Take one task from the current slice's task list and turn it into a concrete plan: which files to touch, what code to write, how to verify. Output lives at `M###-S##-T##-PLAN.md`.

## Anti-Pattern: "The task summary is enough, I'll figure out files during execution"

No. Tasks without pre-committed file paths drift. An agent (human or AI) asked to "add signup form" will discover mid-stream that the form lives in three different places and pick the wrong one. File paths in the task plan are a concurrency primitive -- they prevent two tasks from editing the same file by accident, and they make scope-drift detection possible.

## Iron rule

**A task must fit in one context window.** If the plan feels too big, split into two tasks. Signals the task is too big:
- More than ~5 files touched
- Multiple unrelated concerns (e.g. schema change + UI change + new test infra)
- The verification step needs more than 2 commands

When in doubt, split. Smaller tasks ship faster than oversized ones.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- detect current slice + next unplanned task
2. **HARD-GATE: slice must exist** -- abort if no active slice
3. **Confirm task selection** -- show the task line from slice-plan, confirm it's next
4. **Ask file list** -- exact paths to create / modify / delete
5. **Ask task body** -- what the code does, in prose + pseudocode
6. **Ask verification** -- 1-2 commands that prove done
7. **Ask fits-one-context-window check** -- sanity-check or split
8. **Write `M###-S##-T##-PLAN.md`**
9. **Update STATE.md** -- `active_task: T##`
10. **Report + return** -- task ready to execute or dispatch to subagent

## Preamble

```bash
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

_HAS_YTSTACK=$([ -n "$_YT_DIR" ] && echo yes || echo no)

# Ceremony dials (M018): granularity / autonomy from PREFERENCES.md
if command -v yt_prefs >/dev/null 2>&1; then yt_prefs "$_YT_DIR" >/dev/null; else YT_PREF_GRANULARITY=task; YT_PREF_AUTONOMY=loop; YT_PREF_WARNINGS=""; fi
echo "GRANULARITY: $YT_PREF_GRANULARITY"
echo "AUTONOMY: $YT_PREF_AUTONOMY"
echo "PREF_WARNINGS: ${YT_PREF_WARNINGS:-none}"

_NON_INTERACTIVE=false
if [ -n "$YTSTACK_NON_INTERACTIVE" ] || [ -n "$OPENCLAW_SESSION" ] || [ -n "$CLAUDE_AGENT_TEAM_MEMBER" ]; then
  _NON_INTERACTIVE=true
fi

_CURRENT_MILESTONE=none
_ACTIVE_SLICE=none
if [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _ACTIVE_SLICE=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
fi

# If no active slice in STATE.md, infer the first unfinished slice from ROADMAP
if [ "$_ACTIVE_SLICE" = "none" ] || [ -z "$_ACTIVE_SLICE" ]; then
  ROADMAP="$_YT_DIR/$_CURRENT_MILESTONE-ROADMAP.md"
  if [ -f "$ROADMAP" ]; then
    _ACTIVE_SLICE=$(grep -oE '^- \[ \] S[0-9][0-9] --' "$ROADMAP" | head -1 | grep -oE 'S[0-9][0-9]')
  fi
fi

_SLICE_PLAN="$_YT_DIR/$_CURRENT_MILESTONE-$_ACTIVE_SLICE-PLAN.md"

# Next unplanned task = first un-elaborated task in slice-plan
# (Un-elaborated = listed in slice-plan but no corresponding T##-PLAN.md file exists)
_NEXT_TASK=""
if [ -f "$_SLICE_PLAN" ]; then
  for t in $(grep -oE '^- \[ \] T[0-9][0-9] --' "$_SLICE_PLAN" | grep -oE 'T[0-9][0-9]'); do
    _TASK_FILE="$_YT_DIR/$_CURRENT_MILESTONE-$_ACTIVE_SLICE-$t-PLAN.md"
    if [ ! -f "$_TASK_FILE" ]; then
      _NEXT_TASK="$t"
      break
    fi
  done
fi

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "YTSTACK_NON_INTERACTIVE: $_NON_INTERACTIVE"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "ACTIVE_SLICE: $_ACTIVE_SLICE"
echo "SLICE_PLAN: $_SLICE_PLAN"
echo "NEXT_TASK: ${_NEXT_TASK:-none}"
```

## Procedure

### Step 2: HARD-GATE

**STATE lint (M018):** before anything else run `yt_state_lint "$_YT_DIR"` (lib loaded by the preamble) in a Bash call and read `YT_STATE_WARNINGS`. A warning that names a malformed field (`is not M###`, `is not S##`, `is not T##`, `is not ISO-8601`) or "set while current_milestone is none" stops this skill: print the warning and "fix STATE.md first (or run `ytstack:reconcile`)". Other warnings (pointer behind, task already summarized, stale timestamp, done-but-current) are reported in the Step 3 message and do not block.

If `HAS_YTSTACK=no`: abort with "run init-project first".
If `CURRENT_MILESTONE=none`: abort with "run plan-milestone first".
If `ACTIVE_SLICE=none` or slice-plan missing: abort with "run slice-milestone first".
If `NEXT_TASK=none`: report "all tasks in {ACTIVE_SLICE} are planned. Next: execute them or run `/ytstack:plan-task` again if you add a task to the slice-plan." STOP.

### Step 3: Confirm task selection

Read the task line from `{SLICE_PLAN}`. Grep pattern: `^- \[ \] {NEXT_TASK} -- (.*)$`. Extract the description.

Report (no AskUserQuestion -- just show):

> Next unplanned task in **{CURRENT_MILESTONE}-{ACTIVE_SLICE}**:
>
> **{NEXT_TASK}** -- {TASK_DESCRIPTION}
>
> Planning this now. If this isn't the task you want, `/exit` and edit the slice-plan to reorder.

### Step 4: Ask file list

Use AskUserQuestion (open-ended):

> Which files does {NEXT_TASK} touch? List exact paths with action:
>
> - Create: `path/to/new-file.ext`
> - Modify: `path/to/existing.ext` (line range if specific, e.g. `:123-145`)
> - Delete: `path/to/obsolete.ext`
>
> Rule: >5 files touched is a code smell. Consider splitting the task.

Remember as `_FILE_LIST`.

### Step 5: Ask task body

Use AskUserQuestion (open-ended):

> Describe what the code in this task does. Prose is fine -- pseudocode is better. For UI: what interaction and what outcome. For backend: what request/response. For infra: what resource + what state.
>
> Not "implement signup" -- but "signup form POSTs to /api/signup with JSON body {email, password}. Server validates email regex, hashes password with argon2, inserts row into users table, returns 201 + session cookie. Failure cases: duplicate email → 409, invalid regex → 400."

Remember as `_TASK_BODY`.

### Step 6: Ask verification

Use AskUserQuestion (open-ended):

> How do we verify this task is done? 1-2 commands max. Real commands you could run now.
>
> Good: `bun test test/auth/signup.test.ts` or `curl -X POST localhost:3000/api/signup -d '{"email":"a@b.c","password":"test1234"}'`
>
> Bad: "manual test" or "check it works" -- those aren't falsifiable.

Remember as `_VERIFICATION`.

### Step 7: Fits-one-context-window check

Use AskUserQuestion (multi-choice):

> Sanity check: does this task fit one context window? Look at your answers to Steps 4-6.
>
> RECOMMENDATION: A. If you needed to talk yourself into "yes, it fits", it probably doesn't -- split.
>
> A) Yes, fits comfortably. (Completeness: 10/10)
> B) Maybe -- borderline, might overflow. (Completeness: 6/10, risk: high)
> C) No -- I should split this task first.

If C: emit "Splitting needed. Run `/exit`, edit the slice-plan to replace this task with two tasks, then re-run `/ytstack:plan-task`." STOP.

If B: ask user to confirm before proceeding (don't silently overlook the risk).

If A: proceed.

### Step 8: Write `M###-S##-T##-PLAN.md`

```markdown
---
milestone: {CURRENT_MILESTONE}
slice: {ACTIVE_SLICE}
task: {NEXT_TASK}
project: {PROJECT_NAME}
created: {ISO_TIMESTAMP}
status: planned
---

# {CURRENT_MILESTONE}-{ACTIVE_SLICE}-{NEXT_TASK} -- Task Plan

**Summary:** {TASK_DESCRIPTION}

## Files

{FILE_LIST}

## What this does

{TASK_BODY}

## Verification

```bash
{VERIFICATION}
```

Success: command exits 0 and shows expected output. Failure: re-read plan, check if spec drifted.

## Done signal

Run `/ytstack:summarize-task` after execution to mark complete and advance STATE.md.
```

### Step 9: Update STATE.md

Use Edit tool. If `YTSTACK_NON_INTERACTIVE` is `false` (i.e. `CLAUDE_AGENT_TEAM_MEMBER` is unset):
- Change `active_slice: <old>` → `active_slice: {ACTIVE_SLICE}`
- Change `active_task: <old>` → `active_task: {NEXT_TASK}`

If `YTSTACK_NON_INTERACTIVE` is `true` (running as swarm teammate): skip both frontmatter writes. Log:
> `[ytstack:plan-task] skipping STATE.md active_slice/active_task write -- running as swarm teammate (CLAUDE_AGENT_TEAM_MEMBER set)`

Bump `last_updated` regardless.

Update Status line: `**Status:** {CURRENT_MILESTONE} / {ACTIVE_SLICE} / {NEXT_TASK} planned -- ready to execute.`

**Milestone state (M018):** if `{CURRENT_MILESTONE}-ROADMAP.md` still says `status: planned`, flip it to `status: in-progress` (Edit) and mirror the global `ROADMAP.md` row -- the first planned task is where work starts. States are the enum in `docs/ux/skill-structure.md` ("Artifact states").

### Step 10: Report + return

Report:

> Task **{CURRENT_MILESTONE}-{ACTIVE_SLICE}-{NEXT_TASK}** planned.
>
> File: `{SLICE_PLAN_DIR}/{CURRENT_MILESTONE}-{ACTIVE_SLICE}-{NEXT_TASK}-PLAN.md`
>
> STATE.md: `active_slice = {ACTIVE_SLICE}`, `active_task = {NEXT_TASK}`.
> (Skipped if running as swarm teammate.)
>
> Next: execute the task (manually, or dispatch to a subagent, or wait for `ytstack:spawn-milestone-team` M006). When the code is done and verification passes, run `/ytstack:summarize-task`.

## Terminal State

Valid terminal states:
- Return after writing task-plan file + updating STATE.md
- Abort if gates fail (HAS_YTSTACK / CURRENT_MILESTONE / ACTIVE_SLICE / NEXT_TASK unresolved)
- Abort if user picks C in Step 7 (task too big, split needed)

Do NOT invoke `ytstack:summarize-task` automatically -- the user / subagent must execute the task first. Do NOT start writing code from within this skill -- that's the execution phase, a separate concern.

**Autonomy (M018):** with `AUTONOMY: loop` (PREFERENCES default) continue now with the execution of the planned task (`ytstack:test-driven-development`, then `ytstack:verification-before-completion`, then `ytstack:summarize-task`) without asking; stop at the slice boundary (`ytstack:reassess-roadmap`) and at any HARD-GATE. With `AUTONOMY: step` return control after this report. This is the one sanctioned exception to "never auto-chain", scoped to steps inside a slice.

**Granularity (M018):** with `GRANULARITY: slice` the unit planned here is the whole slice: append `## Files`, `## What this does`, `## Verification` to `M###-S##-PLAN.md` instead of writing a `T##-PLAN.md`, set `active_task: all`, and skip Step 7. With `GRANULARITY: milestone` do the same at `M###-ROADMAP.md` level with `active_slice: all`, `active_task: all`.

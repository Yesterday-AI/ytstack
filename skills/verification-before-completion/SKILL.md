---
name: verification-before-completion
metadata:
  tier: core
  version: 0.1.0
description: "Evidence before any done claim, through the vendored superpowers verification-before-completion procedure with the current task's verification command injected. Use before a commit, before a PR, before summarize-task, before telling the user that something works. Not a substitute for test-first work during implementation (test-driven-development)."
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# ytstack:verification-before-completion

Thin wrapper around the vendored superpowers `verification-before-completion` skill (`vendor/superpowers/skills/verification-before-completion/SKILL.md`). Injects the current task's verification command extracted from the task-plan, then inlines the vendored procedure verbatim. Vendor is single source of truth.

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
_M=none; _S=none; _T=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _S=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
  _T=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi
_TASK_PLAN="$_YT_DIR/$_M-$_S-$_T-PLAN.md"
_FENCE=$(printf '\140\140\140')
_VERIFICATION=""
if [ -f "$_TASK_PLAN" ]; then
  _VERIFICATION=$(awk -v f="$_FENCE" '
    /^## Verification/{in_section=1; next}
    /^## /{in_section=0}
    in_section && index($0,f)==1 { in_fence=!in_fence; next }
    in_section && in_fence { print }
  ' "$_TASK_PLAN" | head -5)
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "ACTIVE_TASK: $_M-$_S-$_T"
echo "TASK_PLAN: $_TASK_PLAN"
echo "TASK_PLAN_EXISTS: $([ -f "$_TASK_PLAN" ] && echo yes || echo no)"
echo "VERIFICATION_CMD_FOUND: $([ -n "$_VERIFICATION" ] && echo yes || echo no)"
if [ -n "$_VERIFICATION" ]; then echo "VERIFICATION_CMD:"; echo "$_VERIFICATION"; fi
```

## ytstack invocation notes

The command(s) printed above are the current task's verification commands, extracted from the `## Verification` section of the task-plan. These are what the vendored procedure must actually execute and confirm output of; do not substitute a different "looks like it should work" command.

HARD-GATE: if `TASK_PLAN_EXISTS=no` or `VERIFICATION_CMD_FOUND=no`, abort with: "No verification command in the active task-plan. Either run `ytstack:plan-task` to add one, or invoke this skill outside a ytstack task context where the user will provide the command." Do not invoke the vendored procedure without a command to verify.

After the vendored procedure completes:
- If verification passed: the user may now run `ytstack:summarize-task`.
- If verification failed: do NOT auto-retry. Report raw output and hand control back. The user decides next step (fix-and-retry vs re-scope the task).

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/verification-before-completion/SKILL.md"
```

## Namespace note (ytstack)

The text above is upstream superpowers content (v7.0.2) rendered inside ytstack. Read `superpowers:<skill>` as `ytstack:<skill>` and invoke the ytstack-namespaced skill via the Skill tool. Relative links resolve under `vendor/superpowers/skills/verification-before-completion/` in the ytstack plugin directory (`${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/verification-before-completion/`); read them from there when you need them.

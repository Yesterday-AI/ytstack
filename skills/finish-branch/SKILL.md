---
name: finish-branch
metadata:
  tier: task
  version: 0.1.0
description: "Decides how a finished branch or worktree is integrated (merge locally, push + PR, keep) through the vendored superpowers finishing-a-development-branch procedure, with ytstack's branch, worktree and task-summary state injected. Use when the slice or milestone work on a branch is done and verified, or when the user says finish the branch, merge this, open the PR, wrap up the worktree. Not before verification-before-completion passed and not for closing a task (summarize-task)."
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# ytstack:finish-branch

Thin wrapper around the vendored superpowers `finishing-a-development-branch` skill (`vendor/superpowers/skills/finishing-a-development-branch/SKILL.md`). Injects the branch, worktree flag and the slice's summary state, inlines the vendored procedure verbatim, and adds the ytstack rule that `.ytstack` artifacts are never deleted by the cleanup.

## ytstack context (resolved at render time)

```!
# ytstack resolver (M016): checkout = where this shell runs, via the shared lib.
_LIB="${CLAUDE_SKILL_DIR}/../../hooks/lib/git-ctx.sh"
if [ -f "$_LIB" ]; then
  . "$_LIB"; yt_git_ctx "$PWD"; yt_resolve_yt_dir >/dev/null
  _PROJECT_DIR="$YT_TOPLEVEL"; _YT_DIR="$YT_DIR"; _YT_SCOPE="$YT_SCOPE"; _IS_GIT="$YT_IS_GIT"; _PROJECT_KEY="$YT_REPO_KEY"; _IS_LINKED="$YT_IS_LINKED"
else
  # Host did not substitute CLAUDE_SKILL_DIR (e.g. Codex adapter): project scope only.
  _IS_GIT=$([ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] && echo yes || echo no)
  _PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
  _YT_DIR=""; _YT_SCOPE=none; _PROJECT_KEY=""; _IS_LINKED=no
  [ -d "$_PROJECT_DIR/.ytstack" ] && { _YT_DIR="$_PROJECT_DIR/.ytstack"; _YT_SCOPE=project; }
fi
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$_PROJECT_DIR")
_BRANCH=$(git branch --show-current 2>/dev/null || echo unknown)
_M=none; _S=none; _T=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _S=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
  _T=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi
# Slice summary state: every task in the slice plan needs a non-draft summary before a branch is "done".
_OPEN_TASKS=""; _DRAFT_SUMMARIES=0
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/$_M-$_S-PLAN.md" ]; then
  for t in $(grep -oE '^- \[.\] T[0-9][0-9] --' "$_YT_DIR/$_M-$_S-PLAN.md" | grep -oE 'T[0-9][0-9]'); do
    f="$_YT_DIR/$_M-$_S-$t-SUMMARY.md"
    if [ ! -f "$f" ]; then _OPEN_TASKS="$_OPEN_TASKS $t"
    elif grep -q '^closed: draft' "$f"; then _OPEN_TASKS="$_OPEN_TASKS $t"; _DRAFT_SUMMARIES=$((_DRAFT_SUMMARIES+1)); fi
  done
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "IS_GIT: $_IS_GIT"
echo "IS_LINKED_WORKTREE: $_IS_LINKED"
echo "BRANCH: $_BRANCH"
echo "ACTIVE: $_M-$_S-$_T"
echo "OPEN_TASKS: ${_OPEN_TASKS:-none}"
echo "DRAFT_SUMMARIES: $_DRAFT_SUMMARIES"
```

## ytstack invocation notes

You are invoked inside a ytstack project at the end of a branch's work. `OPEN_TASKS` lists tasks of the active slice without a real summary (missing or still `closed: draft`); `IS_LINKED_WORKTREE` says whether this checkout is a linked worktree (the vendored Step 2 detects the same thing from git; both must agree).

HARD-GATE: if `IS_GIT=no`, abort with "not a git checkout". If `OPEN_TASKS` is not `none`, stop before the vendored menu and say which tasks still need `ytstack:summarize-task` (a draft stub is not a summary). The integration menu comes after the slice is closed on paper, not just in code.

ytstack rules that override nothing in the vendored text but add to it:

- The vendored Step 1 test run is the project's full suite; if the active task plan names a verification command, run that too.
- Cleanup (vendored Step 6) never touches `.ytstack/`: if the worktree holds uncommitted `.ytstack` files, option 1 ("commit them") is the only ytstack-sanctioned choice; leftovers are for `ytstack:reconcile`, never for deletion here.
- The vendored "discard" path is out of scope for ytstack projects unless the user types `discard`; never offer it.
- After option 1 or 2, suggest `ytstack:reassess-roadmap` when the slice is complete, `ytstack:retro` when the milestone is complete, `ytstack:ship` when the user wants the release flow.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/finishing-a-development-branch/SKILL.md"
```

## Namespace note (ytstack)

The text above is upstream superpowers content (v7.0.2) rendered inside ytstack. Read `superpowers:<skill>` as `ytstack:<skill>` and invoke the ytstack-namespaced skill via the Skill tool. Relative links resolve under `vendor/superpowers/skills/finishing-a-development-branch/` in the ytstack plugin directory (`${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/finishing-a-development-branch/`). "Superpowers created this worktree" (vendored Step 6) also covers worktrees created by `ytstack:spawn-milestone-team` under `.claude/worktrees/`; the refusal rule (never `--force`) applies unchanged.

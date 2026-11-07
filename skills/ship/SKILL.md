---
name: ship
metadata:
  tier: task
  version: 0.1.0
description: "Ships the current branch through the installed gstack ship skill (tests, review, commit, push, pull request), gated on ytstack's slice state. Use when a slice or milestone is closed on paper and verified, or when the user says ship it, open the PR, land this. Not before every task of the slice has a summary (summarize-task), not for merging into the base locally (finish-branch), and never for a merge without an explicit merge instruction."
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# ytstack:ship

Thin wrapper around the **installed** gstack `ship` skill (`~/.claude/skills/gstack/ship`, ytstack tested against v1.96.0.0). Checks the install and the slice's paper state, then invokes the gstack skill through the Skill tool. gstack is the single source of truth for the shipping procedure; ytstack owns only the precheck and the gate.

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
# gstack precheck (M017): installed dependency, not vendored
if command -v yt_gstack_ctx >/dev/null 2>&1; then
  yt_gstack_ctx >/dev/null
  echo "GSTACK_AVAILABLE: $YT_GSTACK_AVAILABLE"; echo "GSTACK_DIR: $YT_GSTACK_DIR"; echo "GSTACK_VERSION: ${YT_GSTACK_VERSION:-none}"
  echo "GSTACK_PIN_OK: $YT_GSTACK_PIN_OK (pin v$YT_GSTACK_PIN)"; echo "GSTACK_SKILL_OK: $(yt_gstack_skill_ok ship)"
  echo "BUN_OK: $YT_BUN_OK (${YT_BUN_VERSION:-none})"; echo "GSTACK_INSTALL_CMD: $YT_GSTACK_INSTALL_CMD"
else
  echo "GSTACK_AVAILABLE: unknown (shared lib not loaded)"
fi
_BRANCH=$(git branch --show-current 2>/dev/null || echo unknown)
_M=none; _S=none; _OPEN_TASKS=""
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _S=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
  if [ -f "$_YT_DIR/$_M-$_S-PLAN.md" ]; then
    for t in $(grep -oE '^- \[.\] T[0-9][0-9] --' "$_YT_DIR/$_M-$_S-PLAN.md" | grep -oE 'T[0-9][0-9]'); do
      f="$_YT_DIR/$_M-$_S-$t-SUMMARY.md"
      { [ ! -f "$f" ] || grep -q '^closed: draft' "$f"; } && _OPEN_TASKS="$_OPEN_TASKS $t"
    done
  fi
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "IS_GIT: $_IS_GIT"
echo "BRANCH: $_BRANCH"
echo "ACTIVE_SLICE: $_M-$_S"
echo "OPEN_TASKS: ${_OPEN_TASKS:-none}"
echo "DIRTY: $([ -n "$(git status --porcelain 2>/dev/null)" ] && echo yes || echo no)"
```

## ytstack invocation notes

ship is the release flow for a branch whose ytstack bookkeeping is complete. The installed gstack `ship` skill runs the tests, review, commit, push and pull request; ytstack adds the paper gate and the PR body material (the slice's summaries).

HARD-GATE: `IS_GIT=no`: stop. `OPEN_TASKS` not `none`: stop and name the tasks that still need `ytstack:summarize-task`; a draft stub is not a summary. The gstack skill decides about dirty trees itself; tell it which `.ytstack` files are part of the change.

When gstack asks for the PR description, give it the slice goal (`M###-S##-PLAN.md`) and each task's Outcome paragraph. gstack never merges on ytstack's behalf: a merge needs the user's explicit instruction, and `ytstack:finish-branch` is the local-merge path.

## Terminal State

Report the PR URL (or the push result) and suggest `ytstack:reassess-roadmap` when the slice is complete, `ytstack:retro` when the milestone is complete, `ytstack:document-release` when a version is to be cut. Do NOT auto-invoke any downstream skill.

## HARD-GATE: gstack installed?

This wrapper runs the gstack `ship` skill that is **installed** on this machine (`GSTACK_DIR` above; ytstack is tested against gstack v1.96.0.0, bun >= 1.4.2). gstack is not vendored (DECISIONS 2026-11-07 "Vendor strategy").

- If `GSTACK_AVAILABLE` is `no` (or `unknown`) or `GSTACK_SKILL_OK` is `no`: stop. Tell the user that `ytstack:ship` needs gstack and print the one-line install command from `GSTACK_INSTALL_CMD`. Do not improvise a shipping procedure; `ytstack:finish-branch` is the dependency-free alternative.
- If `GSTACK_PIN_OK` is `no`: continue, but say once that the installed gstack (`GSTACK_VERSION`) is older than the version ytstack was tested with.
- If `BUN_OK` is `no`: continue, but warn that gstack's helpers need bun >= 1.4.2 and may fail.

## Procedure

1. Invoke the Skill tool with `ship` (the installed gstack skill, not `ytstack:ship`). Follow it to completion.
2. Apply the ytstack notes above (PR body from the slice summaries; no merge without instruction).
3. Report per the Terminal State. Do NOT auto-invoke any downstream skill.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- resolver + gstack precheck + open-task gate
2. **HARD-GATE** -- stop with the install command when gstack is missing; stop on open tasks
3. **Invoke installed `ship`** via the Skill tool and follow it to completion
4. **PR body** -- slice goal + task outcomes
5. **Report + return** -- PR URL + next-step suggestion, no auto-chaining

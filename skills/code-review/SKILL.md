---
name: code-review
metadata:
  tier: task
  version: 0.2.0
description: "Reviews the active task's commits with a fresh-context reviewer subagent and handles the feedback with technical rigor, through the vendored superpowers requesting-code-review and receiving-code-review procedures, with the task plan and commit range injected. Use after a task's commits exist and before summarize-task, before a merge or PR, or when the user says review this, code review, check my changes. Not for reviewing a plan (plan-eng-review) and not without commits for the task."
allowed-tools:
  - Bash
  - Read
  - Edit
  - Agent
  - AskUserQuestion
---

# ytstack:code-review

Thin wrapper around two vendored superpowers skills: `requesting-code-review` (dispatch a reviewer subagent with precise context) and `receiving-code-review` (evaluate the feedback instead of performing agreement). Injects the active task's plan and commit range, inlines both vendored procedures verbatim, and routes the findings into ytstack artifacts.

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
# Commits of the active task (same discovery as summarize-task: task-ref pattern, branch fallback).
_COMMITS=""; _COMMITS_SOURCE=none; _BASE_SHA=""; _HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo none)
if [ "$_IS_GIT" = yes ] && [ "$_T" != none ] && command -v yt_task_commits >/dev/null 2>&1; then
  _PAT=$(yt_commit_ref_pattern "$_YT_DIR" "$_M" "$_S" "$_T")
  yt_task_commits "$_PROJECT_DIR" "$_PAT"
  _COMMITS="$YT_COMMITS"; _COMMITS_SOURCE="$YT_COMMITS_SOURCE"
  if [ "$_COMMITS_SOURCE" = task-ref ]; then
    _OLDEST=$(git log --no-merges -E --grep "$_PAT" --pretty=format:%h 2>/dev/null | tail -1)
    [ -n "$_OLDEST" ] && _BASE_SHA=$(git rev-parse "$_OLDEST^" 2>/dev/null || echo "")
  elif [ -n "$YT_COMMITS_BASE" ]; then
    _BASE_SHA="$YT_COMMITS_BASE"
  fi
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "IS_GIT: $_IS_GIT"
echo "ACTIVE_TASK: $_M-$_S-$_T"
echo "TASK_PLAN: $_TASK_PLAN"
echo "TASK_PLAN_EXISTS: $([ -f "$_TASK_PLAN" ] && echo yes || echo no)"
echo "COMMITS_SOURCE: $_COMMITS_SOURCE"
echo "BASE_SHA: ${_BASE_SHA:-none}"
echo "HEAD_SHA: $_HEAD_SHA"
echo "COMMITS_BEGIN"
echo "${_COMMITS:-(none)}"
echo "COMMITS_END"
# Technical spec (M022): the area files that cover what the task changed.
_SPEC_EXISTS=$([ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/spec/SPEC.md" ] && echo yes || echo no)
_SPEC_TOOL="${CLAUDE_SKILL_DIR}/../../bin/ytstack-spec"
echo "SPEC_EXISTS: $_SPEC_EXISTS"
echo "SPEC_AREAS_BEGIN"
if [ "$_SPEC_EXISTS" = yes ] && [ -f "$_SPEC_TOOL" ] && [ -n "$_BASE_SHA" ]; then
  # shortcut: paths are split on whitespace; a path with a space finds no area.
  # shellcheck disable=SC2046
  bash "$_SPEC_TOOL" areas --names $(git diff --name-only "$_BASE_SHA..HEAD" 2>/dev/null | head -200) 2>/dev/null \
    | sed "s|^|.ytstack/spec/|; s|\$|.md|"
fi
echo "SPEC_AREAS_END"
```

## ytstack invocation notes

You are invoked inside a ytstack project after the active task's commits exist. The vendored `requesting-code-review` template needs `{DESCRIPTION}`, `{PLAN_OR_REQUIREMENTS}`, `{BASE_SHA}`, `{HEAD_SHA}`: take the description from the task plan's Summary, the requirements from `TASK_PLAN` (What this does + Verification), and the SHAs from `BASE_SHA` / `HEAD_SHA` above (never guess `HEAD~1`).

HARD-GATE: if `IS_GIT=no`, abort. If `ACTIVE_TASK` has `none` in it or `TASK_PLAN_EXISTS=no`, abort with "no active task plan; run `ytstack:plan-task` or review a plain diff without ytstack". If `COMMITS_SOURCE=none` or `BASE_SHA=none`, abort with "no commits found for the task; commit with the `M###-S##-T##:` prefix (or set `commit_ref_pattern` in PREFERENCES) and re-run".

**Spec check, bounded to the touched area.** When `SPEC_EXISTS=yes`, add to the reviewer's requirements the plan's `## Spec impact` section and the paths listed under `SPEC_AREAS` (the area files of `.ytstack/spec/` that cover the changed files). The reviewer reads those area files, and the section of a `sources` document they point to, against the diff. Two things are findings: the diff changes behaviour, an interface, an invariant or an error path that an area file describes while the plan says `none`; or an area file (or its source) now states something the diff contradicts. A change that restores the described behaviour needs no spec edit and is not a finding. The reviewer does not audit the rest of the spec, other areas or the repository's documentation.

After the reviewer subagent returns, the vendored `receiving-code-review` procedure applies to its findings. ytstack additions:

- Critical and Important findings fixed now get their own task-ref commits; Minor findings and "push-backs with reasoning" go into the task summary's Follow-ups (`ytstack:summarize-task` reads them from the conversation).
- A finding that reveals a repo-wide pattern goes to `KNOWLEDGE.md`; a reversal of an earlier choice goes to `DECISIONS.md`, never silently, and the area file it concerns lists the new entry under "Decisions that apply now" instead of the old one.
- Do NOT run `ytstack:summarize-task` or `ytstack:verification-before-completion` automatically; name them as the next step.

## Vendored procedure 1: requesting (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/requesting-code-review/SKILL.md"
```

## Vendored procedure 2: receiving (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/receiving-code-review/SKILL.md"
```

## Namespace note (ytstack)

The text above is upstream superpowers content (v7.0.2) rendered inside ytstack. Read `superpowers:<skill>` as `ytstack:<skill>` and invoke the ytstack-namespaced skill via the Skill tool. Relative links such as `code-reviewer.md` (the reviewer prompt template) resolve under `vendor/superpowers/skills/requesting-code-review/` in the ytstack plugin directory (`${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/requesting-code-review/`); read the template from there and fill it with the values from the ytstack context block. "Subagent-driven development" in the vendored text corresponds to `ytstack:spawn-milestone-team`'s worktree subagents.

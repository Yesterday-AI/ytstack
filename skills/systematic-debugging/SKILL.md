---
name: systematic-debugging
description: "Root-cause debugging in four phases: investigate, analyze, hypothesize, implement. Iron Law -- no fixes without root cause. Thin ytstack wrapper around the vendored superpowers systematic-debugging procedure, routing findings into KNOWLEDGE.md / DECISIONS.md. Use when hitting a bug, test failure, or unexpected behavior."
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - AskUserQuestion
---

# ytstack:systematic-debugging

Thin wrapper around the vendored superpowers `systematic-debugging` skill (`vendor/superpowers/skills/systematic-debugging/SKILL.md`). Injects ytstack project context, then inlines the vendored procedure verbatim. Findings are routed into ytstack artifacts. Vendor is single source of truth.

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
_M=none; _T=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _T=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "YT_DIR: $_YT_DIR"
echo "CURRENT_MILESTONE: $_M"
echo "ACTIVE_TASK: $_T"
```

## ytstack invocation notes

You are invoked inside a ytstack project (or without -- systematic-debugging is useful outside ytstack too). The Iron Law from the vendored skill holds: no fixes until root cause is identified.

HARD-GATE: none. Debugging may happen before ytstack is initialized.

After the vendored procedure completes:
- If `HAS_YTSTACK=yes` and the root cause reveals a project-level pattern (e.g. "config race between env-vars and config.json reads that will recur elsewhere"), append to `KNOWLEDGE.md` under `## Gotchas` or `## Lessons learned`.
- If the root cause forces an architectural decision (e.g. "we must enforce X pattern across all future modules"), append to `DECISIONS.md` in append-only format.
- If the root cause relates to an active task, reference it in the task-plan body so future sessions see the context.

## Vendored procedure (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/systematic-debugging/SKILL.md"
```

## Namespace note (ytstack)

The text above is upstream superpowers content (v7.0.2) rendered inside ytstack. Read `superpowers:<skill>` as `ytstack:<skill>` (`superpowers:verification-before-completion` is `ytstack:verification-before-completion`, `superpowers:test-driven-development` is `ytstack:test-driven-development`) and invoke the ytstack-namespaced skill via the Skill tool. Relative links resolve under `vendor/superpowers/skills/systematic-debugging/` in the ytstack plugin directory (`${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/systematic-debugging/`); read them from there when you need them.

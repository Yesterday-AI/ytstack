---
name: resume-session
description: "Reconstruct working context at the start of a new session. Reads STATE.md + HANDOFF.md (if present) + latest 3 T##-SUMMARY.md files and synthesizes a 'where we are' briefing. Run at session start before doing anything else."
metadata:
  tier: core
  version: 0.1.0
  triggers:
    - resume session
    - where were we
    - pick up where I left off
    - ytstack resume
allowed-tools:
  - Bash
  - Read
---

# resume-session

Quick-orient at session start. Reads the on-disk state and produces a 3-paragraph briefing the user can scan in 10 seconds. Complements the SessionStart hook (which auto-injects on every session start) by giving the user an on-demand, richer version.

## Anti-Pattern: "I'll just read the files myself"

You'll read STATE.md and think you have the picture, missing HANDOFF.md's in-flight note, the most recent task summary, or the REVIEW-NOTES item that's about to bite. This skill composes all of them. Takes 5 seconds. Run it every session start.

## Checklist

1. **Run preamble** -- detect state + gather file inventory
2. **HARD-GATE** -- ytstack initialized
3. **Synthesize briefing** -- 3 paragraphs: where, in-flight, next
4. **Report** -- done

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

_STATE_FILE="$_YT_DIR/STATE.md"
_HANDOFF_FILE="$_YT_DIR/HANDOFF.md"
_HAS_HANDOFF=$([ -f "$_HANDOFF_FILE" ] && echo yes || echo no)
_MANUAL_HANDOFF_EVENT=none; _MANUAL_HANDOFF_TS=none
if [ "$_HAS_HANDOFF" = yes ]; then
  _MANUAL_HANDOFF_EVENT=$(sed -n 's/^event: *//p' "$_HANDOFF_FILE" | head -1)
  _MANUAL_HANDOFF_TS=$(sed -n 's/^timestamp: *//p' "$_HANDOFF_FILE" | head -1)
fi
# Automatic handoff (written out of tree by the pre-compact hook, per worktree; M016)
_LATEST_AUTO_HANDOFF=none; _AUTO_HANDOFF_TS=none
if command -v yt_state_base >/dev/null 2>&1 && [ -n "${YT_REPO_KEY:-}" ]; then
  _LATEST_LINK="$(yt_state_base)/repos/$YT_REPO_KEY/worktrees/$YT_WT_KEY/latest-handoff"
  if [ -L "$_LATEST_LINK" ] && [ -f "$_LATEST_LINK" ]; then
    _LATEST_AUTO_HANDOFF=$(readlink "$_LATEST_LINK")
    _AUTO_HANDOFF_TS=$(sed -n 's/^timestamp: *//p' "$_LATEST_AUTO_HANDOFF" 2>/dev/null | head -1)
  fi
fi

# Last 3 summaries by mtime
_RECENT_SUMMARIES=""
if compgen -G "$_YT_DIR"/*-SUMMARY.md > /dev/null 2>&1; then
  if command -v yt_find_artifacts >/dev/null 2>&1; then
    _RECENT_SUMMARIES=$(yt_find_artifacts "$_YT_DIR" '*-SUMMARY.md' | head -3)   # flat + milestones/ + quick/ (M018-S03)
  else
    _RECENT_SUMMARIES=$(ls -t "$_YT_DIR"/*-SUMMARY.md 2>/dev/null | head -3)
  fi
fi

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "STATE_FILE: $_STATE_FILE"
echo "HAS_HANDOFF: $_HAS_HANDOFF"
echo "MANUAL_HANDOFF_EVENT: ${_MANUAL_HANDOFF_EVENT:-none}"
echo "MANUAL_HANDOFF_TS: ${_MANUAL_HANDOFF_TS:-none}"
# STATE pointer lint (M018)
_STATE_LINT=0; _STATE_LINT_LINES=""
if command -v yt_state_lint >/dev/null 2>&1 && [ -n "$_YT_DIR" ]; then
  yt_state_lint "$_YT_DIR" >/dev/null; _STATE_LINT="$YT_STATE_WARN_COUNT"; _STATE_LINT_LINES="$YT_STATE_WARNINGS"
fi
echo "STATE_LINT: $_STATE_LINT"
[ -n "$_STATE_LINT_LINES" ] && printf '%s\n' "$_STATE_LINT_LINES" | sed 's/^/STATE_LINT_LINE: /'
echo "LATEST_AUTO_HANDOFF: $_LATEST_AUTO_HANDOFF"
echo "AUTO_HANDOFF_TS: ${_AUTO_HANDOFF_TS:-none}"
echo "RECENT_SUMMARIES_COUNT: $(echo "$_RECENT_SUMMARIES" | grep -c .)"
```

## Procedure

**Step 2 HARD-GATE.** If `HAS_YTSTACK=no`:
> "ytstack isn't initialized in this project. If you expected state here, check the path. Otherwise run `/ytstack:init-project`."
STOP.

**Step 3 -- Read handoffs, then synthesize.** Read each of:
- `STATE.md` (frontmatter + Status + Next action sections)
- The automatic handoff at `LATEST_AUTO_HANDOFF` if not `none` -- the freshest breadcrumb of *this* worktree, written out of tree by the pre-compact hook (position, Next action excerpt, reading list)
- `HANDOFF.md` if present (`MANUAL_HANDOFF_EVENT` / `MANUAL_HANDOFF_TS`; In-flight, Next action, Open decisions, Warnings). When the manual handoff is newer than the automatic one, lean on the manual one; it was written on purpose.
- Each file in `_RECENT_SUMMARIES` (Outcome first lines)

Open the briefing with one line that names the sources: `Handoffs: automatic {AUTO_HANDOFF_TS} ({LATEST_AUTO_HANDOFF}) / manual {MANUAL_HANDOFF_EVENT} {MANUAL_HANDOFF_TS}` (or `none` for either).

Produce a three-paragraph briefing:

**Paragraph 1 -- Where we are:** project name, milestone/slice/task position, branch, last-updated timestamp. Include scope (project vs user) if relevant. When `STATE_LINT` is not 0, name the `STATE_LINT_LINE`s here and say that `plan-task` / `summarize-task` will refuse a malformed pointer until STATE.md is fixed (or `ytstack:reconcile` has run).

**Paragraph 2 -- Most recent work:** Summarize the 3 latest task summaries in one or two sentences each. Focus on *outcomes*, not process. If no summaries, note "no tasks closed yet in this project."

**Paragraph 3 -- Next:** The STATE.md's Next action, enriched with HANDOFF.md's In-flight / Open decisions / Warnings if they exist and are non-empty. End with a concrete first suggested action.

**Formatting:**

```
=== ytstack resume briefing ===

**Where:** {one paragraph}

**Recent:** {one paragraph}

**Next:** {one paragraph}

---
Files read: STATE.md{, HANDOFF.md if present, <N> summary files}
To go deeper: read ROADMAP.md for the big picture, DECISIONS.md for locked choices, REVIEW-NOTES.md for deferred items.
```

**Step 4 -- Report.** Emit the briefing above. No further action -- return control so the user decides what to do next.

## Terminal State

Return after emitting the briefing. Do NOT invoke any other skill. The user (or the next-action-decider) takes over from here.

## Why this exists alongside the SessionStart hook

The SessionStart hook fires automatically on every session start and injects a compressed state summary via `additionalContext`. That's lightweight and always-on.

This skill is the **deep-dive**. When the user explicitly asks "where were we", they want the richer version: HANDOFF.md context, full recent-summary outcomes, open-decision highlights. The hook can't prompt -- this skill can. Use both.

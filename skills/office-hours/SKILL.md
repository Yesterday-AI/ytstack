---
name: office-hours
description: "YC Office Hours -- six forcing questions that expose demand reality, status quo, desperate specificity, narrowest wedge, observation, and future-fit. Use before planning a milestone for a new product / feature / initiative, when you're not sure whether it's worth building. Wrapper around vendored gstack office-hours skill."
tier: task
version: 0.1.0
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
triggers:
  - office hours
  - is this worth building
  - brainstorm this
  - ytstack office hours
---

# office-hours

Run the YC-style six-forcing-question diagnostic on a proposed idea, feature, or milestone scope. Produces a design doc that captures the answers and exposes gaps. Wrapper around vendored gstack office-hours; adds ytstack context-awareness and integration with the milestone-planning flow.

## When to run

- **Before** `ytstack:plan-milestone` if you're unsure whether the milestone is worth building
- When a milestone has shaky premises ("users might want this")
- When someone asks "should we do X" and you want forcing pressure, not polite validation

## Anti-Pattern: "I already know this is worth building"

If true, office-hours takes 10 minutes and confirms it. If false, office-hours saves you a milestone of wasted work. The skill's value is in discovering which one you're in -- which is exactly the knowledge you don't have going in.

## Checklist

1. **Run preamble** -- detect state + vendored skill
2. **HARD-GATE** -- ytstack initialized, vendored skill present
3. **Clarify subject** -- what are we running office-hours ON?
4. **Invoke vendored skill** with the subject as input
5. **Save design doc** -- vendored skill writes to its preferred path; we also symlink/copy into `.ytstack/docs/`
6. **Optionally link to upcoming milestone** -- if user plans to go forward, save the design doc ref to the next milestone's CONTEXT.md
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

_VENDOR_SKILL="${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT not set}/vendor/gstack/office-hours/SKILL.md"
_VENDOR_EXISTS=$([ -f "$_VENDOR_SKILL" ] && echo yes || echo no)

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "VENDOR_SKILL: $_VENDOR_SKILL"
echo "VENDOR_EXISTS: $_VENDOR_EXISTS"
```

## Procedure

**Step 2 HARD-GATE.** Abort if `HAS_YTSTACK=no` or `VENDOR_EXISTS=no` (see `vendor/README.md` for subtree setup).

**Step 3 -- Clarify subject.** Use AskUserQuestion (open-ended):

> What are we running office-hours on?
>
> Pick one:
> - A specific feature idea ("add SSO login")
> - A whole milestone ("the compliance quarter")
> - A product direction ("is the SMB market worth pivoting to?")
> - A technical bet ("should we rewrite the pipeline in Rust?")

Remember as `_SUBJECT`.

**Step 4 -- Invoke vendored.** Read `{VENDOR_SKILL}` in full. Follow its procedure, treating `{SUBJECT}` as the thing being diagnosed. The gstack office-hours skill uses six forcing questions (demand reality, status quo, desperate specificity, narrowest wedge, observation, future-fit); let its logic run end-to-end.

**Step 5 -- Save design doc.** The vendored skill writes a design doc as its output. Capture the path it used (usually under project root or `~/.gstack/projects/`). After completion, copy or symlink into ytstack:

- Target: `{YT_DIR}/docs/office-hours/{ISO_DATE}-{SUBJECT_SLUG}.md`
- Method: `cp <vendor-output-path> <ytstack-target>` (not symlink -- we want a durable copy that survives vendor re-clones)

If the vendored skill didn't write a file (some modes don't), synthesize one yourself from the AskUserQuestion answers: title, one paragraph per question + answer, final recommendation.

**Step 6 -- Optional milestone linkage.** Use AskUserQuestion:

> Office-hours complete. Do you plan to move forward with this (ie. spin up a milestone)?
>
> A) Yes -- reference this design in the next milestone's CONTEXT.md when I run `plan-milestone` (Completeness: 10/10)
> B) No -- shelved for now, the design doc lives at `{TARGET_PATH}` for future reference (Completeness: 10/10)
> C) Maybe -- need to think about it (Completeness: 10/10 -- park it honestly)

If A: note to user that when they next run `plan-milestone`, they should reference `{TARGET_PATH}` in the goal or context. (We don't auto-invoke plan-milestone.)

**Step 7 -- Report + return.**

> Office-hours run on **{SUBJECT}**. Design doc: `{TARGET_PATH}`.
>
> Outcome: {outcome-summary from vendored skill}.
>
> Recommendation: {A/B/C from Step 6}.
>
> Next step:
> - A → run `/ytstack:plan-milestone`, reference the design doc in the Goal
> - B → doc is committed, revisit whenever
> - C → revisit; can re-run office-hours later with updated thinking

## Terminal State

Return after saving design doc. Do NOT invoke `plan-milestone` automatically even on option A.

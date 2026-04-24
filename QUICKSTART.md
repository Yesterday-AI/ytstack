# ytstack Quickstart

From zero to running a tracked milestone in 10 minutes.

## Install

### Local dev (recommended for first try)

```bash
claude --plugin-dir /path/to/ytstack
```

This starts a fresh Claude Code session with ytstack loaded. No marketplace registration needed.

### Via marketplace (once published, M008)

```bash
/plugin marketplace add yesterday-ai/ytstack-marketplace
/plugin install ytstack@ytstack-marketplace
```

### Headless / CI

```bash
claude --plugin-dir /path/to/ytstack --permission-mode acceptEdits -p "<prompt>"
```

The `--permission-mode acceptEdits` flag is required -- ytstack skills write `.ytstack/` artifacts and would stall on permission prompts otherwise. Non-interactive detection via `YTSTACK_NON_INTERACTIVE=1` environment variable.

## First milestone -- worked example

Imagine building a small CLI tool. Here's the end-to-end flow:

### 1. Initialize the project

```text
/ytstack:init-project
```

You'll be asked:
- Scope: **project-level** (recommended -- committed to git) vs user-level (private)
- Name: e.g. "csv-importer"
- One-liner: e.g. "CLI that imports CSV exports from accounting software into the finance database"

Result: `.ytstack/` with 6 files (PROJECT.md, DECISIONS.md, KNOWLEDGE.md, RUNTIME.md, STATE.md, PREFERENCES.md).

### 2. Plan the first milestone

```text
/ytstack:plan-milestone
```

- Goal: "Parse a CSV file and write it to the database."
- Exit criteria: "Command `csv-importer path/to/file.csv` inserts all rows into `imports` table and reports row count."
- Size: M (medium -- 2-3 slices)

Result: `.ytstack/M001-CONTEXT.md` + `.ytstack/M001-ROADMAP.md` with slice placeholders.

### 3. (Optional) CEO-review the plan

```text
/ytstack:plan-ceo-review
```

Challenges your scope, ambition, and premise. If the feature is worth expanding or narrowing, this catches it before code.

### 4. Break the milestone into slices

```text
/ytstack:slice-milestone
```

For each slice placeholder:
- Slice goal: e.g. "S01 -- Parse CSV and validate rows"
- Task list (1-7 tasks per slice): e.g.
  1. Add CLI flag parsing with `--input` and `--output`
  2. Implement CSV reader with streaming
  3. Validate rows against schema

Result: `.ytstack/M001-S01-PLAN.md`, `.ytstack/M001-S02-PLAN.md`, etc.

### 5. (Optional) Eng-review the slice-plans

```text
/ytstack:plan-eng-review
```

Locks in architecture before implementation. Catches file-overlap between slices, test gaps, performance concerns.

### 6. Execute tasks -- two options

**Option A: sequential (simple).** For each task:

```text
/ytstack:plan-task          # elaborate next task (files + body + verification)
/ytstack:test-driven-development   # implement with RED-GREEN-REFACTOR
/ytstack:verification-before-completion  # confirm it passes
/ytstack:summarize-task     # close the task, flip checkbox
```

**Option B: parallel via Agent Teams (faster, experimental).** Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and Claude Code v2.1.32+.

```text
/ytstack:spawn-milestone-team
```

Spawns teammates (one per slice + optional architect-reviewer). Each teammate works in parallel with its own 200k context. Lead coordinates.

### 7. Reassess after each slice

```text
/ytstack:reassess-roadmap
```

Checks if the remaining plan still fits reality given what was learned in the slice. A/B/C decision: proceed, patch, or major rethink.

### 8. Close the milestone

When all slices are done, update `.ytstack/ROADMAP.md` to flip the milestone to `done`. Run `/ytstack:plan-milestone` for the next.

## Reading the state

At any point:

```text
/ytstack:resume-session
```

Reads `.ytstack/STATE.md` + `.ytstack/HANDOFF.md` (if present) + latest 3 task summaries. Gives you a 3-paragraph briefing of where you are.

For a richer snapshot, read the files directly:
- `.ytstack/STATE.md` -- dashboard
- `.ytstack/ROADMAP.md` -- full milestone plan
- `.ytstack/DECISIONS.md` -- architectural decisions log
- `.ytstack/KNOWLEDGE.md` -- patterns and gotchas learned
- `.ytstack/REVIEW-NOTES.md` -- deferred items flagged for end-of-cycle review

## Handoff / resume

Before stepping away for a break:

```text
/ytstack:handoff-session
```

Writes `.ytstack/HANDOFF.md` with current position + in-flight work + open decisions + warnings. Next session reads it via `resume-session`.

The SessionStart hook also auto-injects state on every session start, so `resume-session` is for deep-dives when you want more than the hook's compact summary.

## Debugging

```text
/ytstack:systematic-debugging
```

Four-phase process: investigate → analyze → hypothesize → implement. Root cause required before any fix. Findings auto-logged to `KNOWLEDGE.md` (pattern) and `DECISIONS.md` (architectural shift).

## Common gotchas

- **`claude -p` needs `--permission-mode acceptEdits`** or skills stall on Write prompts.
- **Skill invocations are namespaced:** `/ytstack:init-project`, not `/init-project`.
- **Sentinel files accumulate in `~/.ytstack/.*-prompted`** -- don't worry about them; cleanup command ships later.
- **`.ytstack/` goes in git.** That's the default. Team members inherit project memory on clone.
- **One milestone at a time.** If you start a second before closing the first, the roadmap-tracking breaks. Close M### by flipping status in `.ytstack/ROADMAP.md`.

## More

- Full design: `.ytstack/PROJECT.md`, `.ytstack/DECISIONS.md`
- Sources consulted: `docs/references.md`
- Contributor rules: `CLAUDE.md`
- UX contracts all skills follow: `docs/ux/`

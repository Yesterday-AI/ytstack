# ytstack Quickstart

From zero to a tracked, shipped task -- the way you actually use ytstack: by talking to the agent in natural language. The agent fires skills automatically. Slash-commands are an override path, not the default.

## Install

### Local dev (recommended for first try)

```bash
claude --plugin-dir /path/to/ytstack
```

This starts a fresh Claude Code session with ytstack loaded. No marketplace registration needed.

### Via marketplace

```bash
/plugin marketplace add Yesterday-AI/ytstack
/plugin install ytstack@ytstack
```

Self-marketplaced: `.claude-plugin/marketplace.json` lives in the plugin repo itself. Private-repo auth via `gh auth login`.

### Headless / CI

```bash
claude --plugin-dir /path/to/ytstack --permission-mode acceptEdits -p "<prompt>"
```

The `--permission-mode acceptEdits` flag is required -- ytstack skills write `.ytstack/` artifacts and would stall on permission prompts otherwise. Non-interactive detection via `YTSTACK_NON_INTERACTIVE=1` environment variable.

## How it works

When Claude Code starts in a ytstack project, the `SessionStart` hook injects the `using-ytstack` directive (a compliance primer: "if any skill plausibly applies, invoke it via the `Skill` tool before responding"). After that, the agent matches your natural-language intent against each skill's `description:` field **semantically** (no phrase list, no trigger map) and fires the right one.

You almost never type `/ytstack:<name>`. The agent picks. You type slash-commands only to override, skip, or re-run a specific step.

## First milestone -- worked example

Imagine building a small CLI tool from scratch. You're in an empty project directory (no `.ytstack/` yet). Greenfield flow:

### 1. Say what you want

You type something like:

> "Build me a CLI that imports CSV exports from accounting software into a Postgres staging table."

That phrasing has no ytstack-specific keywords. The agent reads it, matches against every loaded skill's `description:`, and picks `ytstack:office-hours` (its description: "Use as the first step when a new project, feature, or initiative has not yet been validated"). You see:

```
> Skill(ytstack:office-hours)
   Successfully loaded skill · N tools allowed
```

The skill runs its six forcing questions (demand reality, status quo, desperate specificity, narrowest wedge, observation, future-fit). You answer in prose. When the pitch is complete, the skill writes `./OFFICE-HOURS.md` with structured frontmatter:

```
---
name: csv-importer
one-liner: CLI that imports CSV exports from accounting software into the finance database.
mode: builder
---

## Problem ...
## What we're building ...
(pitch body)
```

### 2. "Let's pressure-test the pitch"

You say:

> "Challenge the scope -- am I thinking big enough or too big?"

Agent matches to `ytstack:plan-ceo-review` (description: "Challenge premise, scope, and ambition... concept-mode reviews a pitch..."). It detects concept-mode automatically (milestone doesn't exist, pitch does) and runs the four-mode review (SCOPE EXPANSION / SELECTIVE / HOLD / REDUCE). Outcome: an annotation block prepended to `OFFICE-HOURS.md` with the verdict and reasoning. The original pitch is preserved below.

### 3. (Optional) "Sanity-check the approach"

Say: "Is the tech stack feasible?" -> agent fires `ytstack:plan-eng-review` in concept-mode. Also annotates the pitch. Optional; the flow can proceed without it.

### 4. "Scaffold the project"

You say:

> "OK, set it up for real."

Agent fires `ytstack:init-project` (description: "Scaffold a ytstack project's `.ytstack/` directory... Use AFTER a pitch has been validated"). You get exactly one question: scope (project-level, committed to git, vs user-level, machine-local). That's it. No "what's the project name?" or "give me a one-liner" -- those come from `OFFICE-HOURS.md` frontmatter automatically. `PROJECT.md` is pre-populated. The pitch gets moved to `.ytstack/OFFICE-HOURS-<slug>.md` as a ytstack artifact.

Result: `.ytstack/` with 6 core files + the consumed pitch.

### 5. "Plan the first milestone"

You say:

> "What ships first?"

Agent fires `ytstack:plan-milestone`. Short discuss phase: goal (one-liner outcome), exit criteria (concrete checkable signals), size (S / M / L). Both goal and exit draw heavily from the pitch. Result: `.ytstack/M001-CONTEXT.md` + `.ytstack/M001-ROADMAP.md` with slice placeholders.

### 6. "Break it into slices"

You say:

> "Break M001 into slices."

Agent fires `ytstack:slice-milestone`. For each slice, it asks the goal and 1-7 tasks. Result: `.ytstack/M001-S01-PLAN.md`, `.ytstack/M001-S02-PLAN.md`, etc.

Example S01: "Parse CSV and validate rows" with tasks [add CLI flag parsing, implement CSV reader with streaming, validate rows against schema].

### 7. (Optional) "Architecture review"

Say: "Review the slice plans for architecture." -> `ytstack:plan-eng-review` milestone-mode this time. Same skill, different review subject (slice-plans, not pitch). Catches file-overlap, test gaps, perf concerns.

### 8. Execute tasks

For each task in the active slice, the agent walks the loop. You type minimal prompts:

| You say | Agent fires | What happens |
|---|---|---|
| "Detail the next task" / "what's next" | `ytstack:plan-task` | Writes `M001-S01-T01-PLAN.md` with exact file paths + body + verification command |
| "TDD this" / (often auto-chained after plan-task) | `ytstack:test-driven-development` | RED test first, then minimal code, refactor, commit |
| (on failure) "find the root cause" / "why is X broken" | `ytstack:systematic-debugging` | 4-phase root-cause-required procedure; feeds regression test back into TDD |
| "Is it done?" / "check before commit" | `ytstack:verification-before-completion` | Runs the task-plan's verification command, confirms output |
| "Task is done" / "close this out" | `ytstack:summarize-task` | Writes `M001-S01-T01-SUMMARY.md`, flips checkbox, updates `STATE.md` |

You don't orchestrate the transitions -- the agent does, based on each skill's Terminal State pointer plus your confirmation. You confirm / correct; you don't drive.

**Parallel variant:** when a milestone has multiple slices ready, say something like "dispatch a team to work the slices in parallel" -> agent fires `ytstack:spawn-milestone-team`. Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and Claude Code v2.1.32+. Each teammate works a slice in its own fresh 200k context.

### 9. "Reassess between slices"

At the end of each slice, say: "Does the roadmap still fit reality?" -> `ytstack:reassess-roadmap` reads recent summaries, surfaces deviations, prompts for roadmap changes (add / split / reorder / remove slices).

### 10. Close the milestone

When all slices are done, say: "Close M001." -> agent updates `.ytstack/ROADMAP.md` to flip the milestone to `done`. Then say "plan the next milestone" when you're ready.

## Reading the state

Open a new Claude Code session on the project. Before your first message, the `SessionStart` hook has already injected the `STATE.md` snapshot (current milestone / slice / task, recent summaries, next action). You can just say:

> "Where were we?"

Agent fires `ytstack:resume-session` -- reads `STATE.md` + `HANDOFF.md` + latest 3 task summaries and gives you a 3-paragraph briefing. For a richer snapshot, read the files directly:

- `.ytstack/STATE.md` -- dashboard
- `.ytstack/ROADMAP.md` -- full milestone plan
- `.ytstack/DECISIONS.md` -- architectural decisions log (append-only)
- `.ytstack/KNOWLEDGE.md` -- patterns and gotchas learned
- `.ytstack/REVIEW-NOTES.md` -- deferred items flagged for end-of-cycle review

## Handoff / resume

Before stepping away for a break:

> "I'm stepping away for a week -- do a handoff."

Agent fires `ytstack:handoff-session`. Writes `.ytstack/HANDOFF.md` with current position + in-flight work + open decisions + warnings + a recommended resume prompt. Next session reads it.

The SessionStart hook also auto-injects state on every session start, so `resume-session` is for deep-dives when you want more than the hook's compact summary.

## Debugging

Say:

> "Something's broken, find it."

Agent fires `ytstack:systematic-debugging`. Four-phase process: investigate -> analyze -> hypothesize -> implement. Root cause required before any fix. Findings auto-logged to `KNOWLEDGE.md` (pattern) and `DECISIONS.md` (architectural shift). The fix path merges back into the normal task loop: regression test first (TDD), then verify, then summarize.

## When you DO type a slash-command

Natural language is the happy path. You reach for `/ytstack:<name>` only in these cases:

- **Override the agent's auto-pick.** Agent started `plan-milestone` but you want a CEO challenge first: type `/ytstack:plan-ceo-review`.
- **Re-run a skill explicitly.** You already CEO-reviewed this milestone but want to re-challenge after new learnings: type `/ytstack:plan-ceo-review` again.
- **Skip a step.** Greenfield flow says office-hours first, but you have a written pitch already: just type `/ytstack:init-project` and the skill will read your manual `./OFFICE-HOURS.md` frontmatter.

For everything else, just talk.

## Common gotchas

- **`claude -p` needs `--permission-mode acceptEdits`** or skills stall on Write prompts.
- **Skill invocations are namespaced** under `ytstack:` when you do use slash-commands (`/ytstack:init-project`, not `/init-project`).
- **Sentinel files accumulate in `~/.ytstack/.*-prompted`** -- don't worry about them; cleanup command ships later.
- **`.ytstack/` goes in git.** That's the default. Team members inherit project memory on clone.
- **One milestone at a time.** If you start a second before closing the first, the roadmap-tracking breaks. Close M### by flipping status in `.ytstack/ROADMAP.md`.
- **Agent picks the wrong skill?** Sharpen that skill's `description:` field to cover the intent more explicitly. Don't reintroduce phrase-lists -- that's the antipattern the design principle #6 warns about (see README).

## More

- Full design: `.ytstack/PROJECT.md`, `.ytstack/DECISIONS.md`
- Sources consulted: `docs/references.md`
- Contributor rules: `CLAUDE.md`
- UX contracts all skills follow: `docs/ux/`

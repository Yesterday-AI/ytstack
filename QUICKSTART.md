# ytstack Quickstart

From zero to a tracked, shipped task -- the way you actually use ytstack: by talking to the agent in natural language. The agent fires skills automatically. Slash-commands are an override path, not the default.

## Install

For Codex, follow [Codex setup](docs/codex.md). The workflow below uses Claude
Code command names; in Codex select the corresponding skill from ytstack with
`$ytstack:<skill-name>`. Claude Agent Teams and worktree subagents are not available through the Codex adapter.

### Prerequisites

- Claude Code >= 2.1.214 (the plugin's hooks use `fork`-session matching and `CLAUDE_PLUGIN_DATA`).
- For the six gstack-backed skills (`office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship`, `document-release`): **gstack installed** at `~/.claude/skills/gstack` with **bun >= 1.4.2**. ytstack is tested against gstack v1.96.0.0:

  ```bash
  git clone --branch v1.96.0.0 https://github.com/garrytan/gstack ~/.claude/skills/gstack && (cd ~/.claude/skills/gstack && ./setup --no-browser)
  ```

  Without it those skills stop with this install command; everything else in ytstack works without gstack or bun. gstack's `./setup` also registers its own `Stop` hook in `~/.claude/settings.json` (remove with `~/.claude/skills/gstack/bin/gstack-settings-hook remove-source --source gstack-timeline-stop`) and may skip Chromium; neither affects ytstack.

### Local dev (recommended for first try)

```bash
claude --plugin-dir /path/to/ytstack
```

This starts a fresh Claude Code session with ytstack loaded. No marketplace registration needed.

### Via marketplace (recommended for shared use)

```bash
/plugin marketplace add Yesterday-AI/ystacks
/plugin install ytstack@ystacks
```

`Yesterday-AI/ystacks` is the canonical Yesterday plugin catalog. Private-repo auth via `gh auth login`. ytstack's own repo also self-marketplaces as a legacy path -- see [README install section](./README.md#via-marketplace-recommended-for-shared-use).

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

Then one more question: the areas of the technical spec, proposed from the parts your pitch names. Each area gets a file under `.ytstack/spec/`, marked `planned`: the approved design, nothing built, nothing verified.

Result: `.ytstack/` with 6 core files, `spec/SPEC.md` plus one file per area, and the consumed pitch.

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

**Parallel variant:** when a milestone has multiple independent slices ready, say "run the slices in parallel" -> agent fires `ytstack:spawn-milestone-team`. Your session becomes the orchestrator: one implementer subagent per slice in its own git worktree (branch `ytstack/M###-S##`, fresh context, ytstack skills preloaded), a verifier subagent per finished branch, then the merge (the orchestrator keeps `STATE.md`). It refuses a dirty tree and overlapping slices. `team: on` in `PREFERENCES.md` (plus `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) uses Claude Code Agent Teams instead.

### 9. "Reassess between slices"

At the end of each slice, say: "Does the roadmap still fit reality?" -> `ytstack:reassess-roadmap` reads recent summaries, surfaces deviations, prompts for roadmap changes (add / split / reorder / remove slices). At milestone close it also sweeps the backlog items that were folded into the milestone, prompting per item to keep, trim, or drop.

### 10. Close the milestone

When all slices are done, say: "Close M001." -> agent updates `.ytstack/ROADMAP.md` to flip the milestone to `done`. Then say "plan the next milestone" when you're ready.

## Adopting ytstack in an existing project

The worked example above starts from an empty directory. Most real adoptions do not: the repo already has a README, a `docs/` folder, a CHANGELOG, maybe `docs/adr/`, and a year of commits. Running the office-hours pitch on that is theater, and `init-project` would write placeholders that duplicate what you have.

Open a session in the repo. The SessionStart hook counts brownfield signals (README over 30 lines, more than two `docs/*.md`, CHANGELOG, ADRs, a manifest with over 50 commits, an existing AGENTS.md/CLAUDE.md) and, at two or more, tells the agent to route build-intent to `ytstack:adopt-brownfield`. Say:

> "Set up ytstack for this project."

Agent fires `ytstack:adopt-brownfield`:

1. **Detect + analyze.** You see a mapping table: which existing file would feed `PROJECT.md` (README, CHANGELOG), `DECISIONS.md` (`docs/adr/`), `KNOWLEDGE.md` (`docs/*.md`), `RUNTIME.md` (package scripts, `.env.example`, compose, workflows), the backlog (`docs/plans/`, `ROADMAP.md`); conflicts (two decision sources) and gaps (there is never a STATE.md equivalent) are called out.
2. **Decide per artifact.** One question per slot: **reference** (pointer + one-line index, your file untouched; the default for decisions, docs and backlog), **extract** (distill the memory parts, keep the long form public; the default for PROJECT.md and RUNTIME.md), **move** (`git mv` into `.ytstack/` with a pointer left behind), or **leave**. Nothing is moved or deleted without your answer.
3. **Codebase map.** Four read-only subagents write `.ytstack/codebase/stack.md`, `architecture.md`, `conventions.md`, `concerns.md` (60 lines each, real paths). `plan-milestone` and `plan-task` read these instead of re-discovering the stack.
4. **Scaffold only the gaps.** `PROJECT.md` gets a **Validated** section ("already shipped, no pitch needed") and an **Adoption** table recording your choices; `KNOWLEDGE.md` is a link index over `docs/` with one-line summaries, not copies; `DECISIONS.md` lists your ADRs by reference; `RUNTIME.md` is derived from the manifests; `STATE.md` carries `tracker: none`.
5. **Technical spec.** One question: the areas of the system, proposed from the architecture map and your docs. Each area gets `.ytstack/spec/<area>.md`. Where one of your documents already describes the area, the file only points at it. An area is marked `implemented` only after its code was read against the description; the rest is `partial`, `planned` or `Unknown`.
6. **Pointers.** A `## ytstack project memory` section lands in your `AGENTS.md`/`CLAUDE.md`; `.gitignore` gets the `.ytstack/.local/` line.

**Already on ytstack, no spec yet?** Say "write the technical spec". `adopt-brownfield` then runs steps 3 (only for missing map files) and 5 and touches no other artifact.

Then:

> "Plan the next milestone."

`plan-milestone` scopes the delta, not the existing product. If day-to-day issues live in Linear, GitHub Projects, Paperclip or Jira, set `tracker: linear` (or `github-projects | paperclip | jira`) in `.ytstack/STATE.md`; `plan-milestone` and `reassess-roadmap` then say so and leave BAU work to that tracker instead of asking for a milestone.

If you type `/ytstack:init-project` on such a repo by mistake, it stops after the preamble and points you at `adopt-brownfield` (unless an `OFFICE-HOURS.md` pitch for new scope is present, in which case it proceeds).

## Dialing ceremony up or down

`.ytstack/PREFERENCES.md` has a `## Ceremony` block (written by `init-project` / `adopt-brownfield`):

```markdown
granularity: task        # task | slice | milestone
autonomy: loop           # loop | step
quick_lane: on           # on | off
minimal_code: on         # on | off
```

- With the defaults the agent chains plan-task -> TDD -> verification -> summarize-task inside a slice without asking ("Ralph loop"), stops at the slice boundary for `reassess-roadmap`, routes one-sentence changes ("bump the SDK", "rename the flag") to `ytstack:quick-task` (`.ytstack/quick/Q###-*`), and loads the minimal-code guard before writing code.
- `granularity: slice` for projects that find task-level plans too fine: one PLAN/SUMMARY pair per slice. `milestone` for one pair per milestone.
- `autonomy: step` when you want to approve every step.
- Milestones you will not do: say "reassess the roadmap" and pick `dropped` or `shipped-informally` instead of leaving them `planned` forever.
- Leftovers (draft stubs, stray files): say "reconcile .ytstack" -> `ytstack:reconcile` asks per class and archives; nothing is deleted.

## Reading the state

Open a new Claude Code session on the project. Before your first message, the `SessionStart` hook has already injected the `STATE.md` snapshot (current milestone / slice / task, recent summaries, next action). You can just say:

> "Where were we?"

Agent fires `ytstack:resume-session` -- reads `STATE.md` + `HANDOFF.md` + latest 3 task summaries and gives you a 3-paragraph briefing. For a richer snapshot, read the files directly:

- `.ytstack/STATE.md` -- dashboard
- `.ytstack/spec/SPEC.md` -- what applies now: the areas of the system, one file each (behaviour, where implemented, how to verify)
- `.ytstack/ROADMAP.md` -- full milestone plan
- `.ytstack/DECISIONS.md` -- architectural decisions log (append-only)
- `.ytstack/KNOWLEDGE.md` -- patterns and gotchas learned
- `.ytstack/REVIEW-NOTES.md` -- deferred items flagged for end-of-cycle review

## After the task, after the slice, after the milestone

> "Review my changes."

`ytstack:code-review` dispatches a fresh-context reviewer on the task's commits (task-ref prefix `M###-S##-T##:`) and handles the findings with the superpowers rigor rules; then `summarize-task` closes the task.

> "Slice is done -- finish the branch." / "Ship it."

`ytstack:finish-branch` (merge locally / PR / keep; no dependencies) or `ytstack:ship` (gstack's release flow with tests, review and PR). Both refuse while a task of the slice has no real summary.

> "Retro." / "Write the changelog."

After the milestone closed: `ytstack:retro` (gstack) writes `M###-RETRO.md` from the task summaries; `ytstack:document-release` (gstack) writes the CHANGELOG section for the version. Before the next milestone, "poke holes in this idea" runs `ytstack:grill` (superpowers brainstorming) and parks the design in the milestone context. The SessionStart hook prints these as hints when a slice or milestone is closed.

## Handoff / resume

Before stepping away for a break:

> "I'm stepping away for a week -- do a handoff."

Agent fires `ytstack:handoff-session`. Writes `.ytstack/HANDOFF.md` with current position + in-flight work + open decisions + warnings + a recommended resume prompt. That file is yours: no hook ever overwrites it.

Compaction writes a second, automatic handoff *outside* the repo (`${CLAUDE_PLUGIN_DATA}/repos/<repo-key>/worktrees/<worktree-key>/sessions/<session_id>/HANDOFF.auto.md`, newest via `latest-handoff`). `resume-session` reads the automatic one first, the manual one second, and opens its briefing with which it used. The SessionStart hook also auto-injects state (and both handoff pointers) on every session start, so `resume-session` is for deep-dives when you want more than the hook's compact summary.

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
- **Working in a git worktree?** Fine since 0.2.0: hooks and skills resolve the checkout from where you work, volatile state (auto handoff, journal) lives under `${CLAUDE_PLUGIN_DATA}` and the shared main checkout stays clean. Leftover `~/.ytstack/.*-prompted` sentinel files from older versions can be deleted; nothing reads them any more.
- **`.ytstack/` goes in git.** That's the default. Team members inherit project memory on clone.
- **One milestone at a time.** If you start a second before closing the first, the roadmap-tracking breaks. Close M### by flipping status in `.ytstack/ROADMAP.md`.
- **Agent picks the wrong skill?** Sharpen that skill's `description:` field to cover the intent more explicitly. Don't reintroduce phrase-lists -- that's the antipattern the design principle #6 warns about (see README).

## More

- Full design: `.ytstack/PROJECT.md`, `.ytstack/DECISIONS.md`
- Sources consulted: `docs/references.md`
- Contributor rules: `AGENTS.md`
- UX contracts all skills follow: `docs/ux/`

# AskUserQuestion Format Contract

**Every** `AskUserQuestion` call in any ytstack skill MUST follow this structure. CI validates it. No exceptions except spawned-session mode (see below).

## The 4-Part Structure

```
<Re-ground>
<Simplify>
RECOMMENDATION: Choose <X> because <one-line reason>
<Options>
```

### 1. Re-ground (1-2 sentences)

State where we are. Assume the user hasn't looked at this window in 20 minutes.

- **Project name** (from `PROJECT.md` name-field or git repo basename)
- **Current branch** (from the preamble `_BRANCH` value, NOT from conversation history or gitStatus)
- **Current task context** (what milestone/slice, or what skill is asking)

Example: *"I'm setting up ytstack tracking for 'DocProcessor v1' on branch `main`. No `.ytstack/` exists yet."*

### 2. Simplify (plain English)

Explain the decision a smart 16-year-old could follow. No raw function names, no internal jargon, no implementation details.

- Use concrete examples and analogies
- Say what it DOES, not what it's called
- If you'd need to read the source to understand your own explanation, it's too complex

Example: *"These files are your project memory -- they document what you're building and the decisions you make. Every future session reads them first, so Claude doesn't forget context between sessions."*

### 3. Recommend (required)

```
RECOMMENDATION: Choose <X> because <one-line reason>
```

- Always prefer the **higher-completeness** option over shortcuts
- If both options are Completeness ≥8, pick the higher
- If one option is ≤5, flag it explicitly as a shortcut

### 4. Options (lettered, with metadata)

Each option gets three annotations:

- `Completeness: X/10` (10 = full implementation, 7 = happy path only, 3 = shortcut that defers work)
- `(effort: human: ~T1 / CC: ~T2)` -- human-team time vs CC-assisted time
- `tier: core|task|background` (see [Question Tiers](#question-tiers))

Example:

```
A) Project-level (./.ytstack/) — committed to git, shared with team
   Completeness: 10/10, effort: human: 0 / CC: 0, tier: core

B) User-level (~/.ytstack/projects/<slug>/) — private, machine-local
   Completeness: 7/10, effort: human: 0 / CC: 0, tier: core

C) Both (project-level + user-level for private notes) — hybrid
   Completeness: 9/10, effort: human: low / CC: low, tier: core
```

## Question Tiers

Every question declares a tier. Drives how aggressively the skill asks and whether the answer persists.

| Tier | Scope | Persistence | Example |
|---|---|---|---|
| `core` | session-wide, project-wide | Yes, via sentinel file or `.ytstack/PREFERENCES.md` | "Where should `.ytstack/` live?" |
| `task` | single turn | No, re-ask each time | "Spawn 3 or 5 teammates for this milestone?" |
| `background` | cross-cutting, skip-able | Yes, with default auto-pick | "Enable telemetry?" |

Skills read the tier before asking:
- `core` → always ask if marker absent
- `task` → always ask (no marker)
- `background` → only ask if `--interactive` flag or `YTSTACK_FULL_SETUP=1`; otherwise auto-pick recommended option

## Mandatory Rules

### One question per message

Never stack multiple questions. If a topic needs exploration, split into multiple turns.

### Multiple-choice preferred over open-ended

Open-ended only when the decision genuinely requires the user's own wording (e.g. project name, description). Otherwise A/B/C.

### Cascading binary > long menus

For nuanced 3+ state outcomes, prefer cascaded yes/no:

```
Q1: "Enable usage telemetry? (helps us improve ytstack)" [A=yes / B=no]
  if B → Q2: "Anonymous mode (just a counter, no ID)?" [A=yes / B=no]
    if B → fully off
```

Three states from two binary questions. Cleaner than `A/B/C/D/E`.

### Consent-isolated meta-questions

Meta-questions (setup-mode, telemetry opt-in, visual-companion offer, onboarding-tour) MUST be in their own message. No combining with task-flow content. *"This offer MUST be its own message. Do not combine it with clarifying questions, context summaries, or any other content."*

### Re-ask anchor footer

Every `core`-tier question ends with a one-liner:

```
(to re-ask later: run `ytstack forget <marker-name>` or delete `~/.ytstack/.<marker-name>`)
```

So users know how to undo a premature answer.

## Spawned-Session Mode

If the environment variable `YTSTACK_NON_INTERACTIVE=1` is set OR the session is detected as spawned by an orchestrator (e.g. `$OPENCLAW_SESSION`, `$CLAUDE_AGENT_TEAM_MEMBER`), skills MUST:

1. **Skip `AskUserQuestion` entirely.** Auto-pick the `RECOMMENDATION` option.
2. **Log the auto-pick transparently:** *"Auto-picked A (recommended) because running in spawned session. To change: set `YTSTACK_NON_INTERACTIVE=ask` or run the skill directly."*
3. **Never block on user input.**

This applies to all tiers -- even `core`. The orchestrator/lead is responsible for providing required context upfront.

## Preamble Flag Contract

Every ytstack skill's preamble emits these flags that the AskUserQuestion-block reads:

```bash
BRANCH: <current-git-branch>
PROJECT_SLUG: <git-repo-basename>
HAS_YTSTACK: yes|no
YTSTACK_SCOPE: project|user|both|none
YTSTACK_NON_INTERACTIVE: true|false
EXPLAIN_LEVEL: default|terse|brutal
CURRENT_MILESTONE: <M###|none>
ACTIVE_SLICE: <S##|none>
SENTINELS: <comma-separated list of `.ytstack/.*-prompted` files present>
```

Questions use these flags to decide whether to ask, skip, or re-ground.

## Error Paths

If the user rejects all options (e.g. via Claude Code "cancel"), the skill:

1. Stops. Does not retry silently.
2. Reports: *"You cancelled `<question>`. To resume, run `<skill-name>` again. Nothing was persisted."*
3. Does NOT touch sentinel files (so the question re-asks next time).

## User-Turn Override

If the user's current message contains `"be terse" | "no explanations" | "brutally honest" | "just the answer"` or similar, the skill MUST:

1. Skip the Simplify paragraph.
2. Keep only Re-ground (one line) + RECOMMENDATION + Options.
3. No jargon gloss, no effort estimates unless directly asked.

Persists only for the current turn. Next turn returns to default unless `EXPLAIN_LEVEL=terse` is set in config.

## CI Validation

`ytstack-skill-check` runs on every commit and validates:

- Every `AskUserQuestion` body contains all 4 parts (Re-ground, Simplify, RECOMMENDATION, Options)
- Every option has `Completeness: X/10` and `tier: <tier>`
- Every `core`-tier question has a re-ask anchor footer
- No question stacks multiple asks in one message

Violations fail CI. No exceptions.

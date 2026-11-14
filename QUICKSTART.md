# ytstack Quickstart

From zero to a tracked, shipped task -- the way you actually use ytstack: by talking to the agent in natural language. The agent fires skills automatically. Slash-commands are an override path, not the default.

## Install

For Codex, follow [Codex setup](docs/codex.md). The workflow below uses Claude
Code command names; in Codex select the corresponding skill from ytstack with
`$ytstack:<skill-name>`. Claude Agent Teams and worktree subagents are not available through the Codex adapter.

For Kimi Code, follow [Kimi setup and compatibility](docs/kimi.md). Select
skills with `/skill:ytstack:<skill-name>` or `Skill(skill="ytstack:<name>")`.
Kimi uses static `sessionStart.skill` plus pending context consumed through
UserPromptSubmit, not SessionStart hook stdout. Its close and platform limits
are part of the host guide.

### Prerequisites

- Claude Code >= 2.1.214 (the plugin's hooks use `fork`-session matching and `CLAUDE_PLUGIN_DATA`).
- Kimi Code 2.5.3 is locally verified; 2.6.2 is verified in fresh Linux/Node 24. See [Kimi support status](docs/kimi.md#support-status) before relying on another environment.
- bash and git. Nothing else to install: `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship` and `document-release` are ytstack's own adaptations of gstack skills and ship with the plugin.
- `gh`, logged in, for `ship`, `document-release` and the pull request steps of `finish-lane`. GitHub is the only pull request host the pipeline supports.
- For `visual-review` only: a browser tool in the session that renders a page and returns a screenshot (a Playwright-style browser server or command line, or the host's built-in browser). `curl` or a web fetch does not count. Without one the visual lens records `not run`.

  Upgrading from ytstack 0.5 or older with gstack installed only for ytstack: gstack's `./setup` registered about 60 skills in `~/.claude/skills/` (folders with a `.gstack-owned` marker) plus `~/.claude/skills/gstack`. ytstack no longer uses them; remove them with gstack's own `~/.claude/skills/gstack/bin/gstack-uninstall --keep-state` (read its `--help` first: it also removes gstack installs for other agents).

### Local dev (recommended for first try)

```bash
claude --plugin-dir /path/to/ytstack
```

This starts a fresh Claude Code session with ytstack loaded. No marketplace registration needed.

### Via marketplace (recommended for shared use)

```bash
/plugin marketplace add Yesterday-AI/skills
/plugin install ytstack@yesterday-public-plugins
```

`yesterday-public-plugins` (repo `Yesterday-AI/skills`) is Yesterday's public plugin catalog; it imports ytstack from its own repo. ytstack's own repo also self-marketplaces (`ytstack@ytstack`) -- see [README install section](./README.md#via-marketplace-recommended-for-shared-use).

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
- The minimal-code guard is a work contract, not only a code rule: a task's Verification section says which command runs, how often and where, and the agent does not add passes or scenarios on its own. A review is complete in round one, covers the fix in round two and becomes a diagnosis in round three. What only you can decide is a gate in the plan (`## Gates`: what, who decides, how, when it lapses); at the slice boundary `reassess-roadmap` brings all open gates in one question and tells you two numbers: closed by work, and accepted.

## Let the agent run your product

Tests pass, the page is still broken. To have the agent check the running product, tell it how to start it. Say:

> "Add a Run section to RUNTIME.md: `pnpm dev --port {port}`, ready when `/healthz` answers."

The agent fills the "Run" section of `.ytstack/RUNTIME.md` (`init-project` and `adopt-brownfield` write the empty heading):

```markdown
## Run

- start: pnpm dev --port {port}
- ports: 4100-4199
- ready: curl -fsS http://localhost:{port}/healthz
- url: http://localhost:{port}
```

`bin/ytstack-runtime check` validates the file: required keys, no token in it (names of credentials, never values). Then:

- `bin/ytstack-runtime up` starts the product in the background on a free port from `ports`, one port per worktree, waits until `ready` passes and prints `URL:`, `PORT:`, `PID:`, `LOG:` and `COMMIT:`. Two worktrees run side by side.
- `bin/ytstack-runtime down` stops it, children included. `status` says whether it runs.

A task plan whose Verification names the environment `instance from bin/ytstack-runtime up` is checked at the running product: `verification-before-completion`, the implementer and the verifier start it, check against `URL:`, record the `COMMIT:` line with the result and stop it. Without a "Run" section, or when `up` fails, they report that the check at the running product was not possible. They never start the product another way. Format: `docs/ux/runtime-format.md`.

## Coordinating many lanes

A plan with dozens of packages, one session that delegates all of it. Say:

> "You are the coordinator. Run the plan."

Agent fires `ytstack:coordinate`. It writes no product code. What it keeps, it keeps in files, so that a compaction or a fresh session loses nothing:

- `.ytstack/LANES.md` -- one row per delegated lane (who holds it, branch, pull request, reviewed commit, round, next action). `bin/ytstack-frontier` lists what may start: open, unblocked (`**Blocked by:**` in the slice plans) and unclaimed. A lane is claimed before it is dispatched.
- `.ytstack/questions/` -- one file per question for you, with context, options and a recommendation. You get one at a time, as late as the work allows, and never the same one twice.
- `.ytstack/STANDING.md` -- what you ask for once and for all ("status only at slice boundaries") is written down when you say it.
- A finished lane goes through `ytstack:finish-lane`: commit, push, pull request, review pinned to the commit the host shows (the reviewer states the risk class and the invariants the change touches), the lenses your `.ytstack/spec/REVIEW.md` requires for that kind of change, the route, gates read from the host, merge at the reviewed commit, then the release watch when `RUNTIME.md` has a "Release" section. Under `merge_by: risk` (the default) the coordinator merges only when `bin/ytstack-risk route` says `unattended`; otherwise you merge and get the reasons. A project with no `auto_merge` in its area files sends everything to you. `merge_by: human` sends everything to you anyway.
- A step only you may perform (a production action, a check in a GUI) arrives as one script: `bash .ytstack/handover/<date>-<step>.sh`. It checks first, asks before every change and leaves a receipt.

A status from the coordinator names when it read the pull request state. GitHub through `gh` is the only host the pipeline supports.

## Who merges: the risk route

By default a person merges every change. To let small ones through without you, declare it per area of the technical spec. Say:

> "Docs and tests in the `export` area may merge without me."

The agent adds one field to the frontmatter of `.ytstack/spec/export.md`:

```yaml
auto_merge: low        # none | low | normal; no field means none
```

That edit is itself a rule change, so it goes to you, like a change to `DECISIONS.md`, `PREFERENCES.md` or `REVIEW.md`. For interface changes, add a lens to `.ytstack/spec/REVIEW.md` (linked from `SPEC.md`; optional):

```markdown
## Lenses

- ui | applies: src/components/**, **/*.css | reads: docs/design-guidelines.md | evidence: visual
```

When a lane finishes, `finish-lane` walks it through:

1. **Review.** A reviewer that is not the author reviews the commit the host shows and states `Risk:` (low, normal, high) and `Invariants touched:`, read against the invariants and decisions of the touched areas.
2. **Floor.** `bin/ytstack-risk floor` computes the lowest class the diff allows. Rule documents, the invariants of an area, CI and paths no area covers always go to a person. Dependencies, migrations, infrastructure and changes over 400 lines or 20 files are never low.
3. **Lenses.** One fresh reviewer per required lens. The `ui` lens loads `ytstack:visual-review`: it starts the product at the reviewed commit in its own worktree (the "Run" section above), operates it in a browser and judges screenshots it took itself against your guidelines. No browser tool, no "Run" section, or the reviewer is the author: `not run`, never a pass.
4. **Route.** `bin/ytstack-risk route` says `unattended` only when everything holds: an approving round valid for the head, `invariants: none`, a class within the `auto_merge` of every touched area, a passing line for every required lens.
5. **Merge.** With `merge_by: risk` (the default) and green host gates, `finish-lane` merges at the reviewed commit and tells you in one line what merged, at which class and why. Every other lane stops at `ready` with its merge command and the reasons, for you.

What lands on disk: the round and lens lines under `## Review` in the lane's plan, and the screenshots with a hashed `MANIFEST` under `.ytstack/evidence/<lane>/<sha>/ui/` (`evidence_dir` in `PREFERENCES.md`).

```markdown
- Round 1: a1b2c3d..e4f5a6b -- approved; blocking: 0; follow-ups: 0; risk: low; invariants: none; by: review-M004-S02
- Lens ui: e4f5a6b -- pass; by: ui-M004-S02; evidence: .ytstack/evidence/M004-S02/e4f5a6b/ui (5 images)
```

Nothing declared means a person merges: a project without `auto_merge` sends every change to you. `merge_by: human` sends everything to you anyway. Outside a lane, "check the UI of this commit" runs `visual-review` on its own. Format: `docs/ux/review-policy-format.md`.

## After the merge

Merged is not released. Give `RUNTIME.md` a "Release" section; both commands only read:

```markdown
## Release

- target: production (https://app.example.com)
- deployed: curl -fsS https://app.example.com/version
- healthy: curl -fsS https://app.example.com/healthz
- settle: 180
```

After a merge, `finish-lane` runs `bin/ytstack-watch release --commit <merge commit>`. It asks `deployed` until the target prints the commit (at most 15 minutes), then `healthy` for the settle time, and ends with one receipt that goes into the lane's report:

```
Target: production (https://app.example.com)
Commit: a1b2c3d4e5f60718293a4b5c6d7e8f9012345678
Arrived: yes, the target printed a1b2c3d, read 2026-11-13T19:02:11Z
Health: asked 9, failed 0, last read 2026-11-13T19:04:12Z
Result: released
```

`not arrived` or `unhealthy` comes to you at once, with the receipt. The watch deploys nothing and rolls nothing back. For a merge outside a lane, run the same command yourself.

Between sessions, things go stale: spec drift, lapsed gates, questions nobody answered, lanes without movement. `bin/ytstack-upkeep` lists them in one read-only run without a model. It exits 0 with `nothing needs a look` and 10 otherwise; `--question` leaves one question file under `.ytstack/questions/`, and no second one while the first is open. To run it on a schedule (GitHub Actions, cron, a headless agent run), follow [`docs/recipes/recurring-upkeep.md`](docs/recipes/recurring-upkeep.md).

## When production speaks

Declare where production reports in the "Signals" section of `RUNTIME.md`: one line per source, a command that only reads, names of credentials, never values.

```markdown
## Signals

- errors | read: glitchtip-cli issues --project shop --since 24h --format tsv | kind: errors
```

> "Anything new in production?"

Agent fires `ytstack:signal-intake` (also fit for a scheduled run). It reads every source once and records each real finding once as `.ytstack/signals/F###-<slug>.md`. A second sighting raises its count. A sighting of a finding marked fixed becomes a new finding with `reopens:`: a regression. The intake changes nothing else: no task, no dismissal, no product file. You pick a finding, `systematic-debugging` finds the cause, and `bin/ytstack-signals set F007 --state planned --ref <task>` links the two.

> "Production is down."

Agent fires `ytstack:incident`. Mitigation first, cause afterwards:

1. It opens `.ytstack/incidents/<date>-<slug>.md`, or resumes the open one, and records what is seen (each fact with its read time), a timeline and hypotheses.
2. Every mitigation (a rollback, a restart, a flag) becomes a staged script under `.ytstack/handover/`. It checks first, asks before every change and writes a receipt. You get one question, which mitigation; then you run it, for example `bash .ytstack/handover/2026-11-13-roll-back-checkout.sh`. The agent never runs it.
3. It reads the receipt and the signals again. When you say the mitigation holds, the record turns `mitigated`.
4. The root cause goes to `systematic-debugging`, with the record as its input.

Format of both records: `docs/ux/signal-format.md`.

## Optional: PR watch

Want to hear about a red check or an unresolved bot thread without the agent polling its PRs? Switch on the PR watch once per user:

```bash
bin/ytstack-pr-watch enable
bin/ytstack-pr-watch install-worker --yes   # macOS; without --yes it only prints the plan
```

PRs a session opens with `gh pr create` are then watched. Claude Code gets the news with your next prompt; Codex is woken when the thread is idle. The worker keeps a reserve of your GitHub API quota for your agents. Off by default, and `bin/ytstack-pr-watch disable` turns it off again. Details, policy and limits: [`docs/pr-watch.md`](docs/pr-watch.md).

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

`ytstack:code-review` dispatches a fresh-context reviewer on the task's commits (task-ref prefix `M###-S##-T##:`) and handles the findings with the superpowers rigor rules. The reviewer reads the area files of the changed paths, states the class of the change (`Risk:`) and the invariants it touches, and the round lands as a line under `## Review` in the task plan. Round 1 is complete, round 2 covers the fix, a third round is a diagnosis instead of another review. Then `summarize-task` closes the task, and refuses while a named spec area was not updated.

> "Slice is done -- finish the branch." / "Ship it."

`ytstack:finish-branch` (merge locally / PR / keep; no dependencies) or `ytstack:ship` (release flow with tests, review and PR). Both refuse while a task of the slice has no real summary. A delegated lane goes through `ytstack:finish-lane` instead: the risk route decides who merges, then the release watch runs (see "Who merges" and "After the merge" above).

> "Retro." / "Write the changelog."

At the last slice of a milestone, `reassess-roadmap` folds what still holds into the area files of the spec; `reconcile` then offers to archive the slice and task files of closed milestones. After the milestone closed: `ytstack:retro` writes `M###-RETRO.md` from the task summaries; `ytstack:document-release` writes the CHANGELOG section for the version. Before the next milestone, "poke holes in this idea" runs `ytstack:grill` (superpowers brainstorming) and parks the design in the milestone context. The SessionStart hook prints these as hints when a slice or milestone is closed.

## Handoff / resume

Before stepping away for a break:

> "I'm stepping away for a week -- do a handoff."

Agent fires `ytstack:handoff-session`. Writes `.ytstack/HANDOFF.md` with current position + in-flight work + open decisions + warnings + a recommended resume prompt. That file is yours: no hook ever overwrites it.

Compaction writes a second, automatic handoff *outside* the repo (`${CLAUDE_PLUGIN_DATA}/repos/<repo-key>/worktrees/<worktree-key>/sessions/<session_id>/HANDOFF.auto.md`, newest via `latest-handoff`). `resume-session` reads the automatic one first, the manual one second, and opens its briefing with which it used. The SessionStart hook also auto-injects state (and both handoff pointers) on every session start, so `resume-session` is for deep-dives when you want more than the hook's compact summary.

## Debugging

Say:

> "Something's broken, find it."

Agent fires `ytstack:systematic-debugging`. Four-phase process: investigate -> analyze -> hypothesize -> implement. Root cause required before any fix. Findings auto-logged to `KNOWLEDGE.md` (pattern) and `DECISIONS.md` (architectural shift). The fix path merges back into the normal task loop: regression test first (TDD), then verify, then summarize.

A test that fails only sometimes is not rerun until green: the skill raises the reproduction rate, runs the test on the base commit and, if it flakes there too, records it as a follow-up instead of a defect of this change.

Two more ways in. Production is down right now: that is `ytstack:incident` first, mitigation before cause, and the record becomes the input of `systematic-debugging` afterwards. A finding from `signal-intake` enters here when you pick it up (see "When production speaks").

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
- **Nothing merges without you?** That is the default. Only an area with `auto_merge` lets a change through, and only when the route says `unattended`; the `reason:` lines of `bin/ytstack-risk route` say what failed.
- **A visual lens says `not run`.** The session that ran it had no browser tool, no "Run" section in `RUNTIME.md`, or the product did not come up. `not run` is never a pass: the change goes to you until what was missing exists.
- **No secrets in `RUNTIME.md`.** It is committed. Commands read credentials from the environment; `bin/ytstack-runtime check` fails on a token-looking string, but cannot see a short password.
- **`ytstack-watch release` exits 4.** `RUNTIME.md` has no "Release" section with a `deployed` line; nothing was run.
- **Coordinator mode has not run against a real host yet.** The suites use a stand-in for `gh` and fixture targets; no unattended merge or real release watch has happened in a session.
- **Agent picks the wrong skill?** Sharpen that skill's `description:` field to cover the intent more explicitly. Don't reintroduce phrase-lists -- that's the antipattern the design principle #6 warns about (see README).

## More

- Full design: `.ytstack/PROJECT.md`, `.ytstack/DECISIONS.md`
- Sources consulted: `docs/references.md`
- Contributor rules: `AGENTS.md`
- UX contracts all skills follow: `docs/ux/`

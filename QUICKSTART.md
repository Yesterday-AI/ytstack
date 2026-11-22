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
- For `process-review` only: Node 18 or newer and a GitHub token with read access (`GITHUB_TOKEN`, `GH_TOKEN` or a signed-in `gh`). Without Node the skill stops with one sentence; nothing else in ytstack uses Node.

  Upgrading from ytstack 0.5 or older with gstack installed only for ytstack: gstack's `./setup` registered about 60 skills in `~/.claude/skills/` (folders with a `.gstack-owned` marker) plus `~/.claude/skills/gstack`. ytstack no longer uses them; remove them with gstack's own `~/.claude/skills/gstack/bin/gstack-uninstall --keep-state` (read its `--help` first: it also removes gstack installs for other agents). Everything else an upgrade needs: "Upgrading from 0.x" below.

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

- The lanes file -- one row per delegated lane (who holds it, branch, pull request, reviewed commit, round, next action), out of tree per repository (`ytstack-frontier where`; a `.ytstack/LANES.md` from before stays it until `ytstack-frontier migrate`). The lane's pull request on the host is its state. `bin/ytstack-frontier` lists what may start: open, unblocked (`**Blocked by:**` in the slice plans) and unclaimed. A lane is claimed before it is dispatched.
- `.ytstack/questions/` -- one file per question for you, with context, options and a recommendation. You get one at a time, as late as the work allows, and never the same one twice.
- `.ytstack/standing/` -- what you ask for once and for all ("status only at slice boundaries") is written down when you say it, one file per instruction, so parallel pull requests do not conflict over it. A project that keeps `.ytstack/STANDING.md` alone keeps working.
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

**Every incident leaves a lesson.** When production went down, `main` went red, a review caught a defect or an agent slipped, the skill that handled it ends with `ytstack:lesson`. It names the class (`ci: flaky-order`) and puts the lesson where a machine checks it (a test, a guard, a CI step, an alert), or else into `KNOWLEDGE.md`, never as one more rule in `AGENTS.md`. It records the lesson once per class under `.ytstack/signals/`, so the second time the same thing happens you see a count of 2, not a fresh surprise. A check nobody built yet becomes a lane the coordinator dispatches; a rule change comes to you as a question. When the lesson concerns ytstack itself, it goes upstream per `upstream_feedback` (`suggest` by default: the agent drafts an issue and asks you; `docs/ux/upstream-feedback.md`).

Format of both records: `docs/ux/signal-format.md`.

## When review bots catch what your reviewers missed

A project that runs review roles of its own (a role per review goal, each with a file it reads at every review) declares them in `.ytstack/spec/REVIEW.md`:

```markdown
## Own reviewers

- code | marker: (`code`) | lessons: .github/reviewers/code.md
- security | marker: (`security`) | lessons: .github/reviewers/security.md
```

> "What did the bots catch on #142 that our reviewers missed?"

Agent fires `ytstack:review-lessons`. For each merged pull request it lists the review-bot threads that a later commit fixed and that no role reported on the same lines, names the role whose file says it should have caught each one, and records it once as `review:<role>:<class>` under `.ytstack/signals/`. An escape on a file no role reviews is only named in the report. When a class comes back, or comes once at critical or high severity, it writes the exact checklist line for the role's file as a question under `.ytstack/questions/`. You answer; it never edits the role file itself.

Nobody has to remember to ask. After a merge, the PR watch (when on) tells the owning session to run it, `finish-lane` runs it after its own merge, and `bin/ytstack-upkeep` lists every merged pull request that had no check yet. `retro` counts the escapes per role for the milestone. The loop end to end: `docs/ux/review-policy-format.md`, "The lessons loop".

## Optional: PR watch

Want to hear about a red check or an unresolved bot thread without the agent polling its PRs? Switch on the PR watch once per user:

```bash
bin/ytstack-pr-watch enable
bin/ytstack-pr-watch install-worker --yes   # macOS; without --yes it only prints the plan
```

PRs a session opens with `gh pr create` are then watched. Claude Code gets the news with your next prompt; Codex is woken when the thread is idle. The worker keeps a reserve of your GitHub API quota for your agents. Off by default, and `bin/ytstack-pr-watch disable` turns it off again. Details, policy and limits: [`docs/pr-watch.md`](docs/pr-watch.md). Step by step, with the checks: "Setting up the factory tools" below, step 2.

## Setting up the factory tools

The sections above say what each tool does. This one is the setup, in order, with a check after every step. The factory tools: the risk route (who merges), the PR watch (news about your pull requests), the release watch and the signal intake (after the merge), the upkeep run (what went stale), standing instructions and external plans. Each one is off until you set it up, and a project that sets up none of them works as before: every merge goes to you.

The commands name `bin/...` inside the ytstack plugin. In a shell outside a session, find the installed one first:

```bash
YT=$(ls -d ~/.claude/plugins/cache/*/ytstack/*/ | sort -V | tail -1)   # then "$YT/bin/ytstack-risk" ...
```

Inside a session the SessionStart context names the absolute path, and the agent runs the commands for you when you ask ("set up risk routing").

**Which steps you need.**

- **New project** (`init-project` just ran): steps 1 and 2 now. `init-project` wrote the spec areas as `planned`, so step 1 is short: one `REVIEW.md`, no `auto_merge` until an area has code that was checked. Step 3 when the product deploys somewhere or reports errors somewhere. Step 4 once more than one session works on the project.
- **Existing project** (`adopt-brownfield` ran) **or an upgrade from 0.6 or older**: first make sure the spec exists (`ls .ytstack/spec/SPEC.md`). Without it, say "write the technical spec": `adopt-brownfield` adds only `.ytstack/spec/` and touches nothing else. Then steps 1 to 5, and the "Upgrading from 0.x" checklist below for your version.

### 1. Risk routing: who merges

1. Write `.ytstack/spec/REVIEW.md`. Every section is optional; start with what the project already knows:

   ```markdown
   # Review policy

   ## Always a person

   - infra/**

   ## Lenses

   - ui | applies: src/components/**, **/*.css | reads: docs/design-guidelines.md | evidence: visual

   ## Own reviewers

   - code | marker: (`code`) | lessons: .github/reviewers/code.md
   ```

   A lens needs its `reads` documents in the repository; an own reviewer needs its `lessons` file. Leave out `## Own reviewers` when the project has no review roles of its own. Format: [`docs/ux/review-policy-format.md`](docs/ux/review-policy-format.md).
2. Link it from `.ytstack/spec/SPEC.md` (one line, `[Review policy](REVIEW.md)`); `ytstack-spec lint` fails on an unlinked `REVIEW.md`.
3. Give the areas that may merge without you a ceiling in their frontmatter: `auto_merge: low` (docs, tests, small changes) or `auto_merge: normal`. No field means `none`. Only areas whose code was checked against the description (`status: implemented`) are good candidates.
4. Say who merges in `.ytstack/PREFERENCES.md`, under `## Ceremony`: `merge_by: risk` (the default, written down so the choice is visible), `human` (always you) or `coordinator`.
5. Commit the three edits in one pull request and merge it yourself: a change to `REVIEW.md`, `PREFERENCES.md` or an area's frontmatter always routes to a person, and the policy is read at the base commit, so it applies from the next change on.

Check:

```bash
bin/ytstack-risk check            # exit 0: "review policy ok: 1 lens(es), 1 own reviewer(s)"; exit 1: one line per problem
bash bin/ytstack-spec lint        # 0 failure(s)
```

Then route one recent pull request dry. Nothing is merged; the route only reads (the review records on the host with `--pr`, the diff from git):

```bash
n=142                                                   # a recent PR number
gh pr view $n --json baseRefOid,headRefOid --jq '.baseRefOid+" "+.headRefOid'
git fetch origin pull/$n/head                          # the head commit, if you do not have it
git merge-base <baseRefOid> <headRefOid>               # the base the route compares against
bin/ytstack-risk route --pr $n --base <merge-base> --head <headRefOid> --author <who wrote it>
```

It prints `route: unattended` or `route: person`, then `class`, `ceiling`, `floor`, `areas`, `lenses`, `round:` (where the review record came from: `host review <id> by <login> on <sha>`, `plan` or `none`) and one `reason:` line per condition that failed. On a pull request from before step 5 expect `person`: no review carries a round line yet. What to look at: the `areas` are the ones you expect, the `ceiling` is what you set in step 3, and every `reason:` names something you agree should go to a person. `round: none` means no review on that pull request has the record lines; `finish-lane` and `code-review` post them in the review body from now on ("Records on the host" in the format document).

### 2. PR watch: news about your pull requests

Once per user, not per project. Needs `python3` 3.9 or newer and `gh` signed in; the worker runs on macOS (on Linux `install-worker` prints a systemd user timer and writes nothing).

1. Switch on the hooks: `bin/ytstack-pr-watch enable` (writes `pr_watch=on` to `~/.ytstack/config`).
2. Look at the worker plan: `bin/ytstack-pr-watch install-worker`. It names the launcher, the LaunchAgent and the `PATH` it will use.
3. Install it: `bin/ytstack-pr-watch install-worker --yes`. **If your `gh` comes from asdf or mise**, the plan's `PATH` must not point at a shim: launchd has no shell profile, so a shim cannot run there. `install-worker` takes the first `gh` on your `PATH` that runs on its own and refuses with "No gh (GitHub CLI) on PATH that runs on its own" when only a shim exists. Then install `gh` from a package manager (`brew install gh`) and run step 3 again. A worker installed before 0.8.2 may still carry a shim: run step 3 once more.
4. Restart every running Claude Code and Codex session. A session keeps the hooks it loaded at its start: one that was running before step 1 registers no pull request until it restarts.
5. A coordinator (the one session that owns a repository's pull requests) registers every open one once, at its start and after every restart, without `--session` (it defaults to the current session):

   ```bash
   bin/ytstack-pr-watch register --repo OWNER/REPO --all-open
   ```

   This also covers the pull requests its subagents opened: their hook calls carry the parent's session. Independent sessions in the same repository register only their own (`register --repo OWNER/REPO --pr N`); `--all-open` skips, by name, pull requests another session owns.
6. When a coordinator rotates to a fresh session, the successor takes over the watches in one call, with the old session's id from the handoff ("This session is ..." in its SessionStart context):

   ```bash
   bin/ytstack-pr-watch handover --from claude:<old session id>
   ```

Check:

```bash
bin/ytstack-pr-watch status | jq -r '.health.heartbeat'   # epoch seconds of the last tick: under 600 s old
bin/ytstack-pr-watch status | jq '.watches | length'      # the watches of all sessions
```

After the next worker read of a watched pull request with a red check (every minute while it moves, every 5 minutes once it settled), your next prompt in the owning session shows a notice. Optional: a review policy per repository in `~/.ytstack/pr-watch/state/policy.json`, so a pull request counts as `ready` only after its review bots finished ([`docs/pr-watch.md`](docs/pr-watch.md), "Policy"). Coming from a local install of the watcher: "Migrating from a local install" in the same document.

### 3. `RUNTIME.md` "Release" and "Signals": after the merge

`ytstack-watch release` and `signal-intake` read these two sections of `.ytstack/RUNTIME.md`; without them they stop and run nothing.

1. "Release", when the product deploys somewhere. `deployed` is a command that prints the commit the target serves; `healthy` exits 0 while it is healthy:

   ```markdown
   ## Release

   - target: production (https://app.example.com)
   - deployed: curl -fsS https://app.example.com/version
   - healthy: curl -fsS https://app.example.com/healthz
   - settle: 180
   ```

2. "Signals", when production reports somewhere. One line per source, a command that only reads:

   ```markdown
   ## Signals

   - errors | read: glitchtip-cli issues --project shop --since 24h --format tsv | kind: errors
   ```

   Credentials by name from the environment, never a value: the file is committed.

Check:

```bash
bin/ytstack-runtime check                           # runtime ok: <the sections>
bin/ytstack-runtime sections                        # Release and Signals listed
bin/ytstack-runtime get release deployed            # the command
bin/ytstack-runtime signals                         # one tab-separated line per source
bin/ytstack-watch release --commit "$(git rev-parse origin/main)" --timeout 60
```

The last line watches the commit that is already live (when `main` is what production runs): it should end with `Result: released` or `no health command`. `not arrived` (exit 2) means the `deployed` command does not print the commit, which is what to fix. Then say "anything new in production?" once: `signal-intake` reads every source and records findings under `.ytstack/signals/`. Format: [`docs/ux/runtime-format.md`](docs/ux/runtime-format.md).

### 4. Upkeep on a schedule

1. Run it once by hand: `bin/ytstack-upkeep`. Exit 0 with `nothing needs a look`, 10 with a list. It only reads.
2. Put it on a schedule: the GitHub Actions workflow (opens one issue, never a second while one is open) or the crontab line (leaves one question file under `.ytstack/questions/` with `--question`), both in [`docs/recipes/recurring-upkeep.md`](docs/recipes/recurring-upkeep.md). Pin the ytstack checkout in the workflow to a release tag.

Check: start the workflow once by hand (`gh workflow run ytstack-upkeep.yml`) and read its log; for cron, the log file after the first run.

### 5. Standing instructions and external plans

- **Standing instructions.** What you ask for once and for all ("status only at slice boundaries", "never merge on Fridays") is written down when you say it, one file per instruction under `.ytstack/standing/` (since 0.10.0). Say it to the coordinator; it writes the file. Check: `bin/ytstack-check --standing` (names, frontmatter, every `supersedes` names an earlier entry). A project with only `.ytstack/STANDING.md` keeps working; new instructions go into the directory. Format: [`docs/ux/coordinator-format.md`](docs/ux/coordinator-format.md), "`standing/`".
- **External plans.** A plan kept outside `.ytstack/` (`plans/*.md` tables or checklists) is invisible to `ytstack-frontier`. Check: `bin/ytstack-plans scan` prints one line per plan directory; `verdict=large answer=none` means it was never mapped. Say "reconcile .ytstack": `reconcile` asks once whether to map the open rows into milestones and slices, and records your answer in `PREFERENCES.md`. Your plan files are never written. Format: [`docs/ux/external-plans.md`](docs/ux/external-plans.md).

### What the session start tells you

When a session starts (or after `/clear`, not on resume or compaction), the SessionStart context lists the factory tools that are off although the project would use them, under "Factory tools (said once per session)":

| Line starts with | Means | Fix, or silence it |
|---|---|---|
| `Risk routing is not set up` | `.ytstack/spec/` exists and `merge_by` is `risk`, but there is no `REVIEW.md` or no area with `auto_merge: low` or `normal`: every merge goes to you | step 1; or `merge_by: human` in `PREFERENCES.md` |
| `PR watch is off for this GitHub repository` | no `pr_watch` line in `~/.ytstack/config` | step 2; or `pr_watch=off` in `~/.ytstack/config` |
| `PR watch is on, but its worker ...` | the worker never ticked, or its last tick is 10 minutes old or more | `bin/ytstack-pr-watch status`, then `install-worker --yes` again |
| `RUNTIME.md has no "Release" section` / `"Signals" section` | the project deploys (a `Dockerfile`, `fly.toml`, a deploy workflow, ...) or reports errors (incidents, signals, Sentry or GlitchTip config) | step 3 |

`bin/ytstack-upkeep` lists the same lines in its last section, `factory tools`; they never count as findings.

In Claude Code a second notice comes with a prompt, once per installed version: `ytstack X installed, this session loaded A: reload the skills you use`, followed by the CHANGELOG entry titles in between. The plugin was updated while the session ran, and the skill text the session already loaded is the old one. Invoke the skills you use again; restart the session when the new version brings hooks (a running session keeps the hooks it started with). Codex and Kimi sessions get no version notice.

## Upgrading from 0.x

After every update:

1. Update the catalog and the plugin: `claude plugin marketplace update yesterday-public-plugins && claude plugin update ytstack` (or `ytstack@ytstack` with the self-marketplace).
2. Restart the running Claude Code, Codex and Kimi sessions. A session keeps the skill text and the hooks it started with. A Claude Code session on a release that has the version notice says so itself ("What the session start tells you" above).
3. The PR watch worker needs nothing: its launcher runs the engine of the version Claude Code has installed.
4. Run `bin/ytstack-upkeep` once in each project. Its last section, `factory tools`, names what is still off.

Then, by the version you come from (newest first; coming from an older one, do every block down to yours):

- **From 0.11.x** (to 0.12.0): nothing to migrate; restart Claude Code sessions to get the new hooks (standing-instruction prompt hook, coordinator path hints, the behind-origin notice). Question files without `class:` still read as escalations, but `ytstack-questions new --decides` now needs `--because <item>` from the `escalate:` list. `ytstack-finish-lane gates --max-open` is gone; the cap moved to `ytstack-finish-lane open-pr --max-open`. `ytstack-pr-watch register --all-open` now registers only your own open, non-draft pull requests (`--author`, `--include-drafts` and `--include-labelled` widen it). A project with milestone directories under `.ytstack/milestones/` gets new artifacts there; flat stays the default.
- **From 0.10.x** (to 0.11.0): nothing to migrate. Incident records closed before 0.11.0 have no `lesson:` line; `ytstack-signals check` lists them as warnings, not failures. Set `upstream_feedback` in `PREFERENCES.md` (or `~/.ytstack/config`) only if you want something other than `suggest`. A coordinator that rotates hands its PR watches to the successor with `bin/ytstack-pr-watch handover --from claude:<old session id>`. `finish-lane` and `code-review` now post the review record lines in the review body on the pull request, and `ytstack-risk route --pr <n>` reads them from there, so a repository where agents may not write in the main checkout can route `unattended`. A plan under `plans/` shows up in `bin/ytstack-plans scan`; `reconcile` offers to map it (step 5 above).
- **From 0.9.x:** standing instructions can live as one file each in `.ytstack/standing/` (0.10.0). `STANDING.md` keeps working; nothing to move. After the first entry: `bin/ytstack-check --standing`.
- **From 0.9.0 or 0.9.1:** a Claude Code session that registered with its bare id had its PR watch notices stored for a Codex thread and never saw them. Run one `register` in that session (a coordinator: `register --repo OWNER/REPO --all-open`, without `--session`); it moves those watches and their notices (0.9.2).
- **From 0.9.0 or older:** a session that ran when the PR watch was switched on registered nothing. Restart it; the coordinator then runs `register --repo OWNER/REPO --all-open` once (0.9.1).
- **From 0.8.x or older:** review lessons are new (0.9.0). A project with review roles of its own adds `## Own reviewers` to `REVIEW.md` (step 1); `bin/ytstack-upkeep` then lists merged pull requests without an escape check.
- **From 0.8.0 or 0.8.1 with `gh` from asdf or mise:** run `bin/ytstack-pr-watch install-worker --yes` again; the old worker may carry a shim that cannot run under launchd (0.8.2).
- **From 0.7.x:** the PR watch is new and off (0.8.0). Switch it on with step 2. If you ran the watcher as a local tool before: `bin/ytstack-pr-watch migrate --from <old install>` (prints the plan; `--yes` copies), then "Migrating from a local install" in [`docs/pr-watch.md`](docs/pr-watch.md) for the rest.
- **From 0.6 or older:** projects have no technical spec yet (0.7.0). Say "write the technical spec": `adopt-brownfield` writes `.ytstack/spec/` and touches no other artifact. Then steps 1 and 3. `merge_by: risk` became the default, but without an `auto_merge` field in an area every merge still goes to you. Older task plans without `## Spec impact` close fine: `summarize-task` works the impact out at closure.
- **From 0.5 or older:** gstack is no longer used. If it was installed only for ytstack, remove its skills with `~/.claude/skills/gstack/bin/gstack-uninstall --keep-state` (see Prerequisites; read its `--help` first).
- **From 0.3 or older:** add the `## Ceremony` block to `.ytstack/PREFERENCES.md` ("Dialing ceremony up or down"), or keep the defaults (task, loop, on, on, team off). Leftover `~/.ytstack/.*-prompted` files can be deleted; nothing reads them.

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
- **No unattended merge and no release watch has run against a real host yet.** The suites use a stand-in for `gh` and fixture targets. In the field, a coordinator did two production releases with hand-made post-checks on 2026-11-14 (issue #54); a "Release" section is what would let `ytstack-watch release` do that check.
- **Agent picks the wrong skill?** Sharpen that skill's `description:` field to cover the intent more explicitly. Don't reintroduce phrase-lists -- that's the antipattern the design principle #6 warns about (see README).

## More

- Full design: `.ytstack/PROJECT.md`, `.ytstack/DECISIONS.md`
- Sources consulted: `docs/references.md`
- Contributor rules: `AGENTS.md`
- UX contracts all skills follow: `docs/ux/`

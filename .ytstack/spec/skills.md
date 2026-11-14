---
area: skills
status: implemented
paths:
  - skills/**
  - agents/**
sources:
  - docs/ux/skill-structure.md
  - docs/ux/askuserquestion-format.md
  - docs/ux/agent-structure.md
verified_at: f4f54ab
---

# skills

## Purpose

The skill tree (`skills/*/SKILL.md`) and the agent definitions (`agents/*.md`): the procedures an agent loads through the Skill tool and the three roles dispatched through the Agent tool. Section layout, question format and agent format are defined in the three `sources`. This file holds what they lack: the skill classes, the shared preamble, the ceremony preferences, the non-interactive mode and the agents' division of work. The files a skill writes are described in [artifacts.md](artifacts.md).

## Behavior

### Skill classes

| Class | Mark in the file | Members |
|---|---|---|
| Native procedure | no `metadata.kind`; own `## Preamble` with a `bash` block, `## Checklist`, `## Terminal State` | `adopt-brownfield`, `handoff-session`, `init-project`, `plan-milestone`, `plan-task`, `quick-task`, `reassess-roadmap`, `reconcile`, `resume-session`, `slice-milestone`, `spawn-milestone-team`, `summarize-task`, `coordinate`, `finish-lane`, `handover-step`, `lane-retro`, `visual-review`, `signal-intake`, `incident` |
| superpowers wrapper | a render-time block that prints `vendor/superpowers/skills/<src>/SKILL.md`, plus `## ytstack invocation notes` and `## Namespace note` | `code-review` (two vendored skills), `finish-branch`, `grill`, `systematic-debugging`, `test-driven-development`, `verification-before-completion` |
| gstack wrapper | `yt_gstack_ctx` precheck, `## HARD-GATE: gstack installed?`, the sentence "Invoke the Skill tool with `<name>`" | `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship`, `document-release` |
| Directive | `metadata.kind: directive`, `user-invocable: false` | `using-ytstack`, `minimal-code` |
| Reference | `metadata.kind: reference`, `user-invocable: true` | `atomic-design`, `deutschland-stack-api`, `european-alternatives-api`, `oss-project`, `software-craftsmanship` |

- **Selection.** `hooks/session-start` injects the full text of `skills/using-ytstack/SKILL.md` at every session start. The agent matches the user's intent against each skill's `description` and invokes the skill through the Skill tool. There is no trigger table; `metadata.triggers` is documentation.
- **No chaining.** A procedure skill ends by returning control and naming the next skill. It does not invoke it. The one exception is `autonomy: loop` (below).
- **Gates.** A procedure skill stops with a message that names the skill to run first when its prerequisite artifact is missing. `plan-task` and `summarize-task` also run `yt_state_lint` and stop on a malformed `STATE.md` pointer.
- **superpowers wrappers** render the vendored text when the skill loads, after a context block and the invocation notes. The wrapper says where the output goes in `.ytstack/`; the vendored file is never edited.
- **gstack wrappers** stop and print `GSTACK_INSTALL_CMD` when gstack is not installed, warn once when the installed version is below the pin or bun is below the minimum, then invoke the installed gstack skill and write the result as a ytstack artifact. Nothing from gstack is inlined.

### Shared preamble

Every native procedure and every wrapper starts its first shell block with the resolver block from `docs/ux/skill-structure.md` ("Resolver contract"). Directives and references have no preamble. The block sources `hooks/lib/git-ctx.sh` and calls:

- `yt_git_ctx "$PWD"`: the checkout is where the shell runs. It yields the toplevel, whether this is a linked worktree, and a repo key (a hash of the git common dir, shared by all worktrees of a repository).
- `yt_resolve_yt_dir`: `<toplevel>/.ytstack` if it exists (project scope), otherwise `~/.ytstack/projects/<repo key>` (user scope), otherwise none.

Further lib functions the preambles call: `yt_prefs`, `yt_state_lint`, `yt_commit_ref_pattern`, `yt_task_commits`, `yt_find_artifacts`, `yt_brownfield_signals`, `yt_gstack_ctx`, `yt_gstack_skill_ok`, `yt_ensure_gitignore`, `yt_state_base`.

When the host does not substitute `${CLAUDE_SKILL_DIR}`, the block's fallback branch resolves project scope only. Lib-only values then print as defaults or `unknown`, and user scope is not found.

A preamble prints `KEY: value` lines. The procedure refers to them by name. Each preamble prints the flags its own procedure uses; `HAS_YTSTACK` is the only one all of them print.

### Ceremony preferences

Read from `PREFERENCES.md` in the resolved `.ytstack` directory by `yt_prefs` in `hooks/lib/git-ctx.sh`, which defines the accepted values and defaults. An invalid value falls back to the default and is reported as `PREF_WARNINGS`.

| Key | What it switches | Where |
|---|---|---|
| `granularity` | The smallest unit that gets a plan and a summary. Below `task`, `plan-task` appends the plan sections to the slice plan (or the milestone roadmap) and sets `active_task: all`; `summarize-task` writes one summary per slice or milestone; at `milestone`, `slice-milestone` writes a single slice. | `plan-task`, `summarize-task`, `slice-milestone` |
| `autonomy` | `loop`: inside a slice, `plan-task` continues into `test-driven-development`, `verification-before-completion` and `summarize-task`, and `summarize-task` continues with the next `plan-task`, without asking. It stops at the slice boundary and at every gate. `step`: every skill returns control. `slice-milestone` never chains. | `using-ytstack`, `plan-task`, `summarize-task` |
| `quick_lane` | `off`: `quick-task` stops at its gate and points at `plan-task`. `on`: `using-ytstack` routes one-sentence changes with a known cause to `quick-task`. | `quick-task`, `using-ytstack` |
| `minimal_code` | `on`: `hooks/session-start` adds a pointer that tells the agent to load `minimal-code` before writing code or adding a check, and the TDD wrapper applies its ladder in the GREEN step. `off`: no pointer. A rendered brief carries the contract in both cases. | `hooks/session-start`, `test-driven-development`, `bin/ytstack-brief` |
| `team` | `off`: `spawn-milestone-team` dispatches worktree subagents. `on`: it emits an Agent Teams instruction and requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. | `spawn-milestone-team` |
| `merge_by` | `risk` (default): the coordinator merges when `bin/ytstack-risk route` says `unattended` and the host's gates hold, otherwise a person. `human`: always a person. `coordinator`: always the coordinator. A value outside the three reads as `human`. | `finish-lane` |
| `evidence_dir` | Where a visual review stores its screenshots, default `.ytstack/evidence`, relative to the main checkout. | `visual-review`, `bin/ytstack-risk`, `bin/ytstack-finish-lane` |

### Non-interactive mode

`adopt-brownfield`, `init-project`, `plan-milestone`, `plan-task`, `reassess-roadmap`, `slice-milestone` and `summarize-task` print `YTSTACK_NON_INTERACTIVE: true` when `YTSTACK_NON_INTERACTIVE`, `OPENCLAW_SESSION` or `CLAUDE_AGENT_TEAM_MEMBER` is set to any non-empty value. Then:

- `init-project` picks project scope; `adopt-brownfield` picks the recommended handling per slot; `plan-milestone` takes the goal from the prompt and picks size M. Each pick is logged in one line.
- `plan-task`, `summarize-task` and `reassess-roadmap` skip their writes to the `STATE.md` pointer fields and still update `last_updated` and the status line.

No other skill reads the flag.

### Agents and parallel dispatch

| Agent | Works in | Does | Never |
|---|---|---|---|
| `architect` | main checkout, read-only | reviews slice plans against `DECISIONS.md`, `KNOWLEDGE.md` and the code; verdict approved, approved with caveats or rejected | writes code, re-plans |
| `implementer` | own worktree, branch `ytstack/M###-S##` | one slice: per task `plan-task`, `test-driven-development`, `verification-before-completion`, `summarize-task`, commits with the task ref, then reports | merges, pushes, edits outside the plan's Files section |
| `verifier` | fresh worktree on the slice branch | runs every task plan's verification command and compares it with the summary; checks the plan's spec impact against the area file of the touched code; verdict pass, pass with caveats or fail per task | edits anything, re-runs until green, reads areas the task did not touch |

`spawn-milestone-team` runs in the main session as orchestrator and does not edit source files. It refuses a dirty tree (the lanes file it writes itself does not count) and a linked worktree, asks before dispatching slices that name the same file, claims and dispatches one implementer per ready slice, then one verifier per finished slice. A fail sends the slice back to an implementer on the same branch; two fails in a row stop the run. Depending on the answer to its dispatch question it merges accepted branches with `git merge --no-ff` or leaves them. It never pushes.

### The technical spec in the loop

- `plan-task` works out a task's spec impact from the area files that cover the planned files; `summarize-task` does not close a task whose named area was not updated ([artifacts.md](artifacts.md)).
- `code-review` gives the reviewer the plan's "Spec impact" and the area files of the changed paths. The reviewer reads those against the diff and nothing else of the spec. The verifier does the same for the task it verifies.
- `reassess-roadmap` answers the drift report of `bin/ytstack-spec` at the slice boundary, once per area: correct the description, or set `verified_at`.
- `resume-session`, `handoff-session` and the SessionStart injection name `spec/SPEC.md`; they do not restate it. `quick-task` corrects an area file only when the change made a statement in it false.

### The work contract

`skills/minimal-code/SKILL.md` is the one text that says how much work is enough: the smallest complete change and the smallest sufficient evidence. The other skills apply it at their decision point and do not restate it.

- **Dispatch.** `bin/ytstack-brief render` builds a worker's brief from the plan files and includes the body of `minimal-code` verbatim. `spawn-milestone-team` dispatches with that text and checks the worker's report with `bin/ytstack-brief check` before a verifier runs. A brief has a kind (`implement`, `review`, `prepare`) that says what the worker may do. The report has the fixed labels of `docs/ux/coordinator-format.md` ("The report"), among them `Status:` (complete, partial, blocked), "Not checked:" and `Next:`.
- **Plan.** A task plan's Verification section names the command, `Runs:` and `Environment:`. What work cannot produce is a gate line under `## Gates` (what, who decides, how, when it lapses). A gate never holds a task open.
- **Slice boundary.** `reassess-roadmap` collects the open gates of the milestone and work that repeats without advancing (three or more review rounds on a task), puts them to the human in one question, records only what was answered, and reports two numbers: slices closed by work and slices accepted. In non-interactive mode it asks nothing and records nothing.
- **Review.** `code-review` counts rounds from the `## Review` lines in the task plan. Round 1 reviews the whole change, round 2 the fix, and from round 3 no reviewer is dispatched: the skill diagnoses scope, conflicting rules or solution and asks the human. The reviewer states the assumed load, gives a concrete case and "If skipped" per finding and follows the project's severity policy.
- **Evidence.** A result is a check on a commit in an environment. `verification-before-completion` runs the plan's command as often as the plan says and notes the commit. The verifier makes one independent run per commit and cites an earlier verdict when the task's files are unchanged since. `summarize-task` records check, commit and environment and does not run the check again.
- **Tests.** The TDD wrapper writes a failing test first for logic and bug fixes; a trivial change gets none. `systematic-debugging` treats a test that fails only sometimes as a question of whose defect it is: reproduced on the base commit it becomes a tracked follow-up, otherwise it is the change's defect; the required check still has to turn green.
- **The running product.** A plan whose result shows only at the running product names `Environment: instance from bin/ytstack-runtime up` (`plan-task`). `verification-before-completion`, the implementer and the verifier start the instance with `up`, check against its `URL:`, note its `COMMIT:` line and stop it with `down`. Without a "Run" section, or when `up` fails, the check is reported as not possible and never claimed; the verifier gives such a task no PASS.
- **Handoff.** `handoff-session` points instead of copying and names under "Suggested skills" the one or two skills the next session should start with.

### Coordinating many lanes

Formats: `docs/ux/coordinator-format.md`. The four skills below are for the session that owns a plan and delegates all of it; none of them writes product code.

- `coordinate` is a loop with a fixed order: start from `STANDING.md`, `LANES.md`, the frontier and the questions (never from a conversation summary), read host facts fresh and stamp them with their read time, claim a lane before dispatching it, finish lanes through `finish-lane`, poll through `bin/ytstack-watch`, ask one question at a time from a question file, write a standing instruction down when it is given, stop a lane that failed verification twice or needs a third review, and rotate through a handoff after the first compaction.
- `spawn-milestone-team` claims each lane with `bin/ytstack-frontier` before it dispatches, keeps the lane's row current, and looks at the frontier again whenever a lane is verified or merged.
- `finish-lane` takes a reported lane to a merged pull request with `bin/ytstack-finish-lane`: review pinned to the host's head, the required lenses, `route`, the gates read from the host, the merge decided by `merge_by` and the route, then `bin/ytstack-watch release` on the merge commit when `RUNTIME.md` has a "Release" section (in the background; the receipt goes into the report, nothing is rolled back). A merge without a person is reported in one line with class, ceiling and lenses. The pipeline supports GitHub through `gh` only; on another host the skill stops after the route.
- **The class of a change.** `code-review` prints the floor of `bin/ytstack-risk` and has a reviewer that is not the author end with `Risk:`, `Severity:`, `Reach:` and `Invariants touched:`, read against "Invariants and security boundaries" and "Decisions that apply now" of the touched areas, also when only code moved. The round line records class, invariants and reviewer; a session reviewing its own change writes `by: self`, which routes to a person. Each lens the floor names gets a separate fresh reviewer with the lens brief (`bin/ytstack-brief render --kind review --lens <name>`) and one lens line.
- `visual-review` is the lens reviewer of a user interface change: its own worktree at the reviewed commit, `bin/ytstack-runtime up`, a browser tool that renders and returns screenshots, its own screenshots of the changed views, states and two widths, reviewed against the lens documents; evidence with `MANIFEST` in the main checkout. It is `not run`, never `pass`, when the reviewer is the author, a document or the "Run" section is missing, the product does not come up or no browser tool exists. It edits no product file.
- `signal-intake` reads every source of "Signals" once with its read time, separates findings from noise by stated rules, records through `bin/ytstack-signals new` (an unreadable source is a finding too) and changes nothing else. `incident` puts the mitigation before the cause: facts with read times, timeline, hypotheses, mitigations as handover scripts it never runs, one question at a time, and never picks a mitigation without a person; the cause goes to `systematic-debugging` afterwards.
- `handover-step` writes a step only the human may perform as one staged script from `skills/handover-step/template.sh`, checks it with `bin/ytstack-handover check` and never runs it. In the script one typed yes carries one change: every `mutate` takes a `confirm` of its own. The place is `handover_dir:` in `PREFERENCES.md`.
- `lane-retro` samples finished lanes in six fixed categories and proposes, per candidate, a check that replaces an instruction line or a pointer that replaces a search. It implements nothing itself.
- `reassess-roadmap` carries a gate that needs a person's verdict as a question file when the project keeps `questions/`, folds a closed milestone into the area files, and names the archive offer of `reconcile`.

## Interfaces and contracts

- `docs/ux/skill-structure.md`: frontmatter, required sections, the resolver block, banned preamble patterns, terminal state, artifact states.
- `docs/ux/askuserquestion-format.md`: the four-part question body, option annotations, tiers.
- `docs/ux/agent-structure.md`: agent frontmatter, body sections, size limit.
- `hooks/lib/git-ctx.sh`: the comment above each function names the globals it sets. `YT_GSTACK_PIN` and `YT_BUN_MIN` there are the gstack pin and the bun minimum.
- The worker brief and the report shape: `skills/spawn-milestone-team/brief-template.md`, rendered by `bin/ytstack-brief`. Dispatch, report check and verifier prompt: `skills/spawn-milestone-team/SKILL.md`, Steps 5 to 7.
- The artifacts skills read and write: [artifacts.md](artifacts.md).

## Invariants and security boundaries

- `vendor/**` is never edited. Different behavior goes into the wrapper.
- gstack is never vendored or inlined. `bin/ytstack-check` fails a gstack wrapper that references `vendor/gstack` or lacks the precheck, the install command, the Skill-tool sentence or the gate.
- No preamble uses the banned patterns listed in `docs/ux/skill-structure.md`; `bin/ytstack-check` fails on them and on a shell preamble that does not source the lib.
- Skills and agents never delete, move or revert `.ytstack/` artifacts. `reconcile` is the only skill that moves them, and it asks first.
- No skill merges to a shared branch, pushes or opens a pull request unless the user asked for it (`ship`, `finish-branch`).
- Directives are not user-invocable.

## Error behavior

- Missing prerequisite: the skill prints which skill to run and stops. Nothing is written.
- `summarize-task` with a failed verification: no summary, the task stays open.
- Cancelled question in `adopt-brownfield`: nothing is written.
- gstack missing: the wrapper stops with the install command and does not improvise the procedure.
- Lib not loaded: the fallback branch runs; see "Shared preamble".

## Known limits

- `bin/ytstack-check` enforces part of the contracts; the rules are the `check_*` functions named under "Where implemented". For skills it fails on frontmatter name and description, a missing `## Checklist` or `## Terminal State` in a procedure skill, and the resolver and wrapper rules. It only warns on em-dashes in skill prose, missing recommended sections and missing `metadata.tier` or `metadata.version`. It does not check `AskUserQuestion` bodies, the set of preamble flags, `dot` syntax, `HARD-GATE` tag balance or skill file size. Those stay review items.
- The `depends-on` frontmatter and the `DEPS_OK` flag in `docs/ux/skill-structure.md` are not used by any skill.
- `explain_level`: two preambles print `EXPLAIN_LEVEL` from `~/.ytstack/config`. No code switches on it, and `yt_prefs` does not read the `explain_level` line in `PREFERENCES.md`.
- Unknown -- how the open-ended questions of `plan-task`, `slice-milestone` and `summarize-task` are answered in non-interactive mode. The skills define no answer source for them.
- Unknown -- whether an implementer's `AskUserQuestion` calls reach the user from a worktree subagent. The brief does not set `YTSTACK_NON_INTERACTIVE`.
- Under `merge_by: risk` only the hard gate of `finish-lane` keeps a session from calling `bin/ytstack-finish-lane merge` after `route: person`; the script's `merge` does not read the route. Whether a screenshot was taken by the reviewer and not copied is the hard gate of `visual-review`; the script checks hashes and names.
- `visual-review`, `signal-intake`, `incident` and the route in `finish-lane` have not run in a real session; no change has merged without a person yet. Which browser tool a host offers a dispatched reviewer is unknown before such a run.

## Where implemented

- `skills/<name>/SKILL.md`, one directory per skill; `agents/architect.md`, `agents/implementer.md`, `agents/verifier.md`.
- `hooks/lib/git-ctx.sh`: resolver, preferences, gstack precheck.
- `hooks/session-start`: injection of `using-ytstack` and the `minimal-code` pointer.
- `vendor/superpowers/skills/`: the inlined procedures.
- `bin/ytstack-check`: `check_skill`, `check_agent`, `check_cross_refs`, `check_resolver_contract`, `check_inline_leaks`, `check_gstack_wrappers`.
- Tests: `tests/skill-preambles.test.sh` (every preamble in a main checkout and a linked worktree, preference flags, fallback branch), `tests/ytstack-check.test.sh` (checker rules), `tests/git-ctx.test.sh` (resolver, `yt_prefs`, `yt_gstack_ctx`), `tests/hooks-readonly.test.sh` (injection size, `minimal_code` pointer).
- `evals/`: one trigger and outcome case per lifecycle skill, see `evals/README.md`.

## How to verify

- `bin/ytstack-check`: exit code 0 or 2, no `[fail]` line, last line starts with `OK`.
- `bash tests/skill-preambles.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/ytstack-check.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/git-ctx.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/run-all.sh`: last line `ALL SUITES PASSED`.

## Decisions that apply now

- DECISIONS.md -- "2026-11-13: Whether a person looks at a change is decided per change: a floor from the diff, the class an independent reviewer states, a ceiling per area, lenses per kind of change (M025)" (narrows the `merge_by: human` default of the M024 entry to `risk`)
- DECISIONS.md -- "2026-11-13: `RUNTIME.md` has three sections with a fixed line format, read only through `bin/ytstack-runtime` (M025-S01)"
- DECISIONS.md -- "2026-11-13: After a merge the release is watched, not driven; upkeep is a script and a recipe, not a skill (M026)"
- DECISIONS.md -- "2026-11-13: Production findings and incidents are skill work on read-only access; a mitigation is a handover script a person runs (M027)"
- DECISIONS.md -- "2026-04-23: Skills-based plugin, not Agent SDK library"
- DECISIONS.md -- "2026-04-23: UX contracts enforced by CI, not convention"
- DECISIONS.md -- "2026-04-23: Accept Agent Teams experimental status as known risk" (applies to `team: on`)
- DECISIONS.md -- "2026-04-24: Add `using-ytstack` skill + SessionStart-hook-injected directive for agent-driven skill selection"
- DECISIONS.md -- "2026-04-24: Skill selection is semantic (description-based), not keyword-based" (narrows the entry above: no trigger map)
- DECISIONS.md -- "2026-04-24: User-facing skill count is flat, one SKILL.md = one skill"
- DECISIONS.md -- "2026-04-24: Greenfield-flow reorder -- office-hours → plan-ceo-review → [plan-eng-review] → init-project → plan-milestone"
- DECISIONS.md -- "2026-04-24: Wrapper mechanism = shell-exec inject + cross-ref check"
- DECISIONS.md -- "2026-04-25: Vendored-preamble drift accepted for wrapped skills" (superpowers wrappers only)
- DECISIONS.md -- "2026-04-25: Lifecycle-phase as the curation heuristic"
- DECISIONS.md -- "2026-05-31: Add `kind: reference` skill class (exempt from procedure-section contract)"
- DECISIONS.md -- "2026-05-31: ytstack encourages git worktree isolation for parallel swarm execution"
- DECISIONS.md -- "2026-05-31: Swarm commit discipline -- lead commits path-scoped, teammates do not (M012)" (shared-tree mode under `team: on` only)
- DECISIONS.md -- "2026-11-07: Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency" (narrows the wrapper mechanism to superpowers; gstack wrappers invoke the installed skill)
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree" (source of the resolver contract)
- DECISIONS.md -- "2026-11-07: Ceremony scales with the change -- granularity, autonomy, quick lane and minimal-code guard are project preferences with loud defaults"
- DECISIONS.md -- "2026-11-07: Brownfield adoption is a reference-first distillation, never a pitch" (narrows the greenfield flow: an existing codebase skips the pitch)
- DECISIONS.md -- "2026-10-13: Remove generated Codex copies; load the existing skills directly" (one skill tree for both hosts)
- DECISIONS.md -- "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)" (the spec steps in the loop)
- DECISIONS.md -- "2026-11-13: Verification, review and orchestration work are bounded like code (M023, issue #35)" (the work contract; extends the ceremony entry of 2026-11-07 from code to evidence and review)
- DECISIONS.md -- "2026-11-13: Coordinator mode keeps lanes, questions and standing instructions in files and reads host facts fresh (M024, issue #34)"
- DECISIONS.md -- "2026-11-13: `STATE.md` is a pointer with a size bound; history leaves it through `reconcile`, a closed milestone is folded into the spec (M022-S03)"

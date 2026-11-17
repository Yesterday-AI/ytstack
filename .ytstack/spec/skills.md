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
verified_at: 4ef4811
---

# skills

## Purpose

The skill tree (`skills/*/SKILL.md`) and the agent definitions (`agents/*.md`): the procedures an agent loads through the Skill tool and the three roles dispatched through the Agent tool. Section layout, question format and agent format are defined in the three `sources`. This file holds what they lack: the skill classes, the shared preamble, the ceremony preferences, the non-interactive mode and the agents' division of work. The files a skill writes are described in [artifacts.md](artifacts.md).

## Behavior

### Skill classes

| Class | Mark in the file | Members |
|---|---|---|
| Native procedure | no `metadata.kind`; own `## Preamble` with a `bash` block, `## Checklist`, `## Terminal State` | `adopt-brownfield`, `handoff-session`, `init-project`, `plan-milestone`, `plan-task`, `quick-task`, `reassess-roadmap`, `reconcile`, `resume-session`, `slice-milestone`, `spawn-milestone-team`, `summarize-task`, `coordinate`, `finish-lane`, `handover-step`, `lane-retro`, `visual-review`, `signal-intake`, `incident`, `review-lessons`, `lesson` |
| superpowers wrapper | a render-time block that prints `vendor/superpowers/skills/<src>/SKILL.md`, plus `## ytstack invocation notes` and `## Namespace note` | `code-review` (two vendored skills), `finish-branch`, `grill`, `systematic-debugging`, `test-driven-development`, `verification-before-completion` |
| Adapted from gstack | a native procedure with `metadata.upstream` (the gstack release it follows); no gstack runtime reference | `office-hours`, `plan-ceo-review`, `plan-eng-review`, `retro`, `ship`, `document-release` |
| Directive | `metadata.kind: directive`, `user-invocable: false` | `using-ytstack`, `minimal-code` |
| Reference | `metadata.kind: reference`, `user-invocable: true` | `atomic-design`, `deutschland-stack-api`, `european-alternatives-api`, `oss-project`, `software-craftsmanship` |

- **Selection.** `hooks/session-start` injects the full text of `skills/using-ytstack/SKILL.md` at every session start. The agent matches the user's intent against each skill's `description` and invokes the skill through the Skill tool. There is no trigger table; `metadata.triggers` is documentation.
- **No chaining.** A procedure skill ends by returning control and naming the next skill. It does not invoke it. The exceptions are `autonomy: loop` (below), `finish-lane`, which invokes `review-lessons` after a merge it made (M030), and the lesson step (M032): `incident` (once mitigated), `systematic-debugging` (once the cause is known), `finish-lane` (a review that requested changes, a failed lens or check) and `coordinate` (a red `main`, a slip) invoke `lesson`, which returns to them.
- **Gates.** A procedure skill stops with a message that names the skill to run first when its prerequisite artifact is missing. `plan-task` and `summarize-task` also run `yt_state_lint` and stop on a malformed `STATE.md` pointer.
- **superpowers wrappers** render the vendored text when the skill loads, after a context block and the invocation notes. The wrapper says where the output goes in `.ytstack/`; the vendored file is never edited.
- **Adapted gstack skills** carry the method in their own `SKILL.md` (and optional `references/*.md`), run the standard preamble, need only bash, git and gh, and write ytstack artifacts. The optional outside voice of `plan-ceo-review` and `plan-eng-review` is a fresh-context subagent. They are kept in sync with upstream through `bin/ytstack-gstack-diff` ([dependencies.md](dependencies.md)).

### Shared preamble

Every native procedure and every wrapper starts its first shell block with the resolver block from `docs/ux/skill-structure.md` ("Resolver contract"). Directives and references have no preamble. The block sources `hooks/lib/git-ctx.sh` and calls:

- `yt_git_ctx "$PWD"`: the checkout is where the shell runs. It yields the toplevel, whether this is a linked worktree, and a repo key (a hash of the git common dir, shared by all worktrees of a repository).
- `yt_resolve_yt_dir`: `<toplevel>/.ytstack` if it exists (project scope), otherwise `~/.ytstack/projects/<repo key>` (user scope), otherwise none.

Further lib functions the preambles call: `yt_prefs`, `yt_state_lint`, `yt_commit_ref_pattern`, `yt_task_commits`, `yt_find_artifacts`, `yt_artifact_dir`, `yt_artifact_path`, `yt_brownfield_signals`, `yt_ensure_gitignore`, `yt_state_base`. A skill that writes or reads a milestone's files prints `ARTIFACT_DIR`, the directory the milestone already lives in (flat, or `milestones/M###/`, see [artifacts.md](artifacts.md)), and writes its new files there. A skill that counts or lists a milestone's files (`reassess-roadmap`, `retro`, `spawn-milestone-team`, `plan-eng-review`) reads every layout through `yt_find_artifacts`, one file per name. Shell parameters in skill text are written `${1}`, awk fields `$ 1`, because Kimi expands `$1` in loaded skill text.

When the host does not substitute `${CLAUDE_SKILL_DIR}`, the block's fallback branch resolves project scope only. Lib-only values then print as defaults or `unknown`, `ARTIFACT_DIR` is the flat directory, and user scope is not found.

A preamble prints `KEY: value` lines. The procedure refers to them by name. Each preamble prints the flags its own procedure uses; `HAS_YTSTACK` is the only one all of them print.

### Ceremony preferences

Read from `PREFERENCES.md` in the resolved `.ytstack` directory by `yt_prefs` in `hooks/lib/git-ctx.sh`, which defines the accepted values and defaults. An invalid value falls back to the default and is reported as `PREF_WARNINGS`.

| Key | What it switches | Where |
|---|---|---|
| `granularity` | The smallest unit that gets a plan and a summary. Below `task`, `plan-task` appends the plan sections to the slice plan (or the milestone roadmap) and sets `active_task: all`; `summarize-task` writes one summary per slice or milestone; at `milestone`, `slice-milestone` writes a single slice. | `plan-task`, `summarize-task`, `slice-milestone` |
| `autonomy` | `loop`: inside a slice, `plan-task` continues into `test-driven-development`, `verification-before-completion` and `summarize-task`, and `summarize-task` continues with the next `plan-task`, without asking. It stops at the slice boundary and at every gate. `step`: every skill returns control. `slice-milestone` never chains. | `using-ytstack`, `plan-task`, `summarize-task` |
| `quick_lane` | `off`: `quick-task` stops at its gate and points at `plan-task`. `on`: `using-ytstack` routes one-sentence changes with a known cause to `quick-task`. | `quick-task`, `using-ytstack` |
| `minimal_code` | `on`: `hooks/session-start` adds a pointer that tells the agent to load `minimal-code` before writing code or adding a check, and the TDD wrapper applies its ladder in the GREEN step. `off`: no pointer. A rendered brief carries the contract in both cases. | `hooks/session-start`, `test-driven-development`, `bin/ytstack-brief` |
| `team` | `off`: `spawn-milestone-team` dispatches worktree subagents. `on`: it emits an Agent Teams instruction and requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; each teammate is named after its slice (`impl-M004-S02`), which `hooks/teammate-idle` reads as the teammate's lane. | `spawn-milestone-team` |
| `merge_by` | `risk` (default): the coordinator merges when `bin/ytstack-risk route` says `unattended` and the host's gates hold, otherwise a person. `human`: always a person. `coordinator`: always the coordinator, except that a `reason: spec` line of the route sends the lane back to the worker first. A value outside the three reads as `human`. | `finish-lane` |
| `evidence_dir` | Where a visual review stores its screenshots, default `.ytstack/evidence`, relative to the main checkout. | `visual-review`, `bin/ytstack-risk`, `bin/ytstack-finish-lane` |
| `escalate` | What a coordinator brings to a person (`docs/ux/coordinator-format.md`, "Who decides"): a comma separated subset of `violation`, `deviation`, `irreversible`, `secret`, `spend`, default all five; `reserved` (a plan line that says verdict, approval or sign-off, or a standing entry) always holds. Everything else the coordinator decides and records in `DECISIONS.md`. A value with an item outside the five reads as all five. | `coordinate` (preamble `ESCALATE`, Step 8), `bin/ytstack-questions new` |
| `upstream_feedback` | What concerns ytstack itself (`docs/ux/upstream-feedback.md`). `suggest` (default): a draft checked by `bin/ytstack-upstream check`, shown to the person, nothing sent. `file`: searched, then filed or commented at Yesterday-AI/ytstack with `gh`; without a `gh` login, or in a non-interactive, CI or teammate session, it reads as `suggest`. `off`: nothing. Without the key, the last `upstream_feedback=` line of `~/.ytstack/config`; an invalid value reads as `suggest`. `using-ytstack` names the channel at every session start. | `using-ytstack`, `retro`, `lane-retro`, `lesson`, `bin/ytstack-upstream` |

### Non-interactive mode

`adopt-brownfield`, `init-project`, `plan-milestone`, `plan-task`, `reassess-roadmap`, `slice-milestone` and `summarize-task` print `YTSTACK_NON_INTERACTIVE: true` when `YTSTACK_NON_INTERACTIVE`, `OPENCLAW_SESSION` or `CLAUDE_AGENT_TEAM_MEMBER` is set to any non-empty value. Then:

- `init-project` picks project scope; `adopt-brownfield` picks the recommended handling per slot; `plan-milestone` takes the goal from the prompt and picks size M. Each pick is logged in one line.
- `plan-task`, `summarize-task` and `reassess-roadmap` skip their writes to the `STATE.md` pointer fields and still update `last_updated` and the status line.
- `retro`, `lane-retro` and `lesson`, which read the flag too, send nothing upstream under any `upstream_feedback`; their drafts wait for a person.

### Agents and parallel dispatch

| Agent | Works in | Does | Never |
|---|---|---|---|
| `architect` | main checkout, read-only | reviews slice plans against `DECISIONS.md`, `KNOWLEDGE.md` and the code; verdict approved, approved with caveats or rejected | writes code, re-plans |
| `implementer` | own worktree, branch `ytstack/M###-S##` | one slice: per task `plan-task`, `test-driven-development`, `verification-before-completion`, `summarize-task`, commits with the task ref, then reports | merges, pushes, edits outside the plan's Files section |
| `verifier` | fresh worktree on the slice branch | runs every task plan's verification command and compares it with the summary; checks the plan's spec impact against the area file of the touched code; verdict pass, pass with caveats or fail per task | edits anything, re-runs until green, reads areas the task did not touch |

`spawn-milestone-team` runs in the main session as orchestrator and does not edit source files. It refuses a dirty tree (the lanes file it writes itself does not count) and a linked worktree, asks before dispatching slices that name the same file, claims and dispatches one implementer per ready slice, then one verifier per finished slice. A fail sends the slice back to an implementer on the same branch; two fails in a row stop the run. Depending on the answer to its dispatch question it merges accepted branches with `git merge --no-ff` or leaves them. It never pushes.

### The technical spec in the loop

- `plan-task` works out a task's spec impact from the area files that cover the planned files; `summarize-task` does not close a task whose named area was not updated ([artifacts.md](artifacts.md)).
- `code-review` gives the reviewer the plan's "Spec impact" and the area files of the changed paths. The reviewer reads those against the diff and nothing else of the spec; with a `## Checks` section in `REVIEW.md`, a guard the diff adds or changes without its line there is a finding too. The verifier does the same for the task it verifies.
- `reassess-roadmap` answers the drift report of `bin/ytstack-spec` at the slice boundary, once per area: correct the description, or set `verified_at`.
- `resume-session`, `handoff-session` and the SessionStart injection name `spec/SPEC.md`; they do not restate it. `quick-task` corrects an area file only when the change made a statement in it false.

### The work contract

`skills/minimal-code/SKILL.md` is the one text that says how much work is enough: the smallest complete change and the smallest sufficient evidence. The other skills apply it at their decision point and do not restate it.

- **Dispatch.** `bin/ytstack-brief render` builds a worker's brief from the plan files and includes the body of `minimal-code` verbatim. `spawn-milestone-team` dispatches with that text and checks the worker's report with `bin/ytstack-brief check` before a verifier runs. A brief has a kind (`implement`, `review`, `prepare`) that says what the worker may do. The report has the fixed labels of `docs/ux/coordinator-format.md` ("The report"), among them `Status:` (complete, partial, blocked), "Not checked:", `Next:` and `Spec:`, the spec delta: the edited sections as `<area>: <file> (<section>)` or `none -- <reason>`; the brief's "Spec impact" section makes editing the section a change makes false a duty. A task its slice plan lists without a task plan gets a plan-first brief: its first deliverable is the task plan in `plan-task`'s format, committed alone; a slice plan with its own `## Files` stands in for its tasks' plans.
- **Plan.** A task plan's Verification section names the command, `Runs:` and `Environment:`. What work cannot produce is a gate line under `## Gates` (what, who decides, how, when it lapses). A gate never holds a task open.
- **Slice boundary.** `reassess-roadmap` collects the open gates of the milestone and work that repeats without advancing (three or more review rounds on a task), puts them to the human in one question, records only what was answered, and reports two numbers: slices closed by work and slices accepted. In non-interactive mode it asks nothing and records nothing.
- **Review.** `code-review` counts rounds from the `## Review` lines in the task plan. Round 1 reviews the whole change, round 2 the fix, and from round 3 no reviewer is dispatched: the skill diagnoses scope, conflicting rules or solution and asks the human. The reviewer states the assumed load, gives a concrete case and "If skipped" per finding and follows the project's severity policy.
- **Evidence.** A result is a check on a commit in an environment. `verification-before-completion` runs the plan's command as often as the plan says and notes the commit. The verifier makes one independent run per commit and cites an earlier verdict only for the same commit, environment and command; on another commit it runs again, because a check reads files its plan does not name. `summarize-task` records check, commit and environment and does not run the check again.
- **Tests.** The TDD wrapper writes a failing test first for logic and bug fixes; a trivial change gets none. `systematic-debugging` treats a test that fails only sometimes as a question of whose defect it is: reproduced on the base commit it becomes a tracked follow-up, otherwise it is the change's defect; the required check still has to turn green.
- **The running product.** A plan whose result shows only at the running product names `Environment: instance from bin/ytstack-runtime up` (`plan-task`). `verification-before-completion`, the implementer and the verifier start the instance with `up`, check against its `URL:`, note its `COMMIT:` line and stop it with `down`. Without a "Run" section, or when `up` fails, the check is reported as not possible and never claimed; the verifier gives such a task no PASS.
- **Handoff.** `handoff-session` points instead of copying and names under "Suggested skills" the one or two skills the next session should start with.

### Coordinating many lanes

Formats: `docs/ux/coordinator-format.md`. The four skills below are for the session that owns a plan and delegates all of it; none of them writes product code.

- `coordinate` is a loop with a fixed order: start from the standing instructions (the entries of `standing/` in the resolved `YT_DIR`, project or user scope, newest first without superseded ones, and `STANDING.md`), `LANES.md`, the frontier and the questions (never from a conversation summary), read host facts fresh and stamp them with their read time, claim a lane before dispatching it, finish lanes through `finish-lane`, run the factory tools of Step 7 (one table of command, when and skip condition; the preamble prints `MERGE_BY`, `REVIEW_POLICY`, `OWN_REVIEWERS`, `PR_WATCH` with the heartbeat age, `RELEASE` and `SIGNALS`, and `YT_BIN=<dir>`, through which it runs every bin): the route before every merge, also one it makes itself outside `finish-lane` (then through `ytstack-finish-lane merge` and `finish-lane`'s rule of who merges), with the PR watch on (flag set and a worker heartbeat under 10 minutes old) register the repository's open pull requests by its own GitHub login, without drafts and do-not-merge labels, to itself as their owning session (`ytstack-pr-watch register --all-open` without `--session`, at the start, after every restart or rotation and after a worker opened one) and otherwise poll through `bin/ytstack-watch`, `ytstack-watch release` after every merge to production, `signal-intake` / `incident` for signals and `review-lessons` after a merge with a bot finding, `lesson` on a red `main` and on every slip of a lane or its own (the open lessons in every status from the preamble's `LESSONS` line, a lesson proposal asked with the daily question, lesson lanes `lesson-F###` dispatched from the frontier with `ytstack-brief render --lesson` and set `fixed` after their merge), decide itself, and record in `DECISIONS.md`, what no plan line (only one that says verdict, approval or sign-off) and no standing entry reserves and no item of `escalate` (the preamble's `ESCALATE` line) names, write a question file with its class and item (`--decides <who> --because <item>`, or `--info <who>` for a fact) otherwise, ask one question at a time from a question file whose Context names its source and purpose, write a standing instruction down when it is given, before the next dispatch, with `ytstack-standing add` (a new file in `standing/` on the day's standing branch and pull request, `--here` in user scope; `STANDING.md` only where no `standing/` exists; agent memory is no substitute), close an ended one with `ytstack-standing end`, act on the ended, to-check and failed-check lines its preamble prints from `ytstack-standing list` (with the newest entry's age and the human prompts since), its preamble writes the coordinate session marker (the resolved `.ytstack` and the repository key) the coordinate-mode hooks act on, finds the automatic handoff through `yt_latest_handoff`, and prints the operating checklist of `docs/ux/coordinator-format.md` (the same block `session-start` injects), stop a lane that failed verification twice or needs a third review, and rotate after the first compaction in one step while lanes run: a handoff written from the files with the "Rotation" block of `docs/ux/coordinator-format.md` (PR watch session, background watches, each running worker's address), the successor's Step 3 takes the PR watches over with `ytstack-pr-watch handover --from <session>`, and the old session stays open only as a relay that appends its workers' reports to `HANDOFF.md`. It also prints the sessions in other repositories it works with between `PEERS_BEGIN` and `PEERS_END` (`ytstack-frontier peer list`, the `## Peers` lines of `LANES.md`), carries them under `Peers:` in the Rotation block, and takes progress per phase for a status from `ytstack-status --phases` (issues #81, #84). A pull request other lanes wait on is registered as a focus PR (`register --pr N --focus`, or `ytstack-watch --focus N`); on `STALL 1` it asks the holding lane once for an ETA, on `STALL 2` it releases the lane and claims a fresh worker on the same branch in a new worktree instead of relaying the same instruction again (issue #91). Every round of its loop starts with `ytstack-frontier check` in Step 5, and each `stale:` line (exit 2) gets its action in that round before any new dispatch. Its hard gate forbids closing a lane's pull request, reopening it to retrigger checks and deleting its branch: a cap counts pull requests ready for review and limits opening and dispatching, never a merge, and a lane that waits for it is `parked` with a draft pull request, a check reruns with `gh run rerun`; in Claude Code the coordinate hooks hint at this, at a dispatch without `isolation`, at `gh pr merge`, at a red `main` read with `gh run list`, and at rotation after a compaction (issue #83).
- `spawn-milestone-team` claims each lane with `bin/ytstack-frontier` before it dispatches, keeps the lane's row current, and looks at the frontier again whenever a lane is verified or merged.
- `finish-lane` takes a reported lane to a merged pull request with `bin/ytstack-finish-lane`: review pinned to the host's head, the required lenses, `route` with the worker's report (its spec delta is checked against the diff, so a lane that skipped `summarize-task` and changed an area without its description or a reason goes to a person, under `merge_by: coordinator` back to the worker; a `checks:` line notes a CI edit that the checks inventory of `REVIEW.md` did not follow and goes to the person who merges), the gates read from the host, the merge decided by `merge_by` and the route, then `bin/ytstack-watch release` on the merge commit when `RUNTIME.md` has a "Release" section (in the background; the receipt goes into the report, nothing is rolled back). A merge without a person is reported in one line with class, ceiling and lenses. After a merge it made itself, and when `REVIEW.md` declares own reviewers, it invokes `review-lessons` for the pull request. Before a lane goes back for a review that requested changes, a failed lens or a failed check, it invokes `lesson` (its Step 14). These two are the skills it may invoke. Its hard gate forbids closing the lane's pull request, reopening it to retrigger checks and deleting its branch; a cap counts pull requests ready for review and limits opening (`open-pr --max-open` opens a draft at the cap, the lane is `parked`), never a merge (issue #83). The pipeline supports GitHub through `gh` only; on another host the skill stops after the route.
- **The class of a change.** `code-review` prints the floor of `bin/ytstack-risk` and has a reviewer that is not the author end with `Risk:`, `Severity:`, `Reach:` and `Invariants touched:`, read against "Invariants and security boundaries" and "Decisions that apply now" of the touched areas, also when only code moved. The round line records class, invariants and reviewer; a session reviewing its own change writes `by: self`, which routes to a person. On a pull request `finish-lane` and `code-review` post the round and lens lines in the body of a review on the reviewed head, and `finish-lane` routes with `--pr`: the record needs no commit that would move the head away from a head-bound review. Each lens the floor names gets a separate fresh reviewer with the lens brief (`bin/ytstack-brief render --kind review --lens <name>`) and one lens line.
- `visual-review` is the lens reviewer of a user interface change: its own worktree at the reviewed commit, `bin/ytstack-runtime up`, a browser tool that renders and returns screenshots, its own screenshots of the changed views, states and two widths, reviewed against the lens documents; evidence with `MANIFEST` in the main checkout. It is `not run`, never `pass`, when the reviewer is the author, a document or the "Run" section is missing, the product does not come up or no browser tool exists. It edits no product file.
- `signal-intake` reads every source of "Signals" once with its read time, separates findings from noise by stated rules, records through `bin/ytstack-signals new` (an unreadable source is a finding too) and changes nothing else. `incident` puts the mitigation before the cause: facts with read times, timeline, hypotheses, mitigations as handover scripts it never runs, one question at a time, and never picks a mitigation without a person; once mitigated it records the lesson through `lesson` with `--incident`, and the cause goes to `systematic-debugging` afterwards, which records the cause's lesson the same way.
- `review-lessons` reads merged pull requests (the numbers given, or the `review checks` items of `bin/ytstack-upkeep`) with `bin/ytstack-review-escapes`, names the owning role of each `fixed` and `escaped` bot thread from the role files, records it with `bin/ytstack-signals new --kind review` and the check with `review-checked --tally` (caught/escaped per role, `-` for no owner), and at the threshold (second sighting of a class, or the first at critical or high severity as the bot states it) writes the exact line for the role file as a question file. An escape no role owns is only reported. It never edits a role file or a rule document and changes no finding's state. `retro` adds caught, escaped and the escape rate per role for the milestone window from those tallies (a line without one is "not recorded"), never from the host, and the incidents and repeats per class from `ytstack-signals lesson list --since <window start>` (a repeat: count 2 or more, or a lesson that reopens one). The owning role is the skill's judgment from the role files; no script checks it. `lesson` closes an incident of any class: one class line (area `production`, `ci`, `evidence`, `review` or `process`, a class slug, an existing one first), a target by the first rule that applies (a machine check; a proposal as a question file for agent behaviour or a rule; a `KNOWLEDGE.md` entry), recorded with `ytstack-signals lesson new` (`--incident` for a record), then put in place: the knowledge entry written, the check built where the caller may change code, otherwise `## Files` and `## Verification` in the finding for a lane; `fixed` only when the target exists. It never writes `AGENTS.md` or `CLAUDE.md`, never changes a rule file and never dismisses; it asks one question for a proposal only in an interactive session that is not a coordinator's. A class that is a behaviour of ytstack itself also goes upstream (its Step 8), and `retro` and `lane-retro` end with an "Upstream" section: what concerns ytstack, handled per `upstream_feedback` through `bin/ytstack-upstream` and `gh` (`docs/ux/upstream-feedback.md`); the skills point at that document and do not repeat its rules.
- `handover-step` writes a step only the human may perform as one staged script from `skills/handover-step/template.sh`, checks it with `bin/ytstack-handover check` and never runs it. In the script one typed yes carries one change: every `mutate` takes a `confirm` of its own. The place is `handover_dir:` in `PREFERENCES.md`.
- `lane-retro` samples finished lanes in six fixed categories and proposes, per candidate, a check that replaces an instruction line or a pointer that replaces a search. It implements nothing itself.
- `reassess-roadmap` carries a gate that needs a person's verdict as a question file when the project keeps `questions/`, folds a closed milestone into the area files, and names the archive offer of `reconcile`.

## Interfaces and contracts

- `docs/ux/skill-structure.md`: frontmatter, required sections, the resolver block, banned preamble patterns, terminal state, artifact states.
- `docs/ux/askuserquestion-format.md`: the four-part question body, option annotations, tiers. `docs/ux/agent-structure.md`: agent frontmatter, body sections, size limit.
- `hooks/lib/git-ctx.sh`: the comment above each function names the globals it sets.
- The worker brief and the report shape: `skills/spawn-milestone-team/brief-template.md`, rendered by `bin/ytstack-brief`; its "Standing instructions" carry the whole text of each entry for the lane's role, pending ones included. Dispatch, report check and verifier prompt: `skills/spawn-milestone-team/SKILL.md`, Steps 5 to 7.
- The artifacts skills read and write: [artifacts.md](artifacts.md).

## Invariants and security boundaries

- `vendor/**` is never edited. Different behavior goes into the wrapper.
- No skill installs, calls or references a gstack runtime. `bin/ytstack-check` (`check_gstack_adapted`) fails an adapted skill without `metadata.upstream`, with such a reference, a symlink or an em-dash.
- No preamble uses the banned patterns listed in `docs/ux/skill-structure.md`; `bin/ytstack-check` fails on them and on a shell preamble that does not source the lib.
- Skills and agents never delete, move or revert `.ytstack/` artifacts. `reconcile` is the only skill that moves them, and it asks first; it is also the one that writes task-plan skeletons for tasks that ran without a plan and moves a `STATE.md` pointer that is behind, each after its own question ([artifacts.md](artifacts.md)).
- No skill merges to a shared branch, pushes or opens a pull request unless the user asked for it (`ship`, `finish-branch`).
- Directives are not user-invocable.

## Error behavior

- Missing prerequisite: the skill prints which skill to run and stops. Nothing is written.
- `summarize-task` with a failed verification: no summary, the task stays open.
- Cancelled question in `adopt-brownfield`: nothing is written.
- Lib not loaded: the fallback branch runs; see "Shared preamble".

## Known limits

- `bin/ytstack-check` enforces part of the contracts; the rules are the `check_*` functions named under "Where implemented". For skills it fails on frontmatter name and description, a missing `## Checklist` or `## Terminal State` in a procedure skill, and the resolver and wrapper rules. It only warns on em-dashes in skill prose, missing recommended sections and missing `metadata.tier` or `metadata.version`. It does not check `AskUserQuestion` bodies, the set of preamble flags, `dot` syntax, `HARD-GATE` tag balance or skill file size. Those stay review items.
- The `depends-on` frontmatter and the `DEPS_OK` flag in `docs/ux/skill-structure.md` are not used by any skill.
- `explain_level`: two preambles print `EXPLAIN_LEVEL` from `~/.ytstack/config`. No code switches on it, and `yt_prefs` does not read the `explain_level` line in `PREFERENCES.md`.
- Unknown -- how the open-ended questions of `plan-task`, `slice-milestone` and `summarize-task` are answered in non-interactive mode. The skills define no answer source for them.
- Unknown -- whether an implementer's `AskUserQuestion` calls reach the user from a worktree subagent. The brief does not set `YTSTACK_NON_INTERACTIVE`.
- Under `merge_by: risk` only the hard gate of `finish-lane` keeps a session from calling `bin/ytstack-finish-lane merge` after `route: person`; the script's `merge` does not read the route. Whether a screenshot was taken by the reviewer and not copied is the hard gate of `visual-review`; the script checks hashes and names.
- `visual-review`, `signal-intake`, `incident`, `review-lessons`, `lesson`, the route in `finish-lane` and the upstream channel have not run in a real session; no change has merged without a person yet, and no issue has been filed under `upstream_feedback: file`. Which browser tool a host offers a dispatched reviewer is unknown before such a run.

## Where implemented

- `skills/<name>/SKILL.md`, one directory per skill; `agents/architect.md`, `agents/implementer.md`, `agents/verifier.md`.
- `hooks/lib/git-ctx.sh`: resolver, preferences.
- `hooks/session-start`: injection of `using-ytstack` and the `minimal-code` pointer.
- `vendor/superpowers/skills/`: the inlined procedures.
- `bin/ytstack-check`: `check_skill`, `check_agent`, `check_cross_refs`, `check_resolver_contract`, `check_inline_leaks`, `check_gstack_adapted`.
- Tests: `tests/skill-preambles.test.sh` (every preamble in a main checkout and a linked worktree, preference flags, fallback branch, a milestone in `milestones/M###/`, `backlog/<dir>/` and split between there and flat), `tests/ytstack-check.test.sh` (checker rules), `tests/git-ctx.test.sh` (resolver, `yt_prefs`), `tests/hooks-readonly.test.sh` (injection size, `minimal_code` pointer).
- `evals/`: one trigger and outcome case per lifecycle skill, see `evals/README.md`.

## How to verify

- `bin/ytstack-check`: exit code 0 or 2, no `[fail]` line, last line starts with `OK`.
- `bash tests/skill-preambles.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/ytstack-check.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/git-ctx.test.sh`: exit 0, last line `<n> passed, 0 failed`.
- `bash tests/run-all.sh`: last line `ALL SUITES PASSED`.

## Decisions that apply now

- DECISIONS.md -- "2026-11-13: Whether a person looks at a change is decided per change: a floor from the diff, the class an independent reviewer states, a ceiling per area, lenses per kind of change (M025)" (narrows the `merge_by: human` default of the M024 entry to `risk`); extended by "2026-11-15: The risk route reads the review round from the review on the host first; the plan is the fallback (M031-S02, issue #54)"
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
- DECISIONS.md -- "2026-11-07: Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency" (narrows the wrapper mechanism to superpowers)
- DECISIONS.md -- "2026-11-14: The six gstack skills become ytstack's own adaptations, synced with upstream; no gstack install"
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree" (source of the resolver contract)
- DECISIONS.md -- "2026-11-07: Ceremony scales with the change -- granularity, autonomy, quick lane and minimal-code guard are project preferences with loud defaults"; the channel of "2026-11-15: Feedback about ytstack itself goes through one channel with a setting; a script checks the body, the agent posts (M033-S01, issue #55)" is one more preference
- DECISIONS.md -- "2026-11-07: Brownfield adoption is a reference-first distillation, never a pitch" (narrows the greenfield flow: an existing codebase skips the pitch)
- DECISIONS.md -- "2026-10-13: Remove generated Codex copies; load the existing skills directly" (one skill tree for both hosts)
- DECISIONS.md -- "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)" (the spec steps in the loop)
- DECISIONS.md -- "2026-11-13: Verification, review and orchestration work are bounded like code (M023, issue #35)" (the work contract; extends the ceremony entry of 2026-11-07 from code to evidence and review), extended by "2026-11-15: The spec delta is the report's existing `Spec:` label, checked for its form (issue #75)", "2026-11-15: A brief for an unplanned task makes the task plan its first deliverable (issue #76)", "2026-11-15: `finish-lane`'s route checks the spec delta; a gap routes to a person (issue #75)" as narrowed by "2026-11-15: The spec delta of a lane is checked per area, from the plans of its own range (PR #88 review)", and "2026-11-15: The checks inventory is a `## Checks` section of `REVIEW.md`, not an area file (issue #75)" (the `code-review` finding)
- DECISIONS.md -- "2026-11-13: Coordinator mode keeps lanes, questions and standing instructions in files and reads host facts fresh (M024, issue #34)", extended by "2026-11-14: Standing instructions are one file per entry in `.ytstack/standing/`; `STANDING.md` stays valid (issue #57)", by "2026-11-15: PR watch bulk registration takes only your own ready PRs; bins are called through `YT_BIN` (issue #85)", by "2026-11-15: Lane liveness is part of `ytstack-frontier check`, worktree cleanup only prints commands, peers are list lines in `LANES.md` (issue #84)" (the peers of `coordinate`), by "2026-11-15: Coordinate mode is a session marker the coordinate preamble writes; the standing hooks act only with it (issue #72)", "2026-11-15: In coordinate mode the operating path is injected and checked by hooks that warn; a lint repeated in three sessions blocks once (issue #76)" and "2026-11-15: Standing entries end by `until`, `until-condition` or `until-check` and are closed by an entry of `kind: end`; their commands run only in `ytstack-standing list` (issues #73, #74)" and "2026-11-15: STALL detection lives in both watchers, owner liveness in `ytstack-frontier owner`; focus PRs are read every tick (issue #91)" (focus PRs and the two STALL steps of `coordinate`) and "2026-11-15: Hooks read a stale checkout from origin, say a reminder once per session and pointer, and keep a coordinator on its path with hints, not denies (issues #82, #83)" (the hard gate of `coordinate` and `finish-lane`, `parked`, Step 5's liveness check), the latter narrowed by "2026-11-15: The open-PR cap limits opening, never a merge; origin's STATE.md is read only when the checkout is strictly behind and unedited (review of PR #94)" (the cap); narrowed by "2026-11-15: A coordinator decides what nobody reserved; a person gets only a closed list of escalations, and a question names its source and purpose (issue #78)" (`escalate`, Step 8 of `coordinate`)
- DECISIONS.md -- "2026-11-13: `STATE.md` is a pointer with a size bound; history leaves it through `reconcile`, a closed milestone is folded into the spec (M022-S03)"; "2026-11-15: `reconcile` writes task-plan skeletons and fixes the STATE pointer, after asking; the logic is `bin/ytstack-reconcile` (issue #76)" narrows its rule that `reconcile` leaves the pointer alone

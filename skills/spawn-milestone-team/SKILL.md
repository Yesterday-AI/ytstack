---
name: spawn-milestone-team
description: "Dispatches the current milestone's slices to parallel workers: by default one worktree-isolated implementer subagent per slice plus a fresh verifier per slice, orchestrated from the main session which never edits source; with PREFERENCES team on, a Claude Code Agent Team instead. Use after slice-milestone and plan-eng-review when the slices are independent, or when the user says spawn the team, run the slices in parallel, dispatch the milestone. Not for a single slice or sequential work (plan-task)."
metadata:
  tier: task
  version: 0.4.0
  triggers:
    - spawn team
    - dispatch milestone
    - run slices in parallel
    - parallel slice execution
    - ytstack team
allowed-tools:
  - Bash
  - Read
  - Edit
  - Agent
  - AskUserQuestion
---

# spawn-milestone-team

Run a sliced milestone in parallel. The main session becomes a thin orchestrator: it dispatches one `ytstack:implementer` subagent per slice into its own git worktree, one `ytstack:verifier` subagent per finished slice into a fresh worktree, merges the slice branches it accepts, and advances `STATE.md`. The orchestrator never edits source files; its context stays small because the work happens in the subagents' contexts. What may start and who holds it is on disk, not in the orchestrator's memory: `bin/ytstack-frontier` reads the `**Blocked by:**` lines of the slice plans and keeps one row per lane (one delegated slice, `M004-S02`) in `.ytstack/LANES.md`. Claude Code Agent Teams remain available as an explicit opt-in (`team: on` in PREFERENCES) for milestones that need teammates to talk to each other.

## Anti-Pattern: "Just execute the slices sequentially myself"

That works, and it is the right call when slices share files, when the milestone is S or M with one or two slices, or when you want to watch every step. Parallel dispatch pays off when slices are independent (no file overlap, no cross-references), the milestone is L, and you want to step away.

## Anti-Pattern: "Agent Teams are the parallel mode"

Teams are experimental, cannot be resumed after `/resume`, ignore the agents' `skills` preload, and cost more tokens because teammates coordinate through a mailbox. Worktree subagents are first-class: isolated checkout, preloaded skills, resumable, cleaned up when nothing changed. Teams buy inter-agent discussion; most milestones do not need it.

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- execution mode, milestone state, slice plans, overlap, branch state
2. **HARD-GATE** -- `.ytstack`, milestone, slice plans, clean working tree
3. **Check slice independence** -- stop or accept the risk when slices overlap
4. **Confirm the dispatch plan** -- one question: workers, branches, verifier, merge policy
5. **Claim and dispatch the frontier** -- `bin/ytstack-frontier list`; per ready lane a claim, one rendered brief (`bin/ytstack-brief render`) and one `Agent` call with `isolation: worktree`; no dispatch when the claim is refused
6. **Check each report** -- `bin/ytstack-brief check` on the worker's report; an incomplete report goes back once
7. **Verify each finished slice** -- one `Agent` call per slice branch, fresh verifier
8. **Merge accepted slices, look at the frontier again** -- slice branch into the working branch, `STATE.md` from the orchestrator's side; back to item 5 until no lane is ready or in flight
9. **Report + return** -- per slice: branch, verdict, merge result, what is still blocked; next step `reassess-roadmap`

Items 5 to 8 each end with the `bin/ytstack-frontier set` call that records the lane's stage and its next action in `.ytstack/LANES.md`.

## Preamble

```bash
# ytstack resolver (M016): checkout = where this shell runs, via the shared lib.
_LIB="${CLAUDE_SKILL_DIR}/../../hooks/lib/git-ctx.sh"
if [ -f "$_LIB" ]; then
  . "$_LIB"; yt_git_ctx "$PWD"; yt_resolve_yt_dir >/dev/null
  _PROJECT_DIR="$YT_TOPLEVEL"; _YT_DIR="$YT_DIR"; _YT_SCOPE="$YT_SCOPE"; _IS_GIT="$YT_IS_GIT"; _PROJECT_KEY="$YT_REPO_KEY"; _IS_LINKED="$YT_IS_LINKED"
else
  # Host did not substitute CLAUDE_SKILL_DIR (e.g. Codex adapter): project scope only.
  _IS_GIT=$([ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] && echo yes || echo no)
  _PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
  _YT_DIR=""; _YT_SCOPE=none; _PROJECT_KEY=""; _IS_LINKED=no
  [ -d "$_PROJECT_DIR/.ytstack" ] && { _YT_DIR="$_PROJECT_DIR/.ytstack"; _YT_SCOPE=project; }
fi
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$_PROJECT_DIR")
_HAS_YTSTACK=$([ -n "$_YT_DIR" ] && echo yes || echo no)

# Execution mode (M019-S04): PREFERENCES team off (default) -> worktree subagents; on -> Agent Teams.
if command -v yt_prefs >/dev/null 2>&1; then yt_prefs "$_YT_DIR" >/dev/null; else YT_PREF_TEAM=off; YT_PREF_WARNINGS=""; fi
_EXECUTION=$([ "${YT_PREF_TEAM:-off}" = on ] && echo team || echo subagents)

_CURRENT_MILESTONE=none
[ -f "$_YT_DIR/STATE.md" ] && _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)

_SLICE_PLANS=""
if [ "$_CURRENT_MILESTONE" != none ] && [ -d "$_YT_DIR" ]; then
  _SLICE_PLANS=$(ls "$_YT_DIR"/$_CURRENT_MILESTONE-S[0-9][0-9]-PLAN.md 2>/dev/null)
fi
_SLICE_COUNT=$(printf '%s' "$_SLICE_PLANS" | grep -c . 2>/dev/null); _SLICE_COUNT=${_SLICE_COUNT:-0}

# Open slices (status not done) and file overlap between their task plans / Files sections.
_OPEN_SLICES=""; _OVERLAP=""
for p in $_SLICE_PLANS; do
  s=$(printf '%s' "$p" | sed -E 's/.*-(S[0-9][0-9])-PLAN\.md$/\1/')
  [ "$(sed -n 's/^status: *//p' "$p" | head -1)" = done ] && continue
  _OPEN_SLICES="$_OPEN_SLICES $s"
done
if [ -n "$_OPEN_SLICES" ]; then
  _TMPF=$(mktemp "${TMPDIR:-/tmp}/ytspawn.XXXXXX")
  for s in $_OPEN_SLICES; do
    # file-like tokens: backticked `path.ext`, "Create/Modify/Delete: path", or bare dir/file.ext in the slice + task plans
    cat "$_YT_DIR"/$_CURRENT_MILESTONE-$s-PLAN.md "$_YT_DIR"/$_CURRENT_MILESTONE-$s-T[0-9][0-9]-PLAN.md 2>/dev/null \
      | grep -oE '(`[^` ]+\.[A-Za-z0-9]+`|(Create|Modify|Delete): *[A-Za-z0-9_./-]+\.[A-Za-z0-9]+|[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)+\.[A-Za-z0-9]+)' \
      | sed -E 's/^(Create|Modify|Delete): *//' | tr -d '`' | sort -u | sed "s/^/$s /"
  done > "$_TMPF"
  _OVERLAP=$(awk '{f[$2]=f[$2]" "$1; n[$2]++} END{for (k in n) if (n[k]>1) print k":"f[k]}' "$_TMPF" | sort)
  rm -f "$_TMPF"
fi

_BRANCH=$(git branch --show-current 2>/dev/null || echo unknown)
# LANES.md is the orchestrator's own file during a run: it does not make the tree dirty.
_DIRTY=$([ -n "$(git status --porcelain 2>/dev/null | grep -v '\.ytstack/LANES\.md$')" ] && echo yes || echo no)
_EXISTING_SLICE_BRANCHES=$(git branch --list "ytstack/$_CURRENT_MILESTONE-S*" 2>/dev/null | sed 's/^[* ]*//' | tr '\n' ' ')
_AT_ENABLED=$([ "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" = "1" ] && echo yes || echo no)

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "EXECUTION: $_EXECUTION"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "SLICE_COUNT: $_SLICE_COUNT"
echo "OPEN_SLICES: ${_OPEN_SLICES:-none}"
echo "OVERLAP: ${_OVERLAP:-none}"
echo "BRANCH: $_BRANCH"
echo "IS_LINKED_WORKTREE: $_IS_LINKED"
echo "DIRTY: $_DIRTY"
echo "EXISTING_SLICE_BRANCHES: ${_EXISTING_SLICE_BRANCHES:-none}"
echo "AGENT_TEAMS_ENABLED: $_AT_ENABLED"
[ -n "${YT_PREF_WARNINGS:-}" ] && echo "PREF_WARNINGS: $YT_PREF_WARNINGS"
exit 0
```

## Procedure

### Step 2: HARD-GATE

- `HAS_YTSTACK=no`: abort "run init-project first".
- `CURRENT_MILESTONE=none`: abort "run plan-milestone first".
- `SLICE_COUNT=0` or `OPEN_SLICES=none`: abort "nothing to dispatch; run slice-milestone, or the milestone is done".
- `DIRTY=yes`: abort "commit or stash-free: commit the working tree first; slice branches fork from it". A changed `.ytstack/LANES.md` alone does not count: a run that is taken up again finds its own rows there.
- `IS_LINKED_WORKTREE=yes`: abort "run the orchestrator from the main checkout; nested worktrees are not supported".
- `EXECUTION=team` and `AGENT_TEAMS_ENABLED=no`: abort "PREFERENCES team: on needs CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1; set it or switch team: off".

### Step 3: Check slice independence

`OVERLAP` lists files named in more than one open slice (`path:S01 S02`). If it is not `none`, use AskUserQuestion:

> Slices share files: {OVERLAP}. Running them in parallel means merge conflicts on those files.
>
> RECOMMENDATION: B. A re-slice costs minutes; a conflicted merge of two subagents' work costs an afternoon.
>
> A) Accept the risk, dispatch anyway; the orchestrator resolves conflicts at merge time. (Completeness: 6/10, risk: medium)
> B) Stop, re-run `ytstack:slice-milestone` to separate the files. (Completeness: 10/10)
> C) Stop, execute sequentially (`ytstack:plan-task` per task). (Completeness: 10/10)

If B or C: STOP.

### Step 4: Confirm the dispatch plan

One AskUserQuestion with the plan spelled out:

> Dispatch **{CURRENT_MILESTONE}** ({OPEN_SLICES}) from branch `{BRANCH}`:
>
> - one `ytstack:implementer` per slice, each in its own worktree on branch `ytstack/{CURRENT_MILESTONE}-S##` (forked from `{BRANCH}`), working through the slice's tasks with plan-task -> TDD -> verification -> summarize-task;
> - a slice starts when the slices its plan names under `**Blocked by:**` are done, and it is claimed in `.ytstack/LANES.md` before it starts, so no slice is started twice;
> - one `ytstack:verifier` per finished slice in a fresh worktree, running every task plan's verification command on the slice branch;
> - merge of each verified slice branch into `{BRANCH}` by the orchestrator (fast-forward or merge commit; `STATE.md` kept from `{BRANCH}` and re-pointed), then `ytstack:reassess-roadmap`.
>
> RECOMMENDATION: A.
>
> A) Dispatch as described. (Completeness: 10/10)
> B) Dispatch, but stop before merging: leave the slice branches for me to merge. (Completeness: 9/10)
> C) Fewer workers than slices: one implementer takes two slices in sequence. (Completeness: 10/10, slower, cheaper)

Remember as `_MERGE_POLICY` (A = orchestrator merges, B = branches only) and `_WORKERS`.

### Step 5: Claim and dispatch the frontier (EXECUTION=subagents)

Ask what may start. The frontier is every lane that is open, unblocked and unclaimed; the script works it out from the roadmap checkboxes, the `**Blocked by:**` line of each slice plan and `.ytstack/LANES.md`:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier" list --milestone {CURRENT_MILESTONE}
```

```
M004-S01	done
M004-S02	claimed	impl-M004-S02 2026-11-13T10:02Z
M004-S03	blocked	S02
M004-S04	ready
```

- `ready`: dispatch it now. With the detail `unplanned` the slice has no plan: leave it and name it in the report (`ytstack:slice-milestone` comes first).
- `blocked`: it waits for the slices named behind it. Do not start it.
- `claimed`: somebody holds it. Do not start it again. If it is a lane of this run whose worker you no longer remember (after a compaction or a new session), read its row in `.ytstack/LANES.md` and continue at the stage that Status and Next action name.

Claim each ready lane before anything is sent to a worker:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier" claim {CURRENT_MILESTONE}-S## --by impl-{CURRENT_MILESTONE}-S## --kind implement --branch ytstack/{CURRENT_MILESTONE}-S##
```

Exit 1 means the claim is refused: the lane is held, and the message says by whom and since when (or its row is `blocked`, `dropped` or `merged` and was not released). Do not dispatch that lane, and do not claim it under another name. With fewer workers than ready lanes (Step 4, C), claim only as many lanes as there are free workers; the others stay `ready` for the next look.

Render the brief of every lane you claimed; do not write it by hand. The script builds it from the slice plan and its task plans (outcome, files, verification, spec impact, gates, the checkout command) and adds the work contract (the body of `ytstack:minimal-code`) and the report shape:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-brief" render --slice {CURRENT_MILESTONE}-S## --branch ytstack/{CURRENT_MILESTONE}-S## --base {BRANCH}
```

The output is the Agent prompt. Append only what the plans do not hold:

```
STATE.md in your worktree is your copy; update it as the skills do.
Do not run ytstack:reassess-roadmap.
```

and, on a re-dispatch, the checker's lines (Step 6) or the verifier's output (Step 7).

```
Agent(
  subagent_type: "ytstack:implementer",
  isolation: "worktree",
  name: "impl-{CURRENT_MILESTONE}-S##",
  description: "Implement slice S## of {CURRENT_MILESTONE}",
  prompt: <the rendered brief plus the appended lines>
)
```

The lanes claimed in one look go out in one message, so they run concurrently. When the Agent call of a lane is out, record it:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier" set {CURRENT_MILESTONE}-S## --status running --next "wait for the report"
```

**Look again, do not batch.** Each time a lane is verified (Step 7) or merged (Step 8), run `list` again and claim and dispatch what became ready: a slice that needed another slice's result starts then, rendered with `--base {BRANCH}`, which holds that result after the merge. The run is over when `list` shows no `ready` and no `claimed` lane. What is left is `done` or `blocked`; a `blocked` lane goes into the report with what blocks it.

Under merge policy B nothing is merged, so a verified lane stays at Status `ready` (shown as `claimed`) and its dependents stay `blocked`. There the run is over when every `claimed` lane has Status `ready`. A blocked lane whose only open blocker is such a verified lane may be claimed and rendered with that lane's branch as `--base`; one with several is left for the user.

If `bin/ytstack-frontier` is not reachable (a host that does not substitute `CLAUDE_SKILL_DIR`): keep `.ytstack/LANES.md` by hand. Read the `**Blocked by:**` lines of the slice plans yourself, add the lane's row before its dispatch, change only that row afterwards, and never start a lane whose row has one of the Status values `claimed`, `running`, `reported`, `in-review`, `ready`. The table, under a frontmatter with `updated: <UTC time>` (the other Status values are `merged`, `blocked`, `dropped`):

```markdown
| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |
|---|---|---|---|---|---|---|---|---|---|
| M004-S02 | implement | running | impl-M004-S02 2026-11-13T10:02Z | ytstack/M004-S02 | - | - | - | 0 | wait for the report |
```

The same rendered text works for any worker that takes a prompt: a `general-purpose` Agent, or the command-line agent of another host that reads a prompt from stdin, started in a worktree of its own (the brief's Git section switches the branch of the checkout it runs in). The host's adapter document names the command. The brief does not depend on the worker loading a skill.

If `bin/ytstack-brief` is not reachable: fill `brief-template.md` (next to this file) by hand from the plans and paste the body of `skills/minimal-code/SKILL.md` under "Work contract". Never dispatch a brief without the contract.

Do not wait idle: while implementers run, the orchestrator may plan the next milestone's context or answer the user, but it does not edit source files.

### Step 6: Check each report

When a worker reports, validate the report before anything is done with it:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-brief" check <<'REPORT'
<the worker's final message>
REPORT
```

`report ok`: go to Step 7. Otherwise the checker prints one line per problem (`missing: Not checked`, `Checks run: no exit code in "..."`). Send the report back to the worker once, with exactly those lines. Do not reconstruct the missing facts yourself: a commit list or an exit code the orchestrator looked up is not the worker's statement. A second incomplete report: stop that slice and tell the user.

Keep from each worker only the report's facts (outcome, commits, check lines, blockers), not its transcript. A `Blockers:` value other than `none` goes to the user once, with what is needed to resolve it; the slice is neither verified nor merged until then.

Record where the lane stands (one call, the line that applies):

```bash
F="${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier"
"$F" set {CURRENT_MILESTONE}-S## --status reported --next "dispatch the verifier"         # report ok, no blocker
"$F" set {CURRENT_MILESTONE}-S## --next "wait for the completed report"                   # sent back once
"$F" set {CURRENT_MILESTONE}-S## --status blocked --next "<what it waits for, one line>"  # a blocker, or the second incomplete report
```

A lane set to `blocked` is not started by a later look at the frontier. When what blocked it is resolved, take it up with `release` and a new `claim`:

```bash
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier" release {CURRENT_MILESTONE}-S##
```

### Step 7: Verify each finished slice

When a report passed the check and names no blocker, dispatch a verifier for that slice:

```
Agent(
  subagent_type: "ytstack:verifier",
  isolation: "worktree",
  name: "verify-{CURRENT_MILESTONE}-S##",
  description: "Verify slice S## on its branch",
  prompt: "Branch ytstack/{CURRENT_MILESTONE}-S##. Run `git checkout ytstack/{CURRENT_MILESTONE}-S##` in your worktree, then for every .ytstack/{CURRENT_MILESTONE}-S##-T##-PLAN.md run its Verification command from a cold context, as often as its Runs line says, and compare with the T##-SUMMARY.md claims (no summary: with the worker's report below). Report pass / pass-with-caveats / fail per task with the raw output and the commit you ran on. Do not edit anything. Worker's report: <the worker's report lines>"
)
```

When the verifier is out, and again when its verdict is in, record it (round 1 is the first verifier of the lane, every further one adds one):

```bash
F="${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier"
"$F" set {CURRENT_MILESTONE}-S## --status in-review --round <n> --next "wait for the verifier"                          # verifier dispatched
"$F" set {CURRENT_MILESTONE}-S## --status ready --head <the commit the verifier ran on> --next "merge into {BRANCH}"   # pass or pass-with-caveats
"$F" set {CURRENT_MILESTONE}-S## --status running --next "wait for the fix report"                                      # fail, implementer re-dispatched
"$F" set {CURRENT_MILESTONE}-S## --status blocked --next "two failed verifications, told the user"                      # second fail in a row
```

Under merge policy B the next action of a verified lane is "left for the user to merge".

A `fail` sends the slice back: re-dispatch the implementer on the same branch with the verifier's output appended to the rendered brief. The lane is still held by that implementer, so there is no new claim. Two consecutive fails: stop and report to the user.

After a fix, the next verifier gets the earlier verdict in its prompt (task, commit, result). A fix makes a new commit, so it runs every task's check again on that commit: a check also reads files its plan does not name (an imported helper, a configuration, a fixture), and unchanged planned files do not carry an earlier PASS over. It cites an earlier verdict only for the same commit, environment and command (`ytstack:minimal-code`, "Evidence").

### Step 8: Merge accepted slices, look at the frontier again

`_MERGE_POLICY = A`: for each verified slice, from the main checkout on `{BRANCH}`. What is merged is the commit the verifier ran on (the row's "Reviewed head"); a branch that moved since then goes back to Step 7 first.

```bash
git merge --no-ff ytstack/{CURRENT_MILESTONE}-S##
"${CLAUDE_SKILL_DIR}/../../bin/ytstack-frontier" set {CURRENT_MILESTONE}-S## --status merged --next -
```

If `.ytstack/STATE.md` conflicts, resolve it from the orchestrator's side (`git checkout --ours .ytstack/STATE.md && git add .ytstack/STATE.md`) and re-point `current_milestone / active_slice / active_task` by hand afterwards: the orchestrator owns the main pointer, the worktree copies were the workers'. Other `.ytstack` conflicts (slice plan checkboxes, summaries) are keep-both. Run the project's test suite on the merged result; a red suite stops the merge of further slices and the dispatch of new ones, and goes to the user. Keep the slice branches until the milestone's reassess has run, then delete them (`git branch -d`).

`_MERGE_POLICY = B`: leave the branches, list them. The rows stay at Status `ready`.

Never push, never open a PR here (`ytstack:ship` / `ytstack:finish-branch` do that on request).

After each merge (policy A) or each verified slice (policy B): back to Step 5 and look at the frontier again. Go on to Step 9 only when Step 5 says the run is over.

### Step 5-8 under EXECUTION=team

With `team: on` and Agent Teams enabled, skip the subagent calls and emit the team instruction instead (unchanged from 0.1.x): one teammate per slice using the `ytstack:implementer` definition, an optional architect-lead, the shared task list from the roadmap, teammates with `YTSTACK_NON_INTERACTIVE=1`, the lead coordinating and running `reassess-roadmap` at the end. Present the instruction and wait for "go"; Claude Code creates the team from the next prompt. Teams cannot be resumed after `/resume`; say so once. No lanes are claimed in team mode: the team's shared task list says who holds what.

### Step 9: Report + return

> Dispatched {CURRENT_MILESTONE}: {per slice: branch, the outcome from the implementer's report, verifier verdict, merge result}.
> {Only when a lane is left: per lane that is blocked or unplanned, what it waits for.}
> Lanes: `.ytstack/LANES.md`.
> Next: `ytstack:reassess-roadmap` (slice boundaries), then `ytstack:finish-branch` or `ytstack:ship` for `{BRANCH}`.

## Terminal State

Return when the frontier of Step 5 shows no lane that is ready or in flight: every dispatched lane is merged (policy A), verified with its branch listed (policy B), or blocked and named in the report. Or return after emitting the team instruction (team mode). Do NOT invoke `reassess-roadmap`, `finish-branch` or `ship` automatically. Abort at the HARD-GATE of Step 2 or on B / C in Step 3.

## Limitations

- Worktree subagents fork from the default branch, so the brief's Git section re-bases them onto the orchestrator's branch; a dirty orchestrator tree is refused for that reason.
- The verifier checks out the slice branch inside its own worktree; it never sees the orchestrator's uncommitted state (`.ytstack/LANES.md` at most).
- Blocking edges are read between the slices of one milestone. A `**Blocked by:**` entry that names anything else keeps the slice blocked until the line is edited.
- Agent Teams (opt-in): experimental, no resume, one team per session, `skills` preload ignored for teammates, lead fixed for the team's lifetime.

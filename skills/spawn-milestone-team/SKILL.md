---
name: spawn-milestone-team
description: "Dispatches the current milestone's slices to parallel workers: by default one worktree-isolated implementer subagent per slice plus a fresh verifier per slice, orchestrated from the main session which never edits source; with PREFERENCES team on, a Claude Code Agent Team instead. Use after slice-milestone and plan-eng-review when the slices are independent, or when the user says spawn the team, run the slices in parallel, dispatch the milestone. Not for a single slice or sequential work (plan-task)."
metadata:
  tier: task
  version: 0.3.0
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

Run a sliced milestone in parallel. The main session becomes a thin orchestrator: it dispatches one `ytstack:implementer` subagent per slice into its own git worktree, one `ytstack:verifier` subagent per finished slice into a fresh worktree, merges the slice branches it accepts, and advances `STATE.md`. The orchestrator never edits source files; its context stays small because the work happens in the subagents' contexts. Claude Code Agent Teams remain available as an explicit opt-in (`team: on` in PREFERENCES) for milestones that need teammates to talk to each other.

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
5. **Dispatch implementers** -- one rendered brief (`bin/ytstack-brief render`) and one `Agent` call per slice, `isolation: worktree`, independent slices in parallel
6. **Check each report** -- `bin/ytstack-brief check` on the worker's report; an incomplete report goes back once
7. **Verify each finished slice** -- one `Agent` call per slice branch, fresh verifier
8. **Merge accepted slices** -- slice branch into the working branch, `STATE.md` from the orchestrator's side
9. **Report + return** -- per slice: branch, verdict, merge result; next step `reassess-roadmap`

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
_DIRTY=$([ -n "$(git status --porcelain 2>/dev/null)" ] && echo yes || echo no)
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
- `DIRTY=yes`: abort "commit or stash-free: commit the working tree first; slice branches fork from it".
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
> - one `ytstack:verifier` per finished slice in a fresh worktree, running every task plan's verification command on the slice branch;
> - merge of each verified slice branch into `{BRANCH}` by the orchestrator (fast-forward or merge commit; `STATE.md` kept from `{BRANCH}` and re-pointed), then `ytstack:reassess-roadmap`.
>
> RECOMMENDATION: A.
>
> A) Dispatch as described. (Completeness: 10/10)
> B) Dispatch, but stop before merging: leave the slice branches for me to merge. (Completeness: 9/10)
> C) Fewer workers than slices: one implementer takes two slices in sequence. (Completeness: 10/10, slower, cheaper)

Remember as `_MERGE_POLICY` (A = orchestrator merges, B = branches only) and `_WORKERS`.

### Step 5: Dispatch implementers (EXECUTION=subagents)

Render the brief of every open slice; do not write it by hand. The script builds it from the slice plan and its task plans (outcome, files, verification, spec impact, gates, the checkout command) and adds the work contract (the body of `ytstack:minimal-code`) and the report shape:

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

Dispatch by actual dependency. Slices that need nothing from each other go out in one message, so they run concurrently. A slice that needs another slice's result waits until that slice is verified, and is rendered then with that result as `--base` (`{BRANCH}` after the merge, the other slice's branch under merge policy B).

The same rendered text works for any worker that takes a prompt: a `general-purpose` Agent, or the command-line agent of another host that reads a prompt from stdin, started in a worktree of its own (the brief's Git section switches the branch of the checkout it runs in). The host's adapter document names the command. The brief does not depend on the worker loading a skill.

If the script is not reachable: fill `brief-template.md` (next to this file) by hand from the plans and paste the body of `skills/minimal-code/SKILL.md` under "Work contract". Never dispatch a brief without the contract.

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

### Step 7: Verify each finished slice

When a report passed the check and names no blocker, dispatch a verifier for that slice:

```
Agent(
  subagent_type: "ytstack:verifier",
  isolation: "worktree",
  name: "verify-{CURRENT_MILESTONE}-S##",
  description: "Verify slice S## on its branch",
  prompt: "Branch ytstack/{CURRENT_MILESTONE}-S##. Run `git checkout ytstack/{CURRENT_MILESTONE}-S##` in your worktree, then for every .ytstack/{CURRENT_MILESTONE}-S##-T##-PLAN.md run its Verification command from a cold context, as often as its Runs line says, and compare with the T##-SUMMARY.md claims (no summary: with the worker's report below). Report pass / pass-with-caveats / fail per task with the raw output and the commit you ran on. Do not edit anything. Worker's report: <the eight report lines>"
)
```

A `fail` sends the slice back: re-dispatch the implementer on the same branch with the verifier's output appended to the rendered brief. Two consecutive fails: stop and report to the user.

After a fix, the next verifier gets the earlier verdict in its prompt (task, commit, result). It runs again only the checks of tasks whose files changed since that commit, and cites the earlier verdict for the rest: evidence for the same commit, environment and check stands (`ytstack:minimal-code`, "Evidence").

### Step 8: Merge accepted slices

`_MERGE_POLICY = A`: for each verified slice, from the main checkout on `{BRANCH}`:

```bash
git merge --no-ff ytstack/{CURRENT_MILESTONE}-S##
```

If `.ytstack/STATE.md` conflicts, resolve it from the orchestrator's side (`git checkout --ours .ytstack/STATE.md && git add .ytstack/STATE.md`) and re-point `current_milestone / active_slice / active_task` by hand afterwards: the orchestrator owns the main pointer, the worktree copies were the workers'. Other `.ytstack` conflicts (slice plan checkboxes, summaries) are keep-both. Run the project's test suite on the merged result; a red suite stops the merge of further slices. Keep the slice branches until the milestone's reassess has run, then delete them (`git branch -d`).

`_MERGE_POLICY = B`: leave the branches, list them.

Never push, never open a PR here (`ytstack:ship` / `ytstack:finish-branch` do that on request).

### Step 5-8 under EXECUTION=team

With `team: on` and Agent Teams enabled, skip the subagent calls and emit the team instruction instead (unchanged from 0.1.x): one teammate per slice using the `ytstack:implementer` definition, an optional architect-lead, the shared task list from the roadmap, teammates with `YTSTACK_NON_INTERACTIVE=1`, the lead coordinating and running `reassess-roadmap` at the end. Present the instruction and wait for "go"; Claude Code creates the team from the next prompt. Teams cannot be resumed after `/resume`; say so once.

### Step 9: Report + return

> Dispatched {CURRENT_MILESTONE}: {per slice: branch, the outcome from the implementer's report, verifier verdict, merge result}.
> Next: `ytstack:reassess-roadmap` (slice boundaries), then `ytstack:finish-branch` or `ytstack:ship` for `{BRANCH}`.

## Terminal State

Return after the merge step (policy A) or after listing the slice branches (policy B), or after emitting the team instruction (team mode). Do NOT invoke `reassess-roadmap`, `finish-branch` or `ship` automatically. Abort at the HARD-GATE or on B / C in Steps 3-4.

## Limitations

- Worktree subagents fork from the default branch, so the brief's Git section re-bases them onto the orchestrator's branch; a dirty orchestrator tree is refused for that reason.
- The verifier checks out the slice branch inside its own worktree; it never sees the orchestrator's uncommitted state (there is none).
- Agent Teams (opt-in): experimental, no resume, one team per session, `skills` preload ignored for teammates, lead fixed for the team's lifetime.

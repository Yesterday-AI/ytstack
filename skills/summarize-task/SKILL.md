---
name: summarize-task
description: "Closes the active task: writes M###-S##-T##-SUMMARY.md with commits, outcome, deviations, follow-ups and the verification result, flips the slice-plan checkbox and advances STATE. Use when a task's verification passed, or when the user says task done, close the task, summarize. Not before verification passed and not for quick-lane changes (quick-task writes its own summary)."
metadata:
  tier: core
  version: 0.3.0
  triggers:
    - summarize task
    - task done
    - ytstack task complete
    - close task
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
---

# summarize-task

Close a task: capture what actually happened (often different from the plan), flip checkboxes, advance STATE.md. Produces an append-to-history artifact future sessions can read.

## Anti-Pattern: "The task is done, I don't need a summary"

Without a summary, the next session has no way to know this task happened -- STATE.md wasn't updated, the slice-plan checkbox is still `[ ]`, and the next agent will either redo the work or get confused. The summary is the closure signal. Always write it, even for one-line tasks ("CSS tweak -- shipped in one commit, no follow-up needed").

## Checklist

You MUST create a TodoWrite task for each of these items:

1. **Run preamble** -- detect active task + plan file
2. **HARD-GATE: active task must exist** -- abort if none
3. **Read the plan** -- show user the original scope
4. **Ask outcome** -- what actually shipped
5. **Ask deviations** -- what differed from plan (if anything)
6. **Ask follow-ups** -- new tasks / decisions surfaced during execution
7. **Ask verification result** -- did the verification command pass?
8. **Check the spec impact** -- the plan's `## Spec impact` against what the task changed; an unmet impact stops the closure
9. **Write `M###-S##-T##-SUMMARY.md`**
10. **Flip slice-plan checkbox** `[ ]` → `[x]`
11. **Update STATE.md** -- clear `active_task`, bump counts (including a `progress:` block when present), update status line
12. **Offer git stage** -- ask if user wants git-add of touched files
13. **Report + return** -- suggest next task or slice-close

## Preamble

```bash
# ytstack resolver (M016): checkout = where this shell runs, via the shared lib.
_LIB="${CLAUDE_SKILL_DIR}/../../hooks/lib/git-ctx.sh"
if [ -f "$_LIB" ]; then
  . "$_LIB"; yt_git_ctx "$PWD"; yt_resolve_yt_dir >/dev/null
  _PROJECT_DIR="$YT_TOPLEVEL"; _YT_DIR="$YT_DIR"; _YT_SCOPE="$YT_SCOPE"; _IS_GIT="$YT_IS_GIT"; _PROJECT_KEY="$YT_REPO_KEY"
else
  # Host did not substitute CLAUDE_SKILL_DIR (e.g. Codex adapter): project scope only.
  _IS_GIT=$([ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] && echo yes || echo no)
  _PROJECT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)
  _YT_DIR=""; _YT_SCOPE=none; _PROJECT_KEY=""
  [ -d "$_PROJECT_DIR/.ytstack" ] && { _YT_DIR="$_PROJECT_DIR/.ytstack"; _YT_SCOPE=project; }
fi
cd "$_PROJECT_DIR" 2>/dev/null || true
_PROJECT_SLUG=$(basename "$_PROJECT_DIR")

_HAS_YTSTACK=$([ -n "$_YT_DIR" ] && echo yes || echo no)

# Ceremony dials (M018): granularity / autonomy from PREFERENCES.md
if command -v yt_prefs >/dev/null 2>&1; then yt_prefs "$_YT_DIR" >/dev/null; else YT_PREF_GRANULARITY=task; YT_PREF_AUTONOMY=loop; YT_PREF_WARNINGS=""; fi
echo "GRANULARITY: $YT_PREF_GRANULARITY"
echo "AUTONOMY: $YT_PREF_AUTONOMY"
echo "PREF_WARNINGS: ${YT_PREF_WARNINGS:-none}"

_NON_INTERACTIVE=false
if [ -n "$YTSTACK_NON_INTERACTIVE" ] || [ -n "$OPENCLAW_SESSION" ] || [ -n "$CLAUDE_AGENT_TEAM_MEMBER" ]; then
  _NON_INTERACTIVE=true
fi

_CURRENT_MILESTONE=none
_ACTIVE_SLICE=none
_ACTIVE_TASK=none
if [ -f "$_YT_DIR/STATE.md" ]; then
  _CURRENT_MILESTONE=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _ACTIVE_SLICE=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
  _ACTIVE_TASK=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi

_PLAN_FILE="$_YT_DIR/$_CURRENT_MILESTONE-$_ACTIVE_SLICE-$_ACTIVE_TASK-PLAN.md"
# M018-S03: tolerate milestones/M###/ layouts on the read side
if [ ! -f "$_PLAN_FILE" ] && command -v yt_find_artifacts >/dev/null 2>&1; then
  _ALT=$(yt_find_artifacts "$_YT_DIR" "$_CURRENT_MILESTONE-$_ACTIVE_SLICE-$_ACTIVE_TASK-PLAN.md" | head -1)
  [ -n "$_ALT" ] && _PLAN_FILE="$_ALT"
fi
_SLICE_PLAN="$_YT_DIR/$_CURRENT_MILESTONE-$_ACTIVE_SLICE-PLAN.md"

# Gather this task's commits for a durable, committed `## Commits` section.
# ytstack's commit convention prefixes task commits with `M###-S##-T##:`
# (see CLAUDE.md), so grep the log for that ref. This is the SINGLE owner of
# commit-to-task linking; the post-tool-use-bash hook only drops a draft stub
# and never maintains a commit list (issue #22 / M015).
_TASK_REF="$_CURRENT_MILESTONE-$_ACTIVE_SLICE-$_ACTIVE_TASK"
_TASK_COMMITS=""
_TASK_COMMITS_SOURCE=none
_TASK_COMMITS_BASE=""
_COMMIT_PATTERN="^$_TASK_REF:"
if [ "$_IS_GIT" = yes ]; then
  if command -v yt_task_commits >/dev/null 2>&1; then
    # Shared lib (M016): pattern from PREFERENCES.md `commit_ref_pattern` (default ^M###-S##-T##:),
    # then branch fallback (merge-base with the default branch .. HEAD) for squash-merge repos.
    _COMMIT_PATTERN=$(yt_commit_ref_pattern "$_YT_DIR" "$_CURRENT_MILESTONE" "$_ACTIVE_SLICE" "$_ACTIVE_TASK")
    yt_task_commits "$_PROJECT_DIR" "$_COMMIT_PATTERN"
    _TASK_COMMITS="$YT_COMMITS"; _TASK_COMMITS_SOURCE="$YT_COMMITS_SOURCE"; _TASK_COMMITS_BASE="$YT_COMMITS_BASE"
  else
    _TASK_COMMITS=$(git log --no-merges -E --grep "$_COMMIT_PATTERN" --pretty=format:'- `%h` -- %s' 2>/dev/null)
    [ -n "$_TASK_COMMITS" ] && _TASK_COMMITS_SOURCE=task-ref
  fi
fi

echo "HAS_YTSTACK: $_HAS_YTSTACK"
echo "YTSTACK_NON_INTERACTIVE: $_NON_INTERACTIVE"
echo "CURRENT_MILESTONE: $_CURRENT_MILESTONE"
echo "ACTIVE_SLICE: $_ACTIVE_SLICE"
echo "ACTIVE_TASK: $_ACTIVE_TASK"
echo "PLAN_FILE: $_PLAN_FILE"
echo "SLICE_PLAN: $_SLICE_PLAN"
echo "IS_GIT: $_IS_GIT"
echo "COMMIT_PATTERN: $_COMMIT_PATTERN"
echo "TASK_COMMITS_SOURCE: $_TASK_COMMITS_SOURCE"
echo "TASK_COMMITS_BASE: ${_TASK_COMMITS_BASE:-none}"
echo "TASK_COMMITS_BEGIN"
echo "${_TASK_COMMITS:-(none found: no subject matched $_COMMIT_PATTERN and no commits on this branch past its base)}"
echo "TASK_COMMITS_END"

# Spec impact (M022): the plan's "## Spec impact" against what the task changed
# (its commits plus the working tree). Decided from the files, not from prose.
_SPEC_TOOL="${CLAUDE_SKILL_DIR}/../../bin/ytstack-spec"
_HAS_SPEC=$([ -f "$_YT_DIR/spec/SPEC.md" ] && echo yes || echo no)
_SPEC_IMPACT_EXIT=not-run; _SPEC_IMPACT_OUT=""
if [ "$_HAS_SPEC" = yes ] && [ -f "$_PLAN_FILE" ] && [ -f "$_SPEC_TOOL" ]; then
  if [ -n "$_TASK_COMMITS_BASE" ]; then
    _SPEC_IMPACT_OUT=$(bash "$_SPEC_TOOL" impact --plan "$_PLAN_FILE" --grep "$_COMMIT_PATTERN" --base "$_TASK_COMMITS_BASE" 2>&1); _SPEC_IMPACT_EXIT=$?
  else
    _SPEC_IMPACT_OUT=$(bash "$_SPEC_TOOL" impact --plan "$_PLAN_FILE" --grep "$_COMMIT_PATTERN" 2>&1); _SPEC_IMPACT_EXIT=$?
  fi
fi
echo "HAS_SPEC: $_HAS_SPEC"
echo "SPEC_IMPACT_EXIT: $_SPEC_IMPACT_EXIT"
echo "SPEC_IMPACT_BEGIN"
echo "${_SPEC_IMPACT_OUT:-(not run)}"
echo "SPEC_IMPACT_END"
```

## Procedure

### Step 2: HARD-GATE

**STATE lint (M018):** run `yt_state_lint "$_YT_DIR"` first. Malformed-field or "set while current_milestone is none" warnings stop this skill ("fix STATE.md first, or run `ytstack:reconcile`"); the remaining warning kinds are reported in the Step 3 message and do not block.

If any of `HAS_YTSTACK / CURRENT_MILESTONE / ACTIVE_SLICE / ACTIVE_TASK` is `no / none`:
> "No active task to summarize. Check STATE.md and run the preceding skill (`plan-task` / `slice-milestone` / `plan-milestone` / `init-project`) as needed."
STOP.

If `PLAN_FILE` does not exist:
> "STATE.md says active_task={ACTIVE_TASK} but plan file missing at {PLAN_FILE}. Repair manually before summarizing."
STOP.

### Step 3: Read the plan

Read `{PLAN_FILE}`. Extract Summary, Files, Verification. Show:

> Closing **{CURRENT_MILESTONE}-{ACTIVE_SLICE}-{ACTIVE_TASK}**.
>
> Original plan: {SUMMARY}
> Files planned: {FILE_LIST}
> Verification: {VERIFICATION_CMD}

### Step 4: Ask outcome

Use AskUserQuestion (open-ended):

> What actually shipped? 2-4 sentences. Use past tense. Say what the code does now, not what you did to it.
>
> Good: "Signup form validates email client-side and POSTs JSON to /api/signup. Server hashes with argon2 and inserts user row. Returns 201 with session cookie. Duplicate email returns 409."
>
> Bad: "I implemented signup" -- too vague, not useful to future sessions.

Remember as `_OUTCOME`.

### Step 5: Ask deviations

Use AskUserQuestion (open-ended):

> Did anything differ from the plan? Extra files, skipped features, refactors, new dependencies?
>
> Enter "none" if the plan held up.

Remember as `_DEVIATIONS`.

### Step 6: Ask follow-ups

Use AskUserQuestion (open-ended):

> Anything that surfaced during execution that needs follow-up? Add them as:
> - new tasks (get added to next slice or a new slice)
> - decisions to lock in `DECISIONS.md`
> - patterns worth capturing in `KNOWLEDGE.md`
> - items to flag in `REVIEW-NOTES.md` for end-of-cycle
>
> Enter "none" if clean.

Remember as `_FOLLOWUPS`.

### Step 7: Ask verification result

Use AskUserQuestion (multi-choice):

> Did the plan's verification step pass?
>
> Verification was: `{VERIFICATION_CMD}`
>
> A) Passed -- clean exit, expected output. (Completeness: 10/10)
> B) Passed with caveats -- exits 0 but something's off. (Completeness: 7/10, flag in followups)
> C) Failed -- task not actually done. (Completeness: 0/10, do not close)
>
> If C: do NOT proceed. Re-execute the task until it passes, then re-run this skill.

If C: STOP. Do not write the summary.

Remember as `_VERIFICATION_RESULT` (value: `passed` / `passed_with_caveats`).

### Step 8: Check the spec impact

The technical spec under `.ytstack/spec/` says what applies now (format: `docs/ux/spec-format.md`). A task that changed what an area file describes is not closed until that description is true again. The preamble already ran the check; read `SPEC_IMPACT_EXIT` and the lines between `SPEC_IMPACT_BEGIN` and `SPEC_IMPACT_END`.

| `SPEC_IMPACT_EXIT` | Meaning | What to do |
|---|---|---|
| `0` | The plan says `none`, or every area it names was updated: the area file **or a source it names** changed with the task. | Keep the printed lines as `_SPEC_RECORD`. Continue. |
| `1` | The plan names an area, and neither its area file nor its sources changed. | STOP. Do not write the summary. See below. |
| `4` | The spec lives in user scope, outside the repository: git cannot see an edit of the area file, and no source of it changed. Each such area has an `UNVERIFIABLE` line. | Every line says `modified after the task's first commit`: keep the printed lines as `_SPEC_RECORD` and continue. Any other line: ask the person once (below). |
| `3` | The plan has no `## Spec impact` section (it was written before the field existed). | Decide now with the rule of `ytstack:plan-task` Step 7. An area changed: update it first, then continue. Otherwise `_SPEC_RECORD` is `none -- <reason>`. |
| `not-run` with `HAS_SPEC=no` | The project has no technical spec. | `_SPEC_RECORD` is `none -- the project has no technical spec`. Continue. |
| `not-run` with `HAS_SPEC=yes` | The script was not reachable on this host. | Do the check by hand: for each area in the plan's `## Spec impact`, the task's commits (`git log --name-only` for the commits listed above) or the working tree must contain a change to `.ytstack/spec/<area>.md` or to a path under its `sources`. Then treat the result like `0` or `1`. |

On `1` there are two honest ways forward, and no third:

- **The task did change that contract.** Update the area file, or the authoritative source it names, in the task's commits. Then re-run this skill. Updating the source is enough; a pointer that is still correct is not edited.
- **The plan was wrong and the contract did not change.** Correct the plan's `## Spec impact` to `none -- <reason>` and record the correction under Deviations in Step 5's answer. Then re-run this skill.

On `4` with a line that does not say `modified after the task's first commit`, ask once with AskUserQuestion; `{BRANCH}` is the output of `git branch --show-current`, `{AREA_FILES}` the paths from the `UNVERIFIABLE` lines. With `YTSTACK_NON_INTERACTIVE: true` nobody can answer: STOP like exit `1` and report the `UNVERIFIABLE` lines.

> Closing {CURRENT_MILESTONE}-{ACTIVE_SLICE}-{ACTIVE_TASK} of {PROJECT_NAME} on branch `{BRANCH}`. Its plan says the task changes spec areas whose files live in your home directory, outside the repository: {AREA_FILES}.
>
> Git only sees files inside the repository, so it cannot show whether those descriptions were updated. You know whether you edited them.
>
> RECOMMENDATION: Choose B unless you edited those files for this task, because a summary that claims an update nobody made misleads every later session.
>
> A) Yes, the files describe the change now -- recorded as confirmed by you
>    Completeness: 9/10, effort: human: 0 / CC: 0, tier: task
>
> B) No, not yet -- the task stays open until they are updated
>    Completeness: 10/10, effort: human: ~5m / CC: ~2m, tier: task

On A, `_SPEC_RECORD` is the printed lines plus `confirmed by the person: the area file was updated`. On B, STOP like exit `1`. Do not edit a file inside the repository to produce git evidence for an edit outside it.

A sentence in the summary does not satisfy the check, and neither does an edit that changes no statement. A task whose plan says `none` closes without any spec edit: a bug fix that restores the described behaviour, a refactoring and a trivial change need none.

### Step 9: Write `M###-S##-T##-SUMMARY.md`

```markdown
---
milestone: {CURRENT_MILESTONE}
slice: {ACTIVE_SLICE}
task: {ACTIVE_TASK}
project: {PROJECT_NAME}
closed: {ISO_TIMESTAMP}
verification: {VERIFICATION_RESULT}
---

# {CURRENT_MILESTONE}-{ACTIVE_SLICE}-{ACTIVE_TASK} -- Summary

## Commits

{The commit list captured between TASK_COMMITS_BEGIN / TASK_COMMITS_END in the preamble, labelled by TASK_COMMITS_SOURCE:
- `task-ref`: list the commits as captured (their subjects matched COMMIT_PATTERN).
- `branch`: write "No commit subject matched `{COMMIT_PATTERN}`; commits on this branch since `{TASK_COMMITS_BASE}`:" followed by the list. Do NOT claim the task shipped uncommitted.
- `none`: write "No commits found for this task: no subject matched `{COMMIT_PATTERN}` and the current branch has no commits past its base. Either the work is uncommitted or it landed under another ref -- say which after checking `git status`."
This section replaces the throwaway hook draft; it is the durable commit-to-task link. The pattern comes from `PREFERENCES.md` `commit_ref_pattern` (default `^M###-S##-T##:`; tokens `M###`, `S##`, `T##`, `{task}`).}

## Outcome

{OUTCOME}

## Deviations from plan

{DEVIATIONS}

## Follow-ups

{FOLLOWUPS}

## Spec

{SPEC_RECORD: one line per area as `<area>: <file that changed> -- <section>`, or `none -- <reason>`. Taken from Step 8, never rephrased into a claim the check did not make.}

## Verification

Command: `{VERIFICATION_CMD}` -- {VERIFICATION_RESULT} at `{short SHA the check ran on}` in {environment the plan names, default: local checkout}{, runs: N -- only when the plan asks for more than one}.

Not checked: {what was not run or not looked at, and why; "nothing" only when that is true}
```

The Verification line is the task's evidence: the check, the commit and the environment. It records the run that `ytstack:verification-before-completion` already made; closing a task is not a reason to run the check again (`ytstack:minimal-code`, "Evidence").

### Step 10: Flip slice-plan checkbox

Edit `{SLICE_PLAN}`. Replace:

```
- [ ] {ACTIVE_TASK} -- {TASK_DESC}
```

with:

```
- [x] {ACTIVE_TASK} -- {TASK_DESC}
```

Also bump `completed_tasks` in the slice-plan's frontmatter by 1.

### Step 11: Update STATE.md

If `YTSTACK_NON_INTERACTIVE` is `false` (i.e. `CLAUDE_AGENT_TEAM_MEMBER` is unset), edit STATE.md frontmatter:
- `active_task: {ACTIVE_TASK}` → `active_task: none`
- If the slice is now fully complete (all tasks `[x]`): also `active_slice: {ACTIVE_SLICE}` → `active_slice: none`

If `YTSTACK_NON_INTERACTIVE` is `true` (running as swarm teammate): skip frontmatter writes. Log:
> `[ytstack:summarize-task] skipping STATE.md active_task/active_slice write -- running as swarm teammate (CLAUDE_AGENT_TEAM_MEMBER set)`

Regardless of teammate mode:
- `last_updated: ...` → bump to current
- Status line → `**Status:** {CURRENT_MILESTONE} / {ACTIVE_SLICE} -- {N}/{TOTAL} tasks done in slice. Next task: pick from slice-plan or run `/ytstack:plan-task`.`

**Progress block (M021):** if the `STATE.md` frontmatter has a `progress:` block, update it in the same edit. Add 1 to `done` when the closed task is an item the block counts. Tasks are the default unit; a project that counts something else says so in a comment line inside the block, and `done` / `total` then follow that ledger. If the closed task was added after `total` was set, raise `total` as well. Never write `done` above `total`. Then run `yt_state_lint "$_YT_DIR"`: a warning that starts with `progress:` means the edit is wrong; fix it before Step 12. As a swarm teammate skip the block with the other frontmatter writes and note the pending increment under Follow-ups in the summary. No block: do nothing and do not add one. `bin/ytstack-status` shows these numbers in the status line (`docs/statusline.md`).

If the slice is now fully complete (all tasks `[x]`): update status to recommend `/ytstack:reassess-roadmap`, flip the slice's `status:` to `done` in `{SLICE_PLAN}` frontmatter, and when every slice in `{CURRENT_MILESTONE}-ROADMAP.md` is checked flip the milestone's `status:` to `done` there and mirror the global `ROADMAP.md` row (M018 artifact states).

### Step 12: Offer git stage

If `IS_GIT=yes`, use AskUserQuestion:

> Task closed. Want to stage the touched files for commit?
>
> Files from plan: {FILE_LIST}
>
> RECOMMENDATION: A if the files match the plan. B if you touched additional files (deviation case).
>
> A) Stage the planned files -- `git add {FILE_LIST}` then you commit manually with a message
> B) Don't stage -- I'll handle it myself
> C) Stage all changes -- `git add -A` (use with caution; may include unintended files)

If A: run `git add {FILE_LIST}` and report `git status` output.
If B: skip.
If C: confirm once more (destructive-flavored), then `git add -A` + `git status`.

### Step 13: Report + return

Report:

> Task **{ACTIVE_TASK}** closed.
>
> Summary at: `{YT_DIR}/{CURRENT_MILESTONE}-{ACTIVE_SLICE}-{ACTIVE_TASK}-SUMMARY.md`
> Spec: {SPEC_RECORD}
> Slice-plan checkbox flipped.
> STATE.md: `active_task` cleared.
>
> Next step:
> - If slice has more tasks: `/ytstack:plan-task` for the next one
> - If slice is complete: `/ytstack:reassess-roadmap` to check if plan still fits reality before moving to next slice
> - If milestone is complete: flip milestone status in ROADMAP.md and run `/ytstack:plan-milestone` for the next

## Terminal State

Valid terminal states:
- Return after summary file + slice-plan update + STATE.md update + optional git stage
- Abort on HARD-GATE failure (no active task / missing plan file)
- Abort on verification failure (C in Step 7) -- task stays open
- Abort on an unmet spec impact (Step 8) -- task stays open until the area file or its source is updated, or the plan's impact is corrected
- Abort on an unverifiable user-scope area the person did not confirm (Step 8, exit `4`, answer B or non-interactive)

Do NOT invoke `plan-task`, `reassess-roadmap`, or `plan-milestone` automatically -- except under `AUTONOMY: loop` (PREFERENCES default, M018): when the slice still has unplanned or open tasks, continue with `ytstack:plan-task` for the next one without asking; when this summary closed the slice's last task, stop and recommend `ytstack:reassess-roadmap` (slice boundary). With `AUTONOMY: step` return control after the report.

**Granularity (M018):** with `GRANULARITY: slice` the summary file is `M###-S##-SUMMARY.md` and the task ref for commit discovery is `M###-S##` (`yt_commit_ref_pattern "$_YT_DIR" M### S## ""` with the default pattern reduced to `^M###-S##:`); with `GRANULARITY: milestone` it is `M###-SUMMARY.md` / `^M###:`. Flip the slice (or milestone) status to `done` instead of a task checkbox.

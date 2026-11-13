---
name: code-review
metadata:
  tier: task
  version: 0.4.0
description: "Reviews the active task's commits with a fresh-context reviewer subagent and handles the feedback with technical rigor, through the vendored superpowers requesting-code-review and receiving-code-review procedures, with the task plan and commit range injected. Use after a task's commits exist and before summarize-task, before a merge or PR, or when the user says review this, code review, check my changes. Not for reviewing a plan (plan-eng-review) and not without commits for the task."
allowed-tools:
  - Bash
  - Read
  - Edit
  - Agent
  - AskUserQuestion
---

# ytstack:code-review

Thin wrapper around two vendored superpowers skills: `requesting-code-review` (dispatch a reviewer subagent with precise context) and `receiving-code-review` (evaluate the feedback instead of performing agreement). Injects the active task's plan and commit range, inlines both vendored procedures verbatim, and routes the findings into ytstack artifacts.

## ytstack context (resolved at render time)

```!
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
_M=none; _S=none; _T=none
if [ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/STATE.md" ]; then
  _M=$(sed -n 's/^current_milestone: *//p' "$_YT_DIR/STATE.md" | head -1)
  _S=$(sed -n 's/^active_slice: *//p' "$_YT_DIR/STATE.md" | head -1)
  _T=$(sed -n 's/^active_task: *//p' "$_YT_DIR/STATE.md" | head -1)
fi
_TASK_PLAN="$_YT_DIR/$_M-$_S-$_T-PLAN.md"
# Commits of the active task (same discovery as summarize-task: task-ref pattern, branch fallback).
_COMMITS=""; _COMMITS_SOURCE=none; _BASE_SHA=""; _HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo none)
if [ "$_IS_GIT" = yes ] && [ "$_T" != none ] && command -v yt_task_commits >/dev/null 2>&1; then
  _PAT=$(yt_commit_ref_pattern "$_YT_DIR" "$_M" "$_S" "$_T")
  yt_task_commits "$_PROJECT_DIR" "$_PAT"
  _COMMITS="$YT_COMMITS"; _COMMITS_SOURCE="$YT_COMMITS_SOURCE"
  if [ "$_COMMITS_SOURCE" = task-ref ]; then
    _OLDEST=$(git log --no-merges -E --grep "$_PAT" --pretty=format:%h 2>/dev/null | tail -1)
    # The parent of the task's first commit; for a repository's root commit the
    # empty tree. Without --verify, rev-parse prints the unresolved "<sha>^".
    [ -n "$_OLDEST" ] && _BASE_SHA=$(git rev-parse --verify --quiet "$_OLDEST^" 2>/dev/null || git hash-object -t tree /dev/null 2>/dev/null)
  elif [ -n "$YT_COMMITS_BASE" ]; then
    _BASE_SHA="$YT_COMMITS_BASE"
  fi
fi
echo "HAS_YTSTACK: $([ -n "$_YT_DIR" ] && echo yes || echo no)"
echo "IS_GIT: $_IS_GIT"
echo "ACTIVE_TASK: $_M-$_S-$_T"
echo "TASK_PLAN: $_TASK_PLAN"
echo "TASK_PLAN_EXISTS: $([ -f "$_TASK_PLAN" ] && echo yes || echo no)"
echo "COMMITS_SOURCE: $_COMMITS_SOURCE"
echo "BASE_SHA: ${_BASE_SHA:-none}"
echo "HEAD_SHA: $_HEAD_SHA"
echo "COMMITS_BEGIN"
echo "${_COMMITS:-(none)}"
echo "COMMITS_END"
# Technical spec (M022): the area files that cover what the task changed.
_SPEC_EXISTS=$([ -n "$_YT_DIR" ] && [ -f "$_YT_DIR/spec/SPEC.md" ] && echo yes || echo no)
_SPEC_TOOL="${CLAUDE_SKILL_DIR}/../../bin/ytstack-spec"
echo "SPEC_EXISTS: $_SPEC_EXISTS"
echo "SPEC_AREAS_BEGIN"
if [ "$_SPEC_EXISTS" = yes ] && [ -f "$_SPEC_TOOL" ] && [ -n "$_BASE_SHA" ]; then
  # shortcut: paths are split on whitespace; a path with a space finds no area.
  # shellcheck disable=SC2046
  bash "$_SPEC_TOOL" areas --names $(git diff --name-only "$_BASE_SHA..HEAD" 2>/dev/null | head -200) 2>/dev/null \
    | sed "s|^|.ytstack/spec/|; s|\$|.md|"
fi
echo "SPEC_AREAS_END"
# Review rounds (M023): one line per round in the task plan under "## Review".
_ROUNDS=0; _LAST_HEAD=""
if [ -f "$_TASK_PLAN" ]; then
  _ROUNDS=$(grep -c -E '^- Round [0-9]+:' "$_TASK_PLAN" 2>/dev/null); _ROUNDS=${_ROUNDS:-0}
  _LAST_HEAD=$(grep -E '^- Round [0-9]+:' "$_TASK_PLAN" 2>/dev/null | tail -1 | sed -n -E 's/^- Round [0-9]+: *[0-9a-f]+\.\.([0-9a-f]+).*/\1/p')
  [ -n "$_LAST_HEAD" ] && ! git rev-parse --verify --quiet "$_LAST_HEAD^{commit}" >/dev/null 2>&1 && _LAST_HEAD=""
fi
echo "REVIEW_ROUND: $((_ROUNDS + 1))"
echo "LAST_REVIEWED_HEAD: ${_LAST_HEAD:-none}"
# The risk gate (M025): what the script decided about the whole change of the
# task before any reviewer speaks, and the lenses that change requires.
_RISK_TOOL="${CLAUDE_SKILL_DIR}/../../bin/ytstack-risk"
echo "RISK_FLOOR_BEGIN"
if [ -f "$_RISK_TOOL" ] && [ -n "$_BASE_SHA" ] && [ "$_HEAD_SHA" != none ]; then
  bash "$_RISK_TOOL" floor --base "$_BASE_SHA" --head "$_HEAD_SHA" 2>&1 | head -40
else
  echo "floor: unknown (bin/ytstack-risk is not reachable, or the task has no commit range)"
fi
echo "RISK_FLOOR_END"
```

## ytstack invocation notes

You are invoked inside a ytstack project after the active task's commits exist. The vendored `requesting-code-review` template needs `{DESCRIPTION}`, `{PLAN_OR_REQUIREMENTS}`, `{BASE_SHA}`, `{HEAD_SHA}`: take the description from the task plan's Summary, the requirements from `TASK_PLAN` (What this does + Verification) plus the numbered list under "Bounded review", and the SHAs from `BASE_SHA` / `HEAD_SHA` above (never guess `HEAD~1`; from round 2 on the base is `LAST_REVIEWED_HEAD`).

HARD-GATE: if `IS_GIT=no`, abort. If `ACTIVE_TASK` has `none` in it or `TASK_PLAN_EXISTS=no`, abort with "no active task plan; run `ytstack:plan-task` or review a plain diff without ytstack". If `COMMITS_SOURCE=none` or `BASE_SHA=none`, abort with "no commits found for the task; commit with the `M###-S##-T##:` prefix (or set `commit_ref_pattern` in PREFERENCES) and re-run".

**Spec check, bounded to the touched area.** When `SPEC_EXISTS=yes`, add to the reviewer's requirements the plan's `## Spec impact` section and the paths listed under `SPEC_AREAS` (the area files of `.ytstack/spec/` that cover the changed files). The reviewer reads those area files, and the section of a `sources` document they point to, against the diff. Two things are findings: the diff changes behaviour, an interface, an invariant or an error path that an area file describes while the plan says `none`; or an area file (or its source) now states something the diff contradicts. A change that restores the described behaviour needs no spec edit and is not a finding. The reviewer does not audit the rest of the spec, other areas or the repository's documentation.

## Bounded review (ytstack)

A review ends. Where the vendored text below and this section differ, this section applies.

**Which round this is** (`REVIEW_ROUND` above):

| Round | What is reviewed | What the reviewer may report |
|---|---|---|
| 1 | The whole change, `BASE_SHA..HEAD_SHA`, with the callers and boundaries it touches. | Everything it finds. This round is meant to be complete. |
| 2 | Only the fix: `LAST_REVIEWED_HEAD..HEAD_SHA`, and what those commits touch. Give the reviewer the findings of round 1. | Whether each finding is fixed. A new finding only when the fix introduced it, or when it is a serious defect (a permission that no longer holds, data that can be lost, a wrong result) with its concrete trigger; that one still blocks. Nothing about code the fix did not touch, no new matters of taste. |
| 3 or more | Nothing. Do NOT dispatch a reviewer. | See "Third round" below. |

**What the reviewer is told, in addition to the vendored template** (put it into `{PLAN_OR_REQUIREMENTS}`):

1. Open with what the change does, in two sentences, and with `Assumed load:` the product stage and the volume the review rates against, and where that number comes from: `PROJECT.md`, the area file's "Known limits" and "Runtime and deployment assumptions", `RUNTIME.md`, a budget the plan sets. If no document states it, write `assumed, not documented: <what>`.
2. Every finding has the file and lines, a concrete case (this input or this state leads to this wrong result) confirmed by reading the lines again, the smallest fix, and `If skipped:` with what happens then, in one sentence. No case, no finding.
3. A scale or speed finding is rated against the assumed load. A path that gets slow or fails only at a volume this stage does not reach is a note, with the volume at which it starts to matter. At the stage's own load it is rated like any defect. Broken contracts, security boundaries, lost data and wrong answers are rated the same at any load.
4. A `shortcut:` comment that names its limit is a decision, not a finding, unless the assumed load is already beyond that limit.
5. No acceptance conditions the plan does not have, no vague worries, no style preferences.
6. Close with `Not checked:` what was not looked at, and why.
7. After `Not checked:` come four labels, each at the start of a line. How to decide them: "The class of the change" below. Hand the reviewer that paragraph and the lines between `RISK_FLOOR_BEGIN` and `RISK_FLOOR_END`.

```
Risk: <low | normal | high>
Severity: <what the worst plausible mistake in this change costs>
Reach: <what it can affect: these files, one area, several areas, stored data, users>
Invariants touched: <none | area: the invariant or decision, in its own words>
```

**The class of the change.** Whether a person has to look at a change is decided from its class. The table under "Risk classes" in `${CLAUDE_SKILL_DIR}/../../docs/ux/review-policy-format.md` says what `low`, `normal` and `high` mean; the reviewer reads it there. The reviewer states the class. The author of a change never does.

- **Severity and reach first.** What does the worst plausible mistake in this change cost, and what can it affect? The class follows from those two answers, not from the size of the diff.
- **The floor.** The lines between `RISK_FLOOR_BEGIN` and `RISK_FLOOR_END` are what `bin/ytstack-risk floor` computed from the diff of the whole task: `floor:`, one `reason:` per rule that raised it, the `areas:` the change touches, their `ceiling:` and the `lenses:` it requires. A reviewer cannot state a class below `floor:`. `floor: person` means the change goes to a person whatever the review says; the review still runs and still states its class. A first line other than `floor: low`, `floor: normal` or `floor: person` means the floor is unknown: the report says so under `Not checked:`.
- **Invariants.** The reviewer reads the change against the sections "Invariants and security boundaries" and "Decisions that apply now" of every area file under `SPEC_AREAS`. A rule the change shifts is named under `Invariants touched:` with its area, in the document's own words. That holds also when the diff changes only code and leaves the document alone: no path rule sees that case, only this reading does. A change that touches such a rule is `high`. With no area file to read against, the answer is `none`, and `Not checked:` says that no area file covers the change.
- **Round 2.** It looks at the fix only, but the newest round line is the one that counts, so its four labels speak for the whole change. Give the reviewer the four labels of round 1. It restates them and changes one only when the fix changes the answer.

**Who reviews.** The reviewer is never the author. This skill dispatches a fresh reviewer (the vendored procedure below); name the Agent call `review-{ACTIVE_TASK}`, and that name goes into the round line as `by:`. A session that reviews its own change without a dispatched reviewer writes `by: self`. Say then, in plain words, that this was no independent review: the route of that change is `person` (`bin/ytstack-risk route`), and nothing merges it without one.

**Whose severity counts.** If the project says what blocks a change (a review policy in `AGENTS.md`, `CONTRIBUTING.md` or a reviewers folder), that policy rates the findings. A finding it rates non-blocking is never used to hold the task: it goes to Follow-ups. A risk the policy says a person has to accept is written as a gate in the task plan (`## Gates`, format in `ytstack:plan-task`); nobody in this session accepts it.

**Record the round.** After the findings are handled, append one line to the task plan under `## Review` (add the heading on the first round), with seven-character SHAs:

```
- Round {REVIEW_ROUND}: {base}..{HEAD_SHA} -- {approved | changes requested}; blocking: {n}; follow-ups: {n}; risk: {low | normal | high}; invariants: {none | area: the rule}; by: {reviewer}
```

`{base}` is `BASE_SHA` in round 1 and `LAST_REVIEWED_HEAD` afterwards. The line is what the next run counts; without it every review looks like the first.

`risk` and `invariants` are the reviewer's `Risk:` and `Invariants touched:` values, unchanged, on this one line: no `;` inside a value, several rules joined with commas. You do not raise or lower them; `bin/ytstack-risk` takes the higher of the stated class and the floor. `by` is the reviewer's name, or `self`. A reviewer that left a label out is asked for it once. A line without `risk`, `invariants` or `by` reads as a round that states none of them, and the change goes to a person.

**Third round.** Two rounds are recorded and the change is still not accepted. A third review would find a third thing. Stop and diagnose instead, from the round lines, the findings and the fix commits:

- **Scope:** is the disputed point something the plan never decided? Then it is a question for the human, not for a reviewer.
- **Conflicting rules:** do two rules of the project ask for opposite things here? Name both.
- **Solution:** did each fix move the problem instead of removing it? Then the approach is wrong, not the last commit.

Put the diagnosis to the human in one AskUserQuestion: what does not converge, which of the three it is, your recommendation, and the options (decide the point; change the scope of the task; accept the change with the remaining finding as a tracked follow-up, where the project's policy allows that). Do not dispatch a reviewer, do not write another fix, do not run `ytstack:summarize-task`.

## After the reviewer returns

The vendored `receiving-code-review` procedure applies to its findings. ytstack additions:

- Critical and Important findings fixed now get their own task-ref commits; Minor findings and "push-backs with reasoning" go into the task summary's Follow-ups (`ytstack:summarize-task` reads them from the conversation).
- A finding that reveals a repo-wide pattern goes to `KNOWLEDGE.md`; a reversal of an earlier choice goes to `DECISIONS.md`, never silently, and the area file it concerns lists the new entry under "Decisions that apply now" instead of the old one.
- Do NOT run `ytstack:summarize-task` or `ytstack:verification-before-completion` automatically; name them as the next step.

## Vendored procedure 1: requesting (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/requesting-code-review/SKILL.md"
```

## Vendored procedure 2: receiving (inlined verbatim)

```!
cat "${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/receiving-code-review/SKILL.md"
```

## Namespace note (ytstack)

The text above is upstream superpowers content (v7.0.2) rendered inside ytstack. Read `superpowers:<skill>` as `ytstack:<skill>` and invoke the ytstack-namespaced skill via the Skill tool. Relative links such as `code-reviewer.md` (the reviewer prompt template) resolve under `vendor/superpowers/skills/requesting-code-review/` in the ytstack plugin directory (`${CLAUDE_SKILL_DIR}/../../vendor/superpowers/skills/requesting-code-review/`); read the template from there and fill it with the values from the ytstack context block. "Subagent-driven development" in the vendored text corresponds to `ytstack:spawn-milestone-team`'s worktree subagents.

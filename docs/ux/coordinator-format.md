# Coordinator formats

One session that owns a plan and delegates all of it needs four things on disk, so that it can lose its context and continue from files: who works on what (lanes), what may start next (the frontier), what only the human can decide (questions) and what the human asked for once and for all (standing instructions). This document fixes their formats. The skills that use them are `coordinate`, `spawn-milestone-team`, `finish-lane`, `handover-step`, `lane-retro` and `reassess-roadmap`; the scripts are `bin/ytstack-frontier`, `bin/ytstack-questions`, `bin/ytstack-finish-lane`, `bin/ytstack-handover`, `bin/ytstack-watch` and `bin/ytstack-brief`.

All files live in the project's `.ytstack/` directory and are user-owned like every artifact there.

## Two rules for everything a coordinator writes

1. **Written as history.** Every entry carries the UTC time it was written. A statement about code names its commit. An entry that was overtaken is marked superseded with the date and what replaced it; it is not rewritten and not deleted.
2. **Host facts are never stored as current.** The state of a pull request, of its checks, of a review thread or of a deployed build lives on the host and changes without the coordinator. `.ytstack/` records what the coordinator did (dispatched, reviewed commit X, asked the human) and identifiers (a branch, a pull request number). Before a status goes to the human, the host facts in it are read again, and the status says when: `read 2026-11-13T10:42Z`.

## `LANES.md` -- who works on what

A lane is one unit of delegated work: by default one slice (`M004-S02`), where a plan needs it one task (`M004-S02-T03`) or a named piece outside the milestone plan (`review-pr-12`). `STATE.md` stays the pointer of the session's own position and links this file; the table does not live in `STATE.md`.

```markdown
---
updated: 2026-11-13T10:42:00Z
---

# Lanes

| Lane | Kind | Status | Claimed by | Branch | Worktree | PR | Reviewed head | Round | Next action |
|---|---|---|---|---|---|---|---|---|---|
| M004-S01 | implement | merged | impl-M004-S01 2026-11-13T08:10Z | ytstack/M004-S01 | - | 11 | a1b2c3d | 1 | - |
| M004-S02 | implement | running | impl-M004-S02 2026-11-13T10:02Z | ytstack/M004-S02 | .claude/worktrees/m004-s02 | - | - | 0 | wait for the report |
```

| Column | Holds |
|---|---|
| Lane | The reference. Unique in the file. |
| Kind | `implement`, `review` or `prepare` (see "Lane kinds"). |
| Status | `claimed` (taken, not dispatched yet), `running`, `reported` (the worker's report is in and passed the check), `in-review`, `ready` (its gates held when last read), `merged`, `blocked`, `dropped`. What the coordinator did or saw last; not a host fact. |
| Claimed by | The worker's name and the UTC time of the claim. `-` when nobody holds it. |
| Branch, Worktree | Where the work is. `-` when it does not apply. |
| PR | The number, as an identifier. Its state is read from the host when needed. |
| Reviewed head | The commit the newest independent review looked at. A merge happens at this commit or not at all. |
| Round | The number of review rounds on this lane (`code-review` rules: round 1 complete, round 2 the fix, round 3 a diagnosis). |
| Next action | One line: what the coordinator does next for this lane, or what it waits for. For `blocked`: on what. |

A lane that was never claimed has no row. `bin/ytstack-frontier` is the only writer besides a human: it changes one row per call, takes a lock for the write (`LANES.md.lock`, so that claims sent together do not lose a row) and rewrites `updated`. Cells contain no `|`. A held lane is released before it can be claimed again.

## Blocking edges and the frontier

A slice plan names what has to be finished before it can start, directly under its goal:

```markdown
**Goal:** Users can export only what changed since a date.

**Blocked by:** S01, S03
```

`**Blocked by:** none` or no line: nothing blocks it. A task plan may carry the same line with task references (`**Blocked by:** T01`). Only real dependencies are written: a slice that needs another slice's result. Order of preference is not a dependency.

The **frontier** is every lane that is open, unblocked and unclaimed. `bin/ytstack-frontier` prints one line per slice of the current milestone:

```
M004-S01	done
M004-S02	claimed	impl-M004-S02 2026-11-13T10:02Z
M004-S03	blocked	S02
M004-S04	ready
```

The list also reads the lanes table: a row with Status `merged` counts as done even while the roadmap checkbox is still open, and a row with Status `blocked` is listed as blocked with its next action. A lane that an open or asked question names under `blocks:` is blocked until the question is answered.

A claim is written before the work is dispatched: `ytstack-frontier claim <lane> --by <worker>`. Claiming a lane that is already held fails and names the holder. That is what keeps a second message to a running lane from starting the same work twice. The coordinator dispatches again whenever the frontier changes, not once per milestone.

## Lane kinds

`bin/ytstack-brief render --kind <kind>` adds what the worker may do:

| Kind | The worker | Its report |
|---|---|---|
| `implement` | changes files inside the brief's scope and commits with the task prefix | as below |
| `review` | reads only; reviews one commit range that the brief pins (`--head <sha>`); findings follow `code-review` ("Bounded review") | `Outcome:` carries the verdict (`approved` or `changes requested`) and the reviewed commit |
| `prepare` | writes files and commits nothing: for a sandbox that cannot take the git index lock, and for research | `Uncommitted:` lists every file it left |

## The report

Every worker ends with the same labels, each at the start of a line. `bin/ytstack-brief check` validates them.

```
Task: <ref>
Status: <complete | partial | blocked>
Outcome: <what holds now, one to three sentences, past tense>
Commits: <git log --oneline <base>..HEAD, or "none">
Uncommitted: <files changed and not committed, or "none">
Checks run: <command> -- exit <n> at <short sha> in <environment>
Spec: <area: file that changed | none -- reason>
Deviations: <or "none">
Blockers: <or "none">
Not checked: <what was not run or not looked at, and why; "nothing" only when that is true>
Next: <the next action for whoever dispatched this, in one line>
```

`partial` and `blocked` are values of `Status:`, never a word in a paragraph. `Status: blocked` needs a `Blockers:` value other than `none`; `Status: complete` needs `Blockers: none`.

## `questions/` -- what only the human can decide

One file per pending question: `.ytstack/questions/Q###-<slug>.md`.

```markdown
---
id: Q007
state: open
decides: the operator
opened: 2026-11-13T09:15:00Z
asked: none
answered: none
blocks: M004-S03, G02
---

# Q007 -- Does the export include rows that were archived before the cut-over?

## Context

<What the coordinator knows, with pointers to files and commits. Enough to answer without asking back.>

## Options

- A) <option> -- consequence: <what follows>
- B) <option> -- consequence: <what follows>

## Recommendation

<One option and one reason.>

## Answer

<Empty until answered. Then: the answer, who gave it and when, and the DECISIONS.md entry it became.>
```

| `state` | Means |
|---|---|
| `open` | Written, not put to the human yet. |
| `asked` | Put to the human at `asked`. It is not asked again. |
| `answered` | `## Answer` is filled; the answer is recorded in `DECISIONS.md` when it decides something that lasts. |

Rules:

- Before a question file is written, the plan, `DECISIONS.md` and the answered questions are searched. What they answer is not asked.
- One question at a time, as late as the work allows, with everything prepared: the human should be able to answer from the file alone.
- A gate of a slice or task plan (`## Gates`) that needs a person's verdict gets a question file; `blocks` names the gate. `reassess-roadmap` still brings all open ones in one message at a slice boundary.
- No agent fills `## Answer` with anything the human did not say.

`bin/ytstack-questions list` prints the open and asked ones; `check` validates the files.

## `STANDING.md` -- what the human asked for once and for all

An instruction that holds beyond the task at hand ("never merge without my word", "status only at slice boundaries") is written down when it is given, because a summary after a compaction does not keep it.

```markdown
# Standing instructions

- 2026-11-13T09:02Z -- Status reports only at slice boundaries. Scope: this project.
- 2026-11-12T16:40Z -- ~~Reviews run on every push.~~ Superseded 2026-11-13T09:05Z: one review per lane, a second only for the fix.
```

Own words, never a quotation. One line each: time, the instruction, its scope. The coordinator reads the file at every start and after every compaction, before it acts.

## Checked mechanically

- `bin/ytstack-frontier check`: `LANES.md` has the ten columns, lane references are unique, `Status` and `Kind` hold listed values, a held lane has a claim time.
- `bin/ytstack-questions check`: ids are unique and match the file name, `state` holds a listed value, `asked` and `answered` are set exactly when the state says so, an answered file has text under `## Answer`.
- `bin/ytstack-brief check`: the report labels, the three `Status:` values and their consistency with `Blockers:`.
- `bin/ytstack-handover check`: the staged script of a human-only step (see `skills/handover-step/SKILL.md`).

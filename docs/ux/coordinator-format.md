# Coordinator formats

One session that owns a plan and delegates all of it needs four things on disk, so that it can lose its context and continue from files: who works on what (lanes), what may start next (the frontier), what only the human can decide (questions) and what the human asked for once and for all (standing instructions). This document fixes their formats. The skills that use them are `coordinate`, `spawn-milestone-team`, `finish-lane`, `handover-step`, `lane-retro` and `reassess-roadmap`; the scripts are `bin/ytstack-frontier`, `bin/ytstack-questions`, `bin/ytstack-finish-lane`, `bin/ytstack-handover`, `bin/ytstack-watch` and `bin/ytstack-brief`.

All files live in the project's `.ytstack/` directory and are user-owned like every artifact there.

## Two rules for everything a coordinator writes

1. **Written as history.** Every entry carries the UTC time it was written. A statement about code names its commit. An entry that was overtaken is marked superseded with the date and what replaced it; it is not rewritten and not deleted.
2. **Host facts are never stored as current.** The state of a pull request, of its checks, of a review thread or of a deployed build lives on the host and changes without the coordinator. `.ytstack/` records what the coordinator did (dispatched, reviewed commit X, asked the human) and identifiers (a branch, a pull request number). Before a status goes to the human, the host facts in it are read again, and the status says when: `read 2026-11-13T10:42Z`.

## `LANES.md` -- who works on what

A lane is one unit of delegated work: by default one slice (`M004-S02`), where a plan needs it one task (`M004-S02-T03`), a lesson whose check is still to be built (`lesson-F012`, see below) or a named piece outside the milestone plan (`review-pr-12`). `STATE.md` stays the pointer of the session's own position and links this file; the table does not live in `STATE.md`.

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

A lane that was never claimed has no row. `bin/ytstack-frontier` is the only writer besides a human: it changes one row per call, takes a lock for the write (the file `LANES.md.lock`, so that claims sent together do not lose a row) and rewrites `updated`. Cells contain no `|`. A held lane is released before it can be claimed again.

### Peers

The sessions in other repositories that the coordinator works with (a session that deploys, one that owns a shared service) are part of its state, so a compaction does not drop who is who. They stand in a `## Peers` section after the lanes table, one list line each:

```markdown
## Peers

- prod deploy | Yesterday-AI/cloud | claude:6f1c2d0e-1b7a-4c55-9a1e-0c3d5e7f9a21 | 2026-11-15T09:12Z
- review bot owner | acme/app | agent b7e2 | 2026-11-15T08:40Z
```

The cells are the role, the repository, the address (what the host gives to reach that session) and the UTC time of the last contact. Role and repository together name a peer. `ytstack-frontier peer set <role> --repo <owner/name> --address <address> [--contact <UTC>]` adds the line or replaces it, with the last contact now unless `--contact` gives one; `ytstack-frontier peer list` prints the lines tab separated. A message to another session goes to the address listed here, never to one remembered from the conversation, and `peer set` runs after every contact. The lines are list items, not table rows, so every reader of the lanes table leaves them alone.

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

### Lanes that stall

`ytstack-frontier check [--minutes N]` reads a well-formed table for lanes that nobody moves, one line each, and exits 2 when it prints one:

```
stale: M004-S02: running, no commit on ytstack/M004-S02 for 95 minutes (since 2026-11-15T08:40Z)
stale: M004-S05: running, but its worktree .claude/worktrees/m004-s05 does not exist: the worker ended; read its branch and set the status
stale: review-pr-43: running review lane, no report for 200 minutes (claimed 2026-11-15T06:00Z)
stale: M004-S06: ready, nobody claimed it for 70 minutes (first seen 2026-11-15T09:00Z)
```

A `running` row is stale when its worktree no longer exists (the worker ended) or, for an `implement` lane, when its branch had no commit for N minutes (default 60), counted from the claim when that is newer or the row names no branch. A running row with a pull request in it is a fix round (`finish-lane`), not a report: its clock starts when a check first sees that pull request and round in the row, and a new round starts it again. A `review` or `prepare` lane commits nothing; it is stale after 3 x N minutes since its claim without a report. A `ready` lane of the frontier is stale when nobody claimed it for N minutes since a check first saw it ready. First sights are kept outside the tree, one writer at a time (`<state base>/repos/<repo key>/frontier-seen`, the base of `yt_state_base`). `bin/ytstack-upkeep` lists these lines under `lanes`. A stale line is a prompt to read the lane's branch and set its row, or to dispatch the ready lane; it never releases a lane by itself.

### Pull requests that stall

A lane with a pull request can stall in a way the clock above does not see in time: a blocking review, a conflict or a red check, and then nobody pushes. Both watchers say so (issue #91). The rule is the same in both: a pull request in an actionable state with no new head for T minutes (default 15) gets a mark, once after T and once more after the next T, never a third time.

```
2026-11-15T14:30:07Z #1896 STALL 1: conflict, review changes_requested; no new head for 15 min (head a1b2c3d); lane M004-S03 held by impl-S03 (running), last commit 52 min ago on ytstack/M004-S03
- acme/app#1896: action_required (head a1b2c3d4, 40s ago) -- Merge conflict with base branch; STALL 2: no new head or status for 31 min; lane M004-S03 held by impl-S03 (running), last commit 68 min ago on ytstack/M004-S03
```

The first is a line of `ytstack-watch --stall <minutes>` (states it counts: checks red, a conflict, changes requested on the head), the second the line of the PR watch's status block (state `action_required`, policy key `stall_minutes`; `docs/pr-watch.md`). The tail after the time is `ytstack-frontier owner --pr <N>`: the lane whose `PR` cell names the pull request (`12` or `#12`), its holder and status, and the age of the last commit on its branch, or of the claim when that is newer, the clock `check` uses. Without such a row the line ends after the time. What the coordinator does with `STALL 1` and `STALL 2` is in `skills/coordinate/SKILL.md`, Step 7.

A pull request that blocks other lanes is a focus pull request: `ytstack-pr-watch register --pr <N> --focus` reads it on every worker tick and lists it first under `Focus (read every tick):`, `ytstack-watch --focus <N>` reads it every 20 seconds and prints it first.

### Lesson lanes

Every incident ends with a lesson (`docs/ux/signal-format.md`, "Lessons"). A lesson whose target is a check that nobody built yet, `open` or `planned`, is work that may start like a slice. The frontier lists it after the slices of the milestone, also when no milestone is open:

```
lesson-F012	ready	lesson:ci:flaky-order
lesson-F014	blocked	unplanned: the lesson has no ## Files or no ## Verification
```

The lesson carries its own plan: a `## Files` and a `## Verification` section after `## Next`. Without them the lane is blocked until the lesson step or the coordinator writes them. A question that names `lesson-F012` under `blocks:` blocks it like a slice. The brief comes from `ytstack-brief render --lesson F012` (with `--kind review --head <sha>` for its review); the lane goes through `finish-lane` like any other. After the merge the coordinator sets the lesson `fixed` (`ytstack-signals set F012 --state fixed`); until then the frontier lists the merged lane as done, with a reminder.

## Lane kinds

`bin/ytstack-brief render --kind <kind>` adds what the worker may do:

| Kind | The worker | Its report |
|---|---|---|
| `implement` | changes files inside the brief's scope and commits with the task prefix | as below |
| `review` | changes no product file and commits nothing; reviews one commit range that the brief pins (`--head <sha>`); findings follow `code-review` ("Bounded review"). A lens reviewer (`--lens <name>`, `docs/ux/review-policy-format.md`) with `evidence: visual` writes its screenshots into the evidence directory and nothing else | `Outcome:` carries the verdict (`approved` or `changes requested`) and the reviewed commit; a review states `Risk:`, `Severity:`, `Reach:` and `Invariants touched:`, a lens adds `Lens:` and `Evidence:` |
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

## `standing/` -- what the human asked for once and for all

An instruction that holds beyond the task at hand ("never merge without my word", "status only at slice boundaries") is written down when it is given, because a summary after a compaction does not keep it.

One file per instruction: `.ytstack/standing/<YYYYMMDDTHHMMZ>-<slug>.md`, the UTC time it was given and a lowercase slug. Two pull requests that each add an instruction add two files and never touch the same line.

```markdown
---
given: 2026-11-13T09:05:00Z
scope: every lane of this project
supersedes: 20261112T1640Z-review-every-push
---

One review per lane, a second only for the fix.
```

| Key | Holds |
|---|---|
| `given` | The UTC time, ISO (`YYYY-MM-DDTHH:MMZ`, seconds optional). The same minute as the file name, whose time orders the entries; missing seconds count as `00`. |
| `scope` | Where the instruction applies. Not empty. |
| `supersedes` | Empty, or the file name (without `.md`) of the earlier entry this one replaces. |

Rules:

- Own words, never a quotation. The body is the instruction.
- An entry is not edited after it is written and nothing is deleted. An instruction that replaces another is a new file whose `supersedes` names the old one; from then on the old one no longer holds.
- Readers take the entries newest first and skip every entry that another entry supersedes. `yt_standing` in `hooks/lib/git-ctx.sh` prints them; the preambles of `coordinate`, `finish-lane` and `signal-intake` list them between `STANDING_ENTRIES_BEGIN` and `STANDING_ENTRIES_END`. The coordinator reads every listed file at every start and after every compaction, before it acts.
- A `README.md` in the directory is a note for people and is not an entry.

### `STANDING.md`

The single file of earlier versions stays valid. A project without `standing/` keeps it as it was: one line per instruction, time, the instruction, its scope; a replaced line is struck through and dated.

```markdown
# Standing instructions

- 2026-11-13T09:02Z -- Status reports only at slice boundaries. Scope: this project.
- 2026-11-12T16:40Z -- ~~Reviews run on every push.~~ Superseded 2026-11-13T09:05Z: one review per lane, a second only for the fix.
```

Where both exist, both are read: `STANDING.md` may be a short index that points at the directory, and lines it still holds keep holding. New instructions go into `standing/`; the coordinator appends to `STANDING.md` only in a project that has no `standing/` directory yet.

## Rotation -- the handoff of a coordinator

A coordinator rotates to a fresh session after one compaction, while its lanes run (`skills/coordinate/SKILL.md`, Step 12). It writes `HANDOFF.md` in the format of `handoff-session` and puts this block into "In-flight work". The block holds what the files above do not: what runs in the old session and how the successor reaches it.

```markdown
Rotation at 2026-11-15T09:12Z. Lanes, frontier, questions and standing instructions are in the files.

- PR watch session: claude:6f1c2d0e-1b7a-4c55-9a1e-0c3d5e7f9a21
- Background watches: `ytstack-watch --pr 41,43 --interval 60`; `ytstack-watch release --commit 9b8c7d6` since 2026-11-15T09:05Z
- Running workers:
  - M004-S02 | impl-M004-S02 | address: agent a3f9c1 | worktree: .claude/worktrees/m004-s02 | branch: ytstack/M004-S02 | dispatched 2026-11-15T08:40Z
  - review-pr-43 | review-pr-43 | address: codex pid 81234, log /tmp/review-pr-43.log | worktree: .worktrees/review-pr-43 | branch: - | dispatched 2026-11-15T09:01Z
- Peers:
  - prod deploy | Yesterday-AI/cloud | claude:6f1c2d0e-1b7a-4c55-9a1e-0c3d5e7f9a21 | 2026-11-15T09:12Z
```

| Line | Holds |
|---|---|
| `PR watch session:` | The old session's id as the PR watch stores it (`claude:<id>`, or the Codex thread id), or `none` when the PR watch is off. The successor runs `ytstack-pr-watch handover --from <id>` (`docs/pr-watch.md`). |
| `Background watches:` | The command of every `ytstack-watch` the old session runs, so that the successor starts them again. `none` when there are none. |
| `Running workers:` | One line per dispatched worker that has not reported: lane, name, address, worktree, branch, dispatch time. The address is what the host gave the dispatcher to reach the worker. A worker reports to the session that started it. |
| `Peers:` | The lines of `ytstack-frontier peer list` (`LANES.md`, "Peers"): role, repository, address, last contact. `none` when there are none. The successor writes to these addresses, never to one from a summary. |

The old session stays open as a relay until every listed worker has reported. Per report it runs `ytstack-brief check`, sets the row to `reported` and appends the report's labelled lines, with the UTC time, under `## Reports after the rotation` at the end of `HANDOFF.md`. It does nothing else. The successor leaves the rows of the listed workers alone until their reports are there, or until the person says the old session is closed.

## Checked mechanically

- `bin/ytstack-frontier check`: `LANES.md` has the ten columns, lane references are unique, `Status` and `Kind` hold listed values, a held lane has a claim time, every line under `## Peers` is a list line with four cells and a UTC time (a table row there is named as one); then the lanes that stall ("Lanes that stall", exit 2). `ytstack-frontier owner --pr <N>`: the lane that holds a pull request and its last commit or claim, exit 1 without a row ("Pull requests that stall").
- `bin/ytstack-upkeep --worktrees`: the linked worktrees (not the main one, not the one it runs in) and local branches with the state of their pull request (an open one first, else the newest), the age of the last commit, uncommitted changes, unpushed commits and the lane of the main checkout's `LANES.md` that holds them, and the `git worktree remove` / `git branch -D` commands for those whose pull request is merged or closed, with no open one, nothing unpushed, clean, unlocked and unheld. It prints the commands and runs none.
- `bin/ytstack-status --phases [--json]`: done, in review and total per milestone and in total, with each change since the last text report, its cause and the phases that joined or left (`docs/statusline.md`, "Progress per phase").
- `bin/ytstack-questions check`: ids are unique and match the file name, `state` holds a listed value, `asked` and `answered` are set exactly when the state says so, an answered file has text under `## Answer`.
- `bin/ytstack-brief check`: the report labels, the three `Status:` values and their consistency with `Blockers:`.
- `bin/ytstack-handover check`: the staged script of a human-only step (see `skills/handover-step/SKILL.md`).
- `bin/ytstack-check --standing [<project dir>]`: every entry in `standing/` has a name of the form above with a date and time that exist, `given` as an existing ISO UTC time in the minute of its name, a `scope` and a body, and every `supersedes` names an earlier entry that exists (missing seconds count as `00`). Without a directory argument it resolves `.ytstack` like the skill preambles, user scope included.

# Coordinator formats

One session that owns a plan and delegates all of it needs four things on disk, so that it can lose its context and continue from files: who works on what (lanes), what may start next (the frontier), what only the human can decide (questions) and what the human asked for once and for all (standing instructions). This document fixes their formats. The skills that use them are `coordinate`, `spawn-milestone-team`, `finish-lane`, `handover-step`, `lane-retro` and `reassess-roadmap`; the scripts are `bin/ytstack-frontier`, `bin/ytstack-questions`, `bin/ytstack-finish-lane`, `bin/ytstack-handover`, `bin/ytstack-watch`, `bin/ytstack-brief` and `bin/ytstack-standing`.

All files but one live in the project's `.ytstack/` directory and are user-owned like every artifact there. The exception is the lanes file: it lives out of tree, per repository (see "`LANES.md`").

**The host is the ledger of a lane (issue #79).** A lane's state is its pull request (open, draft, checks, review, merged), read fresh from the host. Nothing the host already knows is written to a file in the repository. What only the coordinator knows (who holds a lane, its next action, its review round, a lane without a pull request yet) stays with the session, out of tree, beside the automatic handoff and the coordinate marker. What lasts (`DECISIONS.md`, `standing/`, `questions/`, the spec, the roadmap tick of a change) goes to main by pull request, bundled on the lane's branch by `finish-lane`, never as a bookkeeping pull request of its own. `bin/ytstack-upkeep` names every UTC day with more than three merged pull requests that changed only `.ytstack/`.

## Two rules for everything a coordinator writes

1. **Written as history.** Every entry carries the UTC time it was written. A statement about code names its commit. An entry that was overtaken is marked superseded with the date and what replaced it; it is not rewritten and not deleted.
2. **Host facts are never stored as current.** The state of a pull request, of its checks, of a review thread or of a deployed build lives on the host and changes without the coordinator. `.ytstack/` records what the coordinator did (dispatched, reviewed commit X, asked the human) and identifiers (a branch, a pull request number). Before a status goes to the human, the host facts in it are read again, and the status says when: `read 2026-11-13T10:42Z`.

## Operating checklist

The order a coordinator keeps for every event, short enough to survive a compaction. `hooks/session-start` injects the block between the two markers below in a coordinate session (the session marker of "Coordinate mode and the hooks"), on start, resume and after a compaction, and the `coordinate` preamble prints it; both read it from this file, so it lives only here (`tests/hooks-readonly.test.sh` compares them).

<!-- operating-checklist:begin -->
Coordinator operating checklist (scripts in bin/ of the plugin):
1. Dispatch: ytstack-frontier claim <lane> --by <worker> -> ytstack-brief render -> Agent with that brief. Never a hand-written brief.
2. Report: ytstack-brief check -> ytstack-frontier set <lane> --status reported -> ytstack:finish-lane.
3. Human instruction beyond the task: ytstack-standing add, before the next dispatch; never only in memory.
4. Merge to production: ytstack-watch release --commit <sha>.
5. After a compaction: run the coordinate preamble again, then rotate (Step 12).
6. Decide yourself, into DECISIONS.md; ask only for ESCALATE or a plan line saying verdict/approval/sign-off.
7. Each round: ytstack-frontier check, act on each stale: line.
8. Merge via ytstack-finish-lane; never gh pr merge or close a lane PR (cap: parked; CI: gh run rerun).
<!-- operating-checklist:end -->

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
| Status | `claimed` (taken, not dispatched yet), `running`, `reported` (the worker's report is in and passed the check), `in-review`, `ready` (its gates held when last read), `parked` (held; its pull request waits open, for a person or for the cap on open pull requests, then as a draft: the cap counts pull requests ready for review, limits opening and dispatching, never a merge; `gh pr ready <N>` under the cap, `gh pr ready <N> --undo` takes one out of the count; never closed to make room), `merged`, `blocked`, `dropped`. What the coordinator did or saw last; not a host fact. |
| Claimed by | The worker's name and the UTC time of the claim. `-` when nobody holds it. |
| Branch, Worktree | Where the work is. `-` when it does not apply. |
| PR | The number, as an identifier. Its state is read from the host when needed. |
| Reviewed head | The commit the newest independent review looked at. A merge happens at this commit or not at all. |
| Round | The number of review rounds on this lane (`code-review` rules: round 1 complete, round 2 the fix, round 3 a diagnosis). |
| Next action | One line: what the coordinator does next for this lane, or what it waits for. For `blocked`: on what. |

A lane that was never claimed has no row. `bin/ytstack-frontier` is the only writer besides a human: it changes one row per call, takes a lock for the write (the file `LANES.md.lock` beside it, so that claims sent together do not lose a row) and rewrites `updated`. Cells contain no `|`. A held lane is released before it can be claimed again.

### Where the lanes file lives

Out of tree, one per repository: `${XDG_STATE_HOME:-~/.local/state}/ytstack/repos/<repo key>/LANES.md`, beside the session home of the coordinate marker (the same base for a hook and for the Bash tool; `yt_lanes_file` in `hooks/lib/git-ctx.sh` is the one resolver every reader uses). The repository key is the one of the automatic handoff, so every linked worktree of the repository reads the same file. A successor session on the same machine reads it there; one on another machine rebuilds it from the host, since every implement lane has a pull request or a branch there.

| Command | Does |
|---|---|
| `ytstack-frontier where` | Prints the lanes file and where it lives: `<path>` TAB `out-of-tree` or `repo`. |
| `ytstack-frontier migrate` | Copies a repo `.ytstack/LANES.md` out of tree and adds `snapshot: <UTC>` to the repo file's frontmatter. |
| `ytstack-frontier snapshot` | Writes the lanes file to `.ytstack/LANES.md` of the checkout with a `snapshot: <UTC>` line, and commits nothing. |

**Migration.** A project from before #79 keeps its `.ytstack/LANES.md` as the lanes file while no out-of-tree file exists: every reader and writer uses it as before, and the `coordinate` preamble says `LANES_MIGRATE`. `migrate` ends that once; the marked repo copy rides with the next lane's pull request or is removed there. A `LANES.md` with a `snapshot:` key is never the lanes file. `migrate` also copies such a snapshot when no out-of-tree file exists (a new machine), without the key; its held rows are then read against their pull requests before anyone acts on them.

**Snapshots.** `LANES.md` in the repository is optional: written only when a person asks for one, or at a milestone boundary inside that milestone's last lane pull request (`finish-lane`, Step 3).

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

The first is a line of `ytstack-watch --stall <minutes>` (states it counts: checks red, a conflict, a reviewer whose newest review on the head requests changes), the second the line of the PR watch's status block (state `action_required`, policy key `stall_minutes`; `docs/pr-watch.md`). `STALL 2` comes one full window after `STALL 1`, never first; a new head starts at `STALL 1` again. The tail after the time is `ytstack-frontier owner --pr <N>`: the lane whose `PR` cell names the pull request (`12` or `#12`; a held row before a dropped or merged one), its holder and status, and the age of the last commit on its branch, or of the claim when that is newer, the clock `check` uses. Without such a row the line ends after the time. What the coordinator does with `STALL 1` and `STALL 2` is in `skills/coordinate/SKILL.md`, Step 7.

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
Spec: <area>: <file you edited> (<section>); ... | none -- <reason>
Deviations: <or "none">
Blockers: <or "none">
Not checked: <what was not run or not looked at, and why; "nothing" only when that is true>
Next: <the next action for whoever dispatched this, in one line>
```

`partial` and `blocked` are values of `Status:`, never a word in a paragraph. `Status: blocked` needs a `Blockers:` value other than `none`; `Status: complete` needs `Blockers: none`.

`Spec:` is the **spec delta**: what the change did to the technical spec (`docs/ux/spec-format.md`). Either one entry per edited section, `<area>: <file> (<section>)` with the area file or the source it names, several joined by `;`, or `none -- <reason>` with a reason from the plan rule (restores the described behaviour, no behaviour or contract changes, not covered by an area). It is the worker's side of the plan's `## Spec impact`: the plan says what will change, the report what did. A bare `none` and prose without a path are no delta. `finish-lane` checks the delta against the diff before a merge without a person (`bin/ytstack-finish-lane route --report`).

## `questions/` -- what only the human can decide

One file per pending question: `.ytstack/questions/Q###-<slug>.md`.

```markdown
---
id: Q007
state: open
class: escalation
decides: the operator
because: deviation
opened: 2026-11-13T09:15:00Z
asked: none
answered: none
blocks: M004-S03, G02
---

# Q007 -- Does the export include rows that were archived before the cut-over?

## Context

Source: <where the need comes from: the plan line, file, commit, standing entry or review thread>
Purpose: <what the answer is for: what it unblocks or changes>

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

| `class` | Means | Written by |
|---|---|---|
| `escalation` | `decides` takes the decision; `because` names the item of the list below that sends it to that person. | `new --decides <who> --because <item>` |
| `info` | `decides` supplies a fact (a token and where it lives, an access, a date) or takes note of a report; the decision stays with the coordinator. `because: none`. | `new --info <who>` |

A file without `class` and `because` was written before these keys and reads as `escalation`; `check` accepts it.

### Who decides

What the plan or a standing entry does not reserve for a person, the coordinator decides, and records in `DECISIONS.md` when it lasts. A question goes to a person only for one item of a closed list:

| `because` | What |
|---|---|
| `violation` | The work would break a rule of the project or a concept it stands on (`DECISIONS.md`, an invariant of the spec, `AGENTS.md`). |
| `deviation` | The work would leave the plan: other scope, another approach, a dropped or added slice. |
| `irreversible` | An irreversible step, or one on production, that no plan line covers. |
| `secret` | A secret: a token, a key, a credential. |
| `spend` | Money: a paid service, more capacity, a purchase. |
| `reserved` | A plan line or a standing entry reserves the verdict. A plan line reserves only when it says verdict, approval or sign-off; a line that names a person as the author of an analysis or a step reserves nothing. |

`escalate:` in `PREFERENCES.md` (under `## Ceremony`) narrows the first five for a project: `escalate: violation, deviation, irreversible, secret, spend` is the default, and a value with an item outside them reads as the default. `reserved` always holds. `new --decides` refuses an item that is not on the list and says to decide it instead.

`ask` refuses a question whose `## Context` has no `Source:` line or no `Purpose:` line with a value (a `<placeholder>` is no value): the person answers from the file alone. This holds for both classes and for files written before the two lines.

Rules:

- Before a question file is written, the plan, `DECISIONS.md` and the answered questions are searched. What they answer is not asked.
- One question at a time, as late as the work allows, with everything prepared: the human should be able to answer from the file alone.
- A gate of a slice or task plan (`## Gates`) that needs a person's verdict gets a question file; `blocks` names the gate. `reassess-roadmap` still brings all open ones in one message at a slice boundary.
- No agent fills `## Answer` with anything the human did not say.

`bin/ytstack-questions list` prints the open and asked ones; `check` validates the files, `class` and `because` included.

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
| `until` | Optional. An ISO UTC time after `given`; from then on the entry has ended. |
| `until-condition` | Optional. One sentence naming the event that ends the entry ("PR #1879 merged"). The coordinator checks it when the list names it. |
| `until-check` | Optional. A command that exits 0 once the entry has ended (`gh pr view 1879 --json state -q .state \| grep -qx MERGED`). It may stand alone (the command is the condition) or beside `until-condition` (the sentence says for people what it checks). |
| `check` | Optional. A command that exits non-zero while the instruction is not kept; its first output line is the warning (`test -n "$(find .ytstack/LANES.md -mmin -120)" \|\| echo "LANES.md older than 2 h"; ...`). |
| `kind` | Optional. Only `end`: the entry closes the one its `supersedes` names and is no instruction itself. |

Rules:

- Own words, never a quotation. The body is the instruction.
- An entry is not edited after it is written and nothing is deleted. An instruction that replaces another is a new file whose `supersedes` names the old one; from then on the old one no longer holds.
- An entry ends by its `until`, by an `until-check` that exits 0, or when the coordinator finds its `until-condition` met. It is then closed with a short entry of `kind: end` that supersedes it, whose body says what ended it ("Ended: PR #1879 merged at 2026-11-15T10:02Z."); `ytstack-standing end <entry> --reason "..."` writes it. That keeps the record append-only.
- Readers take the entries newest first and skip every entry that another entry supersedes, every entry of `kind: end` and every entry whose `until` has passed. `yt_standing` in `hooks/lib/git-ctx.sh` prints them; the preambles of `finish-lane` and `signal-intake` list them between `STANDING_ENTRIES_BEGIN` and `STANDING_ENTRIES_END`, the preamble of `coordinate` lists there what `ytstack-standing list` prints. The coordinator reads every listed file at every start and after every compaction, before it acts.
- A `README.md` in the directory is a note for people and is not an entry.

### Writing and listing: `bin/ytstack-standing`

- `add "<text>" --scope "<scope>" [--supersedes <entry>] [--until <ISO UTC>] [--until-condition "<sentence>"] [--until-check "<command>"] [--check "<command>"]` writes the entry, named from UTC now and the first words of the text. By default it writes in a worktree of its own outside the checkout (`<state base>/repos/<repo key>/standing-worktree`), on the branch `standing/<YYYYMMDD>`, commits, pushes and opens one pull request per UTC day, or adds to the open one (through `ytstack-pr-watch create` when the PR watch is on, else `gh pr create`). `--here` writes into the resolved `standing/` and commits nothing; user scope always does that. The entry has to pass `ytstack-check --standing`, else nothing is written. A new day's branch starts from the newest pending standing branch (see below), so that an entry can supersede or end one that still waits in that pull request; an earlier day's branch with commits origin does not have is pushed first. `--supersedes`, `--until`, `--slug` and `--base` take one line.
- `end <entry> --reason "<text>"` writes the closing entry (`kind: end`, the scope of the closed one), also for an entry that is still pending.
- `list` prints, in this order: the newest entry with its age and the number of human prompts this session sent since (from `hooks/standing-prompt`), the active entries as `- <name> (<scope>): <first sentence>` (pending ones marked `(pending: <branch>)`), the ended ones (to close), the conditions to check now, and the failed checks. `--no-checks` runs no command.

**Pending** entries are the ones on a local branch `standing/*` (the branches `ytstack-standing add` creates on this machine) or on the upstream such a branch tracks, that are neither in the working tree nor on the default branch. A remote branch that no local branch tracks is never read: anyone who can push a branch could put an entry there. `list`, the SessionStart injection and the lane briefs show pending entries (text only, with the role filter); `yt_standing`, which `finish-lane` and `signal-intake` print, reads the working tree only.

### Where the commands of an entry run

`until-check` and `check` come from a file in the repository. They run only in `ytstack-standing list` (and so in the `coordinate` preamble), and only for an entry of the working tree whose file is the same as on the default branch (`origin/HEAD`, else `origin/main`, `origin/master`, `main`, `master`; `add` asks the remote first when `origin/HEAD` is missing): merged, so a person reviewed it (a change under `standing/` goes to a person, `bin/ytstack-risk floor`). A pending entry and an unmerged file in the checkout never run; the list says `[check not run: pending]` or `[check not run: not on <branch>]`. Outside a repository (user scope) and in a repository without a commit the files are the user's own and run; a repository with commits whose default branch cannot be found runs none (`[check not run: default branch unknown ...]`). A pending entry's whole text is in `list`, since its file is not on disk. Each runs with `bash -c` in the checkout's toplevel, in a process group of its own, stdin closed, at most `YTSTACK_STANDING_TIMEOUT` seconds (default 5; then the whole group is killed, a timeout counts as "not ended" and as a failed check), and at most ten commands per call; past that each entry says `[check not run: limit of 10 commands per list]`. No hook runs them: `hooks/session-start`, `hooks/standing-prompt` and `hooks/stop` read files only, and an `until` that passed is the only end they apply.

### Scope and roles

The scope is free text. Three roles are read from it, as whole words, case-insensitive:

| Role | Words in the scope |
|---|---|
| coordinator | `coordinator`, `coordinators` |
| lane | `lane`, `lanes`, `worker`, `workers`, `implementer`, `implementers` |
| reviewer | `reviewer`, `reviewers`, `review`, `reviews` |

A scope that names no role applies to everyone. The coordinator gets every entry. `hooks/session-start` injects the active entries for the session's role (coordinator when the `coordinate` preamble left its session marker, else lane), pending ones included, at most six lines; near the injection cap first the three newest (before the Next action is cut), last one pointer line. `ytstack-brief render` puts the entries for its kind (`review`: reviewer, else lane) under "Standing instructions".

### Coordinate mode and the hooks

The `coordinate` preamble writes the session marker `<session home>/<session id>/coordinate` (`yt_session_home`: `${XDG_STATE_HOME:-~/.local/state}/ytstack/sessions`; the id is `CLAUDE_CODE_SESSION_ID`), with the resolved `.ytstack` on its first line and the repository key on its second (in user scope the `.ytstack` lies outside the repository). Only then do these hooks act, so a session that never ran `coordinate` is not touched.

- `hooks/standing-prompt` (UserPromptSubmit) counts every human prompt and flags one that reads like a standing instruction. It looks for instruction phrases, not single words: from now on, going forward, until further notice, don't touch, hands off, prioritise, remember to, an imperative "always/never <verb>" at the start of a clause, a temporary hold or prohibition with until, till or while and a time or condition ("hold merges until 12:37", "no deploys while the load test runs", "until the load test ends"); German ab jetzt, ab sofort, von nun an, bis auf weiteres, solange ... nicht, grundsaetzlich, immer wenn, nie wieder, nie mehr, niemals, denk dran, merk dir, priorisiere, fass ... nicht an, kuenftig, and the temporary forms "bis 12:37 keine ...", "keine ... bis/solange/waehrend ...", "solange ..." at the start of a clause. A prompt that is one question and nothing else is never flagged ("bis wann ist das fertig?", "ist das immer noch rot?"). A flagged prompt gets one line of context: record it before the next dispatch.
- `hooks/stop` blocks the stop once when flagged prompts have no entry since: an entry counts when its name time is in or after the minute of the first flagged prompt, in the working tree or added on any ref of the repository after it (local branches, and the remote-tracking branch a pushed standing pull request left). Local git only. The same prompts never block twice.
- `hooks/session-start` injects the "Operating checklist" above, in place of the minimal-code line (a coordinator writes no product code).
- `hooks/pre-tool-use-agent` (PreToolUse on `Agent`, `Task`, `SendMessage`) adds one line of context when the prompt has no line starting with `# Brief: ` (the first line `ytstack-brief render` prints): the path is claim, render, dispatch. It never denies the call; a lookup that is no lane needs no brief. A `SendMessage` of up to 400 characters is a follow-up and is not checked. An `Agent` call of a lookup type (`Explore`, `Plan`, `claude-code-guide`, `statusline-setup`, a type naming search or explore) without a brief is neither warned about nor counted; every other `Agent` call is appended to `dispatches`; a task notification the prompt hook sees is appended to `reports`.
- `hooks/stop` warns, once per session as a `systemMessage`, when the lanes file (`yt_lanes_file`) changed more than five minutes before the newest dispatch or report of the session (or does not exist although lanes were dispatched), and when the `STATE.md` pointer is behind the newest milestone on disk. A warning that comes in three sessions in a row (`YT_LINT_STREAK_N`; counter `<state base>/repos/<repo key>/coordinate-lints`) blocks the stop once in the third session. A session counts once when the finding was there at any of its stops (a session that begins with a status question and dispatches later counts); a session that ended without it breaks the row; overlapping sessions count once each.

- `hooks/pre-tool-use-agent` also adds a line when an `Agent` call that is no lookup has no `isolation` (dispatch lane work with `isolation: "worktree"`), and, on `Bash`, when the command runs `gh pr merge` (the merge is `ytstack-finish-lane merge --at <reviewed head>`) or `gh pr close` (a cap waits with the lane `parked`, a check reruns with `gh run rerun`). Advisory, never a deny: the person may have asked for that close.
- `hooks/pre-compact` counts the session's compactions in `compactions` beside the marker. After one, `hooks/session-start` says `Compaction N of this coordinator: ytstack:coordinate Step 12, rotate now`; from the second on, `hooks/stop` says it too, once per compaction.
- `hooks/post-tool-use-bash` adds one note when the output of `gh run list --branch <default branch>` shows that the newest run of a workflow failed (the tab-separated form or a JSON array with `conclusion` and `workflowName`; with `--repo`/`-R` only for the repository of `origin`): a red main, run `ytstack:lesson`. One note per distinct set of failed runs.
- `hooks/stop` gives a coordinate session no reminder about the `STATE.md` task pointer: a coordinator holds no task.

Claude Code only: Codex registers no UserPromptSubmit or Agent hook of ytstack (its subagent tools are not covered), its PreToolUse and PostToolUse entries on `Bash` run only the PR watch, and Kimi's shell has no session id to write the marker with. On both the skill text (HARD-GATE, Steps 5, 6 and 12) carries these rules without the hooks.

### Goal mode

A long-running coordinator keeps working until its goal's exit criteria hold (issue #99, after Codex's `/goal`). `bin/ytstack-goal` writes the goal as a session marker beside the coordinate marker, `<session home>/<session id>/goal`, and the Stop hook holds the stop while it is open.

| Command | Does |
|---|---|
| `ytstack-goal set <M###> [--until <UTC>] [--rounds N] [--if-unset]` | The milestone is the goal: it holds once the roadmap is `done`, `shipped-informally` or `dropped`, or every slice is ticked or has a `merged` row. The `coordinate` preamble runs it for the current milestone with `--if-unset` (`GOAL:`). |
| `ytstack-goal set "<sentence>" --check "<command>" --file <path> ...` | A sentence goal needs at least one checkable criterion: a command that exits 0, or a file that exists. A milestone goal may add them too. |
| `ytstack-goal status` | Runs every `--check` in the checkout (stdin closed) and records the result, then prints the goal, what is open, the blocker and the rounds used. Exit 0 reached, 1 open, 3 no goal. |
| `ytstack-goal block "<why>"`, `block --clear` | Records a blocker: the stop goes through while it is set. |
| `ytstack-goal clear` | Removes the goal; checklist item 14 of `coordinate` when the milestone closes. |

The Stop hook (`ytstack-goal hook`, files only, no command of the goal) blocks with the open slices, up to three exit criteria of `M###-CONTEXT.md`, the missing files and the checks that failed or never ran. It lets the stop through when a question is `asked`, a blocker is recorded, a lane is `running` or the PR watch watches a pull request for this session while its worker ticks, or the bound is reached (`--until` passed, `--rounds` blocks used); the bound and a reached goal are said once. It never blocks twice in a row without a tool call in between: inside a hook-continued turn (`stop_hook_active`) it blocks again only when the transcript shows a tool call after its last block, and never without a transcript. A standing or lint block of the same stop comes first. Claude Code only: Codex registers no ytstack Stop hook of its own, so the skill says to use its native `/goal`; a Kimi shell has no session id.

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

- `bin/ytstack-frontier where`, `migrate`, `snapshot`: the lanes file out of tree, a repo `LANES.md` from before until `migrate`, a snapshot never read as the lanes file ("Where the lanes file lives").
- `bin/ytstack-goal`: a sentence goal without `--check` or `--file` is refused; `status` runs the checks, `hook` reads their last result ("Goal mode").
- `bin/ytstack-upkeep`, section `bookkeeping`: UTC days of the last seven with more than three merged pull requests that changed only `.ytstack/`, from the first-parent history of `origin`'s default branch (local refs; one pull request per commit whose subject names its number).
- `bin/ytstack-frontier check`: the lanes file has the ten columns, lane references are unique, `Status` and `Kind` hold listed values, a held lane has a claim time, every line under `## Peers` is a list line with four cells and a UTC time (a table row there is named as one); then the lanes that stall ("Lanes that stall", exit 2). `ytstack-frontier owner --pr <N>[,<N>...]`: the lane that holds a pull request and its last commit or claim, one line per PR (with several, each led by the number and a tab), exit 1 without a row ("Pull requests that stall"). A fresh worker's `claim` of a released lane keeps branch and worktree unless given: `--worktree <new>` sets its own, `--worktree -` clears it.
- `bin/ytstack-upkeep --worktrees`: the linked worktrees (not the main one, not the one it runs in) and local branches with the state of their pull request (an open one first, else the newest), the age of the last commit, uncommitted changes, unpushed commits and the lane of the lanes file that holds them, and the `git worktree remove` / `git branch -D` commands for those whose pull request is merged or closed, with no open one, nothing unpushed, clean, unlocked and unheld. It prints the commands and runs none.
- `bin/ytstack-status --phases [--json]`: done, in review and total per milestone and in total, with each change since the last text report, its cause and the phases that joined or left (`docs/statusline.md`, "Progress per phase").
- `bin/ytstack-questions check`: ids are unique and match the file name, `state` holds a listed value, `asked` and `answered` are set exactly when the state says so, an answered file has text under `## Answer`, `class` is `escalation` or `info` (or missing), an escalation names its `because`, and `because` is an item of the list in "Who decides". `new --decides` refuses an item that is not on the project's list, and `ask` a Context without `Source:` and `Purpose:` (issue #78).
- `bin/ytstack-brief check`: the report labels, the three `Status:` values and their consistency with `Blockers:`, and the form of the spec delta under `Spec:`.
- `bin/ytstack-handover check`: the staged script of a human-only step (see `skills/handover-step/SKILL.md`).
- `bin/ytstack-check --standing [<project dir>]`: every entry in `standing/` has a name of the form above with a date and time that exist, `given` as an existing ISO UTC time in the minute of its name, a `scope` and a body, and every `supersedes` names an earlier entry that exists (missing seconds count as `00`); `until` is an existing ISO UTC time after `given`, `until-condition`, `until-check` and `check` are one non-empty line when present, `kind` is `end` or absent, and an `end` names the entry it closes. Without a directory argument it resolves `.ytstack` like the skill preambles, user scope included.

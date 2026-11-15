# Coordinator formats

One session that owns a plan and delegates all of it needs four things on disk, so that it can lose its context and continue from files: who works on what (lanes), what may start next (the frontier), what only the human can decide (questions) and what the human asked for once and for all (standing instructions). This document fixes their formats. The skills that use them are `coordinate`, `spawn-milestone-team`, `finish-lane`, `handover-step`, `lane-retro` and `reassess-roadmap`; the scripts are `bin/ytstack-frontier`, `bin/ytstack-questions`, `bin/ytstack-finish-lane`, `bin/ytstack-handover`, `bin/ytstack-watch`, `bin/ytstack-brief` and `bin/ytstack-standing`.

All files live in the project's `.ytstack/` directory and are user-owned like every artifact there.

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
5. After a compaction: run the coordinate preamble again first.
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
| Status | `claimed` (taken, not dispatched yet), `running`, `reported` (the worker's report is in and passed the check), `in-review`, `ready` (its gates held when last read), `merged`, `blocked`, `dropped`. What the coordinator did or saw last; not a host fact. |
| Claimed by | The worker's name and the UTC time of the claim. `-` when nobody holds it. |
| Branch, Worktree | Where the work is. `-` when it does not apply. |
| PR | The number, as an identifier. Its state is read from the host when needed. |
| Reviewed head | The commit the newest independent review looked at. A merge happens at this commit or not at all. |
| Round | The number of review rounds on this lane (`code-review` rules: round 1 complete, round 2 the fix, round 3 a diagnosis). |
| Next action | One line: what the coordinator does next for this lane, or what it waits for. For `blocked`: on what. |

A lane that was never claimed has no row. `bin/ytstack-frontier` is the only writer besides a human: it changes one row per call, takes a lock for the write (the file `LANES.md.lock`, so that claims sent together do not lose a row) and rewrites `updated`. Cells contain no `|`. A held lane is released before it can be claimed again.

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

`until-check` and `check` come from a file in the repository. They run only in `ytstack-standing list` (and so in the `coordinate` preamble), and only for an entry of the working tree whose file is the same as on the default branch (`origin/HEAD`, else `origin/main`, `main`, `master`): merged, so a person reviewed it (a change under `standing/` goes to a person, `bin/ytstack-risk floor`). A pending entry and an unmerged file in the checkout never run; the list says `[check not run: pending]` or `[check not run: not on <branch>]`. Outside a repository (user scope) and in a repository without a commit the files are the user's own and run. Each runs with `bash -c` in the checkout's toplevel, in a process group of its own, stdin closed, at most `YTSTACK_STANDING_TIMEOUT` seconds (default 5; then the whole group is killed, a timeout counts as "not ended" and as a failed check), and at most ten commands per call; past that each entry says `[check not run: limit of 10 commands per list]`. No hook runs them: `hooks/session-start`, `hooks/standing-prompt` and `hooks/stop` read files only, and an `until` that passed is the only end they apply.

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

- `hooks/standing-prompt` (UserPromptSubmit) counts every human prompt and flags one that reads like a standing instruction. It looks for instruction phrases, not single words: from now on, going forward, until further notice, don't touch, hands off, prioritise, remember to, an imperative "always/never <verb>" at the start of a clause; German ab jetzt, ab sofort, von nun an, bis auf weiteres, solange ... nicht, grundsaetzlich, immer wenn, nie wieder, nie mehr, niemals, denk dran, merk dir, priorisiere, fass ... nicht an, kuenftig. A prompt that is one question and nothing else is never flagged ("bis wann ist das fertig?", "ist das immer noch rot?"). A flagged prompt gets one line of context: record it before the next dispatch.
- `hooks/stop` blocks the stop once when flagged prompts have no entry since: an entry counts when its name time is in or after the minute of the first flagged prompt, in the working tree or added on any ref of the repository after it (local branches, and the remote-tracking branch a pushed standing pull request left). Local git only. The same prompts never block twice.
- `hooks/session-start` injects the "Operating checklist" above, in place of the minimal-code line (a coordinator writes no product code).
- `hooks/pre-tool-use-agent` (PreToolUse on `Agent`, `Task`, `SendMessage`) adds one line of context when the prompt has no line starting with `# Brief: ` (the first line `ytstack-brief render` prints): the path is claim, render, dispatch. It never denies the call; a lookup that is no lane needs no brief. A `SendMessage` of up to 400 characters is a follow-up and is not checked. An `Agent` call of a lookup type (`Explore`, `Plan`, `claude-code-guide`, `statusline-setup`, a type naming search or explore) without a brief is neither warned about nor counted; every other `Agent` call is appended to `dispatches`; a task notification the prompt hook sees is appended to `reports`.
- `hooks/stop` warns, once per session as a `systemMessage`, when `LANES.md` changed more than five minutes before the newest dispatch or report of the session (or does not exist although lanes were dispatched), and when the `STATE.md` pointer is behind the newest milestone on disk. A warning that comes in three sessions in a row (`YT_LINT_STREAK_N`; counter `<state base>/repos/<repo key>/coordinate-lints`) blocks the stop once in the third session. A session counts once when the finding was there at any of its stops (a session that begins with a status question and dispatches later counts); a session that ended without it breaks the row.

Claude Code only: Codex registers no UserPromptSubmit or Agent hook of ytstack (its subagent tools are not covered), and Kimi's shell has no session id to write the marker with.

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
```

| Line | Holds |
|---|---|
| `PR watch session:` | The old session's id as the PR watch stores it (`claude:<id>`, or the Codex thread id), or `none` when the PR watch is off. The successor runs `ytstack-pr-watch handover --from <id>` (`docs/pr-watch.md`). |
| `Background watches:` | The command of every `ytstack-watch` the old session runs, so that the successor starts them again. `none` when there are none. |
| `Running workers:` | One line per dispatched worker that has not reported: lane, name, address, worktree, branch, dispatch time. The address is what the host gave the dispatcher to reach the worker. A worker reports to the session that started it. |

The old session stays open as a relay until every listed worker has reported. Per report it runs `ytstack-brief check`, sets the row to `reported` and appends the report's labelled lines, with the UTC time, under `## Reports after the rotation` at the end of `HANDOFF.md`. It does nothing else. The successor leaves the rows of the listed workers alone until their reports are there, or until the person says the old session is closed.

## Checked mechanically

- `bin/ytstack-frontier check`: `LANES.md` has the ten columns, lane references are unique, `Status` and `Kind` hold listed values, a held lane has a claim time.
- `bin/ytstack-questions check`: ids are unique and match the file name, `state` holds a listed value, `asked` and `answered` are set exactly when the state says so, an answered file has text under `## Answer`.
- `bin/ytstack-brief check`: the report labels, the three `Status:` values and their consistency with `Blockers:`.
- `bin/ytstack-handover check`: the staged script of a human-only step (see `skills/handover-step/SKILL.md`).
- `bin/ytstack-check --standing [<project dir>]`: every entry in `standing/` has a name of the form above with a date and time that exist, `given` as an existing ISO UTC time in the minute of its name, a `scope` and a body, and every `supersedes` names an earlier entry that exists (missing seconds count as `00`); `until` is an existing ISO UTC time after `given`, `until-condition`, `until-check` and `check` are one non-empty line when present, `kind` is `end` or absent, and an `end` names the entry it closes. Without a directory argument it resolves `.ytstack` like the skill preambles, user scope included.

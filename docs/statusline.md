# Status line segment

`bin/ytstack-status` prints one compact segment for the ytstack project that owns the current directory. Your own status line script appends it. A Claude Code plugin cannot set the main `statusLine` itself, so ytstack ships the segment and you wire it in once.

```
V2 76% 138/180 · M021/S01/T02 · waiting: review of PR 12
```

## What it shows

| Project state | Segment |
|---|---|
| `progress` block in `STATE.md` | label, percentage, done/total, task pointer, `waiting_on` if set |
| no block, active slice | task pointer and the slice's task count, for example `M021/S01/T02 3/7` |
| no block, no slice | the milestone, for example `M021` |
| no `.ytstack/`, nothing to show, or a malformed block | nothing, exit code 1 |

The percentage rounds down, so 100% appears only when `done` equals `total`. `waiting_on` is cut after 32 characters.

The task count without a block comes from the checkboxes (`- [x] T01 -- …`) in the active slice plan `M###-S##-PLAN.md`. Every ytstack project gets this form with no upkeep.

## The `progress` block

Optional, in the `STATE.md` frontmatter next to the pointers:

```yaml
---
project: example
current_milestone: M021
active_slice: S01
active_task: T02
progress:
  label: V2                       # required, at most 16 characters
  done: 138                       # integer
  total: 180                      # integer, at least 1, done <= total
  waiting_on: "review of PR 12"   # optional: the one thing that waits for a human
---
```

Use it when the project has a plan that is larger than the active slice: a release, a migration ledger, a rewrite. There is exactly one block. Comment lines and unknown keys inside it are ignored, so a line such as `# counts: ledger rows in docs/plan.md` can say what the numbers count. Tasks are the default unit.

Keeping it current:

- `summarize-task` adds 1 to `done` when it closes a counted task, and `quick-task` does the same for a counted change. Both re-run the STATE lint.
- The STATE lint (`yt_state_lint`, shown at session start) reports a malformed block: missing or long label, non-integer values, `total` below 1, `done` above `total`.
- A malformed block never produces a number. The segment stays empty until the block is fixed.

## Two levels: plan and task

Plan progress belongs to the repository, the task pointer to the checkout.

- **Plan progress** is read from the default branch whenever the checkout is on another branch. A linked worktree or a feature branch carries a stale copy of `STATE.md`, so the script reads the file with `git show` from `origin/<default>`, or from the local `<default>` when it contains `origin/<default>` (unpushed commits). The two are compared by ancestry, not by commit date. The default branch is taken from `origin/HEAD`, else `main`, else `master`. On the default branch itself, and outside Git, the working tree file is used.
- **The task pointer** (`M###/S##/T##`) always comes from the `STATE.md` of the directory you are in.
- **The slice task count** of a project without a block follows the same rule as the block: off the default branch the slice plan named by the pointer is read from the default branch. Only when that slice plan does not exist there yet (a slice planned on the branch) is the copy in your directory counted. A slice that runs in a worktree therefore shows the merged count until its work lands.

Only local refs are read. The script makes no network calls and does not use `gh`; one run takes well under a tenth of a second.

## Progress per phase

`ytstack-status --phases [--json] [-C DIR]` is for a status report or a chart, not for the status line. It reads the files of the checkout (no stdin, no default-branch lookup) and prints one line per milestone roadmap that is not `dropped` or `backlog`, one line per phase that left the report, the total and the time of the read:

```
M004	2/5 done (40%)	1 in review	total 4 -> 5 since the last report: added S05, S06; removed S04
M006	0/1 done (0%)	0 in review	new since the last report
M003	left the report since the last report (was 2 rows)
total	2/6 done (33%)	1 in review	total 6 -> 6 since the last report; joined M006; left M003
read 2026-11-15T10:42Z, log ~/.local/state/ytstack/repos/<key>/phases/denominator.log
```

A row is a slice of the roadmap. It is done when its checkbox is ticked or its row in the lanes file (out of tree, `ytstack-frontier where`) is `merged`; every slice of a `done` or `shipped-informally` milestone counts as done. A row is in review when its lane is `reported`, `in-review` or `ready`. Each text report compares the slices per phase with the text report before and names what changed the total, and which phases joined or left, also when the total stays the same. A grown total is then read as new work, not as lost progress. Only the text report moves that baseline, under a lock; `--json` shows the same change and writes nothing, so drawing a chart does not use it up. Every change is appended to `denominator.log` (UTC time, phase, total before, total after, cause: `first report`, `new phase`, `added S05`, `removed S04`, `phase left the report`) under the state base of `hooks/lib/git-ctx.sh` (`CLAUDE_PLUGIN_DATA`, `PLUGIN_DATA`, `$XDG_STATE_HOME/ytstack` or `~/.local/state/ytstack`), keyed by the repository, never in the tree. `--json` prints the same as one object (`read`, `log`, `phases[]` with `phase`, `status`, `done`, `in_review`, `total`, `percent`, `change` with `before`, `added`, `removed`, `joined` or `null`, `left[]` with `phase` and `before`, and `total` whose `change` carries `before`, `joined[]` and `left[]`), from which a chart is drawn. Exit 1 without `.ytstack/` or without a roadmap.

## Integration in Claude Code

Your status line script receives a JSON object on stdin. Pass it on and append the output. In a bash script:

```bash
input=$(cat)
yt=$(ls -d ~/.claude/plugins/cache/*/ytstack/*/bin/ytstack-status 2>/dev/null | sort -V | tail -1) || true
seg=$([ -n "$yt" ] && printf '%s' "$input" | "$yt") || true
```

Then print `$seg` where you want it, for example `printf '%s%s' "$line" "${seg:+ | $seg}"`.

The script exits 1 when it has nothing to print, and the glob fails while the plugin is not installed. The `|| true` on both lines keeps a status line script that runs under `set -e` or `set -o pipefail` alive in those cases; `$seg` is then empty.

The second line is the stable way to find the script. Plugin files live under a versioned directory that changes with every update, and Claude Code does not put a plugin's `bin/` on the `PATH` of the status line command. The glob picks the highest installed version, so the segment follows `/plugin update` without an edit. If you work from a local checkout, set `yt` to `<checkout>/bin/ytstack-status` instead.

The script reads only `cwd` from the JSON. If your script already knows the directory, `(cd "$dir" && "$yt" </dev/null)` works as well.

## Other hosts and colour

Any harness that calls a status command can use the script: pipe a JSON object with a `cwd` field, or run it with the project as working directory. Missing fields, an empty stdin and non-JSON input all fall back to the working directory.

The segment uses two ANSI colours. Set `NO_COLOR` to any value, or pass `--no-color`, for plain text.

## Limits

- One `progress` track per project. Several named tracks are not supported.
- User-scope projects (`~/.ytstack/projects/<key>`) have no branch copy, so their plan progress always comes from the file on disk.
- Calling the script through a symlink does not work; it finds its library relative to its own path.

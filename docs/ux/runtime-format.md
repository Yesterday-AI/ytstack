# Runtime format

`RUNTIME.md` in the project's `.ytstack/` directory says how the product is started, where its release can be read and where its signals come from. It is user-owned free text, as before. Three sections in it have a fixed line format, so that an agent can start the product in its own worktree, watch a release and read signals without guessing. Each section is optional; a skill that needs a missing one says so and stops, it does not improvise a command.

The script is `bin/ytstack-runtime`. The skills that use the sections are `verification-before-completion`, `visual-review`, `finish-lane` (release watch), `signal-intake` and `incident`, and the agents `implementer` and `verifier`.

## Two rules

1. **Names, never values.** A command may read a credential from the environment of whoever runs it. No token, password or connection string is written into `RUNTIME.md`. `bin/ytstack-runtime check` fails on a string that looks like one.
2. **Commands under "Release" and "Signals" only read.** They are run by unattended agents. A command that changes the target (a deploy, a restart, a flag flip, a write query) does not belong there; it is a step for a person (`handover-step`). The script cannot prove that a command only reads; whoever writes the line vouches for it, and the credentials it uses should be read-only ones.

## What is read in a section

A section runs from its heading (`## Run`, `## Release`, `## Signals`) to the next `#` or `##` heading. In it the list lines (`- ...`) are read. Every other line is free text: a note, the source a value came from. A code fence (` ``` ` or `~~~`) is free text as a whole, inside a section or outside one: a heading or a list line in it is part of an example, not configuration. A section without a list line counts as absent, so a scaffold can write the three headings with one line of explanation each.

## `## Run` -- the product in a worktree

```markdown
## Run

- start: pnpm dev --port {port}
- ports: 4100-4199
- ready: curl -fsS http://localhost:{port}/healthz
- url: http://localhost:{port}
- logs: {log}
- needs: DATABASE_URL, a local Postgres (docker compose up -d db)
- stop: (default)
```

One `- key: value` line per key. `{port}` and `{log}` are replaced in `start`, `ready`, `url`, `logs` and `stop`. Every command runs in the root of the checkout.

| Key | Required | Holds |
|---|---|---|
| `start` | yes | The command that starts the product from the root of the checkout it is run in. `{port}` is replaced by the chosen port, which is also exported as `PORT`. It must not need a second terminal: one command that stays in the foreground. The script puts it in the background; a command that returns counts as a failed start. |
| `ports` | when a value uses `{port}` | A range `<first>-<last>` the script may pick from. Two worktrees get different ports, so that several agents can run the product at once. |
| `ready` | yes | A command that exits 0 once the product answers. The script repeats it until it passes or the timeout ends. An attempt that still runs when the timeout ends is stopped. |
| `url` | no | Where a browser enters. Printed by `up`. |
| `logs` | no | Where the output goes: `{log}` stands for the file the script redirects the start command into; a path or a command when the product logs elsewhere. Printed by `up` as `LOG:`. |
| `needs` | no | What has to exist before `start` works: environment variable names, a local service and the command that brings it up. Read by the agent, not by the script; a failed `up` repeats the line. |
| `stop` | no | A command that stops what `start` started. `(default)` or no line: the script ends the process group it started. With a command the script runs it and then ends the process group as well. |

`bin/ytstack-runtime`:

- `up [--timeout <seconds>]` picks a free port from `ports` (a start position derived from the worktree, then the next one nobody listens on), starts `start` in the background with its output in a log file outside the checkout, repeats `ready` until it passes, and prints five lines: `URL:`, `PORT:`, `PID:`, `LOG:` and `COMMIT:` (`-` for a `url` or a port that is not declared). The timeout is 60 seconds unless given. It exits 1 with the reason, the last output of `ready` and the last lines of the log when `start` exits or `ready` never passes, and leaves nothing running. It refuses a `RUNTIME.md` that does not pass `check`. A second `up` in the same worktree asks `ready` again and prints the running instance instead of starting another.
- `down` stops the instance of this worktree: the process group that `up` started, children included. It prints `not running` when there is none.
- `status` prints the five lines of the instance of this worktree, or `not running` with exit 1.

The pid, the port and the log of an instance live outside the checkout, in the state directory of the worktree (`yt_state_wt_dir` in `hooks/lib/git-ctx.sh`). An instance whose process is gone, or whose pid another process carries by now, counts as not running; `down` never ends a process it did not start.

What an instance proves is what was started: the script prints the commit of the checkout with `COMMIT:`, followed by `(with uncommitted changes)` when the working tree differs from it and `none` outside a repository. A result names that line (`minimal-code`, "evidence").

## `## Release` -- the target after a merge

```markdown
## Release

- target: production (https://app.example.com)
- deployed: curl -fsS https://app.example.com/version
- healthy: curl -fsS https://app.example.com/healthz
- settle: 180
```

| Key | Required | Holds |
|---|---|---|
| `target` | no | The name of what is watched, for the record. |
| `deployed` | yes | A command that prints the commit the target serves now, anywhere in its output (a short or full SHA). |
| `healthy` | no | A command that exits 0 while the target is healthy. |
| `settle` | no | How many seconds `healthy` keeps being asked after the commit arrived. Default 120. |

`bin/ytstack-watch release --commit <sha> [--timeout <seconds>] [--interval <seconds>] [-C <dir>]` reads these keys through `bin/ytstack-runtime get`. It deploys nothing and rolls nothing back: it runs the two commands, in the root of the checkout, and nothing else.

1. It runs `deployed` every interval (default 15 seconds) until the output names the commit, for at most the timeout (default 900 seconds). The output names the commit when a run of hex digits in it starts with `<sha>`, or when `<sha>` starts with that run and the run has seven characters or more. So the target may print a short SHA while the caller passes the full one, and the other way round. `--commit` takes seven hex digits or more.
2. It runs `healthy`, when there is one, every interval for the settle time, and counts the calls and the ones that failed. One failed call makes the result `unhealthy`; the watch still asks until the settle time is over, so the receipt tells one blip from a target that stays down.

A call that still runs after 30 seconds is stopped and counts as failed. While the watch waits it prints a line only when something changed (`<UTC> deployed: <first line of the output>`, `<UTC> arrived: ...`, `<UTC> healthy: ok` or `failed (exit <n>)`). At the end it prints one receipt, five lines with fixed labels, each host fact with the UTC time it was read:

```
Target: production (https://app.example.com)
Commit: a1b2c3d4e5f60718293a4b5c6d7e8f9012345678
Arrived: yes, the target printed a1b2c3d, read 2026-11-13T19:02:11Z
Health: asked 9, failed 0, last read 2026-11-13T19:04:12Z
Result: released
```

| Result | Exit code | The receipt says |
|---|---|---|
| `released` | 0 | the commit arrived and every health call passed |
| `no health command` | 0 | the commit arrived; `Health: not asked: the "Release" section names no healthy command` |
| `not arrived` | 2 | `Arrived: no, not within <n> seconds; the target printed last: <first line>, read <UTC>` and `Health: not asked` |
| `unhealthy` | 3 | `Health: asked <n>, failed <m>, first failure read <UTC>, last read <UTC>` |

Without a "Release" section, or without `deployed` in it, the watch prints one line that names this document and exits 4; nothing is run. A `RUNTIME.md` that does not pass `check` is not run either (exit 1, the problems on stderr). A usage error exits 64.

## `## Signals` -- where production speaks

```markdown
## Signals

- errors | read: glitchtip-cli issues --project shop --since 24h --format tsv | kind: errors | scope: unhandled errors of the web app
- latency | read: ./ops/p95.sh --window 24h | kind: performance | scope: p95 per route, one line per route
```

One line per source: a name (lowercase slug, unique), then `key: value` fields separated by ` | `, in any order. A ` | ` inside a command stays part of the command: a new field starts only where `<word>: ` follows the bar.

| Field | Required | Holds |
|---|---|---|
| `read` | yes | The command that prints the current findings, one per line. It only reads. |
| `kind` | yes | `errors`, `performance`, `alerts` or `logs`. |
| `scope` | no | What the source covers, for whoever reads the findings. |

`bin/ytstack-runtime signals` prints the sources as tab-separated lines (name, kind, read, scope; `-` for an empty one) and nothing when there is no source. How findings become records: `docs/ux/signal-format.md`.

## Reading a value

`bin/ytstack-runtime get <section> <key>` prints the value of one key of "Run" or "Release" and exits 1 when the file, the section or the key is missing. The section is given in any case (`run`, `Release`). Every script and skill reads `RUNTIME.md` through it; none parses the file itself.

Every command takes `-C <dir>` in front of it and then works on the project of that directory, like the other scripts.

## Checked mechanically

`bin/ytstack-runtime check` fails on:

- a key outside the lists above in one of the three sections, a key that stands twice, or a list line there that is not `- key: value` (Run, Release) or `- name | key: value | ...` (Signals); also a key line of "Run" or "Release" that lost its leading `- `
- a "Run" section without `start` or `ready`, a `{port}` without `ports`, a `ports` value that is not `<first>-<last>` with first below last and both within 1 to 65535
- a "Release" section without `deployed`, a `settle` that is not a number
- a signal without `read` or `kind`, a `kind` outside the four values, a name used twice or not a lowercase slug
- a token-looking string anywhere in the three sections, free text included (the rule of `bin/ytstack-handover check`: 32 or more hex digits, or 40 or more characters that mix upper case, lower case and digits)

It prints one line per problem, with the line number where there is one. It exits 0 with `runtime ok: <which sections exist>` and passes a `RUNTIME.md` that has none of the sections (`runtime ok: no sections`) and a project without the file (`runtime ok: no RUNTIME.md`). Text outside the three sections is never read.

What stays a judgment: whether `start` really starts the product, whether a command under "Release" or "Signals" really only reads, and whether a short password or a connection string with one stands in a line: the token rule does not see those.

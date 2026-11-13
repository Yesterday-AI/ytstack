# Runtime format

`RUNTIME.md` in the project's `.ytstack/` directory says how the product is started, where its release can be read and where its signals come from. It is user-owned free text, as before. Three sections in it have a fixed line format, so that an agent can start the product in its own worktree, watch a release and read signals without guessing. Each section is optional; a skill that needs a missing one says so and stops, it does not improvise a command.

The script is `bin/ytstack-runtime`. The skills that use the sections are `verification-before-completion`, `visual-review`, `finish-lane` (release watch), `signal-intake` and `incident`, and the agents `implementer` and `verifier`.

## Two rules

1. **Names, never values.** A command may read a credential from the environment of whoever runs it. No token, password or connection string is written into `RUNTIME.md`. `bin/ytstack-runtime check` fails on a string that looks like one.
2. **Commands under "Release" and "Signals" only read.** They are run by unattended agents. A command that changes the target (a deploy, a restart, a flag flip, a write query) does not belong there; it is a step for a person (`handover-step`). The script cannot prove that a command only reads; whoever writes the line vouches for it, and the credentials it uses should be read-only ones.

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

One `- key: value` line per key.

| Key | Required | Holds |
|---|---|---|
| `start` | yes | The command that starts the product from the root of the checkout it is run in. `{port}` is replaced by the chosen port, which is also exported as `PORT`. It must not need a second terminal: one command, started in the background by the script. |
| `ports` | when `start` or `ready` uses `{port}` | A range `<first>-<last>` the script may pick from. Two worktrees get different ports, so that several agents can run the product at once. |
| `ready` | yes | A command that exits 0 once the product answers. The script repeats it until it passes or the timeout ends. |
| `url` | no | Where a browser enters. Printed by `up`. |
| `logs` | no | Where the output goes: `{log}` stands for the file the script redirects the start command into; a path or a command when the product logs elsewhere. |
| `needs` | no | What has to exist before `start` works: environment variable names, a local service and the command that brings it up. Read by the agent, not by the script. |
| `stop` | no | A command that stops what `start` started. `(default)` or no line: the script ends the process group it started. |

`bin/ytstack-runtime`:

- `up [--timeout <seconds>]` picks a free port from `ports` (a start position derived from the worktree, then the next free one), starts `start` in the background with its output in a log file outside the checkout, repeats `ready` until it passes, and prints `URL:`, `PORT:`, `PID:` and `LOG:` lines. It fails with the last lines of the log when `ready` never passes. A second `up` in the same worktree prints the running instance instead of starting another.
- `down` stops the instance of this worktree.
- `status` prints the instance of this worktree or `not running`.

What an instance proves is what was started: the script prints the commit of the checkout with `COMMIT:`, and a result names it (`minimal-code`, "evidence").

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

`bin/ytstack-watch release --commit <sha> [--timeout <seconds>]` reads these keys through `bin/ytstack-runtime get`. It asks `deployed` until the output contains the commit, then asks `healthy` for the settle time, and prints one receipt: target, commit, when it arrived, how often `healthy` was asked and how often it failed, each with its read time. It deploys nothing and rolls nothing back.

## `## Signals` -- where production speaks

```markdown
## Signals

- errors | read: glitchtip-cli issues --project shop --since 24h --format tsv | kind: errors | scope: unhandled errors of the web app
- latency | read: ./ops/p95.sh --window 24h | kind: performance | scope: p95 per route, one line per route
```

One line per source: a name (lowercase slug, unique), then `key: value` fields separated by ` | `.

| Field | Required | Holds |
|---|---|---|
| `read` | yes | The command that prints the current findings, one per line. It only reads. |
| `kind` | yes | `errors`, `performance`, `alerts` or `logs`. |
| `scope` | no | What the source covers, for whoever reads the findings. |

`bin/ytstack-runtime signals` prints the sources as tab-separated lines (name, kind, read, scope). How findings become records: `docs/ux/signal-format.md`.

## Reading a value

`bin/ytstack-runtime get <section> <key>` prints the value of one key of "Run" or "Release" and exits 1 when the section or the key is missing. Every script and skill reads `RUNTIME.md` through it; none parses the file itself.

## Checked mechanically

`bin/ytstack-runtime check` fails on:

- a key outside the lists above in one of the three sections, or a line there that is not `- key: value` (Run, Release) or `- name | key: value | ...` (Signals)
- a "Run" section without `start` or `ready`, a `{port}` without `ports`, a `ports` value that is not `<first>-<last>` with first below last
- a "Release" section without `deployed`, a `settle` that is not a number
- a signal without `read` or `kind`, a `kind` outside the four values, a name used twice
- a token-looking string anywhere in the three sections

It exits 0 with `runtime ok: <which sections exist>` and passes a `RUNTIME.md` that has none of the sections. Text outside the three sections is never read.

What stays a judgment: whether `start` really starts the product, and whether a command under "Release" or "Signals" really only reads.

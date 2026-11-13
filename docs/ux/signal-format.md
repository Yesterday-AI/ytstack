# Signal format

What production says has to reach the plan, and it has to arrive once. This document fixes the record of a finding: one file per thing a signal source of the project reported and an intake judged worth acting on. The sources are the `read` commands under "Signals" in `RUNTIME.md` (`docs/ux/runtime-format.md`). The script is `bin/ytstack-signals`; the skill that uses it is `signal-intake`.

All files live in the project's `.ytstack/` directory and are user-owned like every artifact there.

## Three rules

1. **Read only.** Nothing here runs a command that changes the target. The script reads and writes files under `.ytstack/`. The only commands a skill runs against production are the `read` commands of "Signals" and what a person orders in the conversation.
2. **Every fact carries its read time.** A line from a source is true for the moment it was read. A record stores it with that UTC time and never as the current state. Before somebody acts on it, the source is read again.
3. **No secret in a record.** A source can print a token, a session id or a mail address. The files are committed. Whoever records a sighting cuts such a value down to what identifies the line. The script cannot see a secret; this stays a judgment.

## `signals/` -- findings

One file per finding: `.ytstack/signals/F###-<slug>.md`.

```markdown
---
id: F007
key: errors:4812
source: errors
kind: errors
state: open
first_seen: 2026-11-13T09:15:02Z
last_seen: 2026-11-14T09:15:04Z
count: 2
ref: none
reopens: none
---

# F007 -- TypeError in checkout: cart is undefined

## What was seen

### read 2026-11-13T09:15:02Z

    4812	TypeError: cart is undefined (checkout.ts:88)	new	events=37

### read 2026-11-14T09:15:04Z

    4812	TypeError: cart is undefined (checkout.ts:88)	unresolved	events=112

## Assessment

The source marks the issue as new, and it occurred 37 times in 24 hours on the checkout route.

## Next

Pick up with `systematic-debugging`; then `ytstack-signals set F007 --state planned --ref <task>`.
```

| Field | Holds |
|---|---|
| `id` | `F` and three digits. Equal to the start of the file name, unique. |
| `key` | The stable identity of the finding at its source: an issue id, a normalised error signature, a route name. The intake chooses it. One word of letters, digits and `. _ : / @ + = -`. By convention it starts with the source name and a colon (`errors:4812`, `latency:/api/export`), so that two sources never share one. |
| `source` | The name of the signal source, as "Signals" declares it. |
| `kind` | `errors`, `performance`, `alerts` or `logs`: the kind of the source. |
| `state` | `open`, `planned`, `fixed` or `dismissed`, see below. |
| `first_seen`, `last_seen` | The read times of the first and of the newest sighting, UTC with seconds. |
| `count` | How many intake runs saw it. Not the number of events at the source. |
| `ref` | The task, quick task or question the finding became (`M004-S02-T03`, `quick/Q012`, `Q007`), or `none`. One word. |
| `reopens` | The id of the fixed finding this one is a regression of, or `none`. |

| `state` | Means |
|---|---|
| `open` | Recorded, nobody picked it up yet. |
| `planned` | It became work; `ref` names it. |
| `fixed` | The work is done. A new sighting of the key is a regression and gets a finding of its own. |
| `dismissed` | A person decided it is not a finding; the reason stands under "Assessment". It stays dismissed however often it is seen. |

The body has three sections in this order:

- **What was seen** -- one block per sighting: a `### read <UTC time>` line and under it the raw line or lines from the source, indented by four spaces so that nothing in them is read as Markdown. The newest five sightings stay, and of one sighting the first twenty lines.
- **Assessment** -- why this is a finding and not noise, in the words of whoever recorded it. A dismissal adds its reason here with its time.
- **Next** -- one line: what happens with it.

### Recorded once

`bin/ytstack-signals new --source <name> --key <key> --title <text> [--kind <kind>] [--read-at <time>]` takes the raw sighting on stdin. The newest finding that carries the key decides what happens, and the first word of the output says which case it was, followed by the id and the path:

| The key belongs to | The script | Prints |
|---|---|---|
| no finding | writes a file with the next id, `state: open`, `count: 1` | `new F008 <path>` |
| an `open` or `planned` finding | sets `last_seen`, raises `count`, appends the sighting | `seen-again F007 <path>` |
| a `dismissed` finding | sets `last_seen`, raises `count`; the sighting is not kept | `dismissed F005 <path>` |
| a `fixed` finding | writes a new finding with `reopens: <the fixed id>`; the fixed one stays as it is | `regression F009 <path>` |

`--kind` is needed only for a source that "Signals" does not declare; otherwise the kind of the source is taken. `--read-at` is the time the source was read (`2026-11-13T09:15:02Z`); without it the time of the call counts. The slug of the file name comes from the title. The title is the heading of the file and can be edited later; the key cannot.

Per key the findings form a chain: the first one reopens nothing, each later one reopens the one before it, and only the newest one is ever not `fixed`.

### After the intake

- `bin/ytstack-signals list [--state <state>]` prints one tab separated line per finding: id, state, source, kind, count, last_seen, ref, reopens, key, title. Without `--state` the open and the planned ones; `--state all` prints every one.
- `bin/ytstack-signals set <id> --state <state> [--ref <ref>]` changes the state. `planned` needs a reference, given now or earlier. `dismissed` takes the reason on stdin and writes it under "Assessment" with the time. A state other than `fixed` is refused while another finding with the same key is newer or not fixed.

The intake never dismisses, never marks a finding fixed and never opens a task. A person or a coordinating session picks a finding, starts `systematic-debugging` and links the two with `set <id> --state planned --ref <task>`. Whoever closes that task sets `fixed`.

Two intake runs can overlap. Every write of the script holds a lock (the file `signals.lock` in `.ytstack/`) and goes through a temporary file in the same directory, so two sightings of one key at the same moment give one file with `count: 2`.

## Checked mechanically

`bin/ytstack-signals check` fails on:

- a file in `signals/` whose name is not `F###-<slug>.md`, an id that differs from the file name or is used by two files, a file without frontmatter
- a `key` or a `ref` that is not one word of the listed characters, a `source` that is not a lowercase slug, a `kind` or a `state` outside the listed values
- `first_seen` or `last_seen` that is not a UTC time with seconds, a `count` that is not a number from 1
- a `planned` finding whose `ref` is `none`, a `dismissed` finding without a reason under "Assessment"
- a body that does not have the three sections, each once and in order
- two findings with one key that both reopen nothing; a `reopens` that names no finding, a finding with another key or one that is not older; a finding that is not `fixed` although a newer one carries its key

It prints one line per problem, starting with the file name, and exits 1. It exits 0 with `signals ok: <n> finding(s)`, and with `no signals` in a project without the directory.

What stays a judgment: whether a line is a finding or noise, whether two lines are the same finding (the choice of the key), and whether a sighting holds a value that must not be committed.

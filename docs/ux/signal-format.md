# Signal format

What production says has to reach the plan, and it has to arrive once. This document fixes two records. A finding is one file per thing a signal source of the project reported and an intake judged worth acting on. An incident record is one file per incident: what was seen, what was tried and who decided what. The sources are the `read` commands under "Signals" in `RUNTIME.md` (`docs/ux/runtime-format.md`). The script is `bin/ytstack-signals`; the skills that use it are `signal-intake` and `incident`.

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
| `kind` | `errors`, `performance`, `alerts` or `logs`: the kind of the source; `review` for a review-bot finding the own reviewers missed (see "Review escapes"). |
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

### Review escapes

A finding a review bot made on a pull request, that a later commit fixed and that none of the project's own reviewers reported (`fixed` and `escaped` in the output of `bin/ytstack-review-escapes`, `docs/ux/review-policy-format.md`, "Escapes"), is a finding of `kind: review`. Its source is no command of "Signals": the pull request is.

```
bin/ytstack-signals new --source review --kind review --key review:<role>:<class-slug> --title <text> --read-at <time> < escape rows
```

- **The key** is `review:<role>:<class-slug>`: the own reviewer that owns the finding, as `REVIEW.md` names it, and a lowercase slug for the class of mistake (`missing-null-guard`, `quota-not-charged`). Both parts are lowercase slugs; the script refuses another form for `kind: review`. One class of one role is one finding: the second escape of the class raises `count` instead of opening a file.
- **The sighting** is the escape row or rows as the script printed them: the bot, the resolution, the match, the file, the lines, the URL of the thread and its title, which carries the bot's severity where the bot states one.
- **A `rejected` bot finding is never recorded**: it was answered without a code change. An `open` one is not a lesson yet.

Which merged pull requests had their escape check is one line each in `.ytstack/signals/review-checks`:

```
<owner/name>#<n> <merge sha> <UTC time>
```

`bin/ytstack-signals review-checked <owner/name>#<n> <merge sha> [--at <time>]` appends the line and prints `checked <owner/name>#<n>`; a pull request that has its line keeps it and the call prints `already <its line>`. `review-checked <owner/name>#<n>` without a commit asks: exit 0 with the line, 1 without. The reference is written as `gh` prints `nameWithOwner`, the commit as 7 to 40 lowercase hex digits. A pull request without escapes gets its line too: the line says the check ran, not that something was found.

## `incidents/` -- the record of an incident

One file per incident: `.ytstack/incidents/<YYYY-MM-DD>-<slug>.md`, the day it was opened in UTC. The record is what a session resumes from: an incident outlives a context, and a summary of a conversation is not a record.

```markdown
---
id: 2026-11-13-checkout-returns-502
state: mitigated
opened: 2026-11-13T09:15:00Z
mitigated: 2026-11-13T09:52:10Z
closed: none
severity: all customers, no orders possible
root_cause: none
---

# Incident -- Checkout returns 502

## What is seen

- 2026-11-13T09:16:10Z -- `./ops/health.sh` (signal `health`): exit 1, `checkout 502 Bad Gateway`
- 2026-11-13T09:18:40Z -- `curl -fsS https://shop.example.com/version` (approved by Kim): `a1b2c3d`, deployed 09:02Z
- 2026-11-13T09:51:30Z -- `./ops/health.sh` (signal `health`): exit 0, `checkout 200`

## Timeline

- 2026-11-13T09:15:00Z -- record opened
- 2026-11-13T09:15:00Z -- Kim reports that customers cannot pay since about 09:05Z
- 2026-11-13T09:31:00Z -- Kim ordered M1
- 2026-11-13T09:50:05Z -- receipt of M1: completed
- 2026-11-13T09:52:10Z -- Kim says it holds; mitigated

## Hypotheses

- H1 -- the release of 09:02Z broke the checkout | for: the first 502 at 09:04Z, two minutes after `a1b2c3d` arrived | against: none | status: supported
- H2 -- the payment provider is down | for: nothing | against: its status page was green at 09:20Z (read by Kim) | status: ruled out

## Proposed mitigations

- M1 -- Roll the checkout back to the release before | changes: the image of deployment checkout in shop-prod | effect: 502 stops within two minutes | risk: the new coupon field disappears until the fix | undo: `kubectl rollout undo` once more | script: .ytstack/handover/2026-11-13-roll-back-checkout.sh | status: carried out, receipt .ytstack/handover/2026-11-13-roll-back-checkout.sh.receipt-20261113T094712Z.txt
- M2 -- Restart the checkout pods | changes: the pods of deployment checkout | effect: unclear, helps only if H1 is wrong | risk: requests in flight fail | undo: none needed | script: .ytstack/handover/2026-11-13-restart-checkout.sh | status: declined

## Decisions

- 2026-11-13T09:31:00Z -- Kim ordered the rollback (M1) and declined the restart (M2).
- 2026-11-13T09:52:10Z -- Kim declared the incident mitigated.

## After

- Root cause: to be found with `systematic-debugging`, this record as its input.
```

| Field | Holds |
|---|---|
| `id` | The file name without `.md`. |
| `state` | `open`, `mitigated` (a person said the mitigation holds) or `closed`. |
| `opened`, `mitigated`, `closed` | UTC times with seconds, or `none`. `open`: only `opened` is set. `mitigated`: `mitigated` is set, `closed` is not. `closed`: `closed` is set; `mitigated` stays `none` when the incident ended without a mitigation. |
| `severity` | As the person stated it, in their terms, or `unstated`. Nobody else grades an incident. |
| `root_cause` | `none`, then the reference of the task that found the cause (`M005-S01-T02`). A closed record needs that reference or `not pursued -- <reason>`. |

The six sections stand in this order:

| Section | Holds |
|---|---|
| What is seen | Facts, one line each: the read time, the command that produced it, the result. A command outside "Signals" names who approved it. A later read is a new line; no line is replaced. |
| Timeline | One line per event, `- <UTC time> -- <event>`, in the order things happened. Append only. |
| Hypotheses | `- H<n> -- <statement> \| for: <evidence> \| against: <evidence> \| status: open`, `supported` or `ruled out`. Evidence points at lines of "What is seen". |
| Proposed mitigations | One line per mitigation, see below. |
| Decisions | What a person ordered or declared, and when, in the recorder's own words. Never a quotation, and never something the person did not say. |
| After | The root-cause task and the follow-ups. |

A mitigation is one list line:

```markdown
- M<n> -- <what it is> | changes: <what it changes, where> | effect: <what should be seen afterwards> | risk: <what can go wrong> | undo: <how, or "cannot be undone"> | script: <path of its handover script> | status: <status>
```

| `status` | Means |
|---|---|
| `proposed` | Prepared, nobody decided. |
| `ordered by <who> at <UTC time>` | A person ordered it. They run the script; no agent does. |
| `carried out, receipt <path>` | The script ran; the receipt says how it ended. |
| `declined` | A person said no. |

Every mitigation is a staged script for a person, made with `bin/ytstack-handover new` and verified with `bin/ytstack-handover check` (`skills/handover-step/SKILL.md`). Paths are written from the root of the repository. A ` | ` inside a value stays part of it: a new field starts only where `<word>: ` follows the bar.

`bin/ytstack-signals incident new --title <text> [--severity <text>]` writes the skeleton (the frontmatter, the six headings, the first timeline line) and prints the path. It refuses when a record of that day with that title exists: an incident is resumed, not opened twice. `bin/ytstack-signals incident list [--state <state>]` prints one tab separated line per record: id, state, opened, severity, title; without `--state` the ones that are not closed. Everything after the skeleton is written by the skill `incident`, with the file tools.

## Checked mechanically

`bin/ytstack-signals check` fails on:

- a file in `incidents/` whose name is not `<YYYY-MM-DD>-<slug>.md`, an `id` that differs from the file name, a file without frontmatter
- a `state` outside the three values, an `opened` that is not a UTC time, a `mitigated` or `closed` that is neither `none` nor a UTC time, and times that contradict the state
- a record without `severity`, a closed record whose `root_cause` is `none`, a `not pursued` without a reason
- a body that does not have the six sections, each once and in order
- a list line under "Proposed mitigations" that does not start with `M<n> -- `, an id used twice, a missing field, a `status` outside the four forms
- a mitigation that is not `declined` and whose script does not exist or does not pass `bin/ytstack-handover check`, and a `carried out` whose receipt does not exist
- a file in `signals/` whose name is not `F###-<slug>.md`, an id that differs from the file name or is used by two files, a file without frontmatter
- a `key` or a `ref` that is not one word of the listed characters, a `source` that is not a lowercase slug, a `kind` or a `state` outside the listed values, a finding of `kind: review` whose key is not `review:<role>:<class-slug>`
- a line of `review-checks` that is not `<owner/name>#<n> <merge sha> <UTC time>`, and a pull request that has two lines
- `first_seen` or `last_seen` that is not a UTC time with seconds, a `count` that is not a number from 1
- a `planned` finding whose `ref` is `none`, a `dismissed` finding without a reason under "Assessment"
- a body that does not have the three sections, each once and in order
- two findings with one key that both reopen nothing; a `reopens` that names no finding, a finding with another key or one that is not older; a finding that is not `fixed` although a newer one carries its key

It prints one line per problem, starting with the file name, and exits 1. It exits 0 with `signals ok: <n> finding(s), <m> incident(s)`, and with `no signals` in a project that has neither directory.

What stays a judgment: whether a line is a finding or noise, whether two lines are the same finding (the choice of the key), and whether a sighting holds a value that must not be committed. In an incident record: whether a fact is one, whether a hypothesis follows from the facts, and whether "Decisions" holds only what a person said. The check reads the form of a mitigation line, not whether its script is the right one.

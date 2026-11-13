# Technical spec format

The technical spec is the part of `.ytstack/` that says **what applies now**: how the system behaves, where that is implemented and how a change is verified. A fresh session reads it instead of reconstructing the present from plans, summaries and decision history.

It lives at the same paths in every ytstack project:

```
.ytstack/spec/SPEC.md        entry point, one page
.ytstack/spec/<area>.md      one file per system area
```

`bin/ytstack-spec` checks the format (`lint`), reports areas whose code moved on without their description (`drift`) and checks a task's documentation impact at closure (`impact`). The skills that write and maintain the spec are `init-project`, `adopt-brownfield`, `plan-task`, `summarize-task`, `code-review` and `reassess-roadmap`.

## Four roles, four places

| Question | Where the answer is | How it changes |
|---|---|---|
| What applies now? | `.ytstack/spec/` and the sources it names | rewritten when the area changes |
| What is being worked on, what is undecided? | `STATE.md`, the open plans | advanced by every task |
| Why was it decided? | `DECISIONS.md` | append-only |
| What happened? | `M###-...-SUMMARY.md`, changelog | append-only |

A plan describes an intended change. A summary describes what a task did. Neither is a description of the system. An area file is: it is edited in place, it has no dated entries, and it never narrates how the current state came about. It links to the decisions and summaries that explain it.

## What the spec does not say

- **Not deployed, not accepted.** An area file describes behaviour in the repository at a commit. Whether that commit runs anywhere, and whether somebody accepted it, is recorded in `STATE.md` and in the project's release records. Nobody infers a deployment or an acceptance from the spec.
- **Not a second definition.** Signatures, schemas, API definitions, configuration values and versions stay in the code and in the files that define them. The spec links to them. A number that the code can answer is not copied into prose.
- **Not a guess.** A fact nobody has established is written as `Unknown` with what is missing. A requirement nobody approved is an open decision, not a rule.

## `SPEC.md`

One page, at most 80 lines. The first thing a session reads after `STATE.md`.

```markdown
---
project: <name>
updated: <YYYY-MM-DD>
---

# <name> -- technical spec

## What this is

<Three to six lines: what the system does, for whom, and its main parts.>

## Areas

| Area | Covers | Status | File |
|---|---|---|---|
| <area> | <one line> | planned / partial / implemented | [<area>.md](<area>.md) |

## Invariants that hold everywhere

- <A rule every area obeys, with a link to the decision or the check that enforces it.>

## Build and test

<The commands, or one line that names the file holding them (`RUNTIME.md`, `codebase/stack.md`, a README section).>

## Keeping this true

- A task plan names its **Spec impact**: the area and section it changes, or `none`.
- A task that changes behaviour updates the area file, or the source the area file names, in the same commits. A task that restores the described behaviour, a refactoring and a trivial edit close with `none`.
- A decision that changes what applies in an area is linked under that area's "Decisions that apply now" in the same commits; the entry it replaces leaves the list.
- Which area describes a path: the `paths` in each area file. Which areas need a look: `bin/ytstack-spec drift`.
- The format: `docs/ux/spec-format.md` in the ytstack plugin.
```

The section "Keeping this true" is part of every `SPEC.md` on purpose. A session on a host without hooks, or an agent that was dispatched with a brief and never loads a skill, still finds the rule in the repository.

## Area file

One file per area, at most 200 lines. An area is a part of the system that somebody could be handed a bug in: it has a boundary, an owner in the code and its own way to be verified. A project has three to eight of them. The name is a lowercase slug (`auth`, `billing-export`, `hooks-and-state`) and is the file name.

### Frontmatter

```yaml
---
area: <slug, equals the file name without .md>
status: planned | partial | implemented
paths:
  - <glob of the code this area describes, e.g. src/auth/**>
sources:
  - <path of an existing document that stays authoritative for this area; optional>
verified_at: <commit the description was last checked against, or none>
---
```

| Field | Meaning |
|---|---|
| `status: planned` | The description is the approved design. The code does not exist yet or was never checked against it. `verified_at` is `none` and `paths` may be empty. |
| `status: partial` | Part of the area is built and checked. Each statement about behaviour that is not built yet is marked `(planned)`. |
| `status: implemented` | The described behaviour exists in the code at `verified_at`: somebody read the code against the description. Whether the commands under "How to verify" ran, and at which commit, is said in that section. |
| `paths` | Git pathspec globs, relative to the repository root. `**` crosses directories. They decide which area a change belongs to. |
| `sources` | Existing documents that hold the description: an architecture guide, an ADR folder, an API reference. They keep their authority (see "Pointer-only"). |
| `verified_at` | A commit, short or full. It is set by whoever read the code against the description, never by a scaffold. |

`status` is about the code and the description. It is never raised because a plan was approved, a pull request merged or a deployment happened.

### Sections

Names and order are fixed. Four sections are in every area file: **Purpose**, **Where implemented**, **How to verify**, **Decisions that apply now**. Each of the others is written when the area has something to say there, replaced by one line linking to the source that holds it, or left out.

| # | Section | Holds |
|---|---|---|
| 1 | `## Purpose` | What the area is for and where it ends, in two to four lines. |
| 2 | `## Behavior` | What it does, as observable rules. Present tense. No history. |
| 3 | `## Interfaces and contracts` | What other parts and users rely on. Links into code, schemas and API definitions; no copies. |
| 4 | `## Data flow` | What enters, what leaves, what is stored, in order. |
| 5 | `## Invariants and security boundaries` | What must always hold, who may do what, where input is trusted and where it is not. |
| 6 | `## Error behavior` | What happens when an operation fails, and what the caller sees. |
| 7 | `## Runtime and deployment assumptions` | What the area needs from its environment. Assumptions, not a deployment record. |
| 8 | `## Known limits` | What it does not do, the load it was built for, deliberate shortcuts with the point at which they stop holding. |
| 9 | `## Where implemented` | Entry points and the files that matter, as paths. Tests that pin the behaviour. |
| 10 | `## How to verify` | The commands that show the area works, runnable as written, and what a pass looks like. |
| 11 | `## Decisions that apply now` | Links to the `DECISIONS.md` entries in force for this area. A decision that narrows an older one is listed with what it narrows. Superseded entries are not listed. |

### Pointer-only

Where a project already has an authoritative document for an area, the area file does not repeat it. It holds the frontmatter with `sources`, the four required sections and whatever the source lacks. "Purpose" then says in one line that the description lives in the source.

Updating the source satisfies a documentation impact. The area file changes only when the pointer itself becomes wrong: a new source, a moved path, a section the source dropped.

## Maintenance rules

### In a plan

Every task plan has a `## Spec impact` section:

```markdown
## Spec impact

- hooks-and-state: Behavior -- the SessionStart injection names SPEC.md
```

or

```markdown
## Spec impact

none -- restores the documented behaviour
```

One line per area: `- <area>: <section> -- <what changes>`. The reason after `none` is one of: restores the described behaviour, no behaviour or contract changes (refactoring, rename, formatting), not covered by an area yet. If no area covers the changed code and the change is not trivial, the plan says so and names the area to add.

### At closure

`summarize-task` runs `bin/ytstack-spec impact` on the plan and the task's commits. For each area the plan names, the impact is satisfied when the task's commits changed **the area file or one of its `sources`**. It is not satisfied by a sentence in the summary. A plan with `none` closes without any spec edit.

The summary records what was updated under `## Spec`: the area, the file and section, or `none` with the plan's reason.

### Drift

`bin/ytstack-spec drift` compares, for every area that is not `planned`, the commits that touched its `paths` with the last commit that touched the area file or one of its `sources`. When code changed after that commit, it prints a **possible documentation impact**. That is a prompt to look, not a finding that the description is wrong: a refactoring changes paths and leaves the contract alone.

The two valid answers:

1. The contract changed: update the area file or its source.
2. The contract did not change: set `verified_at` to the commit you checked. That one-line edit records that somebody looked, and it is the touch that quiets the report.

`verified_at` names a commit that stays in the history. On a branch that will be squash-merged, use the commit the branch started from or the head of the default branch; `lint` warns about a stamp that names no commit.

Nobody edits a description only to quiet the report, and no task is held open by it. The natural moment to answer it is the slice boundary (`reassess-roadmap`), once per area, not once per task.

### Decisions

A new `DECISIONS.md` entry that changes what applies in an area is added to that area's "Decisions that apply now" in the same commit, and the entry it supersedes is removed from the list. `DECISIONS.md` itself stays append-only.

### Scaffolds

`init-project` writes area files from the pitch and the engineering review with `status: planned` and `verified_at: none`. `adopt-brownfield` writes them over the existing documents and its codebase map, pointer-only where a document exists, with `status: implemented` only for what a reader checked against the code and `verified_at` set to that commit. Everything else is `planned`, `partial` or `Unknown`.

## Checked mechanically

`bin/ytstack-spec lint` fails on:

- an area file without valid frontmatter, an `area` that differs from the file name, a `status` outside the three values
- a missing required section, a section name outside the fixed list, sections out of order
- `status: implemented` or `partial` with `verified_at: none` or without `paths`
- a `sources` entry that does not exist, or a `paths` glob that matches no file in the repository (a `planned` area may name paths that do not exist yet)
- an area file that `SPEC.md` does not list, or a listed file that does not exist
- a `SPEC.md` without the sections "Areas" and "Keeping this true"

It warns on an area file above 200 lines, a `SPEC.md` above 80 and a `verified_at` that names no commit in the repository.

`bin/ytstack-spec areas <path>` names the area whose `paths` cover a file. `plan-task` uses it to fill "Spec impact".

What stays a judgment: whether the description is right. The mechanical checks establish that it exists, is reachable and was looked at; `code-review` and the verifier read the touched area against the change.

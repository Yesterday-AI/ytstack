# Review policy format

Whether a person has to look at a change is decided per change, from its risk and its kind. This document fixes the pieces of that decision: the risk classes, the mechanical floor, the ceiling each area of the technical spec sets, the lenses a kind of change requires, the records a review leaves, and the route that follows.

The script is `bin/ytstack-risk`. The skills that use it are `code-review`, `finish-lane`, `visual-review` and `coordinate`. The preference is `merge_by: risk` in `PREFERENCES.md`.

The principle: **the route without a person has conditions, and everything that is not declared goes to a person.** A project that declares nothing behaves as before.

## Risk classes

| Class | A change is this when |
|---|---|
| `low` | A mistake in it is contained and cheap to take back, and nothing a user or another part relies on changes: documentation, tests, comments, copy, an internal rename or refactoring that leaves every contract alone. |
| `normal` | Behaviour changes inside the contract of one area, and a revert takes it back. |
| `high` | It touches an invariant or a decision that applies now, a security boundary, stored data or its shape, an interface another part or a user relies on, or it cannot be taken back by a revert. |

The class of a change is the higher of two values: the **floor** a script computes from the diff, and the **class the reviewer states**. Nobody can state a class below the floor. The author of a change never classifies it.

## The floor

`bin/ytstack-risk floor --base <sha> --head <sha>` reads the difference between the two commits and prints the lowest class the change can have, or `person` when no class is low enough for the route without a person.

```
floor: low | normal | person
reason: <path or subject> -- <rule>
areas: <comma list or none>
ceiling: none | low | normal
lenses: <comma list or none>
```

There is one `reason:` line per path and rule that raised the floor. A rule names at most five paths and counts the rest in one more line. `areas` are the areas the change touches, `ceiling` is the lowest `auto_merge` among them (see "Ceilings"), `lenses` are the lenses the change requires (see "Lenses"). The exit code is 0 when a result was printed, 64 for a usage error and 65 when git cannot answer: no repository, or a commit that does not exist.

**Always a person** (`person`):

- a change to `.ytstack/spec/REVIEW.md`, `.ytstack/DECISIONS.md`, `.ytstack/STANDING.md`, `.ytstack/PREFERENCES.md`, or to an instruction file of the repository (`AGENTS.md`, `CLAUDE.md`, at any depth)
- a change to the frontmatter of an area file, or to the text of its sections "Invariants and security boundaries" and "Decisions that apply now"; the same section of `SPEC.md` ("Invariants that hold everywhere"); an area file or a `SPEC.md` that the change adds or deletes. Other edits of an area file are ordinary: a task that changes behaviour updates "Behavior" in the same commits. So is a `verified_at` stamp on its own: it answers a drift report (`docs/ux/spec-format.md`, "Drift") and changes no policy. `area`, `status`, `paths`, `sources` and `auto_merge` stay `person`
- a change to the checks themselves: `.github/workflows/**`, `.gitlab-ci.yml`, and whatever the project lists
- a changed path that no area covers (see "Ceilings"), other than the process records of the work itself. An area file counts as covered by its own area and touches it; `SPEC.md` needs no area. A renamed or deleted file counts with its old and its new path
- every path the project lists under "Always a person"

**Never low** (at least `normal`):

- dependency manifests and lock files, migrations and schema files, container and infrastructure definitions; the built-in patterns are the list `NEVER_LOW` at the top of the script
- more than 400 changed lines or more than 20 changed files (`size:` in `REVIEW.md` changes the two numbers). Changed lines are added plus deleted lines; a binary file is one file and no lines
- every path the project lists under "Never low"

The built-in lists cannot be shortened by the project, only extended. `REVIEW.md` is itself under "Always a person", so the policy cannot be relaxed on the route it governs.

**Process records** are exempt from the coverage rule and do not count towards the size. They are, under `.ytstack/`: the files `M###-CONTEXT.md`, `M###-ROADMAP.md`, `M###-...-PLAN.md` and `M###-...-SUMMARY.md`, `STATE.md`, `LANES.md`, `KNOWLEDGE.md`, `ROADMAP.md`, `quick/` and `questions/`; and the evidence directory (`evidence_dir`, when it is a path inside the repository). Every other rule applies to them.

**Where the policy is read.** The script reads the policy at the base commit, never from the working tree: the `paths` and `auto_merge` of the area files, `REVIEW.md` and `evidence_dir`. A change to one of them is itself `person`, so the base and the head agree whenever the floor is not `person`, and an edit that is not committed changes nothing. A `REVIEW.md` that does not parse at the base sends every change to a person. A repository without area files has no covered path: the floor is `person` with one reason for all paths.

## Ceilings: what an area allows

An area file of the technical spec (`docs/ux/spec-format.md`) may carry one more frontmatter field:

```yaml
auto_merge: none | low | normal
```

It is the highest class that may merge into this area without a person. No field means `none`. `high` is not a value: a high change always goes to a person. A change that touches several areas gets the lowest of their ceilings.

## `REVIEW.md` -- the project's policy

`.ytstack/spec/REVIEW.md`, linked from `SPEC.md`. Optional; without it only the built-in floor applies and no lens is required.

```markdown
# Review policy

## Always a person

- infra/terraform/**
- src/billing/ledger/**

## Never low

- src/auth/**
- **/*.sql

## Lenses

- ui | applies: src/components/**, src/app/**/*.tsx, **/*.css | reads: docs/design-guidelines.md, docs/product-guidelines.md | evidence: visual
- security | applies: src/auth/**, src/api/middleware/** | reads: .ytstack/spec/auth.md | evidence: none

## Size

- size: 400 lines, 20 files
```

Paths are git pathspec globs relative to the repository root, one per line. Every section is optional. Git itself matches them, the way `bin/ytstack-spec lint` and `drift` read `paths`: `*` stays inside one directory, `**` crosses directories, and `**/name` also matches at the root.

## Lenses: what a kind of change requires

A lens is a second, independent review with one question and the documents that answer it. It is defined by what it reads, not by a role description.

| Field | Required | Holds |
|---|---|---|
| name | yes | Lowercase slug, unique. |
| `applies` | yes | Globs, comma-separated. The lens is required for a change when a changed path matches one. |
| `reads` | yes | The documents the lens reviews against: the project's guidelines, a design guide, an area file. They exist in the repository. |
| `evidence` | yes | `visual` or `none` (below). |
| `skill` | no | A skill the reviewer loads for this lens, when the project has one. |

Rules for every lens:

- The reviewer is not the author of the change and starts with a fresh context. It gets the lens line, the `reads` documents and the pinned commit range, nothing of the author's reasoning.
- The verdict is `pass`, `fail` or `not run`. A reviewer that could not do what the lens asks records `not run` and says why. `not run` never counts as `pass`.
- A missing `reads` document means the lens cannot run.

**`evidence: visual`** means the reviewer looks at the product, not at its code:

- It starts the product itself, in its own worktree at the reviewed commit, through `bin/ytstack-runtime up` (`docs/ux/runtime-format.md`, "Run"), and operates it in a browser.
- It takes its own screenshots of the views, states and widths the change affects. Images supplied by the author do not count. Reading code or the DOM does not count as this lens.
- It stores them under `<evidence dir>/<lane>/<short sha>/<lens>/` with a `MANIFEST` file: one line per image with its SHA-256, the URL, the viewport and what it shows. The evidence directory is `evidence_dir:` in `PREFERENCES.md`, default `.ytstack/evidence`; whether a project commits it is the project's choice.
- No way to start the product, or no browser tool: the verdict is `not run`.

A `MANIFEST` line:

```
<sha256>  <file name> | url: <url> | viewport: <w>x<h> | shows: <text>
```

The hash and the name are separated by two spaces, the way `sha256sum` prints them. The name is a file in the same directory. Blank lines and lines that start with `#` do not count. `bin/ytstack-risk manifest <dir>` writes the hash and the name for every image in the directory (`png`, `jpg`, `jpeg`, `webp`, `gif`) and keeps what a line already said; the reviewer fills in `url`, `viewport` and `shows`. `route` reads the evidence directory a lens line names in the working tree; a relative path starts at the root of the repository.

The procedure is the skill `visual-review`.

## Records

A review leaves lines in the plan of what it reviewed (the slice plan for a slice lane, the task plan for a task) under `## Review`:

```markdown
## Review

- Round 1: a1b2c3d..e4f5a6b -- approved; blocking: 0; follow-ups: 1; risk: low; invariants: none; by: review-M004-S02
- Lens ui: e4f5a6b -- pass; by: ui-M004-S02; evidence: .ytstack/evidence/M004-S02/e4f5a6b/ui (5 images)
```

A lens line has this form, with `none` as evidence for a lens that asks for none:

```
- Lens <name>: <head> -- pass | fail | not run; by: <reviewer>; evidence: <dir> (<n> images) | none
```

The round line is the one `code-review` already writes, with three more fields. The reviewer's report states them with these labels:

```
Risk: <low | normal | high>
Severity: <what the worst plausible mistake in this change costs>
Reach: <what it can affect: these files, one area, several areas, stored data, users>
Invariants touched: <none | area: the invariant or decision, in its own words>
```

"Invariants touched" is answered by reading the change against "Invariants and security boundaries" and "Decisions that apply now" of every area the change touches. A change that shifts such a rule in code without editing the document is still named here, and its class is `high`.

The script reads a record line tolerantly. After ` -- ` comes the verdict, then `key: value` fields separated by `;`. A round line without `risk`, `invariants` and `by` (the form `code-review` wrote before) is a round that states none of them. The newest line counts: the last round line under `## Review`.

A round line is **valid for a head** when it names that head, or when nothing but process records changed between its head and that head. The plan that carries the line, a summary and `STATE.md` move the head without touching the change; a file of the change that came after the review does not. A lens line is valid for a head when it names that head, or when no path under its `applies` changed since.

## The route

`bin/ytstack-risk route --plan <plan file> --base <sha> --head <sha> [--author <worker>]` decides between `unattended` and `person`:

```
route: unattended | person
class: low | normal | high | person | unstated
ceiling: none | low | normal
floor: low | normal | person
areas: <comma list or none>
lenses: <comma list or none>
reason: <path or subject> -- <what failed>
```

There is one `reason:` line per condition that failed, and none when the route is `unattended`. The subject of a reason is a path of the change, `size`, `review`, `class` or `lens <name>`. `class` is `person` when the floor is, and `unstated` when the newest round line states no risk.

The exit code is 0 for `unattended` and 10 for `person`. 64 is a usage error, also a plan file that does not exist; 65 means git cannot answer. A caller treats everything but 0 as "not unattended".

`--author` is the worker that made the change. The script compares it with `by:` of each record. Without `--author` it cannot tell the reviewer from the author, says so in a reason and routes to a person. `by: self` is what a session writes that reviewed its own change: it counts as the author in a round line and in a lens line, whatever `--author` names.

The route is `unattended` only when all of this holds:

1. The floor is not `person`.
2. The newest round line of the plan approves, is valid for the head, states `risk` and `invariants: none`, and names a reviewer other than the author.
3. The class (the higher of floor and stated risk) is not above the ceiling of the touched areas. A change that touches no area has the ceiling `none`.
4. Every required lens has a newest line with `pass` that is valid for the head, from a reviewer other than the author, and its `reads` documents exist at the head. For `evidence: visual` the directory the line names holds a `MANIFEST` with at least one image; every listed image is there with the listed SHA-256, and its line states `url`, `viewport` and `shows`.

The route says nothing about the host. `finish-lane` reads the host's gates (checks, review threads, mergeability, the reviewed commit) as before, and merges on its own only when both hold and `merge_by` is `risk`.

| `merge_by` | Who merges |
|---|---|
| `risk` (default) | The coordinator when the route is `unattended` and the host's gates hold; otherwise a person. The person gets one line in the report either way: what merged unattended, at which class and why. |
| `human` | Always a person. |
| `coordinator` | Always the coordinator, when the host's gates hold. The route is printed and not applied. |

## Checked mechanically

`bin/ytstack-risk check` reads the `REVIEW.md` of the working tree. It fails on a section outside the four, a lens whose name is not a lowercase slug, a lens without `applies`, `reads` or `evidence`, a lens field outside the five, an `evidence` outside the two values, a `reads` document that does not exist, a lens name used twice, and a `size` line that is not two numbers. It prints one line per problem (`REVIEW.md: <what is wrong>`) and exits 1; a clean policy and a project without `REVIEW.md` exit 0.

`bin/ytstack-spec lint` runs that check when `REVIEW.md` exists and counts each line as a failure. It also fails on an `auto_merge` outside the three values and on a `REVIEW.md` that `SPEC.md` does not link.

What stays a judgment: the class the reviewer states, and the verdict of a lens. The script makes sure the judgment was made by somebody else, on this commit, with the evidence the lens asks for.

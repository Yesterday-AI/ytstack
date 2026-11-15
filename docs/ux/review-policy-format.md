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

- a change to `.ytstack/spec/REVIEW.md`, `.ytstack/DECISIONS.md`, `.ytstack/STANDING.md`, a file under `.ytstack/standing/`, `.ytstack/PREFERENCES.md`, or to an instruction file of the repository (`AGENTS.md`, `CLAUDE.md`, at any depth)
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

## Own reviewers

- code | marker: (`code`) | lessons: .github/reviewers/code.md | bots: cursor, greptile-apps
- tests | marker: (`tests`) | lessons: .github/reviewers/tests.md

## Checks

- component-levels | file: scripts/check-levels.mjs | guards: an atom imports no molecule; the import directions of .ytstack/spec/web.md
- secret-scan | file: .github/workflows/secret-scan.yml | guards: no token reaches a pushed commit
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

## Own reviewers: who learns from a review bot

A project that runs review agents of its own (a role per review goal, each with a file it reads at every review) declares them here, so that a finding a review bot made and the roles missed can become a lesson for the role that owns it. Without the section nothing changes.

| Field | Required | Holds |
|---|---|---|
| name | yes | The role, a lowercase slug, unique. |
| `marker` | yes | The text every finding of the role carries, matched literally and unique among the roles: in the pilot project `` (`code`) `` in `🟠 **High** (`code`). <finding>`. A marker that also appears in text the role does not write (a bare `` `code` `` in a "Checked and fine" line) makes that text count as a finding; choose one that does not. It cannot hold a `|`. |
| `lessons` | yes | The file a lesson for the role goes to: the role file or the rule source it reads. It exists in the repository. |
| `bots` | no | Logins, comma-separated, that count as review bots although GitHub does not mark them as bots. |

A lesson is a change to the `lessons` file, and that is a rule change: it is proposed to a person and never written by an agent on its own.

`bin/ytstack-risk reviewers` prints the section, one tab separated line per role: name, marker, lessons, bots.

## Checks: what a reviewer can rely on

A project that runs machine checks of its own (a guard script, a lint rule, a CI step, a test that pins a contract) lists them here, so that a reviewer knows what it does not have to read for and a new rule is not only told in a receipt. Without the section nothing changes.

| Field | Required | Holds |
|---|---|---|
| name | yes | A lowercase slug, unique. |
| `file` | yes | The file that is the check, or that runs it. It exists in the repository. |
| `guards` | yes | What holds when the check passes, in one line; the rule itself stays in the area file or the source it names. |

A pull request that adds a guard, or changes what one guards, adds or updates its line here in the same commits. `bin/ytstack-finish-lane route` prints a `checks:` line when the project keeps the section and a change edits CI (`.github/workflows/`, `.gitlab-ci.yml`) without touching `REVIEW.md`; a change to CI goes to a person anyway, and that person reads the line. `code-review` treats a guard added without its line as a finding.

## Escapes

`bin/ytstack-review-escapes [-C <dir>] --pr <n> [--repo <owner/name>]` reads one pull request through `gh` and prints one tab separated line per review-bot thread under a header:

```
bot	resolution	match	role	path	lines	url	title
chatgpt-codex-connector	fixed	escaped	-	src/app.ts	10-12	https://github.com/acme/shop/pull/101#discussion_r1	P1 Guard the empty cart
greptile-apps	fixed	caught	code	src/app.ts	39	https://github.com/acme/shop/pull/101#discussion_r3	logic: `total` can be undefined
```

**A bot thread** is a review thread whose first comment is by an author GitHub marks as a bot, by a login that ends in `[bot]`, or by a login a `bots:` list names, and whose text carries no role marker. The marker wins over the author type: an own role that posts through a GitHub App is still an own role.

**Resolution:**

| Value | When |
|---|---|
| `fixed` | A commit of the pull request after the thread's commit changed the thread's file on a line no more than 3 lines (`MARGIN`) outside the thread's range. A thread on a whole file is fixed by any later change of the file. |
| `rejected` | The thread is resolved and no such commit exists: the finding was answered without a code change. |
| `open` | The thread is not resolved. |

**Match:** `caught` with the role, when an own finding on the same file overlaps the thread's range widened by `MARGIN`, at the same or an earlier head than the bot's; `escaped` otherwise. An own finding carries a role's marker, whoever posted it, and is either

- a review thread: its file and line range, its commit, or
- a line of a review body: it has no anchor of its own, so it counts only with a cited `` `<path>:<line>` `` or `` `<path>:<start>-<end>` `` on the thread's file (the path in full or a tail of it after a slash), at the commit the review was submitted on. A body line without a cited line matches nothing.

"Earlier head" compares the positions of the two commits in the pull request; when one of them is no longer part of it (a force push), the creation times decide. Lines are those of the commit a thread was written on; MARGIN absorbs the small shifts of the commits in between. Same file and overlapping lines is where the script stops: whether the two findings say the same thing is judged by whoever reads the line.

Only a `fixed` and `escaped` line is a lesson. A `rejected` bot finding was a false positive and is not recorded.

| Exit | Means |
|---|---|
| 0 | No line is `fixed` and `escaped`. |
| 10 | At least one is. |
| 1 | `REVIEW.md` declares no own reviewers; one line of hint, nothing read from the host. |
| 2 | Usage, a broken "Own reviewers" section, or a read that failed. |

Cost: one GraphQL call per 100 threads, reviews or commits (one for most pull requests), one REST call per commit after the oldest resolved bot thread, and one `gh repo view` when neither `--repo` nor an `origin` on github.com names the repository. An escape is recorded as a finding of `kind: review` (`docs/ux/signal-format.md`).

### The lessons loop

From a merge to a changed role file, end to end:

1. **A pull request merges**, whoever merges it. Three ways lead to the check: with the PR watch on, the worker that sees the merge queues one notice to the owning session ("run ytstack:review-lessons for #N", `docs/pr-watch.md`) when it saw at least one bot finding on the pull request; `bin/ytstack-upkeep` lists, under `review checks`, every merged pull request without a line in `.ytstack/signals/review-checks` (one `gh pr list` per run, one call per 100 merged pull requests: the window opens 14 days before the earliest time in `review-checks`, or 14 days ago without one, never further back than 90 days, and stays there, so a check of a newer pull request never hides an older unchecked one; cut at 500 with a notice); `finish-lane` invokes the skill itself after a merge it made. The skill also runs on demand.
2. **`ytstack:review-lessons` reads the pull request** with `bin/ytstack-review-escapes`. Only `fixed` and `escaped` lines go on; `rejected` and `open` ones are counted in its report and recorded nowhere.
3. **It names the owning role** of each escape from the role files (the `lessons` files of this section): their stated scope, checklist and sources. An escape no role owns, for example on a planning file no role reviews, is recorded nowhere and named in the report: that is a gap in the roles, not a lesson for the nearest one.
4. **It records the escape** as `review:<role>:<class>` through `bin/ytstack-signals new --kind review`, with the merge time as the read time, and then the check line with `bin/ytstack-signals review-checked <owner/name>#<n> <merge sha> --tally <role>=<caught>/<escaped>,...`: every `fixed` bot thread counted once, a caught one for the role that caught it, an escaped one for the owning role (`-` without one). A class seen before keeps its key; its count rises.
5. **At the threshold it proposes.** The threshold is the second sighting of a class (count 2 on an `open` finding), the first one at critical or high severity as the bot states it (a Codex `P1` is high, `P0` critical, `P2` medium), or a regression of a class whose lesson was marked fixed. The proposal is a question file under `.ytstack/questions/` (`bin/ytstack-questions new`): the exact checklist line, the role file and the section it goes to, and the escaped threads as evidence. Measured on 30 merged pull requests of the pilot project: 8 bot threads, all `fixed`, 2 caught and 6 escaped, each escape a class of its own; most classes are one-offs, so a single medium escape proposes nothing.
6. **A person answers.** An accepted line goes through the normal task loop, linked with `bin/ytstack-signals set <F> --state planned --ref <task>`, and the task that adds it sets `fixed`. A rejected one is dismissed by the person (`set <F> --state dismissed`, the reason on stdin); further sightings of the class are counted and never proposed again. No agent writes the role file on its own.

`retro` reports per role, for the milestone window, caught and escaped bot findings and the escape rate (escaped / (caught + escaped)) from the tallies, and the `kind: review` findings with their state, read from the ledger and not from the host. A check line without a tally (written before tallies existed) is reported as "not recorded".

## Records

A review leaves lines in the plan of what it reviewed (the slice plan for a slice lane, the task plan for a task) under `## Review`, and on a pull request the same lines in the body of its review on the host ("Records on the host" below):

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

### Records on the host

A plan is a file somebody has to write and commit. Where agents may not write in the main checkout, the line has to be committed on the pull request's branch, and that moves the head: a host rule that counts only reviews on the current head no longer sees the review, and the plan in the main checkout still has no line. So the same lines also go into the body of the review on the pull request (`finish-lane`, Step 7 and 8; `code-review` when the branch has an open pull request), each at the start of a line:

```
Verdict: approved
Reviewed commit: e4f5a6b...
Round: 1

<findings>

- Round 1: a1b2c3d..e4f5a6b -- approved; blocking: 0; follow-ups: 1; risk: low; invariants: none; by: review-M004-S02
```

The host ties a review to the commit it was submitted on (`commit_id` in the GitHub reviews API) and names its author. `route --pr <n>` reads the reviews of the pull request once and takes the record lines from their bodies:

- A review counts when it is submitted (not pending), not dismissed, and by somebody with write access (`author_association` `OWNER`, `MEMBER` or `COLLABORATOR`). Anybody can comment on a public pull request; their lines do not count.
- `author_association` is wider than write access: `MEMBER` is any member of the organization, `COLLABORATOR` includes read and triage. For the review whose line is used, `route` reads the reviewer's permission once more (`gh api repos/<repo>/collaborators/<login>/permission`) and needs `admin`, `maintain` or `write`; any other permission, and a read that fails, routes to a person.
- The newest line counts, by the time its review was submitted. A line on the host wins over the plan; the plan's line counts only when no review carries one of that kind (the round, or the lens).
- The line must name the commit the host tied its review to. A line that names another commit leaves open what was reviewed: `person`. Validity for the head is computed from the host's commit, with the rule above.
- A review in the state `CHANGES_REQUESTED` does not approve, whatever its line says: `person`.
- As on the host, a reviewer's newest review is the state that counts: when it requests changes, the change goes to a person, also when that review carries no record line and another reviewer's line approves. A later approving review of the same reviewer lifts the request; a comment-only review does not, as on GitHub.
- A read that fails routes to a person: a newer review on the host may say what the plan does not.

The round number still comes from the lane's `Round` cell (`LANES.md`) or from the plan; the host carries the record of each round, not the count.

## The route

`bin/ytstack-risk route [--plan <plan file>] [--pr <n> [--repo <owner/name>]] --base <sha> --head <sha> [--author <worker>]` decides between `unattended` and `person`. It needs `--plan`, `--pr` or both; with `--pr` the records come from the host first ("Records on the host"), and `--repo` names the repository when `gh` cannot tell it from the checkout:

```
route: unattended | person
class: low | normal | high | person | unstated
ceiling: none | low | normal
floor: low | normal | person
areas: <comma list or none>
lenses: <comma list or none>
round: host review <id> by <login> on <sha> | plan | none     (only with --pr)
reason: <path or subject> -- <what failed>
```

There is one `reason:` line per condition that failed, and none when the route is `unattended`. The subject of a reason is a path of the change, `size`, `review`, `class` or `lens <name>`. `class` is `person` when the floor is, and `unstated` when the newest round line states no risk. `round:` says where the round line came from.

The exit code is 0 for `unattended` and 10 for `person`, also when the host cannot be read. 64 is a usage error, also a plan file that does not exist; 65 means git cannot answer. A caller treats everything but 0 as "not unattended".

`--author` is the worker that made the change. The script compares it with `by:` of each record. Without `--author` it cannot tell the reviewer from the author, says so in a reason and routes to a person. `by: self` is what a session writes that reviewed its own change: it counts as the author in a round line and in a lens line, whatever `--author` names.

The route is `unattended` only when all of this holds:

1. The floor is not `person`.
2. The newest round line (from the host's reviews with `--pr`, else from the plan) approves, is valid for the head, states `risk` and `invariants: none`, and names a reviewer other than the author.
3. The class (the higher of floor and stated risk) is not above the ceiling of the touched areas. A change that touches no area has the ceiling `none`.
4. Every required lens has a newest line with `pass` that is valid for the head, from a reviewer other than the author, and its `reads` documents exist at the head. For `evidence: visual` the directory the line names holds a `MANIFEST` with at least one image; every listed image is there with the listed SHA-256, and its line states `url`, `viewport` and `shows`.

The route reads the host only for the review records, and only with `--pr`; it says nothing about the host's gates. `finish-lane` reads the host's gates (checks, review threads, mergeability, the reviewed commit) as before, and merges on its own only when both hold and `merge_by` is `risk`. Its own `route` (`bin/ytstack-finish-lane route`) adds the spec delta: a change to an area's paths without its area file or a source in the diff, without a plan that states the impact and without `Spec: none -- <reason>` in the worker's report is `person` (`docs/ux/spec-format.md`, "Before a merge").

| `merge_by` | Who merges |
|---|---|
| `risk` (default) | The coordinator when the route is `unattended` and the host's gates hold; otherwise a person. The person gets one line in the report either way: what merged unattended, at which class and why. |
| `human` | Always a person. |
| `coordinator` | Always the coordinator, when the host's gates hold. The route is printed and not applied. |

## Checked mechanically

`bin/ytstack-risk check` reads the `REVIEW.md` of the working tree. It fails on a section outside the six, a lens whose name is not a lowercase slug, a lens without `applies`, `reads` or `evidence`, a lens field outside the five, an `evidence` outside the two values, a `reads` document that does not exist, a lens name used twice, a `size` line that is not two numbers, an own reviewer whose name is not a lowercase slug or is used twice, one without `marker` or `lessons`, a marker another role has, a `lessons` file that does not exist, an own reviewer field outside the three, and a check whose name is not a lowercase slug or is used twice, one without `file` or `guards`, a `file` that does not exist and a check field outside the two. It prints one line per problem (`REVIEW.md: <what is wrong>`) and exits 1; a clean policy and a project without `REVIEW.md` exit 0.

`bin/ytstack-spec lint` runs that check when `REVIEW.md` exists and counts each line as a failure. It also fails on an `auto_merge` outside the three values and on a `REVIEW.md` that `SPEC.md` does not link.

What stays a judgment: the class the reviewer states, and the verdict of a lens. The script makes sure the judgment was made by somebody else, on this commit, with the evidence the lens asks for.

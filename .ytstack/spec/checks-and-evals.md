---
area: checks-and-evals
status: implemented
paths:
  - bin/ytstack-check
  - bin/ytstack-spec
  - bin/ytstack-brief
  - bin/ytstack-frontier
  - bin/ytstack-questions
  - bin/ytstack-finish-lane
  - bin/ytstack-handover
  - bin/ytstack-watch
  - bin/ytstack-risk
  - bin/ytstack-review-escapes
  - bin/ytstack-runtime
  - bin/ytstack-signals
  - bin/ytstack-upkeep
  - tests/**
  - evals/**
  - docs/recipes/**
  - .github/workflows/**
sources:
  - evals/README.md
  - docs/ux/spec-format.md
  - docs/ux/coordinator-format.md
  - docs/ux/review-policy-format.md
  - docs/ux/runtime-format.md
  - docs/ux/signal-format.md
verified_at: d6001bb
---

# checks-and-evals

## Purpose

Everything that tells a contributor whether a change is acceptable: the static contract checker, the shell and Python test suites, the plugin manifest validation, the behavioural evals, and the GitHub workflows that run part of them. How an eval run is started and read is described in `evals/README.md`. The contracts being checked (`docs/ux/*.md`) belong to the skills and agents they govern.

## Behavior

**`bin/ytstack-check`: static contracts**

- A Python script on the standard library. It finds the plugin root by walking up to `.claude-plugin/plugin.json`; an optional path argument sets where it starts.
- It reads `skills/*/SKILL.md`, `agents/*.md`, the scripts in `hooks/`, both manifests in `.claude-plugin/` and this repository's own `.ytstack/spec/`. One function per contract: `check_skill`, `check_agent`, `check_cross_refs`, `check_vendor_sibling_refs`, `check_resolver_contract`, `check_inline_leaks`, `check_gstack_adapted`, `check_spec`, `check_keeping_block`. Those functions are the complete rule list; the two groups below summarize them.
- `check_spec` runs `bin/ytstack-spec lint` and `drift` on the plugin root and is skipped when the tree has no `.ytstack/spec/`. A format error is a failure; an area whose paths changed after its description is a warning to look. `check_keeping_block` fails when the "Keeping this true" block in `skills/init-project/SKILL.md` or `skills/adopt-brownfield/SKILL.md` differs from the one in `docs/ux/spec-format.md`.
- Failures (`[fail]`): skill frontmatter missing, `name` different from the directory, no description or one over the length limit; a procedure skill without `## Checklist` or `## Terminal State`; an agent file that breaks `docs/ux/agent-structure.md` (required fields, examples, existing `ytstack:` skills, hard line limit); a role named in `skills/spawn-milestone-team/SKILL.md` without `agents/<role>.md`; a wrapper naming a vendored `SKILL.md` that does not exist; a banned shell pattern (`_BANNED`) in a skill or hook; a preamble or hook that does not source `hooks/lib/git-ctx.sh`; inlined vendor text without a covering `## Namespace note`; an adapted gstack skill without `metadata.upstream`, with a gstack runtime reference, a symlink or an em-dash.
- Warnings (`[warn]`): a description that reads like a procedure summary; ytstack keys outside `metadata:`; a missing recommended section; a Checklist without "MUST"; an em-dash character in a skill body outside table rows; an inlined upstream text that points at a skill ytstack does not wrap; a version mismatch between `plugin.json` and `marketplace.json`; soft agent limits.
- Three skill classes skip the section rules: wrappers that inline a vendored `SKILL.md`, `kind: directive` and `kind: reference`.
- Exit codes: 0 without findings, 1 with at least one failure, 2 with warnings and no failure. `--strict` turns every warning into a failure. `--quiet` prints only when something fails. `--tests` also runs `tests/run-all.sh` and reports a failing run as one failure.
- Reading the output: a `FAIL: <n> error(s)` block and a `WARNINGS: <n>` block, one finding per line with its path. The last line is `OK: all skills + agents pass ytstack-check` or `OK (with <n> warning[s])`. Only a `[fail]` line makes the change unacceptable.

**`bin/ytstack-spec`: the technical spec of any project**

- A bash script on git and awk. `lint` checks the format of `.ytstack/spec/`, `drift` lists areas whose `paths` changed after the description or one of its `sources` was last touched, `impact` checks a task plan's "Spec impact" against what the task changed, `areas` names the area of a path. Rules and exit codes: `docs/ux/spec-format.md` and the comment at the top of the script.
- `drift` is advisory and exits 0 unless `--exit-code` is given. It never reads `verified_at`; an area file that is new or edited in the working tree is skipped.
- `lint` fails on an `auto_merge` outside `none`, `low` and `normal`, on a `REVIEW.md` that `SPEC.md` does not link, and on every line `bin/ytstack-risk check` prints. `REVIEW.md` is not an area file: `drift`, `impact` and `areas` do not read it.

**`bin/ytstack-risk`: whether a change may merge without a person** (`docs/ux/review-policy-format.md`)

- `floor --base <sha> --head <sha>` prints the lowest class of the tree difference (`low`, `normal` or `person`), one `reason:` per path and rule, the touched areas, their ceiling and the required lenses. It reads the policy at the base commit, never from the working tree; git matches the globs.
- `route --plan <file> --base <sha> --head <sha> --author <worker>` exits 0 with `route: unattended` only when the floor is not `person`, the newest round line approves, states `risk` and `invariants: none`, names a reviewer other than the author and is valid for the head, the class is within the ceiling, and every required lens has a passing line with its evidence (for `evidence: visual` a `MANIFEST` whose hashes match). Every other case exits 10 with `route: person` and one reason per failed condition. `by: self` and a missing `--author` always route to a person.
- `check` validates `REVIEW.md`, its "Own reviewers" too (slug names, a unique `marker`, a `lessons` file that exists); `reviewers` prints the own reviewers tab separated; `manifest <dir>` writes hash and name of every image into the `MANIFEST` of an evidence directory.

**`bin/ytstack-review-escapes`: review-bot findings the own reviewers missed** (`docs/ux/review-policy-format.md`, "Escapes")

- `--pr <n>` reads a pull request's review threads, reviews and commits through `gh` (GraphQL, paginated) and the changes of the commits after a resolved bot thread (one REST call per commit), and prints one TSV line per bot thread: resolution `fixed`, `rejected` or `open`, and `caught` (with the role) or `escaped`. Exit 10 with a `fixed` and `escaped` line, 0 without, 1 when `REVIEW.md` declares no own reviewers (before any read), 2 on usage or read errors. Read-only. Its suite answers from recorded fixtures under `tests/fixtures/review-escapes/`.

**`bin/ytstack-runtime`: `RUNTIME.md` and the product per worktree** (`docs/ux/runtime-format.md`)

- Every other script and skill reads the "Run", "Release" and "Signals" sections through it. `get <section> <key>` (exit 1 when missing), `signals` (tab separated), `check` (each defect of the three sections, a token-looking string; a file without them passes).
- `up [--timeout <s>]` starts the product in a process group of its own on a free port of the range, at a start position derived from the worktree, waits for `ready` and prints `URL:`, `PORT:`, `PID:`, `LOG:` and `COMMIT:`; a start that exits or a `ready` that does not pass ends with exit 1, the end of the log and nothing running. `down` ends that group and only a process it started; `status`. A zombie counts as ended (the process state is read, not only `kill -0`), and nothing inside a code fence is read as a heading or a key. The state of an instance lives outside the checkout, per worktree.

**`bin/ytstack-signals`: production findings and incident records** (`docs/ux/signal-format.md`)

- `new` records a finding once: a second sighting of the key raises its count, a sighting of a `fixed` one writes a regression with `reopens:`, a `dismissed` one stays dismissed; writes under a noclobber lock. `list`, `set`, `incident new`, `check` (findings and incident records; every mitigation names a handover script that passes `bin/ytstack-handover check` unless declined).
- `--kind review` records an escaped review-bot finding (key `review:<role>:<class-slug>`) without a "Signals" source; `review-checked` records and asks which merged pull request had its escape check, in `signals/review-checks`; `--tally` adds caught/escaped per role as a fourth field, which `check` validates.

**`bin/ytstack-upkeep`**: one read-only run over `.ytstack/` with eight counted sections (spec, state, gates, questions, lanes, runtime, review policy, review checks); exit 0 with `nothing needs a look`, 10 otherwise. `review checks` lists, only when `REVIEW.md` declares own reviewers, the merged pull requests without a line in `signals/review-checks` (an anchored window from 14 days before the earliest time in that file, or 14 days ago without one, at most 90 days back; cut at 500 with a notice), from one `gh pr list --search merged:>=<day>` (one call per 100) (plus one `gh repo view` when `origin` is not a GitHub URL); a failed read is an item, a missing `gh` or `jq` a note. `--question` writes one question file and none while an earlier `Upkeep found ...` is open or asked. `docs/recipes/recurring-upkeep.md` puts it on a schedule.

**`bin/ytstack-brief`: the brief of a dispatched worker and its report**

- A bash script on awk. `render --task <ref>` or `--slice <ref>` prints a brief built from the plan files and `skills/spawn-milestone-team/brief-template.md`, and includes the body of `skills/minimal-code/SKILL.md` as the work contract, read at render time. It prints no brief when the plan, its `## Files` section, the template or the contract is missing (exit 1).
- `render --kind implement|review|prepare` adds what the worker may do; a review brief pins the commit range it reviews (`--head`, optionally `--base`) and has no Git section.
- `check` validates a worker's report from a file or stdin: the labels of the template's "Report" section, each with a value, an exit code in every `Checks run:` line, one of the three `Status:` values and its consistency with `Blockers:`. It prints one line per problem and exits 1, or `report ok`.

**The coordinator scripts** (formats and rules: `docs/ux/coordinator-format.md`; each has a suite of the same name under `tests/`)

- `bin/ytstack-frontier`: `list` prints lane, state and detail per slice (done, claimed, blocked, ready); `claim` refuses a held lane and names the holder; `claim`, `set` and `release` change one row of `LANES.md` under a lock; `check` validates the file. The lock is the file `LANES.md.lock`, created by the shell under noclobber and not by `mkdir`, which is no lock on Ubuntu 26.04 (see `.ytstack/KNOWLEDGE.md`).
- `bin/ytstack-questions`: `new`, `list`, `next`, `ask` (once), `answer` (refused without text under "Answer"), `check`.
- `bin/ytstack-finish-lane`: one step per call (`leftovers`, `commit`, `push`, `open-pr`, `wait-head`, `body-check`, `gates`, `merge`, `route`); every gate is read from GitHub through `gh` at the moment of the call, and `merge` passes the reviewed commit to the host so that a moved head cannot be merged. `route --lane <ref>` reads the lane's worker (the author) and plan from `LANES.md` and runs `bin/ytstack-risk route`. `leftovers` and `commit` leave the evidence directory out. Its suite uses a stand-in for `gh` and a local bare remote.
- `bin/ytstack-handover`: `new` copies `skills/handover-step/template.sh`; `check` is the static verification of a staged script (syntax, unchanged helper block, no raw command, a confirmation of its own before every mutation, no pipe into a shell). The helpers hold the same rule when the script runs: one yes carries one change.
- `bin/ytstack-watch`: polls pull requests through `gh` and prints a line only when head, checks, review or mergeability changed; `--once` prints the snapshot with its read time. `release --commit <sha>` runs `deployed` of "Release" until it names the commit (or `--timeout`, default 900 s), then `healthy` for the settle time, and ends with five receipt lines (`Target:`, `Commit:`, `Arrived:`, `Health:`, `Result:`) with read times. Exit 0 released or no health command, 2 not arrived, 3 unhealthy, 4 no "Release" section, 1 `RUNTIME.md` fails its check. It runs only those two commands and changes nothing.

**Shell suites: `tests/*.test.sh`**

- Plain bash, no framework. A suite prints one line per assertion and ends with its pass and fail count; fixtures live in `mktemp` directories. The comment at the top of each file states the contract it pins.
- `tests/run-all.sh` runs every suite from a neutral temporary directory and prints `PASS` or `FAIL` per suite with that suite's last line. It stops at the first failing suite, prints up to ten of its `FAIL` lines and exits 1. The last line is `ALL SUITES PASSED` or `SUITE FAILURE`. `--linux` runs the same inside an `alpine/git` container with the repository mounted read-only; without a working Docker daemon it prints a skip line and exits 0.
- `tests/ytstack-check.test.sh` tests the checker on a copy of the plugin tree. `tests/ytstack-spec.test.sh` tests `bin/ytstack-spec` on fixture repositories, one case per rule. `tests/ytstack-brief.test.sh` does the same for `bin/ytstack-brief` and compares the rendered contract with the real `skills/minimal-code/SKILL.md`. `tests/evidence-rule.test.sh` pins the evidence reuse rule: the verifier, the dispatcher and the skills area reuse a PASS only for the same commit, and its git fixture shows why (an unchanged planned file, a changed imported helper, a failing check).
- `tests/pr-watch.test.sh` runs the PR watch engine's `unittest` suite (`tests/pr_watch/`, standard library, `gh` and the Codex daemon mocked) and then shell cases for `hooks/pr-watch` (off, on, malformed input), `bin/ytstack-pr-watch` (enable/disable, install-worker and migrate plans, migrate copy, the worker launcher's engine choice) under a temporary HOME. The resolver rule of `bin/ytstack-check` exempts `hooks/pr-watch` by name (`_HOOKS_WITHOUT_RESOLVER`).

**Python host tests: `tests/*_test.py`**

- `unittest` on the standard library. `codex_plugin_test.py` covers the Codex manifests, helper, lifecycle registration, wrapper preambles and vendor imports, and that there is one skill tree without generated copies. `tests/run-all.sh` does not run it.
- `kimi_plugin_test.py` checks native manifest parity and the shared skill tree, including the six self-contained gstack adaptations. `kimi_lifecycle_test.py` covers plain output, the helper's installed and target roots, pending prepare/consume once, parallel consumption, compaction handoff and journal behavior.
- `kimi_live_test.py` installs the plugin into an isolated `KIMI_CODE_HOME` through real Kimi processes. It checks every qualified skill, the six adapted-skill paths, project override separation, pending context on real prompts, compaction, resume, interactive close and the placeholder-sensitive preambles. It uses a local fake model and no real credential, skips without a binary and accepts `KIMI_BIN`. It is not a CI job.

**`claude plugin validate .`**

- Validates the manifests in `.claude-plugin/`. A pass prints `✔ Validation passed` and exits 0. Plugin-directory warnings (one about a missing icon) are printed and do not change the result.

**Behavioural evals: `evals/`**

- One directory per case: `case.yaml` (name, tags, the scaffold script), `prompt.md` (run settings in the frontmatter, then a user-phrased prompt that does not name the skill), `fixture.sh` (builds the repository and `.ytstack/` state the skill expects) and `graders/*.md`.
- Every case has a `skill-fired` grader of type `tool_used` and one or more outcome graders of type `file_exists` or `regex`. No grader calls a model.
- A run is started with `claude plugin eval`; the command and its flags are in `evals/README.md` ("Run").
- Each case is a real model session on the account that starts the run. `--max-cost-usd` caps the spend. What a run cost: `.ytstack/KNOWLEDGE.md` ("Eval runs"), which is also where a run is recorded.
- Results go to `evals/results/<timestamp>/`, which `.gitignore` excludes.

**GitHub workflows**

| File | Job | Runner | Runs |
|---|---|---|---|
| `.github/workflows/ci.yml` | `suites` | ubuntu-latest and macos-latest | `bash tests/run-all.sh`, then `python3 bin/ytstack-check .` |
| `.github/workflows/plugin-check.yml` | `check` | ubuntu-latest | the Python Codex tests, Kimi packaging and lifecycle tests, `bash tests/post-tool-use-bash.test.sh`, `bin/ytstack-check` |
| `.github/workflows/secret-scan.yml` | `secret-scan` | ubuntu-latest | gitleaks over the commits of the pull request or push; the whole tree on a branch-creation push |

- All three run on pull requests and on pushes to `main`. Both checker steps accept exit code 2 and fail on any other non-zero code. The `ci.yml` matrix does not cancel the other runner when one fails.

## Invariants and security boundaries

- A suite writes only into `mktemp` directories and never into the checkout it tests. `tests/run-all.sh` enforces the neutral working directory; `--linux` enforces it with a read-only mount.
- No workflow calls `claude`. CI spends no model budget.
- The eval flag `--scaffold` executes each case's `fixture.sh` as the calling user. It is off by default and meant for cases written in this repository.
- Whether a red workflow blocks a merge: Unknown -- branch protection is a GitHub setting and not readable from the repository.

## Error behavior

- No `.claude-plugin/plugin.json` above the start path: the checker prints an error on stderr and exits 1.
- A crash inside the manifest version comparison becomes a warning ("version agreement check skipped"), not a traceback.
- After the first failing suite `tests/run-all.sh` runs no further suite, so one run shows one broken suite.

## Runtime and deployment assumptions

- The suites run on bash 3.2 (macOS) and bash 5 (Linux). `ci.yml` prints the versions of bash, git, jq and python3 on each runner. `--linux` needs Docker and network access for the image and its packages.
- `claude plugin validate` and `claude plugin eval` need the Claude Code CLI; the minimum version for evals is in `evals/README.md`. An eval run loads nothing that is installed on the machine. A fixture creates everything a skill reads.

## Known limits

- The checker does not read `AskUserQuestion` bodies, sentinel-file names or `allowed-tools`. Those parts of `docs/ux/` are enforced by review.
- An em-dash is a warning, and only `skills/*/SKILL.md` bodies are scanned. Both workflows accept warnings, so an em-dash does not turn CI red. Docs, agents and hooks are not scanned.
- `bin/ytstack-finish-lane` and `bin/ytstack-watch` have run only against a stand-in for `gh`. Unknown -- their behaviour against GitHub (the JSON shapes, the built-in `--jq`, a merge queue).
- No workflow runs `claude plugin validate .`, `claude plugin eval`, `tests/run-all.sh --linux`, the checker with `--strict`, or `bin/ytstack-gstack-diff`.
- The Python Codex tests run on ubuntu only.
- `.claude/skills/check-consistency/SKILL.md` is a manual audit of README against docs and plugin content. No workflow runs it and the checker does not scan `.claude/skills/`.

## Where implemented

- `bin/ytstack-check` -- the checker; its docstring names the flags and exit codes.
- `bin/ytstack-spec` -- the spec tool; `tests/ytstack-spec.test.sh` pins it.
- `bin/ytstack-brief` -- brief renderer and report check; `tests/ytstack-brief.test.sh` pins it.
- `bin/ytstack-frontier`, `bin/ytstack-questions`, `bin/ytstack-finish-lane`, `bin/ytstack-handover`, `bin/ytstack-watch` -- the coordinator scripts, each with `tests/<name>.test.sh`.
- `bin/ytstack-risk`, `bin/ytstack-review-escapes`, `bin/ytstack-runtime`, `bin/ytstack-signals`, `bin/ytstack-upkeep`, each with `tests/<name>.test.sh` (the live cases of `ytstack-runtime` need `python3` and are skipped without it).
- `tests/run-all.sh` -- the suite runner. `tests/*.test.sh` -- the suites. `tests/codex_plugin_test.py`, `kimi_plugin_test.py`, `kimi_lifecycle_test.py`, `kimi_live_test.py` -- the Python host tests.
- `evals/<case>/` -- the eval cases. `evals/README.md` -- how to run them.
- `.github/workflows/ci.yml`, `plugin-check.yml`, `secret-scan.yml`.
- `docs/ux/skill-structure.md`, `docs/ux/agent-structure.md`, `docs/ux/writing-style.md` -- the contracts the checker enforces in part.
- `CONTRIBUTING.md` ("Release checklist") -- the checks expected before a release.

## How to verify

Run from the repository root.

- `bin/ytstack-check` -- pass: exit code 0 or 2 and no `[fail]` line. At `verified_at` it exits 2 with `OK (with 9 warnings)`; every warning is a missing recommended section or a Checklist without "MUST".
- `bash tests/run-all.sh` -- pass: exit 0, one `PASS` line per file in `tests/*.test.sh`, last line `ALL SUITES PASSED`.
- `python3 -m unittest discover -s tests -p 'codex*_test.py'` -- pass: last line `OK`.
- `python3 -m unittest discover -s tests -p 'kimi_plugin_test.py' -v` and the same pattern for `kimi_lifecycle_test.py` -- pass: two and nine tests, each `OK`.
- `python3 -m unittest discover -s tests -p 'kimi_live_test.py' -v` -- seven native tests on a machine with Kimi; local 2.5.3 and official Linux 2.6.2 each passed without skips at `verified_at`.
- `claude plugin validate .` -- pass: `✔ Validation passed`, exit 0.

Not covered by these checks: `claude plugin eval` (costs money). `bash tests/run-all.sh --linux` (Docker) also passed all 26 suites from an export of `verified_at`.

## Decisions that apply now

- DECISIONS.md -- "2026-11-14: Kimi uses native plugin bootstrap and pending lifecycle context (M020)". Source of the offline Kimi CI checks and the separately run native suite.
- DECISIONS.md -- "2026-11-13: Whether a person looks at a change is decided per change: a floor from the diff, the class an independent reviewer states, a ceiling per area, lenses per kind of change (M025)". Source of `bin/ytstack-risk` and the lint rules for `auto_merge` and `REVIEW.md`.
- DECISIONS.md -- "2026-11-13: `RUNTIME.md` has three sections with a fixed line format, read only through `bin/ytstack-runtime` (M025-S01)"
- DECISIONS.md -- "2026-11-13: After a merge the release is watched, not driven; upkeep is a script and a recipe, not a skill (M026)". Source of `release` and `bin/ytstack-upkeep`.
- DECISIONS.md -- "2026-11-13: Production findings and incidents are skill work on read-only access; a mitigation is a handover script a person runs (M027)". Source of `bin/ytstack-signals`.
- DECISIONS.md -- "2026-11-13: The technical spec is a set of artifacts of its own under `.ytstack/spec/` (M022, issue #36)". Source of `bin/ytstack-spec` and the two spec checks.
- DECISIONS.md -- "2026-11-13: Verification, review and orchestration work are bounded like code (M023, issue #35)". Source of `bin/ytstack-brief`.
- DECISIONS.md -- "2026-11-13: Coordinator mode keeps lanes, questions and standing instructions in files and reads host facts fresh (M024, issue #34)". Source of the five coordinator scripts; the pipeline and the watcher support GitHub through `gh` only.
- DECISIONS.md -- "2026-04-23: UX contracts enforced by CI, not convention"
- DECISIONS.md -- "2026-05-31: Add `kind: reference` skill class (exempt from procedure-section contract)"
- DECISIONS.md -- "2026-11-07: Hooks never write relative to CLAUDE_PROJECT_DIR; volatile state lives out-of-tree, per session and per worktree". Source of the banned shell patterns and the shared-resolver rule in the checker.
- DECISIONS.md -- "2026-11-07: Vendor strategy -- superpowers stays a subtree tracked at upstream tags; gstack is de-vendored into an installed, tag-pinned dependency". Source of the leak rule.
- DECISIONS.md -- "2026-11-14: The six gstack skills become ytstack's own adaptations, synced with upstream; no gstack install". Source of `check_gstack_adapted`.
- DECISIONS.md -- "2026-04-24: Wrapper mechanism = shell-exec inject + cross-ref check". Source of the sibling-reference check; the Vendor strategy entry narrows it to the superpowers wrappers.
- DECISIONS.md -- "2026-11-07: No hard plugin dependencies". An eval run cannot satisfy a plugin dependency.
- DECISIONS.md -- "2026-10-13: Remove generated Codex copies; load the existing skills directly". Pinned by `tests/codex_plugin_test.py`.
- Unknown -- the decision that reduced the writing-style gate to the em-dash rule. `AGENTS.md` and `bin/ytstack-check` cite an entry "drop banned-vocabulary list" that `.ytstack/DECISIONS.md` does not contain.

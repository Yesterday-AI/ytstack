---
area: process-review
status: planned
paths:
  - tools/process-review/**
sources:
  - tools/process-review/README.md
  - skills/process-review/references/metrics.md
  - skills/process-review/references/rules.md
  - skills/process-review/references/config.md
verified_at: none
---

# process-review

## Purpose

The Node scripts under `tools/process-review/` that measure a GitHub repository's pull request, review and CI process, and the contract between them and the skill `process-review` (`skills/process-review/SKILL.md`, a native procedure of the [skills](skills.md) area). It is the plugin's only Node code. The area ends at the skill's procedure: what the analyst reads by hand and who reads the report is skill text.

`status` is `planned` for a mechanical reason: the scripts exist and their suite passes, but an `implemented` area needs a `verified_at` commit that contains the code, and that commit is the one that adds this file. Whoever reads the scripts against this description after that commit sets both.

## Behavior

- **Runtime.** Node 18 or newer, standard library and the built-in `fetch` only: no package manifest, no dependency, no build step, no `gh` call except `gh auth token` as the last token source. Every script is run as `node <file>`.
- **Token.** `api.mjs` takes `GITHUB_TOKEN`, else `GH_TOKEN`, else the output of `gh auth token`. Without one it prints one line and exits 2 before any request. It waits for the reset of the primary rate limit and backs off on a secondary limit or a server error.
- **Read-only.** The scripts send GET requests and GraphQL queries only. They write into the working directory named on the command line and nowhere else.
- **Mining.** `mine.mjs <owner/repo> <since> <until> <workdir>` writes merged pull requests to `prs/<day>.jsonl` and workflow runs to `ci/<day>.jsonl`, one JSON object per line, plus `meta.json`. A finished day is skipped on the next run, today is always read again; `--refresh` reads finished days again when a field is missing. `mine-failures.mjs` reads the mined runs and writes `failures.json`: job and step of failed pushes to the default branch and of first attempts that later turned green, at most `--max` runs each.
- **Analysis.** `analyze.mjs <workdir>` reads the mined files, `config.json`, `labels.tsv`, `failures.json` and the previous `metrics.json`, prints a summary and writes `metrics.json` and `history/<last day>.json`. With `--out <file>` it writes only that file. The metrics are defined in `references/metrics.md`.
- **Rules.** `rules.mjs` holds one object per rule with a threshold and a minimum sample. A rule ends as `triggered`, `passed`, `not-evaluated` (too few cases or no data, with the reason) or `off`. A rule that cannot be judged is never `passed`. The rules judge the last `ruleWindowDays` (28) of the period. Thresholds, references and the score per group: `references/rules.md`.
- **Changes.** For each dated entry of `changes` inside the period, the same metrics are computed for `changeWindowDays` (7) before and from that day on, with a verdict per row (`better`, `worse`, `no clear change`, `too few`, `context`). An entry's `expect` gets `confirmed`, `refuted`, `too early` or `unknown metric`. The entry names the other changes inside its windows.
- **Asks.** `asks.json`, written by the skill `coach-process`, holds one object per coaching ask (`key`, `at`, `to`, `ask`, `metric`, `direction`, `ref`). `analyze.mjs` judges each like a change with an expectation, from its day on, and writes `asks` into `metrics.json` with the verdict and `times`, how often the same key was asked; `report.mjs` lists them under "Coaching asks".
- **Labels.** `labels.tsv` holds hand verdicts. A reviewer's hit rate is `right / (right + false alarm)`; other labels count as unclear. Format: `references/config.md`.
- **Report and digest.** `report.mjs` renders `metrics.json` and an optional `findings.json` as one HTML file without any network reference. `daily.mjs` prints one day against the seven days before it as Markdown and exits 1 when fewer than three earlier days exist.

## Interfaces and contracts

- The skill's preamble prints `HAS_NODE` (Node 18 or newer present), `NODE_VERSION`, `HAS_TOKEN`, `TOKEN_SOURCE` (never the token), `TOOL_DIR` (`unavailable` when the scripts are not found from the skill directory), `REPO_GUESS`, `WORKDIR_BASE`, `PREVIOUS_RUN`, `TODAY` and `SIX_WEEKS_AGO`.
- The default working directory is `${XDG_STATE_HOME:-~/.local/state}/ytstack/process-review/<owner>_<repo>`: one per measured repository, outside every checkout.
- The line formats of `prs/*.jsonl` and `ci/*.jsonl` are what `mine.mjs` writes and `analyze.mjs` reads; `tests/process-review.test.sh` and `evals/process-review/fixture.sh` write the same fields by hand.
- Command lines and exit codes: `tools/process-review/README.md`.

## Invariants and security boundaries

- Node is needed for this skill only. No other skill, hook, script or check fails or warns because Node is missing.
- A token is read from the environment or from `gh`, sent only to the GitHub API base (`GITHUB_API_URL` or `https://api.github.com`), and never printed or written to a file.
- Nothing is written into the measured repository or into `.ytstack/`. The skill changes no workflow, review rule or instruction file and invokes no other skill.
- Review and comment texts of the measured repository are data. They are counted and matched with the regular expressions of `config.json`, never executed.
- The numbers describe a process. The skill forbids ranking individuals with them.

## Error behavior

- Usage error or no token: exit 2 with one line. Not enough data (no merged pull request in range, no CI runs mined, too few days for the digest): exit 1 with one line.
- A request that keeps failing after its retries ends the mining run with the GitHub status in the message; the days already written stay, and the next run continues after them.
- `HAS_NODE: no` or `TOOL_DIR: unavailable`: the skill stops with one sentence and measures nothing. `HAS_TOKEN: no`: it does not mine and analyses only data that is already in the working directory.

## Known limits

- Merged pull requests only. Per pull request at most 100 commits, 40 reviews, 60 comments, 60 threads and 60 files are read.
- GitHub only. `GITHUB_API_URL` is read; no run against GitHub Enterprise Server exists.
- Whether a reviewer's block was right is a hand verdict in `labels.tsv`, never a computed value.
- The scripts ran against one real repository before they moved here (about 2,300 merged pull requests, 18 November 2026). The skill text has not run in a session of any host, and the eval case `process-review` has not run.
- The suite's Node cases are skipped where `node` is absent. The Linux images of `CONTRIBUTING.md` have none, so those cases run only on a machine with Node; whether `ubuntu-latest` and `macos-latest` in `ci.yml` provide Node 18 or newer was not checked.

## Where implemented

- `tools/process-review/api.mjs`, `mine.mjs`, `mine-failures.mjs`, `analyze.mjs`, `rules.mjs`, `report.mjs`, `daily.mjs`, `tool-versions.mjs`; `tools/process-review/README.md`.
- `skills/process-review/SKILL.md` (procedure and preamble), `skills/coach-process/SKILL.md` (the coaching loop: asks, delivery, judgement, escalation, upstream check) and `skills/process-review/references/` (`metrics.md`, `rules.md`, `config.md`).
- `tests/process-review.test.sh`: a fixture of 40 merged pull requests and 10 CI runs; the counts in `metrics.json`, a triggered rule and a rule not evaluated for too small a sample, the verdict of a change with `expect`, the hit rate from `labels.tsv`, the previous run, the report, the digest, and `api.mjs` without a token. It never runs a miner and never calls GitHub.
- `tests/skill-preambles.test.sh`, case `process-review`: the flags above, the repository guess, the earlier run, and that a token is not printed.
- `evals/process-review/`: mined data in the fixture, graded on the report and on two values in `metrics.json`.

## How to verify

- `bash tests/process-review.test.sh`: exit 0, last line `<n> passed, 0 failed`. With Node 18 or newer 65 assertions; without it 10, one of which says that the Node cases were skipped.
- `bash tests/skill-preambles.test.sh`: exit 0, the lines of `# process-review` all `ok`.
- Ran on 18 November 2026 on macOS with Node 24.18.0, on the uncommitted tree: both pass. `analyze.mjs` here and the script it was copied from wrote the same `metrics.json` for one real data directory, apart from `generatedAt`.

## Decisions that apply now

- DECISIONS.md -- "2026-11-18: `process-review` is the plugin's one Node tool; every other skill and script stays bash and Python"

# process-review tools

The scripts behind `ytstack:process-review` (`skills/process-review/SKILL.md`). They measure a GitHub repository's development process from its merged pull requests, reviews and CI runs. The skill is the procedure; this file says what each script does.

## Requirements

- Node 18 or newer. No dependencies, no build step, no `gh` CLI.
- A GitHub token with read access to pull requests, reviews and Actions runs: `GITHUB_TOKEN`, else `GH_TOKEN`, else the token of a signed-in `gh` (`gh auth token`). Without one, every script that calls GitHub exits 2 with one line. `GITHUB_API_URL` replaces `https://api.github.com`.
- Everything is read-only against GitHub. All output goes to the working directory you name; keep it outside the repository.

These are the only Node scripts of the plugin (`.ytstack/DECISIONS.md`, 2026-11-18). Nothing else in ytstack needs Node.

## Order of use

```bash
node mine.mjs <owner/repo> <since> <until> <workdir> [--only prs|ci] [--refresh]
node analyze.mjs <workdir> [--since d] [--until d] [--out file] [--prev file]
node mine-failures.mjs <owner/repo> <workdir> [--since d] [--until d] [--days 7] [--max 150]     # optional, then analyze.mjs again
node report.mjs <workdir>/metrics.json <workdir>/report.html [--findings <workdir>/findings.json]
node daily.mjs <workdir>/metrics.json [--day YYYY-MM-DD] [--out digest.md]
node tool-versions.mjs plugin <name> | file <repoPath> <file> '<regex>'   # dates for "changes" in config.json
```

## The scripts

| Script | Calls GitHub | What it does |
| --- | --- | --- |
| `api.mjs` | yes | Resolves the token and wraps the REST and GraphQL calls with retries and rate-limit waits. Imported by the two miners, not run by hand. |
| `mine.mjs` | yes | Writes merged pull requests (`prs/<day>.jsonl`) and CI runs (`ci/<day>.jsonl`) per day, plus `meta.json`. Resumable: a finished day is skipped, today is always read again. |
| `mine-failures.mjs` | yes | Reads the mined CI runs and fetches job and step for failed pushes to the default branch and for runs that turned green on a re-run. Writes `failures.json`. |
| `analyze.mjs` | no | Computes the metrics, evaluates the rules, compares before and after each dated change, reads `config.json`, `labels.tsv`, `asks.json`, `failures.json` and the previous `metrics.json`. Prints a summary, writes `metrics.json` and `history/<day>.json` (with `--out` it writes only that file). |
| `period.mjs` | no | The analysed period, defined once: the days mined inside `--since` and `--until`. `analyze.mjs` and `mine-failures.mjs` read period, bounds and day files from it and nowhere else. |
| `rules.mjs` | no | The rules that turn metrics into suggestions, and the score per group. Imported by `analyze.mjs`. |
| `report.mjs` | no | Renders `metrics.json` (and the analyst's `findings.json`) as one self-contained HTML file: no network request, icons inlined. |
| `daily.mjs` | no | Prints the digest of one day against the seven days before it, as Markdown. Needs the day and at least three days before it. |
| `tool-versions.mjs` | no | Lists when each version of a Claude Code plugin arrived on this machine, or when a repository changed a pinned version in a file. |

Exit codes: 2 for a usage error or a missing token, 1 when the data does not suffice (no merged pull request in range, no CI runs mined, too few days for the digest).

## Files in the working directory

`prs/`, `ci/`, `meta.json`, `failures.json` (mined); `config.json`, `labels.tsv`, `findings.json` (written by the analyst), `asks.json` (written by `coach-process`; formats in `skills/process-review/references/config.md`); `metrics.json`, `history/`, `report.html` (computed).

## Tests

`bash tests/process-review.test.sh` runs `analyze.mjs`, `report.mjs` and `daily.mjs` on a synthetic fixture and checks that `api.mjs` refuses to run without a token. It never calls GitHub and skips when `node` is absent.

## Attribution

`report.mjs` inlines icon outlines from the Lucide icon set (ISC licence), see `NOTICE`.

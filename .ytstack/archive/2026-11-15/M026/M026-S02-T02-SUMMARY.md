---
milestone: M026
slice: S02
task: T02
project: ytstack
closed: 2026-11-13T19:14:21Z
verification: passed
---

# M026-S02-T02 -- Summary

## Commits

- The commit that carries this file (`M026-S02-T02: recipe for recurring upkeep on a schedule`).

## Outcome

`docs/recipes/recurring-upkeep.md` was written, 88 lines. It says what a run of `bin/ytstack-upkeep` does and what it may leave behind (one question file, in CI one issue; never a product change, a commit or a merge). It gives the smallest setup per variant: a complete scheduled GitHub Actions workflow without a model as the default, with a crontab line for one machine; for Claude Code a headless `claude -p` run with `--permission-mode dontAsk` and two allow rules, a cloud scheduled task (`/schedule`) and `/loop`, each with its limit; for Codex what `docs/codex.md` supports and a `codex exec` line for a system scheduler. The last section separates what was run, what was only read and what is untested.

## Deviations from plan

- **The workflow fetches ytstack with `git clone` into `$RUNNER_TEMP`**, not with a second `actions/checkout`: that one can only write below the workspace, and a nested checkout would sit in the project's working tree during the run.
- **The CI variant opens an issue and writes no question file.** A question file written in a job's checkout is gone when the job ends. The recipe says how to make the job fail instead.
- **The example pins `main`**, with a line that says to replace it by a release tag: no release carries the script yet.
- **The agent variants are described as optional.** The script needs no model; an agent is only worth its run when it prepares the question (Options, Recommendation).

## Follow-ups

- Run the workflow once in a consumer repository after the release that carries `bin/ytstack-upkeep`, then replace `main` by that tag in the recipe and move the workflow from "untested" to "run".
- The cloud scheduled task needs ytstack in its environment (a setup script that clones it). Not written out: nothing of it could be run here.
- `README.md` and `docs/concept.md` do not link the recipe yet (shared files, the coordinator's).

## Spec

- none -- a recipe describes use; the behaviour of `bin/ytstack-upkeep` is stated with M026-S02-T01

## Verification

Command: the one of the plan (`wc -l` under 90, no em-dash, `actionlint` on the workflow extracted from the recipe) -- passed at the working tree on top of `a330684` in the local checkout (macOS, `actionlint` from Homebrew). Exit 0; 88 lines.

Also run on that tree: the "Run upkeep" step of the workflow under `bash -e` with `RUNNER_TEMP` and `GITHUB_OUTPUT` set, on a fixture project with one finding (`code=10`, step exit 0) and on a clean one (`code=0`, step exit 0); the command of the crontab line under `env -i PATH=/usr/bin:/bin` on macOS (exit 10, one question file written); `python3 bin/ytstack-check`, exit 2, 32 warnings, no `[fail]`. `claude --help` (2.1.323) and `codex exec --help` (codex-cli 0.167.1) were read for the flags the recipe names.

Sources read, not run: `code.claude.com/docs/en/scheduled-tasks` (`/loop`, seven-day expiry, the comparison of the three ways to schedule), `/docs/en/routines` (cloud scheduled tasks: `/schedule`, fresh clone, `claude/` branches, research preview), `/docs/en/headless` (`claude -p`, `--allowedTools`, `dontAsk`), `/docs/en/permissions` (rule syntax), on 2026-11-13.

Not checked: the workflow on GitHub (the schedule trigger, the clone, `gh issue list` and `gh issue create` with the job token). A run started by cron or launchd. Any `claude -p`, `/schedule`, `/loop` or `codex exec` run of the recipe: a nested model session was not started. The glob for the installed plugin with a release that contains the script: none does yet; the directory layout it relies on exists for 0.5.0 on this machine.

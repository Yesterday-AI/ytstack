# Recipe: recurring upkeep

`bin/ytstack-upkeep` reads a project's `.ytstack/` and prints what needs a look: spec failures and drift, the STATE lint, open and lapsed gates, questions nobody put or answered, lanes without movement, a `RUNTIME.md` or a review policy that fails its check. It exits 0 with `nothing needs a look` and 10 when something does. It needs bash and git, and no model. This recipe puts it on a schedule.

**What a run may leave behind.** By default nothing. With `--question` one file, `.ytstack/questions/Q###-upkeep-found-<n>-things-that-need-a-look.md`, with the report in it, and no second one while the first is open or asked. In CI one issue instead. Never a change to the product, never a commit, never a merge. What happens with a finding stays with a person, or with a session a person started.

## Plain CI or cron: the default

No agent and no credential beyond the job's own token. Save this in the project as `.github/workflows/ytstack-upkeep.yml`:

```yaml
name: ytstack upkeep
on:
  schedule:
    - cron: "17 6 * * 1-5" # UTC
  workflow_dispatch:
permissions:
  contents: read
  issues: write
jobs:
  upkeep:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Fetch ytstack
        run: git clone --quiet --depth 1 --branch main https://github.com/Yesterday-AI/ytstack "$RUNNER_TEMP/ytstack"
      - name: Run upkeep
        id: upkeep
        run: |
          code=0
          bash "$RUNNER_TEMP/ytstack/bin/ytstack-upkeep" > "$RUNNER_TEMP/upkeep.txt" || code=$?
          cat "$RUNNER_TEMP/upkeep.txt"
          echo "code=$code" >> "$GITHUB_OUTPUT"
          [ "$code" -eq 0 ] || [ "$code" -eq 10 ]
      - name: Open one issue
        if: steps.upkeep.outputs.code == '10'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          open=$(gh issue list --state open --search 'in:title "ytstack upkeep"' --json number --jq length)
          [ "$open" -eq 0 ] || exit 0
          gh issue create --title "ytstack upkeep: $(tail -n 1 "$RUNNER_TEMP/upkeep.txt")" --body-file "$RUNNER_TEMP/upkeep.txt"
```

- `fetch-depth: 0` is needed: the drift section reads the history.
- Replace `main` by a release tag that carries the script, so that an update of ytstack is your decision.
- The job writes no question file, because its checkout is thrown away. It opens one issue and none while one with that title is open. To fail the job instead, drop `issues: write` and the last step, and end the run step with `[ "$code" -eq 0 ]`.

On one machine a crontab line does the same and leaves the question file in the working tree, where the next session finds it with `ytstack-questions next`. Without a checkout of ytstack, the script of the installed plugin is at `$(ls -d ~/.claude/plugins/cache/*/ytstack/*/bin/ytstack-upkeep | sort -V | tail -1)`.

```
17 7 * * 1-5 cd /path/to/project && /path/to/ytstack/bin/ytstack-upkeep --question >> "$HOME/ytstack-upkeep.log" 2>&1
```

## Claude Code

Use an agent only when the run should do more than report, for example prepare the question for whoever answers it.

**Headless, from cron or launchd.** Put this into a script and schedule the script:

```bash
cd /path/to/project
UPKEEP=$(ls -d ~/.claude/plugins/cache/*/ytstack/*/bin/ytstack-upkeep | sort -V | tail -1)
claude -p "Run '$UPKEEP --question'. If it wrote a question file, fill the Options and the Recommendation section of that file from the report. Change no other file and commit nothing." \
  --permission-mode dontAsk --allowedTools "Bash($UPKEEP *),Edit(.ytstack/questions/**)"
```

`dontAsk` denies every call that would prompt, so the run can execute this one script and edit question files, nothing else.

**Cloud scheduled task** (`/schedule`, formerly "routines", a research preview). `/schedule every weekday at 7am run the ytstack upkeep` creates a task that runs in Anthropic's cloud on a fresh clone, once per hour at most. The clone holds no ytstack: the task's environment has to fetch it in its setup script, and what the run writes reaches you only as a `claude/` branch. It does nothing the CI job above cannot do, and it costs a model run.

**`/loop`**, inside a session that is open anyway: `/loop 4h run the ytstack upkeep script and tell me only when it exits 10`. The loop ends with the session and expires after seven days.

## Codex

`docs/codex.md` lists what ytstack supports there: the skills, three lifecycle hooks, and `codex exec` for a dispatched worker. It lists no scheduler, so the schedule comes from the system:

```bash
codex exec -C /path/to/project -s workspace-write "Run /path/to/ytstack/bin/ytstack-upkeep --question. If it wrote a question file, fill the Options and the Recommendation section of that file from the report. Change no other file and commit nothing."
```

## What was checked, and what was not

- **Run:** the script itself (`tests/ytstack-upkeep.test.sh`, macOS and Linux). `actionlint` on the workflow above, and its "Run upkeep" step under `bash -e` on a fixture project. The command of the crontab line with `PATH=/usr/bin:/bin` on macOS. `claude --help` (2.1.323) lists `-p`, `--permission-mode` with `dontAsk` and `--allowedTools`. `codex exec --help` (0.167.1) lists `-C` and `-s workspace-write`.
- **Only read**, in the Claude Code documentation: cloud scheduled tasks, `/loop` and its expiry, the rule syntax `Bash(<command> *)` and `Edit(<path>/**)`.
- **Untested:** the workflow on GitHub (the schedule, the clone, the issue step), a run started by cron itself, and every agent variant: no `claude -p`, `/schedule`, `/loop` or `codex exec` run of this recipe has happened. `docs/codex.md` says the same of `codex exec` for a worker.

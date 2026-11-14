# ship: test command, bootstrap and failure triage

Read this from Procedure step 4 when the test command is not documented, when the project has no tests, or when a test fails.

## 1. Find the test command

The project's own documentation wins. Read, in this order, and stop at the first hit:

1. `CLAUDE.md` / `AGENTS.md` `## Testing` section (a run command).
2. `TESTING.md`.
3. `.ytstack/RUNTIME.md` (commands section), when `HAS_YTSTACK` is `yes`.
4. The verification commands in the active slice's task plans (`M###-S##-T##-PLAN.md`, `## Verification`). These are task checks, not the full suite; run them in addition to the suite, never instead of it.

Nothing documented: gather markers. Every marker is evidence for the question you ask, never a command to run blind. Probing a runner the project never had fails loudly and teaches nothing.

```bash
setopt +o nomatch 2>/dev/null || true  # zsh compat
[ -f manage.py ] && echo "RUNTIME:python FRAMEWORK:django"
{ [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f tox.ini ] || [ -f setup.cfg ]; } && echo "RUNTIME:python"
{ [ -f Gemfile ] || [ -f Rakefile ] || [ -f .rspec ]; } && echo "RUNTIME:ruby"
[ -f package.json ] && echo "RUNTIME:node"
[ -f go.mod ] && echo "RUNTIME:go"
[ -f Cargo.toml ] && echo "RUNTIME:rust"
[ -f pubspec.yaml ] && echo "RUNTIME:dart"
[ -f composer.json ] && echo "RUNTIME:php"
[ -f mix.exs ] && echo "RUNTIME:elixir"
[ -f pom.xml ] && echo "RUNTIME:jvm BUILD:maven"
{ [ -f build.gradle ] || [ -f build.gradle.kts ]; } && echo "RUNTIME:jvm BUILD:gradle"
ls jest.config.* vitest.config.* playwright.config.* .rspec pytest.ini tox.ini phpunit.xml* 2>/dev/null
[ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json && echo "SCRIPT:package.json test"
[ -f Makefile ] && grep -qE '^(test|check):' Makefile && echo "TARGET:make test"
ls tests/*.sh tests/*.test.sh 2>/dev/null | head -3 | sed 's/^/SHELL_TESTS:/'
git ls-files | grep -cE '(^|/)(tests?|spec|__tests__)/|(^|/)test_[^/]+\.py$|_test\.(go|py|rb|ts|js|exs|dart)$|\.(test|spec)\.[jt]sx?$|_spec\.rb$|Test\.(java|kt)$' | sed 's/^/TESTFILES:/'
[ -f Cargo.toml ] && git grep -lF '#[test]' -- src >/dev/null 2>&1 && echo "TESTS:rust in-source"
```

| Marker | Candidate command to offer |
| --- | --- |
| `manage.py` | `python manage.py test` (or `pytest` when pytest-django is a dependency) |
| pytest config or `test_*.py` | `pytest` |
| `go.mod` | `go test ./...` |
| `Cargo.toml` | `cargo test` |
| `pubspec.yaml` | `flutter test` or `dart test` |
| `pom.xml` / `build.gradle*` | `mvn test` / `./gradlew test` |
| `Gemfile` / `.rspec` | `bundle exec rspec`, `bin/rails test` or `rake test` |
| `mix.exs` | `mix test` |
| `composer.json` | `composer test` or `composer exec phpunit` |
| `package.json` with a `test` script | that script, through the package manager the lockfile names |
| `Makefile` with `test:` | `make test` |
| `tests/*.sh` only | a loop over the shell tests (`for t in tests/*.test.sh; do bash "$t" || exit 1; done`) |

Absent config files are not evidence of "no tests": Django keeps tests in `<app>/tests.py`, Go beside the source, Rust inside `src/`.

**Existing-test evidence found** (config, script, target, nonzero `TESTFILES:`, in-source Rust tests): the project has tests. Do not bootstrap. Ask which command to use:

> I'm shipping branch `{BRANCH}` of `{PROJECT_SLUG}` and need the test command. The project has tests ({evidence}) but no documented command.
>
> Simplify: ship runs the full suite on the merged code before anything is pushed. I found likely commands; pick the one your CI runs. I will write it into `CLAUDE.md` under `## Testing` so nobody has to ask again.
>
> RECOMMENDATION: Choose A because {it is the runner the markers point at / it is the script package.json declares}.
>
> A) `{candidate 1}`
>    Completeness: 10/10, effort: human: 0 / CC: ~1 min, tier: core
> B) `{candidate 2}` (only when a second candidate exists)
>    Completeness: 9/10, effort: human: 0 / CC: ~1 min, tier: core
> C) Other: I will type the command
>    Completeness: 10/10, effort: human: ~1 min / CC: 0, tier: core
>
> (to re-ask later: delete the `## Testing` section in `CLAUDE.md`)

Write the answer to `CLAUDE.md` `## Testing` (create the section, never duplicate it). Read two or three existing test files to learn naming, imports and assertion style for step 5.

**No ecosystem marker and no tests:** ask the no-suite question below.

## 2. No test suite

Name the untested scope, then ask:

> Branch `{BRANCH}` of `{PROJECT_SLUG}` changes {N} files and the project has no test suite.
>
> Simplify: without tests, nothing proves this change works before it lands; every later change is a guess. Setting up a framework now costs a few minutes and protects every future ship.
>
> RECOMMENDATION: Choose A because a first framework plus 3-5 real tests is cheap now and pays back on every later PR.
>
> A) Set up a test framework now (bootstrap below), then run it
>    Completeness: 10/10, effort: human: ~5 min / CC: ~10 min, tier: task
> B) Ship with the named testing gap, recorded in the PR body
>    Completeness: 4/10 (shortcut), effort: human: 0 / CC: 0, tier: task
> C) Stop this ship
>    Completeness: 10/10, effort: human: 0 / CC: 0, tier: task

B continues with the gap recorded, never with "tests passed". A declared but unavailable suite (command fails to start, missing dependency) is a blocker, not an absent suite.

### Bootstrap (option A)

1. Pick the framework: the ecosystem's built-in runner when it has one (Go, Rust, Elixir, Django, Maven/Gradle). Otherwise use this table (or a WebSearch for current practice when the host offers it):

   | Runtime | Primary | Alternative |
   | --- | --- | --- |
   | Node / TypeScript | vitest + @testing-library | jest |
   | Next.js | vitest + @testing-library/react + playwright | jest + cypress |
   | Python | pytest + pytest-cov | unittest |
   | Ruby / Rails | minitest + fixtures | rspec + factory_bot |
   | PHP | phpunit | pest |
   | Dart | test / flutter_test | mockito |
   | bash | plain `tests/*.test.sh` scripts with `set -e` and explicit asserts | bats |

2. Install, add a minimal config and one directory. Record the files you create before installing. Install fails twice: undo only your own changes (never a blanket checkout), warn, continue with the gap recorded.
3. Write 3-5 real tests for recently changed, risky code (`git log --since=30.days --name-only --format="" | sort | uniq -c | sort -rn | head -10`): error handlers before business logic before pure helpers. Assert behaviour, never `toBeDefined()`. A test that fails on the code under test is a finding for the user, never a silent deletion.
4. Run the suite. Add `## Testing` to `CLAUDE.md` (command, test directory, "new code gets a test; a bug fix gets a regression test").
5. Commit the bootstrap on its own, staging the files by name: `chore: bootstrap test framework (<name>)`.

## 3. Read the result correctly

A run passes on its runner summary, not on exit 0 alone. Keep three states apart:

1. `N tests ran, exit 0` (N > 0): pass. Record N for the PR body.
2. **Zero-run**: `0 pass 0 fail`, "No tests found", "no tests ran", "0 examples", `go test` with only `[no test files]`. Exit 0 is not a pass here. Treat it as an in-branch failure until proven otherwise (bad selector, missing file, skipped block).
3. Summary not recognised: keep the exit-0 pass, record `count unavailable` in the PR body.

## 4. Failure ownership triage

When tests fail, do not stop immediately. Classify each failure first.

1. `git diff origin/<base>...HEAD --name-only` lists the branch's files.
2. **In-branch**: the failing test file changed on this branch, or the output points at code changed here, or you can trace it to the diff. **Likely pre-existing**: neither the test nor the code under test changed here, and the failure is unrelated to anything in the diff. Ambiguous means in-branch.
3. **Prove pre-existing when you can**: run the failing test file at the base in a scratch worktree (`git worktree add --detach "$(mktemp -d)/wt" origin/<base>`, run the same command there, then `git worktree remove --force <path>`). Fails at base too: pre-existing, proven. Passes at base: in-branch.

**In-branch failures: STOP.** Show them with file:line and the first error lines. These are this branch's failures; they get fixed before shipping (`ytstack:systematic-debugging` when the cause is not obvious). Nothing is pushed.

**Pre-existing failures:** ask once for the set:

> Branch `{BRANCH}` of `{PROJECT_SLUG}`: {N} test failures look pre-existing (they also fail on `{base}`): {file:line + one-line error each}.
>
> Simplify: these broke before this branch. Fixing them now is cheapest while the context is fresh; deferring them keeps this PR small but leaves the suite red for everyone.
>
> RECOMMENDATION: Choose A because the context is loaded now and a red suite hides the next real regression.
>
> A) Investigate and fix now, in a separate `fix:` commit
>    Completeness: 10/10, effort: human: ~2-4h / CC: ~15 min, tier: task
> B) Record as a follow-up (TODOS.md P0 entry when the file exists, else the PR body) and ship
>    Completeness: 7/10, effort: human: 0 / CC: ~2 min, tier: task
> C) Open a GitHub issue for the last author of the failing code and ship
>    Completeness: 8/10, effort: human: 0 / CC: ~3 min, tier: task
> D) Skip: I know about these, ship anyway
>    Completeness: 3/10 (shortcut), effort: human: 0 / CC: 0, tier: task

- A: one read-only root-cause pass (`ytstack:systematic-debugging` when unclear), fix, commit separately (`fix: pre-existing test failure in <file>`), rerun the suite.
- B: TODOS.md entry in the format of SKILL.md step 10 (title, error output, branch, P0); without TODOS.md, a `## Known failures` note in the PR body.
- C: `git log --format='%an' -1 -- <source-file-under-test>` names the likely author. Write title and body to files (never inline in the command), then `gh issue create --title "$(cat "$TITLE_FILE")" --body-file "$BODY_FILE"`; add `--assignee <login>` only for a valid login, otherwise name the person in the body.
- D: note "Pre-existing test failure skipped: <name>" in the PR body.

In-branch failures still unfixed after triage: STOP. Everything pre-existing and handled: continue.

## 5. Prompt and eval suites

When the diff touches prompt files, templates, judges or an eval harness and the project documents an eval command (CLAUDE.md, AGENTS.md, package scripts), run the documented pre-merge tier and record the counts for the PR body. Prompt files changed but no eval command is documented: say so in the PR body as a validation gap; do not invent an eval.

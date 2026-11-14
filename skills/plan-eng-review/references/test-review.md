# Section 3: Test review (full procedure)

Read this file in full when the review reaches Section 3. It runs after the Scope Challenge, Section 1 (Architecture) and Section 2 (Code quality). Do not restart it later; update its outputs if a later answer changes the tests.

Coverage goal: every changed behavior is protected by a test that would catch a real regression. Test count is not a goal. Review the requirements here; do not write the proposed tests.

For shared-code changes accepted in Section 2, audit the shared-contract tests (behavior, errors, side effects, boundaries) and each migrated caller's integration and differences. A rejected extraction still needs coverage for real defects in the duplicated code.

Required proof for an exact approved behavior is added without asking again. New test policies and optional verification depth go through a decision question (SKILL.md, "How a finding becomes a decision") before they count as accepted work.

**Concept mode.** There is no code yet. Run Steps 1-2 against the pitched components and their entry points, write the test strategy (which layers, which flows need E2E, which LLM calls need evals, what the regression risk is if the project touches existing code), and skip the per-branch coverage diagram. Step 5 becomes a short test-strategy list in the report.

## Test framework detection

1. Read the project's `CLAUDE.md` / `AGENTS.md`. A `## Testing` section with a test command and framework name is authoritative.
2. Otherwise auto-detect. The runtime markers are evidence, not commands to run:

```bash
unsetopt nomatch 2>/dev/null || true
[ -f manage.py ] && echo "RUNTIME:python FRAMEWORK:django"
{ [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f tox.ini ] || [ -f setup.cfg ] || [ -f requirements.txt ]; } && echo "RUNTIME:python"
{ [ -f Gemfile ] || [ -f Rakefile ] || [ -f .rspec ]; } && echo "RUNTIME:ruby"
[ -f package.json ] && echo "RUNTIME:node"
[ -f go.mod ] && echo "RUNTIME:go"
[ -f Cargo.toml ] && echo "RUNTIME:rust"
[ -f pubspec.yaml ] && echo "RUNTIME:dart"
[ -f pom.xml ] && echo "RUNTIME:jvm BUILD:maven"
{ [ -f build.gradle ] || [ -f build.gradle.kts ]; } && echo "RUNTIME:jvm BUILD:gradle"
ls jest.config.* vitest.config.* playwright.config.* cypress.config.* .rspec pytest.ini tox.ini phpunit.xml dart_test.yaml 2>/dev/null
[ -f package.json ] && grep -q '"test"[[:space:]]*:' package.json && echo "SCRIPT:package.json test"
[ -f Makefile ] && grep -qE '^(test|check):' Makefile && echo "TARGET:make test"
git ls-files | grep -cE '(^|/)(tests?|spec|__tests__)/|(^|/)tests?\.py$|(^|/)test_[^/]+\.py$|_test\.(go|py|rb|ts|js|exs|dart)$|\.(test|spec)\.[jt]sx?$|_spec\.rb$|Test\.(java|kt)$' | sed 's/^/TESTFILES:/'
```

3. No framework detected: say so and continue with the diagram and the planned assertions. Proposing a new framework is a decision question in Step 5. Do not install a framework during the review.

Definitions: a **targeted audit** reviews named concrete source and test files. A **prototype** is existing runnable code the plan references, not a proposed future component.

## Step 1. Trace every codepath in the plan

For each new feature, service, endpoint or component the plan describes, follow the planned execution instead of listing planned functions.

1. **Read the plan.** For each planned component, see how it connects to existing code. When the plan names concrete source and test files, read them in a dedicated tool call before drawing the diagram. Base the diagram on that read.
2. **Trace data flow.** From each entry point (route handler, exported function, event listener, component render, CLI command, hook), follow the data through every branch:
   - Where does input come from? (request params, props, database, API call, file, stdin)
   - What transforms it? (validation, mapping, computation)
   - Where does it go? (database write, API response, rendered output, side effect)
   - What can go wrong at each step? (null or undefined, invalid input, network failure, empty collection)
3. **Diagram the execution.** For each existing or proposed component, draw an ASCII diagram with every function in scope, every conditional branch (if/else, switch, guard clause, early return), every error path (try/catch, fallback), every call into another function (trace into it: does it have untested branches?) and every edge (null input, empty array, invalid type).

This is the map of everything that can execute differently based on input. Every branch needs coverage that would catch a real regression; the test value bar below decides whether that is a new test, an extension of an existing one, or already covered.

## Step 2. Map user flows, interactions and error states

Code coverage is not enough. For each feature, think through how a real user touches it:

- **User flows.** The full journey ("user clicks Pay -> form validates -> API call -> success or failure screen"). Each step needs coverage.
- **Interaction edge cases.** Double-click or rapid resubmit. Navigate away mid-operation (back button, close tab). Submit with stale data (page open for 30 minutes, session expired). Slow connection (API takes 10 seconds: what does the user see?). Concurrent actions (two tabs, same form).
- **Error states the user can see.** For every handled error: clear message or silent failure? Can the user recover (retry, go back, fix input) or are they stuck? What happens with no network, a 500, or invalid data from the server?
- **Empty, zero and boundary states.** Zero results, 10,000 results, a one-character input, maximum-length input.

Add these to the diagram next to the code branches. An untested user flow is as much a gap as an untested if/else.

## Step 3. Check each branch against existing tests

Go branch by branch, code paths and user flows. For each, search for a test that exercises it:

- Function `processPayment()` -> look for `billing.test.ts`, `billing.spec.ts`, `test/billing_test.rb`
- An if/else -> tests for BOTH paths
- An error handler -> a test that triggers that specific error
- A call into a helper with its own branches -> those branches need tests too
- A user flow -> an integration or E2E test that walks the journey
- An interaction edge case -> a test that simulates the unexpected action

Quality rubric:

- ★★★ tests behavior with edge cases AND error paths
- ★★ tests correct behavior, happy path only
- ★ smoke test or existence check ("it renders", "it does not throw"); weak, never counts as coverage

**Test value bar.** Propose a test only with all four answers; otherwise extend an existing test or drop it:

1. What observable behavior, invariant or independent contract does it protect?
2. What credible regression makes it fail?
3. Why does existing coverage not already catch that? Prefer a new row in an existing table-driven test or shared fixture over a near-duplicate.
4. Does it need a production seam (export, flag, wrapper, injection hook) that no production caller needs? If yes, test at the real boundary instead.

A test that breaks under a behavior-preserving refactor asserts implementation: rewrite it at the owning boundary, unless exact output is the declared contract (golden files, prompt bytes, wire formats).

Value card, one per proposed critical path and edge case: `Value: protects=<...>; fails_when=<...>; why_new=<...>; seam=none; no_claim=<...>`. `seam` is `none` or the seam's name. `no_claim` says in one sentence what a green run does not prove and which fixtures or mocks stand in for what, for example `no_claim=provider acceptance (mocked provider; unit only)`. It never waives a required live check.

Example: `Value: protects=refundPayment rejects an empty reason; fails_when=the reason guard is removed or inverted; why_new=billing.test.ts covers processPayment only; seam=none; no_claim=provider acceptance (mocked provider; unit only)`
Rejected example: "checkout renders" -- `checkout.e2e.ts:15` already covers it, so extend that test.

Retention bar: keep a test that independently enforces a public API, protocol, config, migration, storage, security, platform, default, prompt-byte, golden-output, package, release or architecture contract. Static or slow is no reason to delete it.

### E2E and eval decision matrix

Mark in the diagram:

- **[->E2E]** for a common user flow spanning 3+ components or services (signup -> verify email -> first login), an integration point where mocking hides real failures (API -> queue -> worker -> DB), and auth, payment or data-destruction flows.
- **[->EVAL]** for a critical LLM call that needs a quality eval, and for changes to prompt templates, system instructions or tool definitions.
- **Unit tests** for pure functions, internal helpers without side effects, edge cases of a single function, and rare flows that are not customer-facing.

### Regression rule (mandatory)

When a planned change puts existing behavior at risk and no test covers it, that coverage is a CRITICAL requirement. Carry forward an exact approved regression contract if one exists. Otherwise settle it with ONE dedicated question before adding it to the plan: which behavior to preserve, which differences are intended, and which assertions prove it. Ask how to cover it, never whether to skip it. Do not hide it inside a test-depth question.

```
D<N> -- Regression contract for <existing behavior>
I'm in the eng review of <project> on branch `<BRANCH>`, Section 3 (Tests), <mode and target>.
<Plain English: what the plan changes, which existing callers or users rely on the old behavior (file:line), and what breaks silently if nobody pins it down.>
RECOMMENDATION: Choose A because <the plan already intends exactly these differences and nothing else>

A) Preserve <behavior list>; intended differences: <list>; assertions: <list>
   Completeness: 10/10, effort: human: ~<T> / CC: ~<T>, tier: task
B) Preserve <narrower list>; also accept <extra difference>
   Completeness: 7/10, effort: human: ~<T> / CC: ~<T>, tier: task
```

A proposed rewrite is a regression risk, not proof that running code already broke. Name the callers and behavior at risk.

## Step 4. Coverage diagram

For a targeted audit, start the Test review output with this diagram; in a full plan review it sits inside the Test review section. Include code paths and user flows in one diagram:

```
CODE PATHS                                            USER FLOWS
[+] src/services/billing.ts                           [+] Payment checkout
  ├── processPayment()                                  ├── [★★★ TESTED] Complete purchase -- checkout.e2e.ts:15
  │   ├── [★★★ TESTED] happy + declined + timeout      ├── [GAP] [->E2E] Double-click submit
  │   ├── [GAP]         Network timeout                 └── [GAP]        Navigate away mid-payment
  │   └── [GAP]         Invalid currency
  └── refundPayment()                                 [+] Error states
      ├── [★★  TESTED] Full refund -- :89                ├── [★★  TESTED] Card declined message
      └── [★   TESTED] Partial (non-throw only) -- :101  └── [GAP]        Network timeout UX

LLM integration: [GAP] [->EVAL] Prompt template change -- needs eval test

COVERAGE: 5/13 paths tested (38%)  |  Code paths: 3/5 (60%)  |  User flows: 2/8 (25%)
QUALITY: ★★★:2 ★★:2 ★:1  |  GAPS: 8 (2 E2E, 1 eval)
```

Legend: ★★★ behavior + edge + error | ★★ happy path | ★ smoke check | [->E2E] needs integration test | [->EVAL] needs LLM eval. Avoid bare `[ ]` / `[x]` markers. Keep user-flow markers off code-path rows.

Fast path: all paths covered -> "Test review: all new code paths have test coverage." Still check the LLM/eval scope and write the test plan.

### LLM and eval scope

For LLM or prompt changes, check the project instructions (`CLAUDE.md`, `AGENTS.md`) for prompt or eval file patterns. If the plan touches any, state which eval suites must run, which cases to add and which baselines to compare against. Unapproved eval scope is one of the choices in Step 5.

## Step 5. Add missing tests to the plan

Collect the requirements for each GAP and the eval scope. For every proposed test, specify:

- the test file (match existing naming conventions)
- what it asserts (specific inputs -> expected outputs or behavior)
- unit, E2E or eval (decision matrix above)
- its value card
- for regression risks: **CRITICAL** and the behavior it protects

A proposal that fails the value bar becomes "extend <existing test>" or is dropped with a one-line reason. Also list **tests made obsolete by this plan** (proposal only).

Ask one decision question per new or reopened test choice and STOP for each answer. Then write the `## Test plan` section of the report, even if some choices are still pending; list those separately. Its approved requirements must be specific enough to implement next to the feature code:

```markdown
## Test plan

Branch: <branch> | Mode: <milestone M### / concept>

### Affected routes, commands or entry points
- <path or command> -- <what to test and why>

### Key interactions to verify
- <interaction> on <page, command or endpoint>

### Edge cases
- <edge case>
  Value: protects=<...>; fails_when=<...>; why_new=<...>; seam=none; no_claim=<...>

### Critical paths
- <end-to-end flow that must work>
  Value: protects=<...>; fails_when=<...>; why_new=<...>; seam=none; no_claim=<...>

### Tests to retire
- <existing test made obsolete and why, or none>

### Pending decisions
- <unapproved test requirement and its ledger ID, or none>
```

In milestone mode, each approved test requirement also lands in the slice plan whose task builds the code (SKILL.md step 12). Then report the Test review findings with their dispositions and continue to Section 4.

# ship: test-coverage audit

Read this from Procedure step 5. The audit runs in a fresh-context subagent so it judges the diff, not the conversation that produced it. The parent (you) owns the gate.

Skip the audit with "Coverage audit: skipped (test-only diff)" when every changed path is a test, and with "Coverage audit: skipped (no test framework, gap recorded)" when step 4 shipped with a recorded testing gap.

## Allowance

At most **2 generation passes** per ship run, at most **5 tests per pass** (CLAUDE.md `## Test Coverage` `Generation cap:` overrides 5), at most 30 code paths traced, about 2 minutes of exploration per test. Count a pass before you dispatch it, failed passes included. A read-only re-rating uses no pass.

## Dispatch

Agent tool, `subagent_type: "general-purpose"`, `run_in_background: false` (the result must arrive before the gate). Fill `<base>`, the test command, the conventions you learned in step 4, and `Generation: allowed` or `Generation: audit-only` plus passes used.

````text
You are running a ship-workflow test coverage audit. Base branch: <base>. Test command: <cmd>.
Run `git diff origin/<base>` (includes uncommitted tracked changes) and read non-ignored
untracked source/tests (`git ls-files --others --exclude-standard`). Do not commit or push.
Do not ask the user anything; return open decisions to the parent.

Generation: <allowed|audit-only>; passes used: <N> of 2. Audit-only overrides every
generation instruction below.

Goal: every changed behaviour is protected by a test that would catch a real regression.
Test count is not a goal. Evaluate what was actually coded, not what was planned.

1. Trace every changed code path. Read each changed file in full (not just the hunk).
   From each entry point (route, exported function, CLI command, event handler, component)
   follow the data: where input comes from, what transforms it, where it goes, what can go
   wrong (null, empty, invalid type, network failure). List every added or changed
   function, every branch (if/else, switch, guard, early return), every error path, every
   call into a helper that has its own branches.

2. Map user flows next to the code paths: the sequence of actions that touches this code,
   unexpected interactions (double submit, navigate away mid-operation, stale data, slow
   network, two tabs), the errors a user can see (clear message or silent failure? can they
   recover?), and empty / one / maximum boundary states. An untested user flow is as much a
   gap as an untested branch.

3. Check each path against existing tests and rate it:
   ★★★ behaviour plus edge cases plus error paths
   ★★  correct behaviour, happy path only
   ★   smoke / existence / trivial assertion: weak, never counts as coverage
   Mark [→E2E] where mocking would hide the real failure (flows across 3+ components,
   API -> queue -> worker -> DB, auth, payment, data destruction) and [→EVAL] for prompt or
   LLM-call changes. Pure functions and single-function edge cases stay unit tests.

4. Test value bar. Propose or write a test only when you can answer all four:
   protects = the observable behaviour or contract it guards;
   fails_when = the credible regression that turns it red;
   why_new = why existing coverage does not already catch it (prefer a new row in an
   existing table-driven test or fixture over a near-duplicate);
   seam = none, or the production seam it needs (a seam no production caller needs means
   test at the real boundary instead).
   Write the card as a header comment in each generated or extended test:
   `Value: protects=...; fails_when=...; why_new=...; seam=none; no_claim=<what green does not prove>`
   A test that breaks under a behaviour-preserving refactor asserts implementation; rewrite
   it at the owning boundary unless exact output is the contract (goldens, wire formats).

5. REGRESSION RULE (mandatory): when the diff breaks behaviour that worked before (it
   modifies existing behaviour, no existing test covers the changed path, or existing
   callers get a new failure mode), write a regression test immediately, no question.
   Uncertain whether it is a regression: write the test. Proof: the test must fail at HEAD
   in its own assertion before any repair, pass at the base as the control (run it in a
   scratch worktree: `git worktree add --detach <tmp> origin/<base>`, copy the test and its
   new fixtures in, run the single-file command, `git worktree remove --force <tmp>`), and
   pass after the fix. Record `Regression proof: fails at HEAD yes; passes at base
   yes|unavailable (<reason>); passes after fix yes|pending`.

6. Generate tests for uncovered paths (only when Generation: allowed). Error handlers and
   edge cases first. Extend an existing test before creating a file. Match the conventions
   of 2-3 existing test files. Mock only services unrelated to the behaviour under test.
   Run each test: passes -> keep and report the path (the parent commits it); fails ->
   decide whether the test is wrong (correct once) or the product is wrong (keep the red
   test, report it as a product failure). Never delete or weaken a test to get green.
   Never add a production seam for a test. Never put secrets in test files.
   Do not rate tests you wrote in this pass; count them as unrated (weak).

7. Output an ASCII diagram with code paths and user flows side by side, for example:

   CODE PATHS                                   USER FLOWS
   [+] src/billing.ts                           [+] Checkout
     ├── processPayment()                         ├── [★★★ TESTED] purchase, checkout.e2e.ts:15
     │   ├── [★★★ TESTED] happy+declined+timeout   └── [GAP] [→E2E] double-click submit
     │   └── [GAP] invalid currency
     └── refundPayment()
         └── [★  TESTED] partial (no-throw only), billing.test.ts:101
   COVERAGE: 3/6 paths (50%) | QUALITY: ★★★:2 ★★:0 ★:1 | GAPS: 3 (1 E2E)
   Legend: ★★★ behaviour+edge+error | ★★ happy path | ★ smoke | [→E2E] integration | [→EVAL] LLM eval

   List every remaining gap below the diagram as a proposed test with its value card.
   Test-file count before and after: `git ls-files | grep -cE '(\.test\.|\.spec\.|_test\.|_spec\.)'`.

Report any change you made to a test, validator, CI step, timeout, threshold, snapshot or
suppression on its own line with the reason, before the JSON. A command you report names
its observed result; a command you did not run is not reported.

LAST LINE, nothing after it, one JSON object:
{"coverage_pct":N,"coverage_pct_value":N,"gaps":N,"weak_gaps":N,"tests_added":["path"],"tests_extended":["path"],"tests_rejected":[{"gap":"...","reason":"..."}],"tests_before":N,"tests_after":N,"diagram":"<markdown diagram>"}
coverage_pct = paths with any test / total; coverage_pct_value = paths with a ★★ or ★★★
test / total; gaps = paths with no test; null for an undetermined percentage, never 0.
````

## Parent processing

1. Parse the LAST line as JSON. Failure, invalid JSON or no result after about 10 minutes: stop the child, then run the same audit inline once. Partial results stay incomplete, never "passing coverage".
2. Read every test the child wrote or extended. Remove (new file) or revert with Edit (only the child's hunk) any test without a complete value card, with a duplicate `protects`, or that needed a production seam. Note each removal under `tests_rejected`.
3. Read every hunk the child made in a test, CI config or snapshot that loosens a gate (removed or skipped test, raised timeout or threshold, suppression pragma, swallowed exception). Carry each one into step 7's Gate Integrity category; the child's green is a claim until you have read it.
4. Tests the child wrote count as weak until rated. When it wrote tests, dispatch one more read-only Agent with the diagram and the surviving test paths to rate them against the ★ rubric and return `{"coverage_pct_value":N,"weak_gaps":N}` on its last line. Rating fails: skip the gate for this run and say "rating unavailable".
5. Print `Coverage: {X}% value-weighted ({Y}% any test), {gaps} gaps, {K} tests added.` Keep `diagram`, the before/after counts and each regression proof line for the PR body.

## Coverage gate

Read `Minimum:` and `Target:` from CLAUDE.md `## Test Coverage`; defaults Minimum 60%, Target 80%. The gate number X is `coverage_pct_value`; fall back to `coverage_pct` when the value is missing or above `coverage_pct` (clamp). Zero paths or a null percentage: "Coverage gate: could not determine percentage, skipping."

- **X >= target:** "Coverage gate: PASS ({X}%)." List weak paths in the PR body as proposed strengthening.
- **minimum <= X < target**, or **X < minimum**: ask.

> Shipping branch `{BRANCH}` of `{PROJECT_SLUG}`. Value-weighted coverage of the changed code is {X}% ({Y}% counting weak tests); {W} paths have only weak tests and {N} have none. {Target is {target}% | Minimum is {minimum}%, so more behaviour is unprotected than protected}.
>
> Simplify: untested paths are where the next regression slips through unnoticed. I can write tests for the gaps now ({slots} test slots left this run), or you ship and accept the risk on record.
>
> RECOMMENDATION: Choose A because weakly covered and untested paths are where regressions hide, and the context is loaded now.
>
> A) Generate tests for the gaps and strengthen weak tests ({slots} slots left), then re-check
>    Completeness: 10/10, effort: human: 0 / CC: ~5-10 min, tier: task
> B) Ship anyway; the PR body says "Coverage gate: {X}%, risk accepted"
>    Completeness: 5/10 (shortcut), effort: human: 0 / CC: 0, tier: task
> C) These paths do not need tests; the PR body lists them as intentionally uncovered (only offered when X >= minimum)
>    Completeness: 7/10, effort: human: ~1 min / CC: 0, tier: task

With no generation pass left, option A becomes "list the gaps as proposed tests in the PR body" and dispatches nothing. `YTSTACK_NON_INTERACTIVE: true`: take A for true gaps only within the remaining slots (never edit weak tests unattended), log the auto-pick, list weak paths in the PR body.

The gate only asks; it never hard-fails. Generated tests stay uncommitted until step 12 and must pass before they are committed.

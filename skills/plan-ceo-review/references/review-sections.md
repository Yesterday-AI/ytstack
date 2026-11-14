# plan-ceo-review: review sections, required outputs, report

Read this file in full when Step 0 is settled (mode selected, Step 0 work for that mode done). Do not work from memory. The SKILL.md procedure points here at step 11 and returns to step 12 afterwards.

## Review Sections (11 sections, after scope and mode are agreed)

**Anti-skip rule.** Evaluate Sections 1-10 in full for every plan, including strategy, spec, code and infra plans. Run Section 11 if accepted work adds or changes UI screens, components, user interactions, frontend frameworks, user-visible states, mobile/responsive behavior or the design system. Otherwise record `SKIPPED (no UI scope)`. In evaluated sections, say "No issues found" only when there are zero findings.

**Use the review depth chosen in Step 0.** For scope prioritization, use each section to decide inclusion and feasibility under the accepted constraints. Diagrams and maps show candidate boundaries, failure mechanisms, feasibility conditions and unresolved risks. Resolve material blockers now; revisit priorities when new evidence changes them. Leave non-blocking implementation choices pending with an owner and the verification they need.

- **Strategy-only depth:** capability-level rows and "implementation owner must prove ___" notes instead of method-level registries. This is the usual depth in concept mode (a pitch has no code yet).
- **Implementation-ready depth:** the concrete method/codepath, contract, rescue and test rows.
- **One narrow decision:** apply every section to that one choice and its dependencies.

Report what is approved, what is verified and what remains unchosen. Finishing prioritization does not mean the implementation is ready.

**Preserve accepted requirements.** Compare the proposed approach with stated invariants and acceptance criteria (in milestone mode: the exit criteria in `M###-CONTEXT.md`). Report gaps and propose remedies, including omitted mechanisms in HOLD SCOPE. Never weaken a guarantee, accept its violation or change a test to expect it. Low frequency, bounded impact and "we'll document it" do not meet a stricter requirement. Changing a requirement needs the user's explicit word; until then keep both the proposal and the original gap unresolved. Carry prior approvals into findings, tasks and the report.

### How to ask questions

Use the decision procedure from SKILL.md step 6 (0D) and the ytstack AskUserQuestion format:

- **One decision = one AskUserQuestion call.** Use 0D's boundaries, not topic labels.
- Describe the concrete problem with file/line references. Offer 2-3 options, including "do nothing" when reasonable.
- Give each option one line covering effort, risk and maintenance.
- The recommended option offers a complete remedy for this one issue: rescue behavior, verification and failure visibility. Exclude unrelated work; ask about independent findings and new TODOs separately.
- Connect the recommendation to one engineering preference (SKILL.md "Engineering preferences") in one sentence.
- Label questions `D<N>` and cite the ledger row ID so reopened decisions keep their history.
- An "obvious fix" still needs approval when no exact accepted choice covers it.

Use **CRITICAL GAP** / **WARNING** / **OK** for scannability.

### Mode quick reference

Mode controls which work is included, not the depth or section coverage. Review and produce outputs for accepted work in every mode.

| Step | SCOPE EXPANSION | SELECTIVE EXPANSION | HOLD SCOPE | SCOPE REDUCTION |
|------|-----------------|---------------------|------------|-----------------|
| Scope proposals | Offer additions one by one | Offer cherry-picks one by one | No expansions | Offer cuts one by one |
| 10x check | Required; additions need approval | Required; additions need approval | Skip | Skip |
| Platonic ideal | Required | Skip | Skip | Skip |
| Delight opportunities | At least 5, each opt-in | At least 5, each opt-in | Skip | Skip |
| Complexity | Review accepted ambition | Review baseline and accepted additions | Simplest correct accepted scope | Minimum valuable scope |
| Temporal interrogation (0I) | Run | Run | Run | Skip |
| CEO scope summary + spec review (0H) | Write | Write | Skip | Skip |
| Future direction (Section 10) | Review accepted trajectory | Review accepted cherry-picks | Maintainability; no expansions | Maintainability of remaining scope |
| Design (Section 11) | If UI scope | If UI scope | If UI scope | If UI scope |

### Working review decisions (Analyze -> Resolve -> Apply)

At each section's **Decision gate**, run these three steps. Continue the decision ledger with each row's owner section. Review only; do not change code.

**Analyze.** Check the plan, the source and the actual approvals. Correct false claims (and test or runbook text that depends on them) without changing approved behavior. Preserve contracts and mitigations even if later text omits them. Flag approval conflicts. Code you could not read proves neither failure nor safety: record unknown risks with their owner and required verification.

**Resolve.** Take the first path that applies to each finding:

1. This section needs a new choice, or evidence warrants reopening a prior answer: run 0D (SKILL.md step 6) through its post-answer save, then come back here to Apply. Use the same row ID in the ledger and the question. Resolve critical risks now.
2. An exact prior answer covers it: cite that answer and go to Apply.
3. A non-blocking choice belongs to a later section: reference its pending row and owner; leave it undecided here.

Keep independent safety fixes and throughput improvements in separate rows. No path selects the mode again.

**Apply.** Check the working review against each answer's exact scope. Preserve existing content, approved behavior, required implementation, tests and success/failure contracts. Leave unapproved remedies and extra verification pending; do not put them into tasks or prescribe them in diagrams.

Record findings and dispositions, then move to the next section. Do not write a later section's conclusions before reviewing it. After Sections 1-10 and Section 11 (or its skip), return to SKILL.md step 12.

### Section 1: Architecture Review

Publish **Current scope** in chat before the analysis: the selected mode and its rationale; each governing ledger row's ID, disposition and answer reference; accepted, deferred, rejected and pending work kept apart. This is a scope update, not another mode question. Then say `Section 1: Architecture Review`.

Evaluate and diagram:

- System design and component boundaries. Draw the dependency graph.
- Data flow, all four paths. For every new data flow, ASCII-diagram the happy path, the nil path (input missing), the empty path (input present but empty or zero-length) and the error path (upstream call fails).
- State machines. ASCII diagram for every new stateful object, including impossible or invalid transitions and what prevents them.
- Coupling. What new coupling exists, and is it justified? Draw before/after dependencies.
- Scaling. What breaks first under 10x and 100x load?
- Single points of failure. Map them.
- Security architecture. Auth boundaries, data access patterns, API surfaces. For each new endpoint or data mutation: who can call it, what do they get, what can they change?
- Production failure scenarios. For each integration point, one realistic failure and whether the plan handles it.
- Rollback posture. If this ships broken, name the rollback path and its time.
- Value test for artifacts about the work. When the plan adds a status report, audit matrix, certificate, meta-report or conformance check that nothing consumes, ask: who uses it, what decision or delivered behavior changes because it exists, why this is the smallest useful version, and when it retires. An explicit user request answers the first two (record it as provenance); the last two still need answers. A credible, named preventive risk is a valid answer. Manufacturing a consumer to pass the question is the pathology, not an answer. Carve-out: product observability (dashboards, alerts, runbooks for the shipped system) is launch scope, never a process artifact; user-facing docs and agent-consumed instructions are product.

EXPANSION and SELECTIVE EXPANSION add: what would make this architecture elegant and obvious to a new engineer? What infrastructure makes it a platform for later features? In SELECTIVE EXPANSION, check each accepted cherry-pick's architectural fit; flag ones that create coupling or do not integrate cleanly (a chance to revisit with new information).

Required ASCII diagram: full system architecture showing new components and their relationships to existing ones.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 2: Error & Rescue Map

This section catches silent failures. Strategy-only depth: map each retained capability, integration or data boundary that can fail. Implementation-ready depth: map every new method, service or codepath that can fail. Same table shape for both:

```
  METHOD/CODEPATH          | WHAT CAN GO WRONG           | EXCEPTION CLASS
  -------------------------|-----------------------------|-----------------
  ExampleService#call      | API timeout                 | TimeoutError
                           | API returns 429             | RateLimitError
                           | malformed JSON              | JSONParseError
  -------------------------|-----------------------------|-----------------

  EXCEPTION CLASS              | RESCUED?  | RESCUE ACTION          | USER SEES
  -----------------------------|-----------|------------------------|------------------
  TimeoutError                 | Y         | Retry 2x, then raise   | Temporary outage
  RateLimitError               | Y         | Backoff + retry        | Transparent
  JSONParseError               | N <- GAP  | --                     | 500 error <- BAD
```

Rules:

- Catch-all handling (`rescue StandardError`, `catch (Exception e)`, `except Exception`) is a smell. Name the specific exceptions.
- Generic-only logging is not enough. Log what was attempted, with which arguments, for which user or request.
- Every rescued error retries with backoff, degrades gracefully with a user-visible message, or re-raises with added context. "Swallow and continue" is almost never acceptable.
- For each GAP (unrescued error that should be rescued): specify the rescue action and what the user should see.
- For LLM/AI calls: treat malformed JSON, empty output, valid-looking but wrong JSON, and refusals as distinct failure modes.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 3: Security & Threat Model

Security is not a sub-bullet of architecture. Evaluate:

- Attack surface expansion: new endpoints, parameters, file paths, background jobs.
- Input validation: for every new user input, is it validated, sanitized and rejected loudly on failure? What happens with nil, empty string, string where an integer is expected, overlong strings, unicode edge cases, HTML/script injection attempts?
- Authorization: is every new data access scoped to the right user or role? Can user A read user B's data by changing an ID?
- Secrets and credentials: new secrets? In env vars or a secret store, not hardcoded? Rotatable?
- Dependency risk: new packages and their security track record.
- Data classification: PII, payment data, credentials; handling consistent with existing patterns?
- Injection vectors: SQL injection (attacker input executed as database commands), command, template, and prompt injection (attacker text in an LLM input hijacks the model's instructions). Check all.
- Audit logging for sensitive operations.

For each finding: threat, likelihood (High/Med/Low), impact (High/Med/Low), and whether the plan mitigates it.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 4: Data Flow & Interaction Edge Cases

Trace data and user interactions adversarially.

**Data flow tracing.** For every new data flow, an ASCII diagram `INPUT -> VALIDATION -> TRANSFORM -> PERSIST -> OUTPUT` with shadow paths for nil/empty/wrong type, invalid/too long, exception/timeout/out-of-memory, conflict/duplicate/lock, stale/partial/encoding. For each node: what happens on each shadow path, and is it tested?

**Async ordering.** For flows that share mutable state (watch for race conditions: two things happen at the same time and step on each other):

1. **Define the boundary.** State the invariant and its exact caller/time boundary. Draw a combined ASCII schedule with one column per operation and one for the shared state.
2. **Exercise both orders.** For each pair of overlapping awaits that can affect the invariant, show both completion orders. At each relevant await, callback or job handoff: pause, let a competing operation finish, resume, then start a fresh consumer. Exclude an order only by naming the mechanism that prevents it.
3. **Compare the result** against the invariant. The invariant is a requirement, not proof. If safe, name the preventing mechanism. Separate diagrams, one favorable schedule, single-threaded execution and atomic calls do not prove ordering across awaits.
4. **Specify regression proof.** Test the relevant completion orders with controlled pause/release points. Relevant pairs are enough; exhaustive permutations are not needed.

**Interaction edge cases.** For every new user-visible interaction: `INTERACTION | EDGE CASE | HANDLED? | HOW?`. Include double-click and stale submit (is it OK if the action runs twice?), navigate away / timeout / retry, zero / large / changing lists, failed / duplicate / backlogged jobs. Flag each unhandled case as a gap and specify the fix.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 5: Code Quality Review

- Code organization: does new code fit existing patterns?
- Duplicated behavior: if the same logic exists elsewhere, flag it with file and line; similar-looking code alone is not a reason to extract.
- Naming: are new classes, methods and variables named for what they do, not how?
- Error handling patterns (Section 2 maps specifics; this section reviews the patterns).
- Missing edge cases: nil, empty, 429s and timeouts, boundary values.
- Over-engineering: abstractions for problems that do not exist yet.
- Under-engineering: happy-path fragility, missing defensive checks.
- Cyclomatic complexity: flag any new method that branches more than 5 times; propose a refactor.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 6: Test Review

Carry requested or approved coverage forward without re-asking. For an unresolved test-method choice or extra verification scope, name the distinct regression the existing tests miss and resolve that choice through 0D before prescribing it.

Diagram every new thing the plan introduces: UX flows, data flows, codepaths, background jobs and async work, integrations and external calls, error/rescue paths (cross-reference Section 2). For each item:

- Which test type covers it (unit / integration / system / E2E)?
- Does the plan have that test? If not, draft its header within approved coverage; keep new verification proposals pending until decided.
- Happy-path test, failure-path test (which failure, specifically), edge-case test (nil, empty, boundaries, concurrent access).

Assertion check per behavior:

1. **Map the requirement.** Name its observable assertion, a wrong result it rejects, and its `no_claim`: one sentence on what a green result does not prove and which fixtures or mocks stand in for what (`no_claim=provider acceptance (mocked provider; unit only)`, or `no_claim=none beyond protects`). Write it yourself; never ask the user for it. Translate counts, conditions and quantifiers exactly; never weaken an exact count to a lower bound.
2. **Reuse settled proof.** Picking an existing probe or spelling out a determined check is implementation work, not another approval. Verify the caller's path; helper coverage alone does not prove it.
3. **Resolve real gaps.** Explain what the existing requirement fails to cover before calling a check missing. Ask only for an unresolved behavioral choice, a new outcome, or an independent uncovered failure mode. Never silently add, defer or waive a missing behavioral assertion.

Test ambition check (all modes), per new feature:

- Which test would make you confident shipping at 2am on a Friday?
- Which test would a hostile QA engineer write to break this?
- What is the chaos test?

Pyramid check: many unit, fewer integration, few E2E, or inverted? Flakiness risk: flag tests depending on time, randomness, external services or ordering. Load/stress needs for frequently called or data-heavy codepaths. For LLM or prompt changes: if the repo's CLAUDE.md / AGENTS.md lists eval suites or prompt file patterns, name which suites must run, which cases to add and which baselines to compare against.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 7: Performance Review

- N+1 queries (one query for a list, then one per item): does ORM-backed access preload or batch?
- Memory: the maximum production size of each new data structure.
- Database indexes for every new query.
- Caching for expensive computations or external calls.
- Background jobs: worst-case payload, runtime, retry behavior.
- Slow paths: the top 3 slowest new codepaths with estimated p99 latency.
- Connection pool pressure: new DB, Redis or HTTP connections.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 8: Observability & Debuggability Review

New systems break. This section makes sure you can see why.

- Logging: structured lines at entry, exit and each significant branch of new codepaths.
- Metrics: what tells you the feature works, and what tells you it is broken?
- Tracing: trace IDs propagated across new cross-service or cross-job flows?
- Alerting: which new alerts should exist?
- Dashboards: which panels on day 1?
- Debuggability: if a bug is reported 3 weeks after ship, can you reconstruct it from logs alone?
- Admin tooling: new operational tasks that need an admin UI or a script.
- Runbooks: the operational response to each new failure mode.

EXPANSION and SELECTIVE EXPANSION add: what observability would make this a joy to operate (including accepted cherry-picks)?

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 9: Deployment & Rollout Review

- Migration safety: backward-compatible, zero-downtime, table locks?
- Feature flags: should any part sit behind one?
- Rollout order: migrate first, deploy second?
- Rollback plan, step by step.
- Deploy-time risk window: old and new code running at once, what breaks?
- Environment parity: tested in staging?
- Post-deploy verification: first 5 minutes, first hour.
- Smoke tests that run right after deploy.

EXPANSION and SELECTIVE EXPANSION add: what deploy infrastructure would make shipping this routine? Do accepted cherry-picks change the risk profile?

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 10: Long-Term Trajectory Review

- Technical debt introduced: code, operational, testing, documentation.
- Path dependency: does this make future changes harder?
- Knowledge concentration: enough documentation for a new engineer?
- Reversibility, rated 1-5 (1 = one-way door, 5 = easily reversible).
- Ecosystem fit with the repo's framework conventions.
- The 1-year question: is this obvious to a new engineer in 12 months?

EXPANSION and SELECTIVE EXPANSION add: what comes after this ships (phase 2, phase 3), and does the architecture support that? Platform potential for other features? SELECTIVE EXPANSION only: were the right cherry-picks accepted, and did a rejected expansion turn out to be load-bearing for an accepted one?

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

### Section 11: Design & UX Review (skip if no UI scope)

The CEO calling in the designer. Not a pixel-level audit; this checks that the plan has design intent.

- Information architecture: what does the user see first, second, third?
- Interaction state coverage: `FEATURE | LOADING | EMPTY | ERROR | SUCCESS | PARTIAL`.
- User journey coherence: storyboard the emotional arc.
- AI slop risk: does the plan describe generic UI patterns?
- `DESIGN.md` alignment, when the repo has one (preamble flag `DESIGN_MD`).
- Responsive intent: is mobile planned or an afterthought?
- Accessibility basics: keyboard navigation, screen readers, contrast, touch targets.

EXPANSION and SELECTIVE EXPANSION add: what would make this UI feel inevitable? Which 30-minute touches would make users think "oh nice, they thought of that"?

Required ASCII diagram: user flow with screens/states and transitions. After implementation, a visual check of the rendered UI catches what a plan review cannot.

**Decision gate.** Analyze -> Resolve -> Apply before continuing.

## Outside voice integration rule

Used by SKILL.md step 12. Apply Analyze to each outside finding before adding it to the ledger. Correct unsupported claims and keep unknown risks. Reviewer agreement is not new evidence and not approval. Reopen a choice only for a supported material risk, citing its prior answer and the new evidence; resolve it through 0D before amending the review. For an outside finding, use one of these menus instead of fresh alternatives:

- **Policy or implementation:** A) Apply this change; B) Keep this row's current value; C) Investigate before choosing; D) Defer this proposed change only.
- **Whole-candidate scope:** A) Include; B) Defer; C) Cut; D) Hold (stop and discuss without changing the prior disposition). Two candidates take two rows.

Report every finding, its disposition, required verification and any remaining disagreement.

## Resolve remaining TODO choices

**Keep the selected mode.** In HOLD SCOPE, a potential TODO must address an evidenced gap in the accepted scope or its required correctness and operability. Hypothetical capacity, optional features and alternatives to an adequate approved remedy are expansions, even when labelled TODOs; do not surface them in HOLD SCOPE. Expansion modes keep their opt-in ceremony.

Only unanswered TODO proposals reach this menu. Never batch TODOs: one per question, through all four 0D steps. If none remain, record that and continue. For each TODO, describe:

- **What:** one-line description of the work.
- **Why:** the concrete problem it solves or value it unlocks.
- **Pros / Cons:** what you gain; cost, complexity, risk.
- **Context:** enough that someone picking it up in 3 months understands the motivation, the current state and where to start.
- **Effort:** human-team and CC-assisted S/M/L/XL. Rough backlog mapping S->S, M->S, L->M, XL->L (size classes, not time ratios).
- **Priority:** P1/P2/P3.
- **Depends on / blocked by.**

Options: A) Add to `TODOS.md` (or, when the repo keeps no `TODOS.md`, to the review file's "Deferred" list); B) Skip, not valuable enough; C) Keep in the current plan as required work (only when it is already accepted scope).

## Approval readiness

Check the ledger before Required Outputs. For each approved remedy:

1. Cite its actual answer, exact prior approval or logged non-interactive auto-pick. Mode and navigation answers are not remedy approvals; an approach approves only its explicit commitments and their directly required tests.
2. Confirm the review applies only that answer's scope. Independent remedies and extra verification need their own rows.
3. Keep declined, deferred and unanswered changes out of accepted work. An approved delivery-scope deferral is settled; deferring a needed policy decision leaves it unresolved and it shows in the report.

If a draft lacks approval, mark it pending and run 0D. At the end of the ledger record `Approval readiness: PASS` with the checked row IDs and their answer references. A later substantive change invalidates it.

## Required outputs

Write these into the review body (SKILL.md step 14 names the file), before the terminal report.

### Review facts

Derive from the ledger and the completed sections: mode, findings, unresolved choices, critical gaps, scope dispositions, outside-voice coverage. Status is `clean` only with zero unresolved choices and zero critical gaps; otherwise `issues_open`.

### Reality rows

The `REALITY:` lines from 0B, one per row, kept above the Completion Summary that tallies them.

### "NOT in scope"

Deferred and rejected work listed separately, each with its actual answer and a one-line rationale. Deferred work also goes to `TODOS.md` when the repo keeps one; rejected work does not.

### "What already exists"

Existing code and flows that partly solve sub-problems, and whether the plan reuses them.

### "Dream state delta"

Where this plan leaves us relative to the 12-month ideal from 0C.

### Error & Rescue Registry (from Section 2)

Match the approved depth. Implementation-ready: every method that can fail, its exception classes, rescue status/action and user impact. Strategy-only: capability rows with failure mechanism, user impact, known safeguards and the owner who must verify each unknown. Do not invent method contracts.

### Failure Modes Registry

```
  CODEPATH | FAILURE MODE   | RESCUED? | TEST? | USER SEES?     | LOGGED?
  ---------|----------------|----------|-------|----------------|--------
```

Any row with RESCUED=N, TEST=N and USER SEES=Silent is a **CRITICAL GAP**. Strategy-only rows name the capability in CODEPATH and mark unknown coverage as unknown with a verification owner.

### Scope Expansion Decisions (EXPANSION and SELECTIVE EXPANSION only)

Reference the CEO scope summary from 0H. List dispositions without asking again: Accepted, Deferred, Skipped.

### Diagrams (mandatory, all that apply)

System architecture; data flow with shadow paths; state machine; error flow; deployment sequence; rollback flowchart.

### Stale diagram audit

List every ASCII diagram in files this plan touches. Still accurate?

### Implementation tasks

Turn findings into tasks within the approved depth. Implementation-ready tasks describe the build; strategy-only tasks name the next research, design or verification action and its owner. List known files only (unknown: "to be determined"). Each task needs a concrete verification step.

In milestone mode these are **slice candidates** for `ytstack:slice-milestone`, not ytstack tasks: do not create `M###-S##-T##` files. In concept mode they feed `ytstack:plan-milestone` after init.

```markdown
### Implementation tasks
Synthesized from this review's findings. Each derives from a specific finding above.

- [ ] **T1 (P1, human: ~2h / CC: ~15min)** -- <component> -- <imperative title>
  - Surfaced by: <section> -- <finding or line reference>
  - Files: <paths to touch>
  - Verify: <test command or manual check>
```

Rules: P1 blocks ship, P2 should land on the same branch, P3 is a follow-up TODO. No finding, no invented task. A section with zero findings gets `_No new tasks from <section>._`. Effort ratios (human time / CC time) as a default: scaffolding ~100x, tests ~50x, features ~30x, bug fix with regression ~20x, architecture ~5x, research ~3x; adjust and state the assumption.

### Completion Summary

Use the full mode name from 0E. "System Audit" summarizes repository findings from step 3 and the sections. **Lake Score** (complete options chosen): take answered questions that offered a 10/10 option (exclude mode and pure scope choices), count a reopened choice once with its latest answer; Y = eligible questions, X = how many chose the 10/10 option; report X/Y or `N/A`.

```
  +====================================================================+
  |            CEO PLAN REVIEW -- COMPLETION SUMMARY                   |
  +====================================================================+
  | Mode selected        | [full mode name from 0E]                    |
  | Review mode          | [milestone M### / concept <pitch>]          |
  | System Audit         | [key findings]                              |
  | Step 0               | [mode + key decisions]                      |
  | Section 1  (Arch)    | ___ issues found                            |
  | Section 2  (Errors)  | ___ error paths mapped, ___ GAPS            |
  | Section 3  (Security)| ___ issues found, ___ High severity         |
  | Section 4  (Data/UX) | ___ edge cases mapped, ___ unhandled        |
  | Section 5  (Quality) | ___ issues found                            |
  | Section 6  (Tests)   | Diagram produced, ___ gaps                  |
  | Section 7  (Perf)    | ___ issues found                            |
  | Section 8  (Observ)  | ___ gaps found                              |
  | Section 9  (Deploy)  | ___ risks flagged                           |
  | Section 10 (Future)  | Reversibility: _/5, debt items: ___         |
  | Section 11 (Design)  | ___ issues / SKIPPED (no UI scope)          |
  +--------------------------------------------------------------------+
  | NOT in scope         | written (___ items)                         |
  | What already exists  | written                                     |
  | Dream state delta    | written                                     |
  | Error/rescue registry| ___ rows, ___ CRITICAL GAPS                 |
  | Failure modes        | ___ total, ___ CRITICAL GAPS                |
  | TODOs                | ___ proposed, ___ added                     |
  | Scope proposals      | ___ proposed, ___ accepted (EXP + SEL)      |
  | CEO scope summary    | written / skipped by mode                   |
  | Spec review          | score _/10, ___ iterations / unavailable    |
  | Outside voice        | completed / unavailable / skipped (reason)  |
  | Lake Score           | X/Y recommendations chose complete option   |
  | Diagrams produced    | ___ (list types)                            |
  | Stale diagrams found | ___                                         |
  | Unresolved decisions | ___ (listed below)                          |
  | Reality rows         | ___/6 rows, ___ unverified premises         |
  +====================================================================+
```

### Unresolved decisions

Any question left unanswered goes here. Never silently default.

## Terminal report and save

The report is always the **last** `## ` section of the review file. Format:

```markdown
## CEO REVIEW REPORT

| Field | Value |
|-------|-------|
| Date | YYYY-MM-DD |
| Reviewed | <files> |
| Mode | <full mode name> |
| Status | CLEAR / ISSUES OPEN |
| Findings | <N proposals, A accepted, D deferred> or <mode: X, N critical gaps> |
| Outside voice | <subagent: N findings, R resolved, U unresolved> or <unavailable / skipped: reason> |

**VERDICT:** <proceed / proceed with changes / rescope / kill> -- <one line why>. Engineering review: <required next / already done>.

NO UNRESOLVED DECISIONS
```

Display `clean` as CLEAR and `issues_open` as ISSUES OPEN. The last non-whitespace line is either the exact unbolded `NO UNRESOLVED DECISIONS`, or the bold label `**UNRESOLVED DECISIONS:**` followed by one bullet per open item, with the last bullet as the final line. No trailing prose.

Save with a delete-then-append flow:

1. Read the review file. Locate any existing `## CEO REVIEW REPORT` section.
2. If found, delete it with Edit (from that heading to the next `## ` heading or end of file). If the Edit fails, report the error and stop.
3. Write the review body (the `## CEO review YYYY-MM-DD` section with all required outputs) and the new report at the end of the file: Read the file again, then Edit with the current suffix, or Write the complete file when it does not exist.
4. **Read-back gate.** Read the saved file. Verify the accepted changes, the full review body, the verdict and the unresolved-decisions status, with `## CEO REVIEW REPORT` as the last section. If writing or verification fails, report the error and stop: the review is **not persisted** and the skill does not claim completion.

Never replace the report in place; delete it and append the new one at the end.

After the Read-back gate passes, publish the Completion Summary in chat (not appended after the report in the file). Return to SKILL.md step 15.

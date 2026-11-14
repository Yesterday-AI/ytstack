# Pitch artifact templates (Phase 5)

Read this file when writing the pitch artifact. Pick the template that matches the session mode. Placeholders in `{braces}` are filled from the session; a section whose placeholder says "omit" disappears entirely when its condition holds.

**Decision-record concision.** The artifact is a decision record, not a transcript: one bullet per decision with its why; an approach the user ruled out DURING the session gets one line (name + rejection reason), never a resurrected full section that re-argues the case; omit template sections that are empty or that restate what's already settled. No page cap -- extra length must come from genuinely open questions, not template completeness.

**Frontmatter is a contract.** `name:` and `one-liner:` are read by `ytstack:init-project` (and `plan-ceo-review` / `plan-eng-review` read the file) to populate PROJECT.md without re-asking. Keep both on one line each, unquoted, no line breaks. The one-liner follows `[noun] for [audience] that [verb + outcome]`.

## Startup mode

```markdown
---
name: {project or feature name}
one-liner: {[noun] for [audience] that [verb + outcome]}
mode: startup
status: draft
date: {YYYY-MM-DD}
branch: {BRANCH from the preamble, or none}
supersedes: {path of the prior pitch this one replaces; omit the line if none}
---

# Design: {title}

## Problem Statement
{from Phase 2A}

## Demand Evidence
{from Q1 -- specific quotes, numbers, behaviors demonstrating real demand}

## Status Quo
{from Q2 -- concrete current workflow users live with today}

## Target User and Narrowest Wedge
{from Q3 + Q4 -- the specific human and the smallest version worth paying for}

## Constraints
{from Phase 2A}

## Premises
{from Phase 3, each with agree / revised; a named EUREKA from Phase 2.75 goes here}

## Second Opinion
{only if Phase 3.5 ran: the independent cold read -- steelman, key insight, challenged premise, prototype suggestion, verbatim or close paraphrase. Omit the section if it did not run.}

## Approaches Considered
### Approach A: {name}
{from Phase 4}
### Approach B: {name}
{from Phase 4}

## Recommended Approach
{chosen approach with rationale}
Wireframe: {sketch file name, or "none (<reason>)"; omit the line when the approach has no UI}

## Open Questions
{any unresolved questions from the session}

## Success Criteria
{measurable criteria from Phase 2A}

## Distribution Plan
{how users get the deliverable -- binary download, package manager, container image, web service}
{CI/CD pipeline for building and publishing -- GitHub Actions, manual release, auto-deploy on merge?}
{omit this section if the deliverable is a web service with an existing deployment pipeline}

## Dependencies
{blockers, prerequisites, related work}

## The Assignment
{one concrete real-world action the founder should take next -- not "go build it"}

## What I noticed about how you think
{observational, mentor-like reflections referencing specific things the user said during the session. Quote their words back to them -- don't characterize their behavior. 2-4 bullets.}
```

## Builder mode

```markdown
---
name: {project or feature name}
one-liner: {[noun] for [audience] that [verb + outcome]}
mode: builder
status: draft
date: {YYYY-MM-DD}
branch: {BRANCH from the preamble, or none}
supersedes: {path of the prior pitch this one replaces; omit the line if none}
---

# Design: {title}

## Problem Statement
{from Phase 2B}

## What Makes This Cool
{the core delight, novelty, or "whoa" factor}

## Constraints
{from Phase 2B}

## Premises
{from Phase 3}

## Second Opinion
{only if Phase 3.5 ran: the independent cold read -- coolest version, key insight, existing tools, prototype suggestion. Omit the section if it did not run.}

## Approaches Considered
### Approach A: {name}
{from Phase 4}
### Approach B: {name}
{from Phase 4}

## Recommended Approach
{chosen approach with rationale}
Wireframe: {sketch file name, or "none (<reason>)"; omit the line when the approach has no UI}

## Open Questions
{any unresolved questions from the session}

## Success Criteria
{what "done" looks like}

## Distribution Plan
{how users get the deliverable -- binary download, package manager, container image, web service}
{CI/CD pipeline for building and publishing -- or "existing deployment pipeline covers this"}

## Next Steps
{concrete build tasks -- what to implement first, second, third}

## The Assignment
{one concrete real-world action the builder should take next}

## What I noticed about how you think
{observational, mentor-like reflections referencing specific things the user said during the session. Quote their words back to them -- don't characterize their behavior. 2-4 bullets.}
```

## Reviewer Concerns (added by the spec review, Phase 5)

When the spec review stops with findings still open, append this section verbatim from the reviewer's output. Recording a concern does not mark it fixed.

```markdown
## Reviewer Concerns
Review: {rounds run} round(s), stop reason {PASS | MAX_ROUNDS | UNREVIEWED: <cause>}
1. [{blocking|minor}] {dimension}: {problem} -- suggested remedy: {remedy}
```

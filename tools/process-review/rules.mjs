// Rules that turn metrics into suggestions. One object per rule:
//   id, group (flow | review | ci | quality), severity (high | medium | low), name,
//   th: default threshold, min: smallest sample the rule judges,
//   check(m, th) -> { n, hit, problem, good }   n = sample size; problem/good are sentences with counts
//   why, action, ref (source and year of the threshold, when it has one)
// config.json can set { "rules": { "<id>": { "threshold": 0.3 } } } or { "off": true }.
// Thresholds without a ref are coaching defaults, not proven standards.
const pct = (x) => `${(x * 100).toFixed(0)} %`;
const of = (share, total) => Math.round((share ?? 0) * total);

export const RULES = [
  {
    id: "later-rounds-low-yield", group: "review", severity: "high", name: "Later review rounds rarely find a blocker", th: 0.6, min: 20,
    check: ({ total: { efficiency: e } }, th) => {
      const n = e.laterClean + e.laterNonBlocking + e.laterBlocking, low = e.laterClean + e.laterNonBlocking;
      return { n, hit: low / n >= th, problem: `${low} of ${n} later review rounds with a readable result found nothing that blocks (${e.laterClean} nothing at all, ${e.laterNonBlocking} only non-blocking findings).`, good: `Later review rounds earn their cost: ${e.laterBlocking} of ${n} found a blocker.` };
    },
    why: "Every round costs a reviewer run, a CI run and waiting time. A round that finds nothing blocking delays the merge without protecting it.",
    action: "Let a non-blocking review stand: non-blocking findings go into the author's next pull request. A later round reviews only the fixes and the changed lines.",
  },
  {
    id: "rounds-after-merge-only", group: "review", severity: "medium", name: "Re-reviews after merging the base branch", th: 0.1, min: 20,
    check: ({ total: { efficiency: e } }, th) => ({ n: e.laterRounds, hit: e.laterAfterMergeOnly / e.laterRounds >= th, problem: `${e.laterAfterMergeOnly} of ${e.laterRounds} later rounds followed nothing but merge commits of the base branch.`, good: `Only ${e.laterAfterMergeOnly} of ${e.laterRounds} later rounds followed a mere merge of the base branch.` }),
    why: "The author changed nothing, yet the whole pull request was reviewed again.",
    action: "After a clean merge of the base branch, carry the last review over: compare the added and removed lines and confirm in one line instead of a full round.",
  },
  {
    id: "many-rounds", group: "review", severity: "medium", name: "Pull requests with three or more review rounds", th: 0.1, min: 30,
    check: ({ total: { efficiency: e } }, th) => ({ n: e.reviewed, hit: e.threePlusShare >= th, problem: `${of(e.threePlusShare, e.reviewed)} of ${e.reviewed} reviewed pull requests needed three or more rounds (${pct(e.threePlusShare)}).`, good: `Only ${pct(e.threePlusShare)} of the reviewed pull requests needed three or more rounds.` }),
    why: "Three rounds mean the second fix did not settle the review: the task was unclear, the pull request too large, or the reviewer keeps finding new things.",
    action: "Stop before the third round: a person or coordinator decides what still has to change. Read the outliers below for the common cause.",
  },
  {
    id: "first-pass-low", group: "flow", severity: "medium", name: "Few pull requests pass on the first attempt", th: 0.5, min: 30,
    check: ({ total: { efficiency: e } }, th) => ({ n: e.firstPassN, hit: e.firstPassShare < th, problem: `${of(e.firstPassShare, e.firstPassN)} of ${e.firstPassN} pull requests passed on the first attempt (first CI run green and first review not blocking): ${pct(e.firstPassShare)}.`, good: `${pct(e.firstPassShare)} of the pull requests passed on the first attempt (first CI run green, first review not blocking).` }),
    why: "Everything that does not pass at once is babysitting: fix, push, wait for CI and review again.",
    action: "Move the checks that fail most often to before the push (the same lint, type and test commands CI runs), and give authors the reviewer's checklist up front.",
  },
  {
    id: "slow-first-review", group: "flow", severity: "medium", name: "Pull requests wait for their first review", th: 4, min: 30,
    check: ({ total: { efficiency: e } }, th) => ({ n: e.firstReviewMedianH === null ? 0 : e.reviewed, hit: e.firstReviewMedianH > th, problem: `Half of the pull requests wait more than ${e.firstReviewMedianH} hours for their first review.`, good: `The first review arrives after ${e.firstReviewMedianH} hours (median).` }),
    why: "Waiting for pickup is the phase authors cannot shorten themselves.",
    action: "Agree on a time to first review and name who picks up; let a bot or agent reviewer answer first where one exists.",
    ref: "LinearB 2026 benchmarks: pickup under 1 h elite, 1 to 4 h good (75th percentile of vendor customers)",
  },
  {
    id: "large-prs", group: "flow", severity: "low", name: "Large pull requests", th: 228, min: 30,
    check: ({ total: { merged, efficiency: e } }, th) => ({ n: merged, hit: e.sizeMedian > th, problem: `The median pull request changes ${e.sizeMedian} lines.`, good: `The median pull request changes ${e.sizeMedian} lines.` }),
    why: "Large changes are reviewed worse and collide more often with other work.",
    action: "Split by behaviour, not by file; keep generated files and lock files out of the count (ignorePaths).",
    ref: "LinearB 2026 benchmarks: under 100 changed lines elite, over 228 needs focus (75th percentile of vendor customers)",
  },
  {
    id: "ci-hours-not-green", group: "ci", severity: "high", name: "CI time spent on runs that did not end green", th: 0.2, min: 100,
    check: ({ ci }, th) => { const c = ci?.prBranches ?? ci?.all; return { n: c?.runs ?? 0, hit: c.hoursNotGreen / c.hours >= th, problem: `${c.hoursNotGreen} of ${c.hours} CI hours on pull request branches went to runs that were cancelled or failed (${pct(c.hoursNotGreen / c.hours)}).`, good: `Only ${pct(c.hoursNotGreen / c.hours)} of the CI hours on pull request branches went to cancelled or failed runs.` }; },
    why: "Runners are the shared bottleneck when many pull requests are open; time on runs nobody waits for delays every other pull request.",
    action: "Collect changes and push once; cancel superseded runs at the start, not the end (concurrency groups); run cheap checks first so a failure stops the expensive jobs.",
  },
  {
    id: "ci-cancelled", group: "ci", severity: "medium", name: "Many cancelled CI runs", th: 0.2, min: 100,
    check: ({ ci }, th) => { const c = ci?.prBranches ?? ci?.all; return { n: c?.runs ?? 0, hit: c.cancelledShare >= th, problem: `${c.cancelled} of ${c.runs} CI runs on pull request branches were cancelled (${pct(c.cancelledShare)}). Runs on the default branch are not counted here.`, good: `Only ${pct(c.cancelledShare)} of the CI runs on pull request branches were cancelled.` }; },
    why: "A cancelled run usually means a newer push arrived before CI finished: pushes come faster than CI answers.",
    action: "Verify locally and push when the change is complete; a draft pull request can skip the heavy jobs.",
  },
  {
    id: "red-default-branch", group: "quality", severity: "high", name: "Failed CI on the default branch", th: 0.1, min: 30,
    check: ({ ci, defaultBranch }, th) => { const m = ci?.defaultBranchPush; return { n: m ? m.success + m.failure : 0, hit: m?.failureRate > th, problem: `${m?.failure} of ${m?.success + m?.failure} finished push runs on ${defaultBranch} failed (${pct(m?.failureRate ?? 0)}).`, good: `${pct(1 - (m?.failureRate ?? 0))} of the push runs on ${defaultBranch} were green.` }; },
    why: "A red default branch blocks every open pull request and every release, and shows that the checks before merge did not catch what the checks after merge did.",
    action: "Classify one week of failures (merged defect, flaky test, infrastructure). For merged defects: find the check that runs only after merge and move it to the pull request.",
    ref: "CircleCI 2026 software delivery report: 90 % main-branch success as benchmark, 70.8 % observed in Q1 2026 (CircleCI customers)",
  },
  {
    id: "flaky-reruns", group: "ci", severity: "medium", name: "Re-runs that turned green without a change", th: 0.01, min: 100,
    check: ({ ci }, th) => ({ n: ci?.all.runs ?? 0, hit: ci.all.rerunGreen / ci.all.runs >= th, problem: `${ci.all.rerunGreen} of ${ci.all.runs} CI runs turned green on a re-run without a change.`, good: `Only ${ci.all.rerunGreen} of ${ci.all.runs} CI runs needed a re-run to turn green.` }),
    why: "A test that passes on the second try teaches everyone to re-run instead of read, and hides real failures.",
    action: "List the tests that failed in those first attempts; fix or quarantine the repeat offenders and keep a table of known flaky tests.",
  },
  {
    id: "follow-up-fixes", group: "quality", severity: "medium", name: "Defects fixed shortly after merge", th: 0.08, min: 50,
    check: ({ total: { merged, quality: q } }, th) => ({ n: merged, hit: q.followUpDefectShare >= th, problem: `${of(q.followUpDefectShare, merged)} of ${merged} merged pull requests were named by a later fix that is not worded as a review follow-up (${pct(q.followUpDefectShare)}). Another ${of(q.followUpPlannedShare, merged)} were followed only by planned follow-ups of review findings, which do not count here.`, good: `Only ${pct(q.followUpDefectShare)} of the merged pull requests were named by a later defect fix (${pct(q.followUpPlannedShare)} more by planned follow-ups of review findings).` }),
    why: "A fix that names an earlier pull request is the nearest thing to a counted escaped defect. Planned follow-ups are told apart by wording only, so read a sample before concluding.",
    action: "Read ten entries of the follow-up list: what would have caught each before merge (a test, a review role, a CI check)? Add that check.",
  },
  {
    id: "fixes-without-tests", group: "quality", severity: "medium", name: "Fixes without a test", th: 0.2, min: 50,
    check: ({ total: { quality: q } }, th) => ({ n: q.sourceFixes, hit: q.fixWithoutTestShare >= th, problem: `${of(q.fixWithoutTestShare, q.sourceFixes)} of the ${q.sourceFixes} fixes that touch source code touch no test file (${pct(q.fixWithoutTestShare)}).`, good: `${pct(1 - (q.fixWithoutTestShare ?? 0))} of the source-code fixes come with a test change.` }),
    why: "A defect fixed without a pinning test can come back unnoticed.",
    action: "Ask for the failing test first in every behaviour fix; let the review block a fix without one.",
  },
  {
    id: "high-fix-share", group: "quality", severity: "low", name: "A large share of the work is fixing", th: 0.35, min: 50,
    check: ({ total: { merged, quality: q } }, th) => ({ n: merged, hit: q.fixShare >= th, problem: `${of(q.fixShare, merged)} of ${merged} merged pull requests are fixes (${pct(q.fixShare)}).`, good: `${pct(q.fixShare)} of the merged pull requests are fixes.` }),
    why: "Shipping fast and fixing fast often means the review or the tests let too much through.",
    action: "Look for fix chains: several fixes on the same area in a row point at the part that needs a design decision, not another patch.",
  },
  {
    id: "merged-without-review", group: "review", severity: "medium", name: "Merges without any review", th: 0.2, min: 30,
    check: ({ total: { merged, quality: q } }, th) => ({ n: merged, hit: q.noReviewShare >= th, problem: `${of(q.noReviewShare, merged)} of ${merged} pull requests were merged without a review by any named reviewer (${pct(q.noReviewShare)}).`, good: `${pct(1 - q.noReviewShare)} of the merged pull requests had a review.` }),
    why: "An unreviewed merge is fine for low-risk classes and a gap for the others; the number alone does not say which it is.",
    action: "Check the risk-class table: unreviewed merges should sit in the docs and tests rows. Require a review for the sensitive class.",
  },
  {
    id: "unresolved-threads", group: "review", severity: "low", name: "Merged with open review threads", th: 0, min: 30,
    check: ({ total: { merged, quality: q } }, th) => ({ n: merged, hit: q.unresolvedThreadPrs > th, problem: `${q.unresolvedThreadPrs} merged pull requests have a review thread that is unresolved to this day.`, good: "No merged pull request has a review thread that is still unresolved." }),
    why: "A thread still open after the merge is a finding nobody answered. GitHub records no time of resolution, so a thread that was open at the merge and resolved later is not counted: the number is a lower bound.",
    action: "Require resolved conversations in the branch rules, or answer each thread with the reason it stays open.",
  },
  {
    id: "reviewers-disagree", group: "review", severity: "medium", name: "Two reviewers disagree on the same commit", th: 0.2, min: 20,
    check: ({ compare: c }, th) => { const n = c ? c.both + c.onlyA + c.onlyB + c.neither : 0, d = c ? c.onlyA + c.onlyB : 0; return { n, hit: d / n >= th, problem: `On ${d} of ${n} commits reviewed by both, only one of ${c?.a} and ${c?.b} blocked (${c?.onlyA} only ${c?.a}, ${c?.onlyB} only ${c?.b}).`, good: `${c?.a} and ${c?.b} agree on ${n - d} of ${n} commits both reviewed.` }; },
    why: "Each one-sided block is either a false alarm of one reviewer or a miss of the other. Which one decides whether the reviewer can gate merges.",
    action: "Read the one-sided cases and label each: right or false alarm. Report both rates per reviewer before changing who gates.",
  },
];

const PENALTY = { high: 12, medium: 7, low: 3 };
export function evaluate(metrics, overrides = {}) {
  const results = RULES.map((r) => {
    const o = overrides[r.id] ?? {};
    const base = { id: r.id, group: r.group, severity: r.severity, name: r.name, why: r.why, action: r.action, ref: r.ref ?? null, threshold: o.threshold ?? r.th };
    if (o.off) return { ...base, state: "off" };
    let res;
    try { res = r.check(metrics, base.threshold); } catch { res = { n: 0 }; }
    if (!res.n || res.n < r.min || Number.isNaN(res.n)) return { ...base, state: "not-evaluated", reason: res.n ? `only ${res.n} in the sample, the rule needs ${r.min}` : "no data for this rule in the period" };
    return { ...base, state: res.hit ? "triggered" : "passed", n: res.n, text: res.hit ? res.problem : res.good };
  });
  // score per group: 100 x (1 - penalties / (evaluated rules x 12)); a triggered rule costs its penalty once
  const scores = {};
  for (const g of ["flow", "review", "ci", "quality"]) {
    const ev = results.filter((r) => r.group === g && (r.state === "triggered" || r.state === "passed"));
    scores[g] = ev.length ? { score: Math.round(100 * (1 - ev.filter((r) => r.state === "triggered").reduce((s, r) => s + PENALTY[r.severity], 0) / (ev.length * 12))), evaluated: ev.length, triggered: ev.filter((r) => r.state === "triggered").length } : null;
  }
  return { results, scores };
}

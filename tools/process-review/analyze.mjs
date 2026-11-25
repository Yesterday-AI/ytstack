#!/usr/bin/env node
// Computes throughput, efficiency and quality metrics from the files mine.mjs wrote.
// Usage: node analyze.mjs <outDir> [--since YYYY-MM-DD] [--until YYYY-MM-DD] [--out metrics.json]
// Reads <outDir>/config.json when present (references/config.md). Prints a summary, writes metrics.json.
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { evaluate } from "./rules.mjs";

const args = process.argv.slice(2);
const dir = args[0];
const opt = (k, d) => (args.includes(k) ? args[args.indexOf(k) + 1] : d);
if (!dir) { console.error("usage: analyze.mjs <outDir> [--since d] [--until d] [--out file]"); process.exit(2); }
const cfg = existsSync(`${dir}/config.json`) ? JSON.parse(readFileSync(`${dir}/config.json`, "utf8")) : {};
const since = opt("--since", "0000"), until = opt("--until", "9999");
const load = (sub) => !existsSync(`${dir}/${sub}`) ? [] : readdirSync(`${dir}/${sub}`).filter((f) => f.endsWith(".jsonl")).sort()
  .flatMap((f) => readFileSync(`${dir}/${sub}/${f}`, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)));
const uniq = (rows, key) => [...new Map(rows.map((r) => [r[key], r])).values()];
const inRange = (iso) => iso.slice(0, 10) >= since && iso.slice(0, 10) <= until;
const prs = uniq(load("prs"), "number").filter((p) => inRange(p.mergedAt)).sort((a, b) => a.mergedAt.localeCompare(b.mergedAt));
const runs = uniq(load("ci"), "id").filter((r) => inRange(r.createdAt));
if (!prs.length) { console.error("no merged pull requests in range"); process.exit(1); }

// ---- helpers
const hours = (a, b) => (new Date(b) - new Date(a)) / 36e5;
const sorted = (a) => [...a].filter(Number.isFinite).sort((x, y) => x - y);
const q = (a, p) => { const s = sorted(a); return s.length ? s[Math.min(s.length - 1, Math.floor(s.length * p))] : null; };
const med = (a) => q(a, 0.5);
const mean = (a) => (a.length ? a.reduce((s, x) => s + x, 0) / a.length : null);
const share = (n, d) => (d ? n / d : null);
const r1 = (n) => (n === null ? null : Math.round(n * 10) / 10);
const r3 = (n) => (n === null ? null : Math.round(n * 1000) / 1000);
const monday = (iso) => { const d = new Date(`${iso.slice(0, 10)}T00:00:00Z`); return new Date(+d - ((d.getUTCDay() + 6) % 7) * 864e5).toISOString().slice(0, 10); };
const count = (rows, f) => rows.filter(f).length;

// ---- who reviewed: configured rules first, then bots by login, then humans other than the author
const rules = (cfg.reviewers ?? []).map((r) => ({ ...r, re: r.bodyMatch && new RegExp(r.bodyMatch, "i"), ig: r.ignoreBody && new RegExp(r.ignoreBody, "i"), cm: r.cleanMatch && new RegExp(r.cleanMatch, "i") }));
// a bot's notice that it did not review is not a review
const noticeRe = new RegExp(cfg.noticePattern ?? "usage limits?|couldn't run|could not run|rate limit|quota (exceeded|reached)|out of credits|review skipped", "i");
function kindOf(ev, pr) {
  // an inline thread is attributed through the body of the review it was posted with
  const head = (ev.reviewBody || ev.body || "").slice(0, 300);
  for (const r of rules) {
    if (r.login && r.login !== ev.by) continue;
    if (r.re && !r.re.test(head)) continue;
    if (!r.login && !r.re) continue;
    return r.ig?.test(head) ? null : { name: r.name, ruled: true, clean: Boolean(r.cm?.test(head)) };
  }
  if (ev.bot) return noticeRe.test(head) ? null : { name: ev.by, ruled: false };
  if (ev.by === pr.author) return null;
  return { name: "human", ruled: false };
}
const fcfg = cfg.findings && { re: new RegExp(cfg.findings.pattern, "u"), blocking: cfg.findings.blockingGroups ?? [1] };
const findings = (body) => { const m = fcfg && body.match(fcfg.re); return m ? m.slice(1).map(Number) : null; };
const blockingOf = (n) => fcfg.blocking.reduce((s, g) => s + (n[g - 1] ?? 0), 0);
const headAt = (pr, at) => { let h = ""; for (const c of pr.commits) if (c.at <= at) h = c.oid; return h; };
const STATE = { CHANGES_REQUESTED: 3, APPROVED: 2, COMMENTED: 1 };

const fixRe = new RegExp(cfg.fixPattern ?? "^(fix|hotfix|bugfix|revert)\\b|^Revert \"", "i");
const revertRe = /^revert\b|^Revert "/i;
const testRe = new RegExp(cfg.testPattern ?? "(^|/)(tests?|__tests__|e2e|spec)/|[._-](test|spec)\\.[a-z]+$|_test\\.[a-z]+$", "i");
const srcRe = new RegExp(cfg.sourcePattern ?? "\\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|java|kt|rb|php|cs|swift|c|cc|cpp|h|scala|sql)$", "i");
const ignoreRe = new RegExp(cfg.ignorePaths ?? "(^|/)(pnpm-lock\\.yaml|package-lock\\.json|yarn\\.lock|Cargo\\.lock|go\\.sum|poetry\\.lock|CHANGELOG\\.md)$|\\.md$", "i");
const plannedRe = new RegExp(cfg.plannedFollowUpPattern ?? "follow-?ups?\\b|review (r\\d|round|finding|comment)|non-?blocking|\\bnits?\\b|\\bmediums?\\b|\\blows?\\b (finding|severity)|addresses? (the )?(review|feedback)", "i");
const docRe = new RegExp(cfg.docsPattern ?? "\\.(md|mdx|txt|rst|adoc)$|(^|/)(LICENSE|NOTICE)$", "i");
const riskRe = new RegExp(cfg.sensitivePattern ?? "migrat|\\.sql$|(^|/)(auth|security|secrets?|permissions?|rbac|iam|payments?|billing)(/|[._-])|^\\.github/workflows/|(^|/)(k8s|helm|terraform|deploy)/|\\.tf$|(^|/)Dockerfile", "i");

// ---- per pull request
const rows = prs.map((p) => {
  const evs = [...p.reviews.map((e) => ({ ...e, type: "review" })), ...p.comments.map((e) => ({ ...e, type: "comment" }))]
    .filter((e) => e.at <= p.mergedAt) // what arrived after the merge reviewed nothing before it
    .map((e) => ({ ...e, kind: kindOf(e, p) })).filter((e) => e.kind).sort((a, b) => a.at.localeCompare(b.at));
  const threads = p.threads.filter((t) => !t.at || t.at <= p.mergedAt).map((t) => ({ ...t, kind: kindOf(t, p)?.name ?? null }));
  const src = p.files.filter((f) => srcRe.test(f) && !testRe.test(f));
  // risk class by the files touched: what is the most that could break
  const nonDoc = p.files.filter((f) => !docRe.test(f));
  const cls = !p.files.length ? "unknown" : nonDoc.some((f) => riskRe.test(f)) ? "sensitive" : src.length ? "source code"
    : !nonDoc.length ? "docs only" : nonDoc.every((f) => testRe.test(f)) ? "tests only" : "configuration and other";
  return {
    p, evs, threads, cls, day: p.mergedAt.slice(0, 10), week: monday(p.mergedAt), lead: hours(p.createdAt, p.mergedAt),
    ttfr: evs.length ? Math.max(0, hours(p.createdAt, evs[0].at)) : null, size: p.additions + p.deletions,
    kinds: [...new Set([...evs.map((e) => e.kind.name), ...threads.map((t) => t.kind).filter(Boolean)])],
    isFix: fixRe.test(p.title), isRevert: revertRe.test(p.title), noReview: !evs.length && !threads.some((t) => t.kind),
    unresolved: count(threads, (t) => !t.resolved), srcNoTest: src.length > 0 && !p.files.some((f) => testRe.test(f)), touchesSrc: src.length > 0,
  };
});

// the period runs over the days mined, not from the first to the last day something merged: mine.mjs writes a file per day, also an empty one
const minedDays = existsSync(`${dir}/prs`) ? readdirSync(`${dir}/prs`).filter((f) => /^\d{4}-\d\d-\d\d\.jsonl$/.test(f)).map((f) => f.slice(0, 10)).filter((d) => d >= since && d <= until).sort() : [];
const firstDay = [rows[0].day, minedDays[0] ?? "9999"].sort()[0], lastDay = [rows.at(-1).day, minedDays.at(-1) ?? ""].sort().at(-1);
// a pull request merged in the last followUpDays of the period can still be named by a fix nobody has mined yet
const matureUntil = new Date(+new Date(`${lastDay}T00:00:00Z`) - (cfg.followUpDays ?? 7) * 864e5).toISOString().slice(0, 10);

// ---- rounds: one round per reviewed head by the round reviewer
let roundKind = cfg.rounds?.kind;
if (!roundKind) {
  const tally = {};
  for (const r of rows) for (const k of new Set(r.evs.filter((e) => e.type === "review" || e.kind.ruled).map((e) => e.kind.name))) tally[k] = (tally[k] ?? 0) + 1;
  roundKind = (tally.human ?? 0) >= rows.length * 0.05 ? "human" : Object.entries(tally).sort((a, b) => b[1] - a[1])[0]?.[0] ?? "human";
}
for (const r of rows) {
  const byHead = new Map();
  for (const e of r.evs) {
    if (e.kind.name !== roundKind || !(e.type === "review" || e.kind.ruled)) continue;
    const head = e.head || headAt(r.p, e.at);
    const g = byHead.get(head) ?? { head, at: e.at, n: null, state: "COMMENTED" };
    // several reviews of one head: a blocking count is kept, a later clean one does not clear it
    const n = findings(e.body); if (n && !(g.n && blockingOf(g.n) > 0 && blockingOf(n) === 0)) g.n = n;
    if (e.kind.clean) g.cleanHit = true;
    if ((STATE[e.state] ?? 0) > STATE[g.state]) g.state = e.state;
    byHead.set(head, g);
  }
  r.roundList = [...byHead.values()].sort((a, b) => a.at.localeCompare(b.at)).map((g) => ({
    ...g, blocking: fcfg ? (g.n ? blockingOf(g.n) > 0 : null) : g.state === "CHANGES_REQUESTED",
    clean: fcfg ? (g.n ? g.n.every((x) => x === 0) : null) : g.state === "APPROVED" || Boolean(g.cleanHit),
  }));
  r.rounds = r.roundList.length;
  r.later = r.roundList.slice(1).map((g, i) => {
    const between = r.p.commits.filter((c) => c.at > r.roundList[i].at && c.at <= g.at);
    return { ...g, mergeOnly: between.length > 0 && between.every((c) => /^Merge /.test(c.msg)) };
  });
  r.reworkCommits = r.rounds ? count(r.p.commits, (c) => c.at > r.roundList[0].at && !/^Merge /.test(c.msg)) : 0;
}

// ---- quality: follow-up fixes within a window (explicit "#123" link, or shared non-hot files)
const windowH = (cfg.followUpDays ?? 7) * 24;
const pathCount = {};
for (const r of rows) for (const f of r.p.files) pathCount[f] = (pathCount[f] ?? 0) + 1;
const hotLimit = Math.max(5, rows.length * 0.05);
const cold = (f) => !ignoreRe.test(f) && pathCount[f] <= hotLimit;
for (const r of rows) r.cold = new Set(r.p.files.filter(cold));
for (const f of rows.filter((r) => r.isFix)) {
  const refs = new Set([...`${f.p.title}\n${f.p.body}`.matchAll(/#(\d+)\b/g)].map((m) => +m[1]));
  for (const t of rows) {
    if (t === f || t.p.mergedAt >= f.p.createdAt) continue;
    const h = hours(t.p.mergedAt, f.p.mergedAt);
    if (h > windowH) continue;
    // a fix worded as the follow-up of a review finding is planned work, not a defect found after merge
    if (refs.has(t.p.number)) { t.fixExplicit = true; t.fixHours = Math.min(t.fixHours ?? Infinity, h); (t.fixedBy ??= []).push(f.p.number); if (plannedRe.test(`${f.p.title}\n${f.p.body.slice(0, 600)}`)) t.fixPlanned = true; else t.fixDefect = true; }
    else if ([...f.cold].some((x) => t.cold.has(x))) t.fixOverlap = true;
  }
}

// ---- CI
const defaultBranch = cfg.defaultBranch ?? Object.entries(rows.reduce((m, r) => ((m[r.p.base] = (m[r.p.base] ?? 0) + 1), m), {})).sort((a, b) => b[1] - a[1])[0][0];
// a branch name can carry several pull requests of the period: a run belongs to the one that holds its commit,
// else to the first one not yet merged when the run started, else to the last one
const branchOf = new Map();
for (const r of [...rows].sort((a, b) => a.p.mergedAt.localeCompare(b.p.mergedAt))) branchOf.set(r.p.branch, [...(branchOf.get(r.p.branch) ?? []), r]);
const prOfRun = (run) => { const l = branchOf.get(run.branch); return l && (l.find((r) => run.sha && r.p.commits.some((c) => c.oid === run.sha)) ?? l.find((r) => r.p.mergedAt >= run.createdAt) ?? l.at(-1)); };
const ciRuns = runs.filter((r) => !cfg.ciWorkflows || cfg.ciWorkflows.includes(r.name)).map((r) => {
  const min = r.status === "completed" && r.startedAt ? (new Date(r.updatedAt) - new Date(r.startedAt)) / 6e4 : null;
  return { ...r, min: min !== null && min >= 0 && min < 360 ? min : null, week: monday(r.createdAt) };
});
for (const run of ciRuns) { const r = run.branch !== defaultBranch && prOfRun(run); if (r) (r.ci ??= []).push(run); }
for (const r of rows) {
  const first = r.ci && [...r.ci].filter((c) => c.status === "completed" && c.conclusion !== "cancelled" && c.conclusion !== "skipped").sort((a, b) => a.createdAt.localeCompare(b.createdAt))[0];
  r.firstPass = first && r.rounds && r.roundList[0].blocking !== null ? first.conclusion === "success" && first.attempt === 1 && r.roundList[0].blocking === false : null; // green on a re-run is no first pass
  // runner time only from runs with a measured duration; none measured: not available, never zero
  const timed = (r.ci ?? []).filter((c) => c.min !== null);
  r.ciHours = timed.length ? timed.reduce((s, c) => s + c.min, 0) / 60 : null;
}
function ciStats(list) {
  const done = list.filter((r) => r.status === "completed");
  const ok = count(done, (r) => r.conclusion === "success"), bad = count(done, (r) => r.conclusion === "failure"), cancelled = count(done, (r) => r.conclusion === "cancelled");
  const minutes = (f) => done.filter(f).reduce((s, r) => s + (r.min ?? 0), 0);
  return {
    runs: list.length, completed: done.length, timed: count(done, (r) => r.min !== null), success: ok, failure: bad, cancelled, failureRate: r3(share(bad, ok + bad)), cancelledShare: r3(share(cancelled, done.length)),
    rerunShare: r3(share(count(done, (r) => r.attempt > 1), done.length)), rerunGreen: count(done, (r) => r.attempt > 1 && r.conclusion === "success"),
    medianMin: r1(med(done.filter((r) => r.conclusion === "success").map((r) => r.min))), p90Min: r1(q(done.filter((r) => r.conclusion === "success").map((r) => r.min), 0.9)),
    hours: r1(minutes(() => true) / 60), hoursNotGreen: r1(minutes((r) => r.conclusion !== "success") / 60),
  };
}
const mainRuns = ciRuns.filter((r) => r.branch === defaultBranch && r.event === "push");
// runs of pull requests: where a cancelled run is a superseded push, not a queue the default branch drops on purpose.
// A branch counts when a mined pull request came from it or a pull_request event started the run, never only because it is not the default branch (release or develop branches are no pull requests).
const prRuns = ciRuns.filter((r) => r.branch !== defaultBranch && (branchOf.has(r.branch) || r.event?.startsWith("pull_request")));

// ---- aggregate
function summ(g) {
  const rv = g.filter((r) => r.rounds);
  const later = rv.flatMap((r) => r.later);
  const withCi = g.filter((r) => r.ci);
  // first attempt: the first finished CI run is green and the first review round does not block
  const judged = g.filter((r) => r.firstPass !== null);
  const firstPass = count(judged, (r) => r.firstPass);
  return {
    merged: g.length,
    efficiency: {
      leadMedianH: r1(med(g.map((r) => r.lead))), leadP90H: r1(q(g.map((r) => r.lead), 0.9)),
      firstReviewMedianH: r1(med(g.map((r) => r.ttfr))), sizeMedian: med(g.map((r) => r.size)), commitsMedian: med(g.map((r) => r.p.commitCount)),
      reviewed: rv.length, roundsMean: r1(mean(rv.map((r) => r.rounds))), multiRoundShare: r3(share(count(rv, (r) => r.rounds >= 2), rv.length)),
      threePlusShare: r3(share(count(rv, (r) => r.rounds >= 3), rv.length)),
      firstRoundBlockingShare: r3(share(count(rv, (r) => r.roundList[0].blocking === true), count(rv, (r) => r.roundList[0].blocking !== null))),
      laterRounds: later.length, laterClean: count(later, (x) => x.clean === true), laterBlocking: count(later, (x) => x.blocking === true),
      laterNonBlocking: count(later, (x) => x.blocking === false && x.clean === false), laterUnknown: count(later, (x) => x.blocking === null),
      laterAfterMergeOnly: count(later, (x) => x.mergeOnly), reworkCommitsMean: r1(mean(rv.map((r) => r.reworkCommits))),
      ciRunsPerPrMedian: med(withCi.map((r) => r.ci.length)), ciFailedRunShare: r3(share(withCi.reduce((s, r) => s + count(r.ci, (c) => c.conclusion === "failure"), 0), withCi.reduce((s, r) => s + count(r.ci, (c) => c.conclusion === "success" || c.conclusion === "failure"), 0))),
      ciHoursPerPr: r1(mean(withCi.map((r) => r.ciHours).filter((h) => h !== null))),
      firstPassN: judged.length, firstPassShare: r3(share(firstPass, judged.length)),
      ciLoopShare: r3(share(count(withCi, (r) => r.ci.some((c) => c.conclusion === "failure")), withCi.length)), ciJudged: withCi.length,
    },
    quality: {
      fixShare: r3(share(count(g, (r) => r.isFix), g.length)), reverts: count(g, (r) => r.isRevert),
      followUpExplicitShare: r3(share(count(g, (r) => r.fixExplicit), g.length)), followUpOverlapShare: r3(share(count(g, (r) => r.fixExplicit || r.fixOverlap), g.length)),
      followUpMedianH: r1(med(g.filter((r) => r.fixExplicit).map((r) => r.fixHours))),
      followUpMature: count(g, (r) => r.day <= matureUntil), followUpDefectMatureShare: r3(share(count(g, (r) => r.fixDefect && r.day <= matureUntil), count(g, (r) => r.day <= matureUntil))),
      followUpDefectShare: r3(share(count(g, (r) => r.fixDefect), g.length)), followUpPlannedShare: r3(share(count(g, (r) => r.fixPlanned && !r.fixDefect), g.length)),
      noReviewShare: r3(share(count(g, (r) => r.noReview), g.length)), unresolvedThreadPrs: count(g, (r) => r.unresolved > 0),
      sourceWithoutTestShare: r3(share(count(g, (r) => r.srcNoTest), count(g, (r) => r.touchesSrc))),
      fixWithoutTestShare: r3(share(count(g, (r) => r.isFix && r.srcNoTest), count(g, (r) => r.isFix && r.touchesSrc))), sourceFixes: count(g, (r) => r.isFix && r.touchesSrc),
    },
  };
}
const groupBy = (list, key) => list.reduce((m, r) => ((m[r[key]] ??= []).push(r), m), {});
const weeks = Object.fromEntries(Object.entries(groupBy(rows, "week")).sort().map(([w, g]) => [w, { ...summ(g), mainCi: ciStats(mainRuns.filter((r) => r.week === w)) }]));
const kinds = [...new Set(rows.flatMap((r) => r.kinds))].sort();
const days = Object.fromEntries(Object.entries(groupBy(rows, "day")).sort().map(([d, g]) => [d, { merged: g.length, kinds: Object.fromEntries(kinds.map((k) => [k, count(g, (r) => r.kinds.includes(k))])) }]));
const reviewers = Object.fromEntries(kinds.map((k) => {
  const th = rows.flatMap((r) => r.threads.filter((t) => t.kind === k).map((t) => ({ ...t, pr: r.p.number })));
  // a stable pseudo-random sample of threads, to judge by hand whether the findings were right
  const sample = [...th].sort((a, b) => ((a.pr * 2654435761) % 9973) - ((b.pr * 2654435761) % 9973)).slice(0, cfg.sampleSize ?? 12).map((t) => ({ pr: t.pr, path: t.path, body: t.body.slice(0, 240) }));
  return [k, { prs: count(rows, (r) => r.kinds.includes(k)), prShare: r3(share(count(rows, (r) => r.kinds.includes(k)), rows.length)), threads: th.length, threadsResolved: count(th, (t) => t.resolved), sample }];
}));

// ---- optional: two reviewers on the same head (needs findings counts)
function compareOf(list) {
  if (!(cfg.compare && fcfg)) return null;
  const [a, b] = cfg.compare; const m = { both: 0, onlyA: 0, onlyB: 0, neither: 0 }; const disagree = [];
  for (const r of list) {
    // one outcome per reviewer and head: several reviews of the same commit block when any of them does
    const of = (k) => { const h = new Map(); for (const e of r.evs) if (e.kind.name === k && findings(e.body)) { const head = e.head || headAt(r.p, e.at); h.set(head, Boolean(h.get(head)) || blockingOf(findings(e.body)) > 0); } return h; };
    const hb = of(b);
    for (const [head, xb] of of(a)) { if (!hb.has(head)) continue; const yb = hb.get(head);
      m[xb ? (yb ? "both" : "onlyA") : yb ? "onlyB" : "neither"]++; if (xb !== yb) disagree.push({ pr: r.p.number, blocks: xb ? a : b }); }
  }
  return { a, b, ...m, disagree };
}
const compare = compareOf(rows);

const perWorkflow = Object.fromEntries(Object.entries(groupBy(ciRuns, "name")).map(([n, g]) => [n, ciStats(g)]).sort((a, b) => b[1].hours - a[1].hours));
const worst = (f, n = 15) => [...rows].sort((a, b) => f(b) - f(a)).slice(0, n).map((r) => ({ pr: r.p.number, title: r.p.title.slice(0, 90), rounds: r.rounds, leadH: r1(r.lead), ciRuns: r.ci?.length ?? 0 }));
const metrics = {
  repo: cfg.repo ?? null, generatedAt: new Date().toISOString(), period: { from: firstDay, to: lastDay }, roundKind, defaultBranch,
  findingsParsed: Boolean(fcfg), markers: cfg.changes ?? cfg.markers ?? [], total: summ(rows), weeks, days, reviewers, compare,
  ci: runs.length ? { all: ciStats(ciRuns), prBranches: ciStats(prRuns), defaultBranchPush: ciStats(mainRuns), perWorkflow } : null,
  outliers: { mostRounds: worst((r) => r.rounds), longestLead: worst((r) => r.lead), mostCiRuns: worst((r) => r.ci?.length ?? 0) },
  followUps: rows.filter((r) => r.fixExplicit).slice(-(cfg.followUpList ?? 40)).map((r) => ({ pr: r.p.number, title: r.p.title.slice(0, 90), fixedAfterH: r1(r.fixHours), fixedBy: r.fixedBy })),
};
// process cost per risk class
metrics.classes = Object.fromEntries(["docs only", "tests only", "configuration and other", "source code", "sensitive", "unknown"].map((c) => [c, rows.filter((r) => r.cls === c)]).filter(([, g]) => g.length)
  .map(([c, g]) => { const s = summ(g); return [c, { merged: s.merged, leadMedianH: s.efficiency.leadMedianH, reviewedShare: r3(1 - s.quality.noReviewShare), roundsMean: s.efficiency.roundsMean, ciRunsMedian: s.efficiency.ciRunsPerPrMedian, ciHoursPerPr: s.efficiency.ciHoursPerPr, firstPassShare: s.efficiency.firstPassShare }]; }));
// ---- who wrote it: bot account, AI mark (co-author trailer, body footer, branch prefix), or no mark
const aiRe = new RegExp(cfg.agentPattern ?? "claude|copilot|codex|cursor|devin|aider|openhands|jules|gemini|generated with|\\[bot\\]", "i");
for (const r of rows) {
  const p = r.p;
  r.signal = p.authorBot ? "bot account" : aiRe.test((p.coAuthors ?? []).join(" ")) ? "co-author trailer" : aiRe.test(p.bodyTail ?? "") ? "pull request footer" : /^(claude|codex|copilot|cursor|devin|jules)[/-]/i.test(p.branch ?? "") ? "branch prefix" : null;
  r.authorClass = p.authorBot ? "bot account" : r.signal ? "AI-assisted or agent" : p.coAuthors === undefined ? "unknown (mined before author marks)" : "no AI mark";
}
const bySignal = rows.reduce((mm, r) => (r.signal && (mm[r.signal] = (mm[r.signal] ?? 0) + 1), mm), {});
metrics.authors = { signals: bySignal, classes: Object.fromEntries(Object.entries(groupBy(rows, "authorClass")).map(([c, g]) => { const s = summ(g); return [c, { merged: s.merged, sizeMedian: s.efficiency.sizeMedian, leadMedianH: s.efficiency.leadMedianH, roundsMean: s.efficiency.roundsMean, firstPassShare: s.efficiency.firstPassShare, followUpExplicitShare: s.quality.followUpExplicitShare, fixShare: s.quality.fixShare }]; })) };

// ---- what the agents spent: tokens.json (mine-tokens.mjs). Work transcripts join by branch, else worktree name,
// and split at the pull request's first review round: before = implementation, after = fix. Review transcripts
// join by the pull request they posted to and, by time, to the round they produced.
const tokenFile = `${dir}/tokens.json`;
for (const r of rows) r.roundBucket = !r.rounds ? null : r.rounds === 1 ? "1 round" : r.rounds === 2 ? "2 rounds" : "3 or more rounds";
if (existsSync(tokenFile)) {
  const tk = JSON.parse(readFileSync(tokenFile, "utf8")), prices = cfg.prices ?? {};
  const bUsd = (b) => { const p = prices[b.model]; return p ? (b.in * p.in + b.out * p.out + b.cr * p.cacheRead + b.cw * p.cacheWrite) / 1e6 : 0; };
  const sumB = (bs) => bs.reduce((s, b) => ({ usd: s.usd + bUsd(b), min: s.min + b.ms / 6e4, out: s.out + b.out, tokens: s.tokens + b.in + b.out + b.cr + b.cw }), { usd: 0, min: 0, out: 0, tokens: 0 });
  const mainModel = (bs) => { const m = {}; for (const b of bs) m[b.model] = (m[b.model] ?? 0) + bUsd(b); return Object.entries(m).sort((x, y) => y[1] - x[1])[0]?.[0] ?? "unknown"; };
  const inScope = rows.filter((r) => r.p.mergedAt >= tk.since), byNumber = new Map(inScope.map((r) => [r.p.number, r]));
  const work = new Map(); for (const u of tk.units) if (u.kind === "work") (work.get(u.key) ?? work.set(u.key, []).get(u.key)).push(...u.buckets);
  const users = new Map();
  for (const r of inScope) { const k = work.has("branch:" + r.p.branch) ? "branch:" + r.p.branch : work.has("worktree:" + (r.p.branch ?? "").split("/").pop()) ? "worktree:" + r.p.branch.split("/").pop() : null; if (k) { r.wk = k; users.set(k, (users.get(k) ?? 0) + 1); } }
  const z = () => ({ usd: 0, min: 0, out: 0, tokens: 0 });
  for (const r of inScope) {
    if (r.wk && users.get(r.wk) === 1) { // a branch shared by several pull requests cannot be split by time
      const cut = r.roundList?.[0] ? Date.parse(r.roundList[0].at) : Infinity, bs = work.get(r.wk);
      r.impl = sumB(bs.filter((b) => b.t + tk.bucketMs <= cut)); r.fix = sumB(bs.filter((b) => b.t + tk.bucketMs > cut));
    }
  }
  const reviewRuns = [];
  for (const u of tk.units) if (u.kind === "review") {
    const r = byNumber.get(u.pr), s = sumB(u.buckets), end = u.buckets.at(-1).t + tk.bucketMs, model = mainModel(u.buckets);
    const run = { pr: u.pr, roles: u.roles, delta: u.delta, model, usd: s.usd, min: s.min, out: s.out, merged: Boolean(r) };
    if (r) {
      (r.rev ??= z()); for (const f of ["usd", "min", "out", "tokens"]) r.rev[f] += s[f]; r.revRuns = (r.revRuns ?? 0) + 1;
      const i = (r.roundList ?? []).findIndex((g) => Math.abs(Date.parse(g.at) - end) < 20 * 60e3 || (Date.parse(g.at) >= u.buckets[0].t && Date.parse(g.at) <= end + 20 * 60e3));
      if (i >= 0) { const g = r.roundList[i]; Object.assign(run, { round: i + 1, blocking: g.blocking, clean: g.clean, findings: g.n ? g.n.reduce((x, y) => x + y, 0) : null, lastRound: i === r.roundList.length - 1, defectAfterMerge: Boolean(r.fixDefect ?? r.fixExplicit) }); }
    }
    reviewRuns.push(run);
  }
  const allUsd = tk.units.reduce((s, u) => s + sumB(u.buckets).usd, 0), kindUsd = (f) => tk.units.filter(f).reduce((s, u) => s + sumB(u.buckets).usd, 0);
  const perModel = {}; for (const u of tk.units) for (const b of u.buckets) { const x = (perModel[b.model] ??= { out: 0, usd: 0 }); x.out += b.out; x.usd += bUsd(b); }
  const st = (v) => ({ n: v.length, median: r1(med(v)), p90: r1(q(v, 0.9)), mean: r1(mean(v)), sum: Math.round(v.reduce((s, x) => s + x, 0)) });
  const phases = (g) => { const w = g.filter((r) => r.impl), rv = g.filter((r) => r.rev), full = g.filter((r) => r.impl && r.rev);
    return { prs: g.length, withWork: w.length, withReview: rv.length, withAll: full.length,
      implUsd: st(w.map((r) => r.impl.usd)), fixUsd: st(w.map((r) => r.fix.usd)), reviewUsd: st(rv.map((r) => r.rev.usd)),
      implMin: st(w.map((r) => r.impl.min)), fixMin: st(w.map((r) => r.fix.min)), reviewMin: st(rv.map((r) => r.rev.min)),
      totalUsd: st(full.map((r) => r.impl.usd + r.fix.usd + r.rev.usd)),
      shares: full.length ? (() => { const t = { i: 0, f: 0, v: 0 }; for (const r of full) { t.i += r.impl.usd; t.f += r.fix.usd; t.v += r.rev.usd; } const s = t.i + t.f + t.v; return { impl: r3(t.i / s), fix: r3(t.f / s), review: r3(t.v / s) }; })() : null }; };
  const matchedRuns = reviewRuns.filter((x) => x.round);
  const revGroup = (g) => { const judged = g.filter((x) => x.blocking !== null && x.blocking !== undefined), last = g.filter((x) => x.lastRound);
    return { runs: g.length, usdMedian: r1(med(g.map((x) => x.usd))), usdP90: r1(q(g.map((x) => x.usd), 0.9)), usdSum: Math.round(g.reduce((s, x) => s + x.usd, 0)), minMedian: r1(med(g.map((x) => x.min))),
      judged: judged.length, blockingShare: r3(share(count(judged, (x) => x.blocking), judged.length)), cleanShare: r3(share(count(judged, (x) => x.clean), judged.length)),
      findingsMean: r1(mean(g.filter((x) => x.findings !== null && x.findings !== undefined).map((x) => x.findings))),
      usdPerBlockingRun: count(judged, (x) => x.blocking) ? r1(judged.reduce((s, x) => s + x.usd, 0) / count(judged, (x) => x.blocking)) : null,
      passedLast: last.length, defectAfterPass: r3(share(count(last, (x) => x.defectAfterMerge), last.length)) }; };
  const grp = (key, min = 5) => Object.fromEntries(Object.entries(matchedRuns.reduce((m, x) => ((m[key(x)] ??= []).push(x), m), {})).filter(([, g]) => g.length >= min).sort((x, y) => y[1].length - x[1].length).map(([k, g]) => [k, revGroup(g)]));
  for (const r of inScope) if (r.impl || r.rev) { r.usd = (r.impl?.usd ?? 0) + (r.fix?.usd ?? 0) + (r.rev?.usd ?? 0); r.activeMin = (r.impl?.min ?? 0) + (r.fix?.min ?? 0) + (r.rev?.min ?? 0); }
  // a model without a price adds nothing to any cost figure: name it, so that a total is never read as complete
  const unpriced = Object.entries(perModel).filter(([m, v]) => !prices[m] && v.out > 0).map(([m, v]) => ({ model: m, out: v.out })).sort((a, b) => b.out - a.out);
  metrics.cost = { since: tk.since, priceNote: prices.note ?? null, unpriced, transcripts: tk.files, messages: tk.messages,
    totalUsd: Math.round(allUsd), coordinationUsd: Math.round(kindUsd((u) => u.key === "coordination")), reviewUsd: Math.round(kindUsd((u) => u.kind === "review")), workUsd: Math.round(kindUsd((u) => u.kind === "work" && u.key !== "coordination")),
    perModel: Object.fromEntries(Object.entries(perModel).filter(([, v]) => v.usd >= 1).map(([m, v]) => [m, { out: v.out, usd: Math.round(v.usd) }])),
    all: phases(inScope), byClass: Object.fromEntries(Object.entries(groupBy(inScope, "cls")).map(([c, g]) => [c, phases(g)])),
    byRounds: Object.fromEntries(Object.entries(groupBy(inScope.filter((r) => r.rounds), "roundBucket")).sort().map(([c, g]) => [c, phases(g)])),
    review: { runs: reviewRuns.length, onMergedPrs: reviewRuns.filter((x) => x.merged).length, matchedToRound: matchedRuns.length, all: revGroup(matchedRuns),
      byModel: grp((x) => x.model), byRole: grp((x) => (x.roles.length ? x.roles.join(" + ") : "role not named in the brief")), byRound: grp((x) => (x.round === 1 ? "first round" : "later round")),
      byModelFirstRound: Object.fromEntries(Object.entries(matchedRuns.filter((x) => x.round === 1).reduce((m, x) => ((m[x.model] ??= []).push(x), m), {})).filter(([, g]) => g.length >= 5).map(([k, g]) => [k, revGroup(g)])) },
    costliest: inScope.filter((r) => r.usd !== undefined).sort((x, y) => y.usd - x.usd).slice(0, 10).map((r) => ({ pr: r.p.number, title: r.p.title.slice(0, 80), usd: Math.round(r.usd), impl: Math.round(r.impl?.usd ?? 0), fix: Math.round(r.fix?.usd ?? 0), review: Math.round(r.rev?.usd ?? 0), rounds: r.rounds ?? null })) };
}

// ---- which model wrote it: the co-author trailers that name a tool or model; one name, several ("mixed") or none
const modelRe = new RegExp(cfg.modelPattern ?? cfg.agentPattern ?? "claude|gpt|codex|gemini|copilot|cursor|devin|aider|openhands|jules|llama|mistral", "i");
for (const r of rows) {
  const names = [...new Set((r.p.coAuthors ?? []).filter((n) => modelRe.test(n)).map((n) => n.trim()))];
  r.model = r.p.authorBot ? "bot account" : names.length === 1 ? names[0] : names.length > 1 ? "mixed (" + names.sort().join(" + ") + ")" : r.p.coAuthors === undefined ? "unknown (mined before author marks)" : "no model mark";
}
{
  const minN = cfg.modelMinPrs ?? 20;
  const line = (g) => { const s = summ(g); return { merged: s.merged, sizeMedian: s.efficiency.sizeMedian, leadMedianH: s.efficiency.leadMedianH, reviewed: s.efficiency.reviewed, firstRoundBlockingShare: s.efficiency.firstRoundBlockingShare, roundsMean: s.efficiency.roundsMean, firstPassShare: s.efficiency.firstPassShare, ciHoursPerPr: s.efficiency.ciHoursPerPr, followUpDefectShare: s.quality.followUpDefectShare, fixWithoutTestShare: s.quality.fixWithoutTestShare, withCost: g.filter((r) => r.usd !== undefined).length, usdMedian: r1(med(g.filter((r) => r.usd !== undefined).map((r) => r.usd))), activeMinMedian: r1(med(g.filter((r) => r.usd !== undefined).map((r) => r.activeMin))) }; };
  const byModel = groupBy(rows, "model");
  metrics.models = { minPrs: minN,
    overall: Object.fromEntries(Object.entries(byModel).map(([k, g]) => [k, { ...line(g), firstDay: g.map((r) => r.day).sort()[0], lastDay: g.map((r) => r.day).sort().pop() }])),
    byClass: Object.fromEntries(Object.entries(groupBy(rows, "cls")).map(([c, cg]) => [c, Object.fromEntries(Object.entries(groupBy(cg, "model")).filter(([, g]) => g.length >= minN).map(([k, g]) => [k, line(g)]))]).filter(([, v]) => Object.keys(v).length > 1)) };
}

// ---- where the time goes: open -> first review -> last review -> merge (durations do not add up across medians)
const r2 = (n) => (n === null ? null : Math.round(n * 100) / 100);
const span = (list) => ({ n: list.length, medianH: r2(med(list)), p75H: r2(q(list, 0.75)), p90H: r2(q(list, 0.9)) });
const timed = rows.filter((r) => r.evs.length);
metrics.phases = {
  pickup: span(timed.map((r) => r.ttfr)),
  review: span(timed.map((r) => Math.max(0, hours(r.evs[0].at, r.evs.at(-1).at <= r.p.mergedAt ? r.evs.at(-1).at : r.p.mergedAt)))),
  mergeWait: span(timed.map((r) => Math.max(0, hours(r.evs.filter((e) => e.at <= r.p.mergedAt).at(-1)?.at ?? r.p.mergedAt, r.p.mergedAt)))),
  lead: { ...span(rows.map((r) => r.lead)), p95H: r1(q(rows.map((r) => r.lead), 0.95)) },
};
const BUCKETS = [["under 15 min", 0.25], ["15 min to 1 h", 1], ["1 to 4 h", 4], ["4 h to 1 day", 24], ["1 to 3 days", 72], ["3 days to 1 week", 168], ["over 1 week", Infinity]];
metrics.leadHistogram = BUCKETS.map(([name, max], i) => ({ name, count: count(rows, (r) => r.lead <= max && r.lead > (i ? BUCKETS[i - 1][1] : -1)) }));
// merges by weekday (0 = Monday) and hour, UTC
metrics.heat = Array.from({ length: 7 }, () => Array(24).fill(0));
for (const r of rows) { const d = new Date(r.p.mergedAt); metrics.heat[(d.getUTCDay() + 6) % 7][d.getUTCHours()]++; }

// ---- which later rounds pay: by risk class, and by review role where threads name one
const laterBy = (list) => { const l = list.flatMap((r) => r.later), readable = l.filter((x) => x.blocking !== null); return { laterRounds: l.length, readable: readable.length, blocking: count(readable, (x) => x.blocking), blockingShare: r3(share(count(readable, (x) => x.blocking), readable.length)) }; };
metrics.laterYield = { byClass: Object.fromEntries(Object.entries(groupBy(rows, "cls")).map(([c, g]) => [c, laterBy(g)]).filter(([, v]) => v.laterRounds)), byRole: null };
if (cfg.roles?.pattern) {
  const roleRe = new RegExp(cfg.roles.pattern, "i"), byRole = {};
  for (const r of rows) for (const t of r.threads) {
    if (t.kind !== roundKind) continue;
    const role = (t.body.match(roleRe)?.[1] ?? "no role named").toLowerCase();
    // a thread is written while its review is drafted, so it belongs to the first round submitted at or after it
    const i = r.roundList.findIndex((g) => g.at >= t.at), round = i < 0 ? r.roundList.length : i + 1;
    const s = (byRole[role] ??= { first: 0, later: 0, changedAfter: 0, judged: 0 });
    if (round <= 1) s.first++; else s.later++;
    if (t.outdated !== undefined) { s.judged++; if (t.outdated) s.changedAfter++; }
  }
  metrics.laterYield.byRole = byRole;
}

// ---- what each review round found, by its position
metrics.roundYield = [1, 2, 3, 4].map((i) => {
  const g = rows.map((r) => (i < 4 ? r.roundList[i - 1] : null)).filter(Boolean).concat(i === 4 ? rows.flatMap((r) => r.roundList.slice(3)) : []);
  return { round: i === 4 ? "4+" : String(i), n: g.length, blocking: count(g, (x) => x.blocking === true), nonBlocking: count(g, (x) => x.blocking === false && x.clean === false), clean: count(g, (x) => x.clean === true), unknown: count(g, (x) => x.blocking === null) };
}).filter((x) => x.n);
// reviewer ledger: what a reviewer's threads led to
for (const [k, v] of Object.entries(reviewers)) {
  const th = rows.flatMap((r) => r.threads.filter((t) => t.kind === k));
  const known = th.filter((t) => t.outdated !== undefined);
  Object.assign(v, { prsWithThreads: count(rows, (r) => r.threads.some((t) => t.kind === k)), threadsOutdated: known.length ? count(known, (t) => t.outdated) : null, threadsJudged: known.length });
}

// ---- files that fixes keep returning to
const fileStat = {};
for (const r of rows) for (const f of r.p.files) { if (ignoreRe.test(f)) continue; const s = (fileStat[f] ??= { prs: 0, fixes: 0 }); s.prs++; if (r.isFix) s.fixes++; }
metrics.hotspots = Object.entries(fileStat).filter(([, s]) => s.fixes >= 3).sort((a, b) => b[1].fixes - a[1].fixes).slice(0, 12).map(([path, s]) => ({ path, ...s }));

// ---- how long the default branch stayed red: from the first failed push run to the next green one
const mainDone = mainRuns.filter((r) => r.conclusion === "success" || r.conclusion === "failure").sort((a, b) => a.createdAt.localeCompare(b.createdAt));
const reds = []; let redSince = null;
for (const r of mainDone) { if (r.conclusion === "failure") redSince ??= r.createdAt; else if (redSince) { reds.push(hours(redSince, r.updatedAt)); redSince = null; } }
if (metrics.ci) metrics.ci.red = { periods: reds.length, medianH: r1(med(reds)), longestH: r1(reds.length ? Math.max(...reds) : null), totalH: r1(reds.reduce((s, x) => s + x, 0)) };
// ---- what a change did: the same metrics in a window before and after each dated change
const W = cfg.changeWindowDays ?? 7, MIN = cfg.changeMinSample ?? 20;
const dayPlus = (d, n) => new Date(+new Date(`${d}T00:00:00Z`) + n * 864e5).toISOString().slice(0, 10);
// rank-sum test (normal approximation) for values, two-proportion test for shares; |z| >= 1.96 counts as a clear change
function zValues(a, b) {
  const all = [...a.map((v) => [v, 0]), ...b.map((v) => [v, 1])].sort((x, y) => x[0] - y[0]); let ra = 0;
  for (let i = 0; i < all.length;) { let j = i; while (j < all.length && all[j][0] === all[i][0]) j++; const rank = (i + j + 1) / 2; for (let k = i; k < j; k++) if (all[k][1] === 0) ra += rank; i = j; }
  const n1 = a.length, n2 = b.length, u = ra - (n1 * (n1 + 1)) / 2, sd = Math.sqrt((n1 * n2 * (n1 + n2 + 1)) / 12);
  return sd ? ((n1 * n2) / 2 - u) / sd : 0; // positive: values after are higher
}
const zShares = (h1, n1, h2, n2) => { const p = (h1 + h2) / (n1 + n2), sd = Math.sqrt(p * (1 - p) * (1 / n1 + 1 / n2)); return sd ? (h2 / n2 - h1 / n1) / sd : 0; };
const VALUE = [["Lead time, median (h)", (r) => r.lead, med, -1], ["Review rounds per reviewed PR, mean", (r) => r.rounds || null, mean, -1], ["CI hours per PR, mean", (r) => r.ciHours, mean, -1], ["Changed lines, median", (r) => r.size, med, 0]];
const SHARE = [["Passed on the first attempt", (r) => r.firstPass !== null, (r) => r.firstPass, 1], ["PRs with 2+ review rounds", (r) => r.rounds > 0, (r) => r.rounds >= 2, -1], ["PRs with a failed CI run", (r) => Boolean(r.ci), (r) => r.ci.some((c) => c.conclusion === "failure"), -1],
  ["Merged without any review", () => true, (r) => r.noReview, -1], ["Fix PRs", () => true, (r) => r.isFix, -1], ["Fixed again by a linked fix", () => true, (r) => Boolean(r.fixExplicit), -1], ["Fixes without a test file", (r) => r.isFix && r.touchesSrc, (r) => r.srcNoTest, -1]];
// short keys for the rows, used by "expect" in a change entry
const ROW_KEY = { "Merged per day": "mergedPerDay", "Lead time, median (h)": "lead", "Review rounds per reviewed PR, mean": "rounds", "CI hours per PR, mean": "ciHours", "Changed lines, median": "size", "Passed on the first attempt": "firstPass", "PRs with 2+ review rounds": "multiRound", "PRs with a failed CI run": "ciFailed", "Merged without any review": "noReview", "Fix PRs": "fixShare", "Fixed again by a linked fix": "followUp", "Fixes without a test file": "fixNoTest" };
const verdict = (z, dir, n1, n2) => (n1 < MIN || n2 < MIN ? "too few" : !dir ? "context" : Math.abs(z) < 1.96 ? "no clear change" : Math.sign(z) === dir ? "better" : "worse");
const changeList = (cfg.changes ?? cfg.markers ?? []).filter((c) => c.at >= firstDay && c.at <= lastDay).sort((a, b) => a.at.localeCompare(b.at));
function judge(c, peers) {
  const from = dayPlus(c.at, -W), to = dayPlus(c.at, W - 1);
  const before = rows.filter((r) => r.day >= from && r.day < c.at), after = rows.filter((r) => r.day >= c.at && r.day <= to);
  // a change closer to the start of the mined days than one window has no full baseline
  const baselineShort = from < firstDay, daysBefore = Math.max(1, (new Date(`${c.at}T00:00:00Z`) - new Date(`${baselineShort ? firstDay : from}T00:00:00Z`)) / 864e5);
  const out = [{ name: "Merged per day", before: r1(before.length / daysBefore), after: r1(after.length / Math.max(1, Math.min(W, (new Date(`${lastDay}T00:00:00Z`) - new Date(`${c.at}T00:00:00Z`)) / 864e5 + 1))), n1: before.length, n2: after.length, verdict: "context" }];
  for (const [name, val, stat, dir] of VALUE) { const a = before.map(val).filter((v) => v !== null && v !== undefined), b = after.map(val).filter((v) => v !== null && v !== undefined);
    out.push({ name, before: a.length ? r1(stat(a)) : null, after: b.length ? r1(stat(b)) : null, n1: a.length, n2: b.length, verdict: verdict(a.length && b.length ? zValues(a, b) : 0, dir, a.length, b.length) }); }
  for (const [name, of, hit, dir] of SHARE) { const a = before.filter(of), b = after.filter(of), h1 = count(a, hit), h2 = count(b, hit);
    out.push({ name, share: true, before: r3(share(h1, a.length)), after: r3(share(h2, b.length)), n1: a.length, n2: b.length, verdict: verdict(a.length && b.length ? zShares(h1, a.length, h2, b.length) : 0, dir, a.length, b.length) }); }
  const mb = mainDone.filter((r) => r.createdAt.slice(0, 10) >= from && r.createdAt.slice(0, 10) < c.at), ma = mainDone.filter((r) => r.createdAt.slice(0, 10) >= c.at && r.createdAt.slice(0, 10) <= to);
  const f1 = count(mb, (r) => r.conclusion === "failure"), f2 = count(ma, (r) => r.conclusion === "failure");
  out.push({ name: `Failed CI on ${defaultBranch}`, share: true, before: r3(share(f1, mb.length)), after: r3(share(f2, ma.length)), n1: mb.length, n2: ma.length, verdict: verdict(mb.length && ma.length ? zShares(f1, mb.length, f2, ma.length) : 0, -1, mb.length, ma.length) });
  for (const r of out) r.key = ROW_KEY[r.name] ?? "mainFailed";
  // the change's own expectation: which metric should move which way
  let expectation = null;
  if (c.expect?.metric) {
    const r = out.find((x) => x.key === c.expect.metric), want = c.expect.direction === "up" ? "up" : "down";
    const moved = !r || !["better", "worse"].includes(r.verdict) ? "none" : r.after > r.before ? "up" : "down";
    // no verdict from a short baseline, an unfinished window, or follow-up fixes that can still arrive
    const censored = c.expect.metric === "followUp" && dayPlus(to, cfg.followUpDays ?? 7) > lastDay;
    const verdictE = !r ? "unknown metric" : to > lastDay || baselineShort || censored || r.verdict === "too few" ? "too early" : moved === want ? "confirmed" : "refuted";
    expectation = { metric: c.expect.metric, name: r?.name ?? c.expect.metric, direction: want, before: r?.before ?? null, after: r?.after ?? null, share: Boolean(r?.share), moved, verdict: verdictE };
  }
  return { at: c.at, label: c.label, decidedBy: c.decidedBy ?? null, approval: c.approval ?? null, expectation, windowDays: W, before: { from, to: dayPlus(c.at, -1), n: before.length }, after: { from: c.at, to: to > lastDay ? lastDay : to, n: after.length },
    incomplete: to > lastDay, baselineShort, followUpsCensored: dayPlus(to, cfg.followUpDays ?? 7) > lastDay,
    confounded: peers.filter((o) => o !== c && o.at >= from && o.at <= to).map((o) => `${o.label} (${o.at})`), rows: out };
}
metrics.changes = changeList.map((c) => judge(c, changeList));
// coaching asks (asks.json, written by the skill coach-process): each ask is judged like a change with an expectation,
// from the day it was delivered; the same key asked again counts how often the same thing had to be asked
const askFile = `${dir}/asks.json`;
const askAll = existsSync(askFile) ? JSON.parse(readFileSync(askFile, "utf8")) : [];
// { key, at, dropped: true } and { key, at, escalated: true } are the user's decisions about a key (stop asking it; the user takes it up):
// they are no asks, and each marks every ask of that key up to its day
const decided = (f) => new Map(askAll.filter((a) => a[f]).map((a) => [a.key, a.at]));
const droppedAt = decided("dropped"), escalatedAt = decided("escalated");
// how often a key was asked counts every recorded ask, also those before the analysed period
const askEver = askAll.filter((a) => !a.dropped && !a.escalated).sort((a, b) => a.at.localeCompare(b.at));
const askList = askEver.filter((a) => a.at >= firstDay && a.at <= lastDay);
// every key the user decided, with its latest ask, also when that ask lies before the analysed period
metrics.askDecisions = [...new Set([...droppedAt.keys(), ...escalatedAt.keys()])].map((key) => { const l = askEver.filter((a) => a.key === key).at(-1);
  return { key, decision: droppedAt.has(key) ? "dropped" : "escalated", at: droppedAt.get(key) ?? escalatedAt.get(key), ask: l?.ask ?? null, to: l?.to ?? null, lastAsked: l?.at ?? null, times: askEver.filter((a) => a.key === key).length }; });
metrics.asks = askList.map((a) => {
  const j = judge({ ...a, label: a.ask, expect: a.metric ? { metric: a.metric, direction: a.direction } : a.expect }, changeList);
  const same = askEver.filter((o) => o.key === a.key);
  return { key: a.key, at: a.at, to: a.to ?? null, ask: a.ask, ref: a.ref ?? null, times: same.length, nth: same.indexOf(a) + 1, dropped: droppedAt.has(a.key) && droppedAt.get(a.key) >= a.at, escalated: escalatedAt.has(a.key) && escalatedAt.get(a.key) >= a.at, expectation: j.expectation, incomplete: j.incomplete, confounded: j.confounded };
});
// candidates: merged pull requests that changed the process itself, and when each reviewer was first and last seen
const procRe = new RegExp(cfg.processPaths ?? "^\\.github/|(^|/)(AGENTS|CLAUDE|CONTRIBUTING|CODEOWNERS|REVIEW[A-Z]*)(\\.md)?$|^\\.(cursor|claude|codex|greptile)/|(^|/)(lefthook|\\.pre-commit-config|renovate|biome|eslint\\.config|vitest\\.config|playwright\\.config|turbo)\\.", "i");
metrics.changeCandidates = {
  processPrs: rows.filter((r) => r.p.files.some((f) => procRe.test(f))).slice(-(cfg.candidateList ?? 40)).map((r) => ({ at: r.day, pr: r.p.number, title: r.p.title.slice(0, 100), paths: r.p.files.filter((f) => procRe.test(f)).slice(0, 3) })),
  reviewers: kinds.map((k) => { const d = rows.filter((r) => r.kinds.includes(k)).map((r) => r.day); return { reviewer: k, firstSeen: d[0], lastSeen: d.at(-1), prs: d.length }; }),
};
// meta.json is the last mining call's: its count of pull requests closed without a merge belongs to that call's range only
metrics.meta = existsSync(`${dir}/meta.json`) ? JSON.parse(readFileSync(`${dir}/meta.json`, "utf8")) : null;
if (metrics.meta && !(metrics.meta.since === firstDay && metrics.meta.until === lastDay)) metrics.meta = { ...metrics.meta, closedUnmerged: null };

// rules -> suggestions, and what changed since the previous report of this working directory
const outFile = opt("--out", `${dir}/metrics.json`);
// the rules judge the recent weeks, so that a suggestion describes the process as it runs now
const ruleDays = cfg.ruleWindowDays ?? 28, ruleFrom = dayPlus(lastDay, -(ruleDays - 1));
const recentRows = rows.filter((r) => r.day >= ruleFrom), inWin = (r) => r.createdAt.slice(0, 10) >= ruleFrom;
Object.assign(metrics, evaluate({ total: summ(recentRows), defaultBranch, compare: compareOf(recentRows),
  ci: runs.length ? { all: ciStats(ciRuns.filter(inWin)), prBranches: ciStats(prRuns.filter(inWin)), defaultBranchPush: ciStats(mainRuns.filter(inWin)) } : null }, cfg.rules));
metrics.ruleWindow = { from: ruleFrom < firstDay ? firstDay : ruleFrom, to: lastDay, days: ruleDays, merged: recentRows.length };
if (existsSync(`${dir}/failures.json`)) {
  // jobs that only report that another job failed (a "require all" gate) are noise here: ignoreFailedJobs names them
  const F = JSON.parse(readFileSync(`${dir}/failures.json`, "utf8")), ig = cfg.ignoreFailedJobs && new RegExp(cfg.ignoreFailedJobs, "i"), keep = (j) => !ig || !ig.test(`${j.job} › ${j.step ?? ""}`);
  // failures.json may be from an earlier run over other days: only what lies in this period is shown
  const inP = (iso) => Boolean(iso) && iso.slice(0, 10) >= firstDay && iso.slice(0, 10) <= lastDay;
  metrics.failures = { ...F, defaultBranch: F.defaultBranch.filter((r) => inP(r.at)).map((r) => ({ ...r, failed: r.failed.filter(keep) })), 
    // a flaky job is counted from its single sightings inside the period; a file without them (older format) only when it was mined for exactly this period
    flaky: F.flaky.filter(keep).map((j) => (j.seen ? { ...j, count: count(j.seen, inP) } : F.since === firstDay && F.until === lastDay ? j : { ...j, count: 0 })).filter((j) => j.count > 0).sort((a, b) => b.count - a.count) };
}
const headline = (m) => ({ merged: m.total.merged, leadMedianH: m.total.efficiency.leadMedianH, roundsMean: m.total.efficiency.roundsMean, firstPassShare: m.total.efficiency.firstPassShare ?? null,
  followUpExplicitShare: m.total.quality.followUpExplicitShare, mainFailureRate: m.ci?.defaultBranchPush.failureRate ?? null, notGreenShare: m.ci?.all.hours ? r3(m.ci.all.hoursNotGreen / m.ci.all.hours) : null });
const prevFile = opt("--prev", existsSync(outFile) ? outFile : null);
if (prevFile && existsSync(prevFile)) {
  const old = JSON.parse(readFileSync(prevFile, "utf8"));
  // a re-run over the same period keeps the comparison it already had
  const p = old.period?.to === metrics.period.to && old.period?.from === metrics.period.from ? old.previous : old.results && { generatedAt: old.generatedAt, period: old.period, headline: headline(old), triggered: old.results.filter((r) => r.state === "triggered").map((r) => r.id) };
  if (p) metrics.previous = p;
}
metrics.headline = headline(metrics);

// ---- hand labels: was a reviewer's block right, what caused a failure on the default branch
// labels.tsv: date <tab> kind (block | main-failure) <tab> ref (pull request or run) <tab> subject (reviewer, or empty) <tab> label <tab> labelled by <tab> note
if (existsSync(`${dir}/labels.tsv`)) {
  const L = readFileSync(`${dir}/labels.tsv`, "utf8").split("\n").filter((l) => l.trim() && !l.startsWith("#")).map((l) => l.split("\t")).filter((c) => c.length >= 5 && c[0] !== "date")
    .map(([date, kind, ref, subject, label, by = "", note = ""]) => ({ date, kind, ref, subject, label: label.trim().toLowerCase(), by, note }));
  const tallyBy = (list, f) => list.reduce((mm, x) => ((mm[f(x)] = (mm[f(x)] ?? 0) + 1), mm), {});
  const blocks = L.filter((x) => x.kind === "block");
  metrics.labels = {
    total: L.length, by: tallyBy(L, (x) => x.by || "unknown"),
    reviewers: Object.fromEntries(Object.entries(groupBy(blocks, "subject")).map(([k, g]) => { const right = count(g, (x) => x.label === "right"), wrong = count(g, (x) => x.label === "false alarm"); return [k || "unnamed", { labelled: g.length, right, falseAlarm: wrong, unclear: g.length - right - wrong, hitRate: r3(share(right, right + wrong)), by: tallyBy(g, (x) => x.by || "unknown") }]; })),
    mainFailures: tallyBy(L.filter((x) => x.kind === "main-failure"), (x) => x.label),
  };
}

// ---- the last nine calendar days one by one, for the daily digest: a day without a merge is a day with zero merges, not a missing day
const digestEnd = [lastDay, ...mainRuns.map((r) => r.createdAt.slice(0, 10))].sort().at(-1);
const dayList = digestEnd ? Array.from({ length: 9 }, (_, i) => new Date(+new Date(`${digestEnd}T00:00:00Z`) - (8 - i) * 864e5).toISOString().slice(0, 10)).filter((d) => d >= metrics.period.from) : [];
metrics.daily = dayList.map((d) => { const g = rows.filter((r) => r.day === d), s = summ(g), mr = ciStats(mainRuns.filter((r) => r.createdAt.slice(0, 10) === d));
  return { day: d, merged: g.length, roundsMean: s.efficiency.roundsMean, multiRoundShare: s.efficiency.multiRoundShare, firstPassShare: s.efficiency.firstPassShare, firstPassN: s.efficiency.firstPassN, ciHoursPerPr: s.efficiency.ciHoursPerPr, leadMedianH: s.efficiency.leadMedianH, mainRuns: mr.success + mr.failure, mainFailed: mr.failure, mainFailureRate: mr.failureRate }; });

// ---- history of runs: how long has each suggestion been open
const histDir = `${dir}/history`;
if (!opt("--out")) {
  mkdirSync(histDir, { recursive: true });
  writeFileSync(`${histDir}/${metrics.period.to}.json`, JSON.stringify({ generatedAt: metrics.generatedAt, period: metrics.period, headline: metrics.headline, triggered: metrics.results.filter((r) => r.state === "triggered").map((r) => r.id) }));
  const hist = readdirSync(histDir).filter((f) => f.endsWith(".json")).sort().map((f) => JSON.parse(readFileSync(`${histDir}/${f}`, "utf8")));
  for (const r of metrics.results) { if (r.state !== "triggered") continue; let since = null, runs = 0;
    for (let i = hist.length - 1; i >= 0 && hist[i].triggered.includes(r.id); i--) { since = hist[i].period.to; runs++; }
    r.openSince = since; r.openRuns = runs; }
  metrics.historyRuns = hist.length;
}
// ---- review sample: pull requests assigned by their number to another reviewer (config "sample")
// Compared by assignment, never by who happened to review: the number is not chosen, the reviewer that answered is.
function sampleOf() {
  const s = cfg.sample; if (!s) return null;
  const mod = s.modulo ?? 10, loginOf = Object.fromEntries(rules.filter((r) => r.login).map((r) => [r.name, r.login]));
  const armOf = (n) => (n % mod !== 0 ? s.control : s.bots ? (Math.floor(n / mod) % 2 === 0 ? s.bots.even : s.bots.odd) : s.reviewer);
  const list = rows.filter((r) => r.p.createdAt.slice(0, 10) >= s.since);
  for (const r of list) {
    r.arm = armOf(r.p.number);
    // the first answer of a reviewer: its first review or comment, or (a bot without a finding) its thumbs-up
    const firstOf = (k) => [r.evs.find((e) => e.kind.name === k)?.at, (r.p.reactions ?? []).find((x) => x.by === loginOf[k] && x.content === "THUMBS_UP" && x.at <= r.p.mergedAt)?.at].filter(Boolean).sort()[0] ?? null;
    r.armAt = firstOf(r.arm); r.controlAt = r.arm === s.control ? r.armAt : firstOf(s.control);
    // a bot without a finding may leave only its summary in the description: an answer without a time
    const mark = s.bodyMark?.[r.arm];
    r.armSeen = Boolean(r.armAt) || Boolean(mark && `${r.p.body}\n${r.p.bodyTail ?? ""}`.includes(mark));
    const at = r.armAt ?? (r.armSeen ? null : r.controlAt);
    r.sampleThreads = count(r.threads, (t) => t.kind === (r.armSeen ? r.arm : s.control));
    r.pushesAfter = at ? count(r.p.commits, (c) => c.at > at && !/^Merge /.test(c.msg)) : null;
    r.answerH = at ? hours(r.p.createdAt, at) : null;
  }
  const arm = (name) => {
    const g = list.filter((r) => r.arm === name), answered = g.filter((r) => r.armSeen || r.controlAt), known = (f) => answered.map(f).filter((x) => x !== null);
    return {
      assigned: g.length, byAssigned: count(g, (r) => r.armSeen && !(name !== s.control && r.controlAt)), mixed: count(g, (r) => name !== s.control && r.armSeen && r.controlAt),
      fellBack: count(g, (r) => name !== s.control && !r.armSeen && r.controlAt), noReview: count(g, (r) => !r.armSeen && !r.controlAt),
      leadMedianH: r1(med(g.map((r) => r.lead))), leadP90H: r1(q(g.map((r) => r.lead), 0.9)), answerMedianH: r1(med(known((r) => r.answerH))),
      withThreads: count(answered, (r) => r.sampleThreads > 0), answered: answered.length, withThreadsShare: r3(share(count(answered, (r) => r.sampleThreads > 0), answered.length)),
      threadsMean: r1(mean(answered.map((r) => r.sampleThreads))), pushesAfterMean: r1(mean(known((r) => r.pushesAfter))),
      ciFailed: count(g, (r) => r.ci?.some((c) => c.conclusion === "failure")), ciJudged: count(g, (r) => r.ci),
      defectFix: count(g, (r) => r.fixDefect), linkedFix: count(g, (r) => r.fixExplicit), sizeMedian: med(g.map((r) => r.size)),
    };
  };
  const names = [s.control, ...new Set(s.bots ? [s.bots.even, s.bots.odd] : [s.reviewer])];
  const arms = Object.fromEntries(names.map((n) => [n, arm(n)]));
  const c = arms[s.control], cg = list.filter((r) => r.arm === s.control);
  // each bot against the control group: |z| >= 1.96 is a difference larger than chance explains
  const tests = Object.fromEntries(names.slice(1).map((n) => { const a = arms[n], g = list.filter((r) => r.arm === n), enough = a.assigned >= (s.minPrs ?? 30);
    return [n, { enough, lead: r1(zValues(cg.map((r) => r.lead), g.map((r) => r.lead))), withThreads: r1(zShares(c.withThreads, c.answered || 1, a.withThreads, a.answered || 1)),
      defectFix: r1(zShares(c.defectFix, c.assigned || 1, a.defectFix, a.assigned || 1)), ciFailed: r1(zShares(c.ciFailed, c.ciJudged || 1, a.ciFailed, a.ciJudged || 1)) }]; }));
  return { since: s.since, modulo: mod, control: s.control, target: s.target ?? null, total: list.length, arms, tests,
    fellBackList: list.filter((r) => r.arm !== s.control && !r.armSeen).map((r) => r.p.number).slice(-40) };
}
metrics.sample = sampleOf();
writeFileSync(outFile, JSON.stringify(metrics, null, 1));

const pct =(x) => (x === null ? "-" : `${(x * 100).toFixed(1)} %`);
const t = metrics.total, e = t.efficiency, ql = t.quality;
console.log(`${metrics.repo ?? dir}: ${t.merged} merged pull requests, ${metrics.period.from} to ${metrics.period.to}; rounds counted for reviewer "${roundKind}"`);
console.log(`EFFICIENCY  lead time median ${e.leadMedianH} h, p90 ${e.leadP90H} h; first review after ${e.firstReviewMedianH} h (median); size median ${e.sizeMedian} lines`);
console.log(`  reviewed ${e.reviewed}; rounds mean ${e.roundsMean}; 2+ rounds ${pct(e.multiRoundShare)}; 3+ rounds ${pct(e.threePlusShare)}; first round blocking ${pct(e.firstRoundBlockingShare)}`);
console.log(`  later rounds ${e.laterRounds}: clean ${e.laterClean}, non-blocking findings only ${e.laterNonBlocking}, blocking ${e.laterBlocking}, unknown ${e.laterUnknown}; after merge commits only ${e.laterAfterMergeOnly}`);
console.log(`  CI per pull request: ${e.ciRunsPerPrMedian} runs (median), ${e.ciHoursPerPr} runner-hours (mean), failed runs ${pct(e.ciFailedRunShare)}`);
console.log(`QUALITY  fix share ${pct(ql.fixShare)}; reverts ${ql.reverts}; fixed again within the window: linked ${pct(ql.followUpExplicitShare)} (median after ${ql.followUpMedianH} h), linked or same files ${pct(ql.followUpOverlapShare)}`);
console.log(`  merged without any review ${pct(ql.noReviewShare)}; with unresolved threads ${ql.unresolvedThreadPrs}; source changes without a test file ${pct(ql.sourceWithoutTestShare)}, fixes without one ${pct(ql.fixWithoutTestShare)}`);
if (metrics.ci) { const m = metrics.ci.defaultBranchPush, a = metrics.ci.all;
  console.log(`CI  ${a.runs} runs, ${a.hours} h, of that not green ${a.hoursNotGreen} h; cancelled ${pct(a.cancelledShare)}; re-run ${pct(a.rerunShare)} (${a.rerunGreen} turned green: flake candidates)`);
  console.log(`  ${defaultBranch} pushes: ${m.runs} runs, failure rate ${pct(m.failureRate)}, median ${m.medianMin} min, p90 ${m.p90Min} min`); }
console.log("REVIEWERS  " + Object.entries(reviewers).map(([k, v]) => `${k}: ${pct(v.prShare)} of PRs, ${v.threads} threads`).join("; "));
if (compare) console.log(`COMPARE  ${compare.a} vs ${compare.b} on the same head: both block ${compare.both}, only ${compare.a} ${compare.onlyA}, only ${compare.b} ${compare.onlyB}, neither ${compare.neither}`);
console.log(`written: ${outFile}`);

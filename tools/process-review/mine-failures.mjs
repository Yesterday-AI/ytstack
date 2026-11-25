#!/usr/bin/env node
// Looks into the CI runs that need reading: which job and step failed.
// Usage: node mine-failures.mjs <owner/repo> <workdir> [--since d] [--until d] [--days 7] [--max 150]
// Reads <workdir>/ci (from mine.mjs) and <workdir>/config.json, fetches job details for
//   1. failed push runs on the default branch in the last <days> days, with the commit that was pushed, and
//   2. runs of the whole period that turned green on a re-run (the first attempt's failed jobs: flaky candidates),
// and writes <workdir>/failures.json. One request per run and attempt, so the number of runs is capped.
import { rest } from "./api.mjs";
import { periodOf } from "./period.mjs";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const [repo, dir] = process.argv.slice(2);
const arg = (k, d) => (process.argv.includes(k) ? process.argv[process.argv.indexOf(k) + 1] : d), opt = (k, d) => Number(arg(k, d));
if (!repo?.includes("/") || !dir) { console.error("usage: mine-failures.mjs <owner/repo> <workdir> [--since d] [--until d] [--days 7] [--max 150]"); process.exit(2); }
// the period of the analysis, as analyze.mjs reads it (period.mjs): the working directory keeps the days of earlier runs
const P = periodOf(dir, arg("--since", "0000"), arg("--until", "9999"));
const days = opt("--days", 7), max = opt("--max", 150);
const cfg = existsSync(`${dir}/config.json`) ? JSON.parse(readFileSync(`${dir}/config.json`, "utf8")) : {};
const runs = [...new Map(P.load("ci").map((r) => [r.id, r])).values()].filter((r) => (!cfg.ciWorkflows || cfg.ciWorkflows.includes(r.name)) && P.inBounds(r.createdAt));
if (!runs.length) { console.error("no CI runs mined"); process.exit(1); }
P.cover([runs.map((r) => r.createdAt.slice(0, 10)).sort()[0], runs.map((r) => r.createdAt.slice(0, 10)).sort().at(-1)]);
const tally = {}; for (const r of runs) if (r.event === "push") tally[r.branch] = (tally[r.branch] ?? 0) + 1;
// the default branch, as analyze.mjs finds it: configured, else the base most merged pull requests went into, else the branch with most push runs.
// None of them: the default-branch section stays empty, the re-runs are still read.
const bases = {}; for (const p of P.load("prs")) if (p.base && P.inBounds(p.mergedAt)) bases[p.base] = (bases[p.base] ?? 0) + 1;
const top = (m) => Object.entries(m).sort((a, b) => b[1] - a[1])[0]?.[0];
const main = cfg.defaultBranch ?? top(bases) ?? top(tally) ?? null;
// the window of --days ends on the period's last day
const last = `${P.to}T23:59:59Z`;
const from = new Date(+new Date(last) - days * 864e5).toISOString();

// A request that still fails after its retries is recorded in failures.json and makes the run exit 3, so incomplete evidence is never shown as complete.
const incomplete = [];
const gh = async (path) => { try { return await rest(path, 2); } catch (e) { incomplete.push({ path, error: String(e?.message ?? e).slice(0, 200) }); return null; } };
// the failed jobs of one attempt, each with its first failed step
const jobsOf = async (id, attempt) => { const all = []; for (let page = 1; ; page++) { const j = (await gh(`repos/${repo}/actions/runs/${id}/attempts/${attempt}/jobs?per_page=100&page=${page}`))?.jobs ?? []; all.push(...j); if (j.length < 100) return all; } };
const failed = async (id, attempt) => (await jobsOf(id, attempt))
  .filter((j) => j.conclusion === "failure" || j.conclusion === "timed_out")
  .map((j) => ({ job: j.name, step: j.steps?.find((s) => s.conclusion === "failure")?.name ?? null, minutes: j.started_at && j.completed_at ? Math.round((new Date(j.completed_at) - new Date(j.started_at)) / 6e4) : null }));

const mainFailed = runs.filter((r) => r.branch === main && r.event === "push" && r.conclusion === "failure" && r.createdAt >= from).sort((a, b) => a.createdAt.localeCompare(b.createdAt)).slice(-max);
const defaultBranch = []; for (const r of mainFailed) {
  const run = await gh(`repos/${repo}/actions/runs/${r.id}`);
  const title = run?.display_title ?? "";
  // the merged pull request behind the pushed commit: from the squash title, else from the commit itself
  const pr = Number(title.match(/\(#(\d+)\)\s*$/)?.[1]) || (await gh(`repos/${repo}/commits/${run?.head_sha ?? r.sha}/pulls`))?.[0]?.number || null;
  defaultBranch.push({ id: r.id, at: r.createdAt, sha: r.sha, attempt: r.attempt, title: title.slice(0, 140), pr, url: run?.html_url ?? null, failed: await failed(r.id, r.attempt) });
}
console.log(`default branch: ${defaultBranch.length} failed push runs since ${from.slice(0, 10)}`);

const rerun = runs.filter((r) => r.attempt > 1 && r.conclusion === "success").sort((a, b) => b.createdAt.localeCompare(a.createdAt)).slice(0, max);
const flakyJobs = {};
let read = 0;
for (const r of rerun) {
  const f = await failed(r.id, 1); read++;
  for (const j of f) { const k = `${j.job} › ${j.step ?? "(no failed step recorded)"}`; const s = (flakyJobs[k] ??= { job: j.job, step: j.step, count: 0, lastSeen: "", example: r.id, seen: [] }); s.count++; s.seen.push({ at: r.createdAt, id: r.id }); if (r.createdAt > s.lastSeen) { s.lastSeen = r.createdAt; s.example = r.id; } }
}
console.log(`re-runs that turned green: ${read} read of ${runs.filter((r) => r.attempt > 1 && r.conclusion === "success").length}`);
writeFileSync(`${dir}/failures.json`, JSON.stringify({ repo, at: new Date().toISOString(), days, since: P.from, until: P.to, from: from.slice(0, 10), branch: main, defaultBranch, rerunsRead: read, flaky: Object.values(flakyJobs).sort((a, b) => b.count - a.count), incomplete }, null, 1));
console.log(`written: ${dir}/failures.json`);
if (incomplete.length) { console.error(`incomplete: ${incomplete.length} requests failed after retries (first: ${incomplete[0].path}: ${incomplete[0].error}); listed in failures.json`); process.exit(3); }

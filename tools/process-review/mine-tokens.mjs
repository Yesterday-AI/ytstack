#!/usr/bin/env node
// Token usage of local Claude Code sessions, one record per transcript (a session or one subagent).
// usage: mine-tokens.mjs <projects-dir> <name-filter> <workdir> [--since YYYY-MM-DD]
// Reads transcripts only; counts each API message once (by message id); writes <workdir>/tokens.json.
// A transcript is a "review" when it posts a review to a pull request (that number is its target) and is
// a subagent or was briefed as a review. Any other transcript is "work" and goes to the branch it ran on, else to the
// worktree it names most (at least 60 % of its worktree mentions), else to "coordination".
// Usage is kept in five-minute buckets so the analysis can split work before and after a review.
import { readdirSync, statSync, createReadStream, writeFileSync } from "node:fs";
import { join } from "node:path";
import { createInterface } from "node:readline";
const [root, filter, out] = process.argv.slice(2);
const si = process.argv.indexOf("--since"), since = si > 0 ? process.argv[si + 1] : "0000";
const walk = (d) => readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(join(d, e.name)) : e.name.endsWith(".jsonl") ? [join(d, e.name)] : []));
const files = readdirSync(root).filter((n) => n.includes(filter)).flatMap((n) => walk(join(root, n))).filter((f) => statSync(f).mtime.toISOString() >= since);
const POST = /gh pr review (\d+)|pulls\/(\d+)\/reviews[^"\\]{0,200}?(?:--input|-X POST|--method POST| -f | -F )|(?:--input|-X POST|--method POST)[^"\\]{0,200}?pulls\/(\d+)\/reviews/g;
const BRIEF = /\b(independent|delta|visual)\b[^.\n]{0,80}\breview\b|\breview of (PR|pull request)\b|^review\b/i, ROLES = ["code", "concept", "tests", "security", "visual"];
const B = 5 * 60e3, seen = new Set(), wtBranch = {}, units = [];
for (const f of files) {
  const u = { sub: f.includes("/subagents/"), buckets: new Map(), wt: {}, branches: {}, posts: {}, brief: null, lastTs: 0, n: 0 };
  const rl = createInterface({ input: createReadStream(f) });
  for await (const l of rl) {
    if (l.includes(".worktrees/")) {
      for (const m of l.matchAll(/\.worktrees\/([A-Za-z0-9._-]+)/g)) u.wt[m[1]] = (u.wt[m[1]] ?? 0) + 1;
      for (const m of l.matchAll(/worktree add (?:-q )?-b ([A-Za-z0-9._\/-]+) [^ "\\]*\.worktrees\/([A-Za-z0-9._-]+)/g)) wtBranch[m[2]] = m[1];
    }
    const isUse = l.includes('"tool_use"');
    if (isUse && (l.includes("/reviews") || l.includes("gh pr review"))) for (const m of l.matchAll(POST)) { const n = m[1] ?? m[2] ?? m[3]; u.posts[n] = (u.posts[n] ?? 0) + 1; }
    if (u.brief === null && l.includes('"type":"user"')) { try { const c = JSON.parse(l).message?.content; u.brief = (typeof c === "string" ? c : (c ?? []).map((x) => x.text ?? "").join(" ")).slice(0, 600); } catch { u.brief = ""; } }
    if (!l.includes('"output_tokens"')) continue;
    let j; try { j = JSON.parse(l); } catch { continue; }
    const us = j.message?.usage, id = j.message?.id; if (!us || !id || !j.timestamp || j.timestamp < since) continue;
    if (j.gitBranch && !/^(HEAD|main|master)$/.test(j.gitBranch)) u.branches[j.gitBranch] = (u.branches[j.gitBranch] ?? 0) + 1;
    const cwdWt = /\.worktrees\/([^/]+)/.exec(j.cwd ?? "")?.[1]; if (cwdWt) u.wt[cwdWt] = (u.wt[cwdWt] ?? 0) + 5;
    if (seen.has(id)) continue; seen.add(id);
    const t = Date.parse(j.timestamp), model = j.message.model ?? "unknown", k = Math.floor(t / B) * B + "|" + model;
    const b = u.buckets.get(k) ?? { t: Math.floor(t / B) * B, model, in: 0, cw: 0, cr: 0, out: 0, ms: 0 };
    b.in += us.input_tokens ?? 0; b.cw += us.cache_creation_input_tokens ?? 0; b.cr += us.cache_read_input_tokens ?? 0; b.out += us.output_tokens ?? 0;
    if (u.lastTs && t - u.lastTs < B && t > u.lastTs) b.ms += t - u.lastTs;
    u.lastTs = Math.max(u.lastTs, t); u.buckets.set(k, b); u.n++;
  }
  if (u.n) units.push(u);
}
const top = (o) => { const e = Object.entries(o).sort((a, b) => b[1] - a[1]); const sum = e.reduce((a, x) => a + x[1], 0); return e.length && e[0][1] / sum >= 0.6 ? e[0][0] : null; };
const records = units.map((u) => {
  const pr = top(u.posts), review = Boolean(pr) && (u.sub || BRIEF.test(u.brief ?? ""));
  const b = top(u.branches), w = top(u.wt);
  const head = (u.brief ?? "").slice(0, 200).toLowerCase();
  return { kind: review ? "review" : "work", sub: u.sub,
    ...(review ? { pr: Number(pr), roles: ROLES.filter((r) => new RegExp("\\b" + r + "\\b").test(head)), delta: /\bdelta\b|re-review|second round|round [2-9]/i.test(head) }
      : { key: b ? "branch:" + b : w ? (wtBranch[w] ? "branch:" + wtBranch[w] : "worktree:" + w) : "coordination" }),
    buckets: [...u.buckets.values()].sort((x, y) => x.t - y.t) };
});
writeFileSync(join(out, "tokens.json"), JSON.stringify({ generatedAt: new Date().toISOString(), since, bucketMs: B, files: files.length, messages: seen.size, units: records }));
console.log(`subagents with a review post ${units.filter((u) => u.sub && Object.keys(u.posts).length).length}, briefed as review ${units.filter((u) => u.sub && BRIEF.test(u.brief ?? "")).length}, both ${units.filter((u) => u.sub && Object.keys(u.posts).length && BRIEF.test(u.brief ?? "")).length}`);
console.log(`files ${files.length}, messages ${seen.size}, transcripts ${records.length}, of them reviews ${records.filter((r) => r.kind === "review").length}`);

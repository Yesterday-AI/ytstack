#!/usr/bin/env node
// Mines merged pull requests and CI runs of a GitHub repository into per-day JSONL files.
// Usage: node mine.mjs <owner/repo> <since YYYY-MM-DD> <until YYYY-MM-DD> <outDir> [--only prs|ci]
// Needs: a GitHub token with read access (GITHUB_TOKEN, GH_TOKEN, or a signed-in gh). Node 18 or newer, no dependencies.
// Resumable: a finished day is skipped, today is always re-read.
import { graphql, rest } from "./api.mjs";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";

const [repo, since, until, out] = process.argv.slice(2);
const only = process.argv.includes("--only") ? process.argv[process.argv.indexOf("--only") + 1] : "";
if (!repo?.includes("/") || !/^\d{4}-\d\d-\d\d$/.test(since ?? "") || !/^\d{4}-\d\d-\d\d$/.test(until ?? "") || !out) {
  console.error("usage: mine.mjs <owner/repo> <since> <until> <outDir> [--only prs|ci]");
  process.exit(2);
}
const today = new Date().toISOString().slice(0, 10);
const days = [];
for (let d = new Date(`${since}T00:00:00Z`); d <= new Date(`${until}T00:00:00Z`); d = new Date(+d + 864e5)) days.push(d.toISOString().slice(0, 10));

function save(sub, day, rows) {
  mkdirSync(`${out}/${sub}`, { recursive: true });
  const f = `${out}/${sub}/${day}.jsonl`;
  writeFileSync(`${f}.tmp`, rows.map((r) => JSON.stringify(r)).join("\n") + (rows.length ? "\n" : ""));
  renameSync(`${f}.tmp`, f);
  console.log(`${sub} ${day} ${rows.length}`);
}
// --refresh fetches finished days again (after an update of this script added fields)
const refresh = process.argv.includes("--refresh");
// (a day already written with the current fields is kept, so an interrupted refresh resumes)
const current = (f) => { const s = readFileSync(f, "utf8"); return !s.trim() || s.includes('"authorBot"'); };
const done = (sub, day) => { const f = `${out}/${sub}/${day}.jsonl`; return day !== today && existsSync(f) && (!refresh || sub !== "prs" || current(f)); };

const QUERY = `query($q:String!,$n:Int!,$c:String){search(query:$q,type:ISSUE,first:$n,after:$c){pageInfo{hasNextPage endCursor} nodes{... on PullRequest{
 number title body createdAt mergedAt additions deletions changedFiles headRefName baseRefName author{login __typename}
 labels(first:10){nodes{name}}
 reactions(first:30){nodes{content createdAt user{login}}}
 commits(first:100){totalCount nodes{commit{oid committedDate messageHeadline message}}}
 reviews(first:40){nodes{author{login __typename} state submittedAt body commit{oid}}}
 comments(first:60){nodes{author{login __typename} createdAt body}}
 reviewThreads(first:60){totalCount nodes{isResolved isOutdated resolvedBy{login} path comments(first:1){nodes{author{login __typename} createdAt body pullRequestReview{body}}}}}
 files(first:60){nodes{path}}}}}}`;
// cut text without leaving half an emoji behind (a lone surrogate breaks strict JSON readers such as jq)
const cut = (s, n) => (s ?? "").slice(0, n).replace(/[\uD800-\uDBFF]$/, "");
const who = (a) => ({ by: a?.login ?? "ghost", bot: a?.__typename === "Bot" });

async function minePrs(day) {
  const rows = [];
  let cursor = "";
  let size = 20;
  for (;;) {
    let page;
    try {
      page = (await graphql(QUERY, { q: `repo:${repo} is:pr is:merged merged:${day}`, n: size, c: cursor || null }, 2)).data.search;
    } catch (e) {
      if (size <= 3) throw e;
      size = Math.floor(size / 2); // a heavy page timed out: retry it smaller
      continue;
    }
    for (const p of page.nodes) {
      if (!p?.number) continue;
      rows.push({
        number: p.number, title: p.title, body: cut(p.body, 2000), createdAt: p.createdAt, mergedAt: p.mergedAt,
        additions: p.additions, deletions: p.deletions, changedFiles: p.changedFiles, branch: p.headRefName, base: p.baseRefName,
        author: who(p.author).by, authorBot: who(p.author).bot, bodyTail: cut((p.body ?? "").slice(-400), 400),
        // names in Co-authored-by trailers: the usual mark of an AI assistant
        coAuthors: [...new Set(p.commits.nodes.flatMap(({ commit: c }) => [...(c.message ?? "").matchAll(/^co-authored-by:\s*([^<\n]+)/gim)].map((m) => m[1].trim())))].slice(0, 8),
        labels: p.labels.nodes.map((l) => l.name), commitCount: p.commits.totalCount,
        // a review bot without a finding answers with a reaction on the pull request, not with a review
        reactions: (p.reactions?.nodes ?? []).filter((x) => x.user).map((x) => ({ by: x.user.login.replace(/\[bot\]$/, ""), content: x.content, at: x.createdAt })),
        commits: p.commits.nodes.map(({ commit: c }) => ({ oid: c.oid.slice(0, 9), at: c.committedDate, msg: c.messageHeadline })),
        reviews: p.reviews.nodes.map((r) => ({ ...who(r.author), state: r.state, at: r.submittedAt, head: (r.commit?.oid ?? "").slice(0, 9), body: cut(r.body, 1500) })),
        comments: p.comments.nodes.map((c) => ({ ...who(c.author), at: c.createdAt, body: cut(c.body, 1500) })),
        threadCount: p.reviewThreads.totalCount,
        threads: p.reviewThreads.nodes.filter((t) => t.comments.nodes[0]).map((t) => ({ ...who(t.comments.nodes[0].author), resolved: t.isResolved, outdated: t.isOutdated, resolvedBy: t.resolvedBy?.login ?? null, path: t.path, at: t.comments.nodes[0].createdAt, body: cut(t.comments.nodes[0].body, 400), reviewBody: cut(t.comments.nodes[0].pullRequestReview?.body, 300) })),
        files: p.files.nodes.map((f) => f.path),
      });
    }
    if (!page.pageInfo.hasNextPage) return rows;
    cursor = page.pageInfo.endCursor;
  }
}

async function mineCi(day) {
  const rows = [];
  const windows = [[new Date(`${day}T00:00:00Z`), new Date(`${day}T23:59:59Z`)]];
  const iso = (d) => d.toISOString().slice(0, 19) + "Z";
  while (windows.length) {
    const [a, b] = windows.shift();
    const url = (page) => `repos/${repo}/actions/runs?created=${iso(a)}..${iso(b)}&per_page=100&page=${page}`;
    const first = await rest(url(1));
    if (first.total_count > 1000 && b - a > 60000) {
      // the API returns at most 1000 runs per query: halve the window
      const mid = new Date((+a + +b) / 2);
      windows.push([a, new Date(Math.floor(+mid / 1000) * 1000)], [new Date(Math.floor(+mid / 1000) * 1000 + 1000), b]);
      continue;
    }
    for (let page = 1, res = first; ; res = await rest(url(++page))) {
      for (const r of res.workflow_runs) {
        rows.push({ id: r.id, name: r.name, event: r.event, branch: r.head_branch, sha: (r.head_sha ?? "").slice(0, 9), attempt: r.run_attempt, status: r.status, conclusion: r.conclusion, createdAt: r.created_at, startedAt: r.run_started_at, updatedAt: r.updated_at });
      }
      if (page * 100 >= Math.min(first.total_count, 1000) || !res.workflow_runs.length) break;
    }
  }
  return rows;
}

// what the merged-only view leaves out: pull requests of the period closed without a merge, and those open now
if (only !== "ci") {
  const n = async (q) => (await graphql("query($q:String!){search(query:$q,type:ISSUE,first:1){issueCount}}", { q: `repo:${repo} is:pr ${q}` })).data.search.issueCount;
  mkdirSync(out, { recursive: true });
  writeFileSync(`${out}/meta.json`, JSON.stringify({ repo, since, until, at: new Date().toISOString(), closedUnmerged: await n(`is:closed is:unmerged closed:${since}..${until}`), openNow: await n("is:open"), openOlderThanAWeek: await n(`is:open created:<${new Date(Date.now() - 7 * 864e5).toISOString().slice(0, 10)}`) }));
}
for (const day of days) {
  if (only !== "ci" && !done("prs", day)) save("prs", day, await minePrs(day));
  if (only !== "prs" && !done("ci", day)) save("ci", day, await mineCi(day));
}

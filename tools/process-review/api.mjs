// GitHub API access without dependencies and without the gh CLI.
// Token: GITHUB_TOKEN or GH_TOKEN; when neither is set and gh is installed, `gh auth token`.
// Read access to pull requests, reviews and Actions runs is all it needs.
import { execFileSync } from "node:child_process";

let token = process.env.GITHUB_TOKEN || process.env.GH_TOKEN || "";
if (!token) { try { token = execFileSync("gh", ["auth", "token"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim(); } catch { /* no gh */ } }
if (!token) { console.error("no GitHub token: set GITHUB_TOKEN (read access is enough) or sign in with gh"); process.exit(2); }
const BASE = process.env.GITHUB_API_URL || "https://api.github.com";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function call(path, init, tries) {
  for (let i = 1; ; i++) {
    let res;
    try {
      res = await fetch(`${BASE}/${path}`, { ...init, headers: { authorization: `Bearer ${token}`, accept: "application/vnd.github+json", "x-github-api-version": "2022-11-28", "user-agent": "dev-process-analysis", ...(init?.headers ?? {}) } });
    } catch (e) { if (i >= tries) throw e; await sleep(15000 * i); continue; }
    if (res.ok) return res.json();
    // primary rate limit: wait for the reset; secondary limit or server trouble: back off and retry
    const remaining = res.headers.get("x-ratelimit-remaining"), reset = Number(res.headers.get("x-ratelimit-reset")), retry = Number(res.headers.get("retry-after"));
    if ((res.status === 403 || res.status === 429) && remaining === "0" && reset) { await sleep(Math.max(1000, reset * 1000 - Date.now() + 2000)); continue; }
    if (i >= tries || (res.status < 500 && res.status !== 403 && res.status !== 429)) throw new Error(`GitHub ${res.status} for ${path}: ${(await res.text()).slice(0, 200)}`);
    await sleep(retry ? retry * 1000 : 20000 * i);
  }
}
export const rest = (path, tries = 3) => call(path, undefined, tries);
export async function graphql(query, variables, tries = 3) {
  const body = await call("graphql", { method: "POST", body: JSON.stringify({ query, variables }), headers: { "content-type": "application/json" } }, tries);
  if (body.errors?.length && !body.data) throw new Error(`GitHub GraphQL: ${body.errors[0].message}`);
  return body;
}

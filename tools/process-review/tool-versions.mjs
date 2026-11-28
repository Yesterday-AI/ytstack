#!/usr/bin/env node
// Prints dated change entries for the versions of a tool, ready for "changes" in config.json.
// Usage:
//   node tool-versions.mjs plugin <name>              versions of a Claude Code plugin installed on this machine
//   node tool-versions.mjs file <repoPath> <file> <regex>   version bumps of a pinned tool in a repository file
// "plugin" reads the creation time of each version folder under ~/.claude/plugins/cache/*/<name>/:
// when that version arrived on THIS machine. Other machines and agents may have updated at other times.
// "file" walks the git history of <file> (for example package.json, .tool-versions, a lock file) and
// reports each commit in which the first capture group of <regex> changed: when the repository pinned it.
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";

const [mode, a, b, c] = process.argv.slice(2);
const out = [];
if (mode === "plugin" && a) {
  const cache = `${homedir()}/.claude/plugins/cache`;
  for (const market of existsSync(cache) ? readdirSync(cache) : []) {
    const dir = `${cache}/${market}/${a}`;
    if (!existsSync(dir)) continue;
    for (const v of readdirSync(dir)) {
      const st = statSync(`${dir}/${v}`);
      if (st.isDirectory()) out.push({ at: st.birthtime.toISOString().slice(0, 10), label: `${a} ${v}`, time: st.birthtime.toISOString() });
    }
  }
} else if (mode === "file" && a && b && c) {
  const re = new RegExp(c, "m");
  const log = execFileSync("git", ["-C", a, "log", "--reverse", "--format=%H %cI", "--", b], { encoding: "utf8" }).trim().split("\n").filter(Boolean);
  let last = null;
  for (const line of log) {
    const [sha, time] = line.split(" ");
    let text = "";
    try { text = execFileSync("git", ["-C", a, "show", `${sha}:${b}`], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }); } catch { continue; }
    const v = text.match(re)?.[1] ?? null;
    if (v && v !== last) { out.push({ at: time.slice(0, 10), label: `${b}: ${v}`, time, commit: sha.slice(0, 9) }); last = v; }
  }
} else {
  console.error("usage: tool-versions.mjs plugin <name> | file <repoPath> <file> <regex with one capture group>");
  process.exit(2);
}
out.sort((x, y) => x.time.localeCompare(y.time));
console.log(JSON.stringify(out, null, 1));

#!/usr/bin/env node
// The daily digest: one day against the seven days before it. Observes, recommends nothing.
// Usage: node daily.mjs <metrics.json> [--day YYYY-MM-DD] [--out digest.md]
// Run mine.mjs, mine-failures.mjs (optional) and analyze.mjs first. Default day: the last complete day
// (yesterday when the newest mined day is today). Prints Markdown short enough for a chat message.
import { readFileSync, writeFileSync } from "node:fs";

const [file] = process.argv.slice(2);
const opt = (k) => (process.argv.includes(k) ? process.argv[process.argv.indexOf(k) + 1] : null);
if (!file) { console.error("usage: daily.mjs <metrics.json> [--day YYYY-MM-DD] [--out digest.md]"); process.exit(2); }
const m = JSON.parse(readFileSync(file, "utf8"));
const today = new Date().toISOString().slice(0, 10);
const days = m.daily ?? [];
const day = opt("--day") ?? days.filter((d) => d.day < today).at(-1)?.day;
const cur = days.find((d) => d.day === day);
const base = days.filter((d) => d.day < day).slice(-7);
if (!cur || base.length < 3) { console.error(`not enough days around ${day ?? "?"}: the digest needs the day and at least three days before it`); process.exit(1); }

const pct = (x) => (x === null || x === undefined ? "n/a" : `${(x * 100).toFixed(0)} %`);
const val = (x, unit = "") => (x === null || x === undefined ? "n/a" : `${x}${unit}`);
// a value outside the range of the days before is worth a look; inside it, it is ordinary variation
function line(name, key, fmt, worseWhen) {
  const v = cur[key], prior = base.map((d) => d[key]).filter((x) => x !== null && x !== undefined);
  if (v === null || v === undefined || prior.length < 3) return `- ${name}: ${fmt(v)}`;
  const lo = Math.min(...prior), hi = Math.max(...prior);
  const flag = v > hi ? (worseWhen === "high" ? " ⚠ above" : " ↑ above") : v < lo ? (worseWhen === "low" ? " ⚠ below" : " ↓ below") : "";
  return `- ${name}: **${fmt(v)}**${flag ? `${flag} the range of the ${prior.length} days before (${fmt(lo)} to ${fmt(hi)})` : ` (range before: ${fmt(lo)} to ${fmt(hi)})`}`;
}
const out = [`**Process digest ${day}** · ${m.repo ?? ""}`.trim(), "",
  line("Merged pull requests", "merged", (x) => val(x), null),
  line("Review rounds per reviewed pull request", "roundsMean", (x) => val(x), "high"),
  line("Passed on the first attempt", "firstPassShare", pct, "low"),
  line("CI hours per pull request", "ciHoursPerPr", (x) => val(x, " h"), "high"),
  line(`Failed pushes to ${m.defaultBranch}`, "mainFailureRate", pct, "high") + (cur.mainRuns ? ` · ${cur.mainFailed} of ${cur.mainRuns} runs` : ""),
];
const fails = (m.failures?.defaultBranch ?? []).filter((r) => r.at.slice(0, 10) === day);
if (fails.length) {
  out.push("", `Failed pushes to ${m.failures.branch} that day, to be labelled (merged defect, inherited, flaky test, infrastructure):`);
  for (const r of fails.slice(0, 12)) out.push(`- ${r.at.slice(11, 16)} ${r.pr ? `#${r.pr}` : r.sha} ${r.title.slice(0, 70)} · ${r.failed.map((j) => `${j.job} › ${j.step ?? "?"}`).join(" + ") || "no failed job recorded"}`);
  if (fails.length > 12) out.push(`- and ${fails.length - 12} more`);
}
const newFlaky = (m.failures?.flaky ?? []).filter((j) => j.lastSeen.slice(0, 10) === day).slice(0, 5);
if (newFlaky.length) { out.push("", "Jobs that failed and passed on a re-run that day:"); for (const j of newFlaky) out.push(`- ${j.job} › ${j.step ?? "?"} (${j.count} times in the period)`); }
const pending = (m.changes ?? []).filter((c) => c.approval === "pending");
if (pending.length) out.push("", `${pending.length} process change${pending.length > 1 ? "s await" : " awaits"} a person's approval: ${pending.map((c) => `${c.label} (${c.at})`).join("; ")}.`);
out.push("", "_A digest observes. Changes are decided in the weekly review._");
const text = out.join("\n");
if (opt("--out")) writeFileSync(opt("--out"), `${text}\n`);
console.log(text);

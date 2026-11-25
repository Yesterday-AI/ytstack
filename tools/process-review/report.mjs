#!/usr/bin/env node
// Renders metrics.json (from analyze.mjs) as one self-contained HTML file.
// Usage: node report.mjs <metrics.json> <report.html> [--findings findings.json]
// findings.json: [{ "value": "14 %", "tone": "good|warn|bad", "title": "...", "recommendation": "...", "evidence": "..." }]
// written by the analyst; each becomes a card with the value large and the evidence folded.
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const [inFile, outFile] = process.argv.slice(2);
if (!inFile || !outFile) { console.error("usage: report.mjs <metrics.json> <report.html> [--findings findings.json]"); process.exit(2); }
const m = JSON.parse(readFileSync(inFile, "utf8"));
const fi = process.argv.indexOf("--findings");
const findings = fi > 0 && existsSync(process.argv[fi + 1]) ? JSON.parse(readFileSync(process.argv[fi + 1], "utf8")) : [];

const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const short = (k) => { const [, mo, d] = k.split("-"); return `${Number(d)}.${Number(mo)}.`; };
const pct = (x) => (x === null || x === undefined ? "–" : `${(x * 100).toFixed(1)} %`);
const U = (x) => (x === null || x === undefined ? "–" : "$" + Number(x).toLocaleString("en-US"));
const num = (x, unit = "") => (x === null || x === undefined ? "–" : `${x}${unit}`);
const COLORS = ["#d97706", "#0891b2", "#7c3aed", "#c2410c", "#15803d", "#be185d", "#4f6bed", "#64748b"];

function bars({ keys, values, series, title, sub, width = 1080, height = 300, labelEvery = 1, unit = "", markers = [], dimLast = false, label = short }) {
  const padL = 46, padR = 16, padT = 56, padB = 40;
  const all = series ? series.flatMap((s) => s.values) : values;
  const max = Math.max(1e-9, ...all.map((v) => v ?? 0));
  const step = 10 ** Math.floor(Math.log10(max)); const top = Math.ceil(max / step) * step;
  const w = (width - padL - padR) / Math.max(1, keys.length);
  const y = (v) => padT + (height - padT - padB) * (1 - (v ?? 0) / top);
  let s = `<svg viewBox="0 0 ${width} ${height}" role="img" aria-label="${esc(title)}"><text x="${padL}" y="24" class="t">${esc(title)}</text><text x="${padL}" y="42" class="s">${esc(sub ?? "")}</text>`;
  for (let i = 0; i <= 4; i++) { const g = (top / 4) * i; s += `<line x1="${padL}" x2="${width - padR}" y1="${y(g)}" y2="${y(g)}" class="grid"/><text x="${padL - 8}" y="${y(g) + 4}" class="ax" text-anchor="end">${+g.toFixed(2)}</text>`; }
  keys.forEach((k, i) => {
    const x = padL + i * w;
    if (series) { const bw = (w * 0.8) / series.length;
      series.forEach((sr, j) => { const v = sr.values[i] ?? 0; s += `<rect x="${x + w * 0.1 + j * bw}" y="${y(v)}" width="${Math.max(0.5, bw * 0.9)}" height="${y(0) - y(v)}" fill="${sr.color}"><title>${k} · ${esc(sr.name)}: ${v}${unit}</title></rect>`; });
    } else { const v = values[i];
      s += `<rect x="${x + w * 0.15}" y="${y(v)}" width="${w * 0.7}" height="${y(0) - y(v)}" class="bar${dimLast && i === keys.length - 1 ? " cur" : ""}"><title>${k}: ${v ?? "–"}${unit}</title></rect>`;
      if (keys.length <= 16 && v !== null && v !== undefined) s += `<text x="${x + w / 2}" y="${y(v) - 5}" class="val" text-anchor="middle">${v}</text>`; }
    if (i % labelEvery === 0 || i === keys.length - 1) s += `<text x="${x + w / 2}" y="${height - padB + 16}" class="ax" text-anchor="middle">${esc(label(k))}</text>`;
  });
  // more than three changes: numbers on the lines, the legend below the charts (changeLegend)
  const many = markers.length > 3;
  markers.forEach((mk, n) => {
    if (mk.index < 0) return;
    const mx = padL + (mk.index + (mk.frac ?? 0)) * w, ty = many ? 58 + (n % 2) * 13 : 60 + n * 14, right = mx > width * 0.6, col = COLORS[(n + 3) % 8];
    s += `<line x1="${mx}" x2="${mx}" y1="${ty - 8}" y2="${height - padB}" class="mk" stroke="${col}"/>` + (many
      ? `<text x="${mx + 4}" y="${ty}" class="mkt" fill="${col}">${n + 1}</text>`
      : `<text x="${mx + (right ? -6 : 6)}" y="${ty}" class="mkt" fill="${col}" text-anchor="${right ? "end" : "start"}">${esc(mk.label)}${mk.label ? " · " : ""}${short(mk.at)}</text>`);
  });
  if (series) { let lx = width - padR; [...series].reverse().forEach((sr) => { lx -= sr.name.length * 6.4 + 24; s += `<rect x="${lx}" y="16" width="10" height="10" fill="${sr.color}"/><text x="${lx + 14}" y="25" class="ax">${esc(sr.name)}</text>`; }); }
  return `${s}</svg>`;
}

// every calendar day and week of the period, including empty ones
const dayKeys = []; for (let d = new Date(`${m.period.from}T00:00:00Z`); d <= new Date(`${m.period.to}T00:00:00Z`); d = new Date(+d + 864e5)) dayKeys.push(d.toISOString().slice(0, 10));
const lastDays = dayKeys.slice(-42);
const weekKeys = Object.keys(m.weeks).sort();
const mondayOf = (iso) => { const d = new Date(`${iso}T00:00:00Z`); return new Date(+d - ((d.getUTCDay() + 6) % 7) * 864e5).toISOString().slice(0, 10); };
const dayMarkers = m.markers.map((mk) => ({ ...mk, index: lastDays.indexOf(mk.at) }));
const weekMarkers = m.markers.map((mk) => ({ ...mk, index: weekKeys.indexOf(mondayOf(mk.at)), frac: ((new Date(`${mk.at}T00:00:00Z`).getUTCDay() + 6) % 7) / 7 }));
const kindNames = Object.entries(m.reviewers).sort((a, b) => b[1].prs - a[1].prs).slice(0, 6).map(([k]) => k);
const wk = (f) => weekKeys.map((k) => f(m.weeks[k]));
const p100 = (x) => (x === null || x === undefined ? null : +(x * 100).toFixed(1));
const small = (title, sub, values, unit) => `<div class="card half">${bars({ keys: weekKeys, values, title, sub, unit, width: 530, height: 240, labelEvery: Math.ceil(weekKeys.length / 8), markers: weekMarkers.map((x) => ({ ...x, label: "" })) })}</div>`;

const t = m.total, e = t.efficiency, ql = t.quality, ci = m.ci;
// inline icons (Lucide outlines, ISC licence), so the file stays self-contained
const ICON = {
  merge: '<circle cx="18" cy="18" r="3"/><circle cx="6" cy="6" r="3"/><path d="M6 21V9a9 9 0 0 0 9 9"/>',
  clock: '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
  repeat: '<path d="m17 2 4 4-4 4"/><path d="M3 11v-1a4 4 0 0 1 4-4h14"/><path d="m7 22-4-4 4-4"/><path d="M21 13v1a4 4 0 0 1-4 4H3"/>',
  wrench: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>',
  fail: '<circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/>',
  zap: '<path d="M13 2 3 14h9l-1 8 10-12h-9l1-8z"/>',
  warn: '<path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  good: '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
  trend: '<polyline points="22 7 13.5 15.5 8.5 10.5 2 17"/><polyline points="16 7 22 7 22 13"/>',
  gauge: '<path d="m12 14 4-4"/><path d="M3.34 19a10 10 0 1 1 17.32 0"/>',
  shield: '<path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/><path d="m9 12 2 2 4-4"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  play: '<circle cx="12" cy="12" r="10"/><polygon points="10 8 16 12 10 16 10 8"/>',
  search: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
  bulb: '<path d="M15 14c.2-1 .7-1.7 1.5-2.5 1-.9 1.5-2.2 1.5-3.5A6 6 0 0 0 6 8c0 1 .2 2.2 1.5 3.5.7.7 1.3 1.5 1.5 2.5"/><path d="M9 18h6"/><path d="M10 22h4"/>',
  test: '<path d="M14.5 2v17.5c0 1.4-1.1 2.5-2.5 2.5s-2.5-1.1-2.5-2.5V2"/><path d="M8.5 2h7"/><path d="M14.5 16h-5"/>',
  eye: '<path d="M2.06 12.35a1 1 0 0 1 0-.7 10.75 10.75 0 0 1 19.88 0 1 1 0 0 1 0 .7 10.75 10.75 0 0 1-19.88 0"/><circle cx="12" cy="12" r="3"/>',
  undo: '<path d="M3 7v6h6"/><path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13"/>',
};
ICON.bad = ICON.fail;
const icon = (name, size = 18) => `<svg class="ic" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICON[name] ?? ""}</svg>`;
const slug = (x) => x.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").split("-").slice(0, 2).join("-");
const h2 = (name, text) => `<h2 id="${slug(text)}"><span class="hb">${icon(name)}</span>${esc(text)}</h2>`;
// weekly trend as a small line; null values are skipped
function spark(values) {
  const pts = values.map((v, i) => [i, v]).filter(([, v]) => v !== null && v !== undefined);
  if (pts.length < 2) return "";
  const W = 132, H = 34, max = Math.max(...pts.map((p) => p[1])), min = Math.min(0, ...pts.map((p) => p[1])), n = values.length - 1;
  const xy = pts.map(([i, v]) => [4 + (i / n) * (W - 8), H - 4 - ((v - min) / (max - min || 1)) * (H - 8)]);
  const line = xy.map((p) => p.map((c) => c.toFixed(1)).join(",")).join(" ");
  return `<svg class="sp" viewBox="0 0 ${W} ${H}" aria-hidden="true"><polygon points="${xy[0][0].toFixed(1)},${H} ${line} ${xy.at(-1)[0].toFixed(1)},${H}" class="spa"/><polyline points="${line}" class="spl"/><circle cx="${xy.at(-1)[0].toFixed(1)}" cy="${xy.at(-1)[1].toFixed(1)}" r="2.6" class="spd"/></svg>`;
}
// one horizontal bar split into labelled parts
function stack(title, parts) {
  const total = parts.reduce((s, p) => s + (p.value ?? 0), 0);
  if (!total) return "";
  return `<div class="card st"><div class="stt">${esc(title)}</div><div class="stb">${parts.filter((p) => p.value).map((p) => `<span style="width:${(p.value / total) * 100}%;background:${p.color}" title="${esc(p.name)}: ${p.value}"></span>`).join("")}</div><div class="stl">${parts.map((p) => `<span><i style="background:${p.color}"></i>${esc(p.name)} <b>${p.value}</b> · ${((p.value / total) * 100).toFixed(0)} %</span>`).join("")}</div></div>`;
}
const tile = (v, label, ic, trend, extra = "") => `<div class="k">${ic ? `<span class="kb">${icon(ic)}</span>` : ""}<b>${v}</b><span>${esc(label)}</span>${extra}${trend ? spark(trend) : ""}</div>`;
const tbl = (head, rows) => `<table><tr>${head.map((h) => `<th>${esc(h)}</th>`).join("")}</tr>${rows.map((r) => `<tr>${r.map((c) => `<td>${c}</td>`).join("")}</tr>`).join("")}</table>`;
const FOLD = new Set(["By role in the brief", "By round", "Review rounds", "Longest lead time", "Where"]);
const TOP = 10;
const table = (head, rows) => (FOLD.has(head[0]) ? `<details class="nd"><summary>Table: ${esc(head[0].toLowerCase())} (${rows.length} rows)</summary>${tbl(head, rows)}</details>`
  : rows.length <= TOP ? tbl(head, rows) : `${tbl(head, rows.slice(0, TOP))}<details class="nd"><summary>Show all ${rows.length} rows: ${esc(head[0].toLowerCase())}</summary>${tbl(head, rows)}</details>`);
// ---- suggestions from the rules, scores per group, the pipeline as a map
const prev = m.previous ?? null;
const was = (key, fmt) => (prev && prev.headline[key] !== null && prev.headline[key] !== undefined ? `<em class="dl">last report: ${fmt(prev.headline[key])}</em>` : "");
const SEV = { high: ["bad", "High"], medium: ["warn", "Medium"], low: ["", "Low"] };
const results = m.results ?? [];
const hits = results.filter((r) => r.state === "triggered").sort((a, b) => "high medium low".indexOf(a.severity) - "high medium low".indexOf(b.severity));
const passed = results.filter((r) => r.state === "passed");
const skipped = results.filter((r) => r.state === "not-evaluated");
const resolved = prev ? prev.triggered.filter((id) => passed.some((r) => r.id === id)) : [];
const card = (r) => `<div class="f ${SEV[r.severity][0]}" id="${r.id}"><span class="chip ${SEV[r.severity][0]}">${icon(r.severity === "low" ? "bulb" : SEV[r.severity][0], 14)}${SEV[r.severity][1]} · ${esc(r.group)}</span>${r.openRuns > 1 ? `<span class="chip">open for ${r.openRuns} runs, since ${esc(r.openSince)}</span>` : prev ? `<span class="chip">${prev.triggered.includes(r.id) ? "also in the last report" : "new"}</span>` : ""}
<b>${esc(r.name)}</b><p>${esc(r.text)}</p><p class="fa">→ ${esc(r.action)}</p>
<details><summary>Why it matters, and the rule</summary><p class="fr">${esc(r.why)}</p><p class="fp">Rule <code>${r.id}</code> · threshold ${r.threshold} · sample ${r.n}${r.ref ? ` · reference: ${esc(r.ref)}` : ""}</p></details></div>`;
const ring = (g, label) => { const s = m.scores?.[g]; if (!s) return `<div class="k sc"><div><b>–</b><span>${label} · not evaluated</span></div></div>`;
  const c = s.score >= 80 ? "#15803d" : s.score >= 50 ? "#d97706" : "#dc2626", len = 2 * Math.PI * 20;
  return `<div class="k sc"><svg width="56" height="56" viewBox="0 0 56 56" aria-hidden="true"><circle cx="28" cy="28" r="20" fill="none" class="rg" stroke-width="6"/><circle cx="28" cy="28" r="20" fill="none" stroke="${c}" stroke-width="6" stroke-linecap="round" stroke-dasharray="${(len * s.score) / 100} ${len}" transform="rotate(-90 28 28)"/></svg><div><b>${s.score}</b><span>${label} · ${s.triggered} of ${s.evaluated} rules triggered</span></div></div>`; };
function factory() {
  const W = 1080, bw = 180, bh = 88, y = 64, gap = (W - 40 - 5 * bw) / 4, x = (i) => 20 + i * (bw + gap);
  const st = [
    ["merge", "Pull request", `${t.merged} merged`, `${num(e.sizeMedian)} changed lines (median)`],
    ["play", "CI on the branch", `${num(e.ciRunsPerPrMedian)} runs per pull request`, ci ? `${num(ci.all.medianMin, " min")} per green run` : "no CI data"],
    ["eye", "Review", `${num(e.roundsMean)} rounds per pull request`, `first review after ${num(e.firstReviewMedianH, " h")}`],
    ["clock", "Merge", `${num(e.leadMedianH, " h")} from open to merge`, `${num(e.leadP90H, " h")} at the 90th percentile`],
    ["shield", `Branch ${m.defaultBranch}`, ci ? `${pct(ci.defaultBranchPush.failureRate)} of pushes fail CI` : "no CI data", ci ? `${num(ci.defaultBranchPush.medianMin, " min")} per green run` : ""],
  ];
  const loops = [[1, e.ciLoopShare, "of the pull requests had a failed CI run", 0.2], [2, e.multiRoundShare, "needed another review round", 0.3], [4, ql.followUpExplicitShare, "were fixed again after merge", 0.1]];
  let s = `<svg viewBox="0 0 ${W} 290" role="img" aria-label="The pipeline and its loops"><defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0 0 10 5 0 10z" class="ahf"/></marker></defs>
<text x="20" y="24" class="t">The pipeline and its loops</text><text x="20" y="42" class="s">${e.firstPassShare !== null && e.firstPassShare !== undefined ? `${pct(e.firstPassShare)} of ${e.firstPassN} pull requests passed on the first attempt (first CI run green, first review not blocking)` : "first-attempt pass rate: not available for this period"}</text>`;
  st.forEach(([ic, title, a, b], i) => {
    s += `<rect x="${x(i)}" y="${y}" width="${bw}" height="${bh}" rx="10" class="stn"/><g transform="translate(${x(i) + 12} ${y + 12})" class="sti"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${ICON[ic]}</svg></g>
<text x="${x(i) + 38}" y="${y + 26}" class="t">${esc(title)}</text><text x="${x(i) + 12}" y="${y + 52}" class="stv">${esc(a)}</text><text x="${x(i) + 12}" y="${y + 72}" class="s">${esc(b)}</text>`;
    if (i < 4) s += `<line x1="${x(i) + bw + 4}" x2="${x(i + 1) - 6}" y1="${y + bh / 2}" y2="${y + bh / 2}" class="fw" marker-end="url(#ah)"/>`;
  });
  loops.forEach(([from, v, label, bad], k) => {
    if (v === null || v === undefined) return;
    const sx = x(from) + bw / 2, tx = x(0) + bw / 2 + (k - 1) * 34, by = y + bh + 38 + k * 40, col = v >= bad ? "#dc2626" : "#64748b";
    s += `<path d="M${sx} ${y + bh + 2} V${by - 8} Q${sx} ${by} ${sx - 8} ${by} H${tx + 8} Q${tx} ${by} ${tx} ${by - 8} V${y + bh + 8}" fill="none" stroke="${col}" stroke-width="1.8" stroke-dasharray="6 4" marker-end="url(#ah)"/>
<text x="${(sx + tx) / 2}" y="${by + 16}" text-anchor="middle" class="lpl" fill="${col}"><tspan font-weight="700">${pct(v)}</tspan> ${esc(label)}</text>`;
  });
  return `${s}</svg>`;
}
const dur = (h) => (h === null || h === undefined ? "–" : h < 1 ? `${Math.round(h * 60)} min` : h < 48 ? `${+h.toFixed(1)} h` : `${+(h / 24).toFixed(1)} d`);
// horizontal bars: median as the bar, 75th and 90th percentile as marks on a square-root scale
function phases() {
  const P = m.phases; if (!P) return "";
  const rowsP = [["Open → first review", P.pickup], ["First → last review", P.review], ["Last review → merge", P.mergeWait], ["Open → merge (all)", P.lead]].filter(([, v]) => v?.n);
  const W = 1080, left = 190, right = 150, top = 56, rh = 34, max = Math.max(0.1, ...rowsP.map(([, v]) => v.p90H ?? 0)), sx = (v) => left + Math.sqrt((v ?? 0) / max) * (W - left - right);
  let s = `<svg viewBox="0 0 ${W} ${top + rowsP.length * rh + 28}" role="img" aria-label="Where the time goes"><text x="20" y="24" class="t">Where the time goes</text><text x="20" y="42" class="s">bar = median, thin line to the 90th percentile, tick = 75th percentile · hours, square-root scale · medians of phases do not add up to the total</text>`;
  rowsP.forEach(([name, v], i) => { const y = top + i * rh;
    s += `<text x="${left - 10}" y="${y + 15}" class="ax" text-anchor="end" style="font-size:12.5px">${name}</text><line x1="${left}" x2="${sx(v.p90H)}" y1="${y + 11}" y2="${y + 11}" class="fw"/><rect x="${left}" y="${y + 2}" width="${Math.max(2, sx(v.medianH) - left)}" height="18" rx="3" class="${i === rowsP.length - 1 ? "bar cur" : "bar"}"/><line x1="${sx(v.p75H)}" x2="${sx(v.p75H)}" y1="${y + 3}" y2="${y + 19}" class="fw"/>
<text x="${sx(v.p90H) + 8}" y="${y + 15}" class="val">${dur(v.medianH)} · p75 ${dur(v.p75H)} · p90 ${dur(v.p90H)}</text>`; });
  return `<div class="card">${s}</svg></div>`;
}
function heat() {
  const Hm = m.heat; if (!Hm) return "";
  const W = 1080, left = 60, top = 56, cw = (W - left - 20) / 24, ch = 22, max = Math.max(1, ...Hm.flat()), days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
  let peak = [0, 0]; Hm.forEach((r, d) => r.forEach((v, h) => { if (v > Hm[peak[0]][peak[1]]) peak = [d, h]; }));
  let s = `<svg viewBox="0 0 ${W} ${top + 7 * ch + 26}" role="img" aria-label="Merges by weekday and hour"><text x="20" y="24" class="t">When pull requests merge</text><text x="20" y="42" class="s">merges by weekday and hour (UTC) · busiest: ${days[peak[0]]} ${peak[1]}:00 with ${Hm[peak[0]][peak[1]]}</text>`;
  Hm.forEach((r, d) => { s += `<text x="${left - 8}" y="${top + d * ch + 15}" class="ax" text-anchor="end">${days[d]}</text>`;
    r.forEach((v, h) => { s += `<rect x="${left + h * cw + 1}" y="${top + d * ch + 1}" width="${cw - 2}" height="${ch - 2}" rx="3" class="hc" style="opacity:${v ? 0.12 + 0.88 * (v / max) : 0.04}"><title>${days[d]} ${h}:00 · ${v} merges</title></rect>`; }); });
  for (let h = 0; h < 24; h += 3) s += `<text x="${left + h * cw + cw / 2}" y="${top + 7 * ch + 16}" class="ax" text-anchor="middle">${h}:00</text>`;
  return `<div class="card">${s}</svg></div>`;
}
function yieldRows() {
  const Y = m.roundYield; if (!Y?.length) return "";
  const parts = [["a blocking finding", "blocking", "#dc2626"], ["only non-blocking findings", "nonBlocking", "#d97706"], ["nothing", "clean", "#64748b"], ["not readable", "unknown", "#cbd5e1"]];
  return `<div class="card st"><div class="stt">What each review round found</div>${Y.map((r) => `<div class="yr"><span class="yl">Round ${r.round} <em>(${r.n})</em></span><div class="stb">${parts.filter(([, k]) => r[k]).map(([name, k, c]) => `<span style="width:${(r[k] / r.n) * 100}%;background:${c}" title="${name}: ${r[k]} of ${r.n}"></span>`).join("")}</div><span class="yv">${r.n - r.unknown ? `${((r.blocking / (r.n - r.unknown)) * 100).toFixed(0)} % blocking` : "–"}</span></div>`).join("")}
<div class="stl">${parts.map(([name, , c]) => `<span><i style="background:${c}"></i>${name}</span>`).join("")}<span>share blocking = of the rounds with a readable result</span></div></div>`;
}
// what each dated change did: clear changes up front, the full before/after table folded
const dayMinus = (d, n) => new Date(+new Date(`${d}T00:00:00Z`) - n * 864e5).toISOString().slice(0, 10), lastOf = m.period.to;
function changes() {
  const C = m.changes ?? []; if (!C.length) return "";
  const fmt = (r, v) => (v === null || v === undefined ? "–" : r.share ? pct(v) : v);
  const mark = { better: ["good", "better"], worse: ["bad", "worse"] };
  const cardC = (c) => { const clear = c.rows.filter((r) => mark[r.verdict]);
    return `<div class="f"><span class="chip">${short(c.at)}${c.at.slice(0, 4)}</span><span class="chip">${c.before.n} PRs before · ${c.after.n} after</span>${c.incomplete ? '<span class="chip warn">after-window still running</span>' : ""}
<b>${esc(c.label)}</b>
${c.approval === "pending" ? `<p><span class="chip warn">${icon("warn", 14)}awaits a person's approval</span>${c.decidedBy ? `<span class="chip">decided by ${esc(c.decidedBy)}</span>` : ""}</p>` : c.approval ? `<p><span class="chip">${esc(c.approval)}${c.decidedBy ? ` · decided by ${esc(c.decidedBy)}` : ""}</span></p>` : ""}
${c.expectation ? `<p class="ex ${c.expectation.verdict === "confirmed" ? "good" : c.expectation.verdict === "refuted" ? "bad" : ""}">${icon(c.expectation.verdict === "confirmed" ? "good" : c.expectation.verdict === "refuted" ? "bad" : "clock", 16)}<span>Expected: ${esc(c.expectation.name)} goes ${c.expectation.direction}. ${fmt(c.expectation, c.expectation.before)} → ${fmt(c.expectation, c.expectation.after)}: <b>${esc(c.expectation.verdict)}</b></span></p>` : ""}
${clear.length ? `<ul class="cl">${clear.map((r) => `<li class="${mark[r.verdict][0]}">${icon(r.verdict === "better" ? "good" : "bad", 16)}<span>${esc(r.name)}: ${fmt(r, r.before)} → <b>${fmt(r, r.after)}</b> <em>${mark[r.verdict][1]}</em></span></li>`).join("")}</ul>` : `<p class="fr">No metric changed clearly within ${c.windowDays} days before and after.</p>`}
${c.confounded.length ? `<p class="fp">${icon("warn", 14)} ${c.confounded.length} other changes fall inside the windows; the effect cannot be attributed to this one alone.</p><details><summary>The ${c.confounded.length} other changes</summary><p>${esc(c.confounded.join(", "))}.</p></details>` : ""}
<details><summary>All ${c.rows.length} metrics, before and after</summary>${tbl(["Metric", "Before", "After", "n before", "n after", "Reading"], c.rows.map((r) => [esc(r.name), fmt(r, r.before), fmt(r, r.after), r.n1, r.n2, r.verdict + (r.name.startsWith("Fixed again") && c.followUpsCensored ? " (later fixes may still come)" : "")]))}</details></div>`; };
  const cand = m.changeCandidates;
  return `${h2("repeat", "Changes and their effect")}
<p class="note">Each card compares the ${C[0].windowDays} days before a change with the ${C[0].windowDays} days from it on (by merge day, UTC). “Better” and “worse” are shown only where the difference is larger than chance would explain at the 5 % level (rank-sum test for values, two-proportion test for shares) and both sides hold at least ${m.changeMinSample ?? 20} cases. A change that falls together with others, or with a different mix of work, shows what happened after it, not what it caused.</p>
${((open, rest) => `<div class="fs">${open.map(cardC).join("")}</div>${rest.length ? `<details class="nd grp"><summary>${rest.length} dated changes without a stated expectation</summary><div class="fs">${rest.map(cardC).join("")}</div></details>` : ""}`)(C.filter((c) => c.expectation), C.filter((c) => !(c.expectation)))}
${cand ? `<details class="cd"><summary>Process changes found in the history (${cand.processPrs.length} pull requests that touched workflows, review rules or agent instructions) -- candidates for <code>changes</code> in <code>config.json</code></summary>${table(["Merged", "Pull request", "Files"], [...cand.processPrs].reverse().map((p) => [p.at, `${prLink(p.pr)} ${esc(p.title)}`, p.paths.map((x) => `<code>${esc(x)}</code>`).join(" ")]))}
${table(["Reviewer", "First seen", "Last seen", "PRs"], cand.reviewers.map((r) => [esc(r.reviewer), r.firstSeen, r.lastSeen, r.prs]))}</details>` : ""}`;
}
const CLASS_HELP = "Risk class by the files a pull request touches. Process cost should rise from top to bottom.";
const prLink = (n) => (m.repo ? `<a href="https://github.com/${esc(m.repo)}/pull/${n}">#${n}</a>` : `#${n}`);

const html = `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(m.repo ?? "Repository")} · development process</title>
<style>
body{font:15px/1.45 -apple-system,system-ui,sans-serif;margin:32px auto;max-width:1100px;padding:0 16px;color:#1f2328;background:#fafafa}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:32px 0 12px}.lead{color:#59636e;margin:0 0 24px}
.kpis{display:flex;flex-wrap:wrap;gap:12px;margin-bottom:16px}.k{background:#fff;border:1px solid #e4e6ea;border-radius:10px;padding:12px 16px;flex:1 1 150px}
.k b{display:block;font-size:24px}.k span{color:#59636e;font-size:13px}
.card{background:#fff;border:1px solid #e4e6ea;border-radius:10px;padding:8px 8px 4px;margin-bottom:16px}.grid2{display:flex;flex-wrap:wrap;gap:16px}.half{flex:1 1 480px;margin:0}
.card svg{width:100%;height:auto}.ic{width:18px;height:18px;flex:none}.fv .ic{width:24px;height:24px}.t{font-weight:600;font-size:15px;fill:#1f2328}.s{font-size:12px;fill:#59636e}.ax{font-size:11px;fill:#59636e}.val{font-size:11px;fill:#1f2328}
.grid{stroke:#eef0f2}.bar{fill:#4f6bed}.bar.cur{fill:#a7b5f6}.mk{stroke-width:1.5;stroke-dasharray:5 4}.mkt{font-size:12px;font-weight:600;stroke:#fff;stroke-width:4px;paint-order:stroke}
table{border-collapse:collapse;width:100%;background:#fff;border:1px solid #e4e6ea;border-radius:10px;margin-bottom:16px;font-size:13.5px}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid #eef0f2;vertical-align:top}th{color:#59636e;font-weight:600}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr))}.k{position:relative}
h2{display:flex;align-items:center;gap:10px}.hb{display:inline-flex;align-items:center;justify-content:center;width:30px;height:30px;border-radius:8px;background:#e8ecff;color:#3d57d6}
.kb{position:absolute;top:12px;right:12px;color:#8b95a5}.ic{display:block}
.hl{grid-template-columns:repeat(3,1fr)}.hl .k{padding:16px 18px;background:linear-gradient(180deg,#f3f5ff,#fff 60%)}.hl .k b{font-size:34px;letter-spacing:-.5px}.hl .kb{color:#3d57d6;background:#e8ecff;border-radius:8px;padding:6px}
.sp{display:block;width:132px;height:34px;margin-top:8px}.spl{fill:none;stroke:#4f6bed;stroke-width:1.8;stroke-linejoin:round}.spa{fill:#4f6bed;opacity:.12}.spd{fill:#4f6bed}
.st{padding:14px 16px}.stt{font-weight:600;margin-bottom:10px}.stb{display:flex;height:22px;border-radius:6px;overflow:hidden;gap:2px}.stb span{display:block;min-width:2px}
.stl{display:flex;flex-wrap:wrap;gap:6px 18px;margin-top:10px;font-size:13px;color:#59636e}.stl i{display:inline-block;width:10px;height:10px;border-radius:2px;margin-right:6px}.stl b{color:#1f2328}
.fv .ic{display:inline-block;vertical-align:-3px;margin-right:8px}
@media (max-width:760px){.hl{grid-template-columns:repeat(2,1fr)}}
.fs{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:12px}
.f{background:#fff;border:1px solid #e4e6ea;border-top:3px solid #4f6bed;border-radius:10px;padding:12px 16px}.f.good{border-top-color:#15803d}.f.warn{border-top-color:#d97706}.f.bad{border-top-color:#dc2626}
.fv{display:block;font-size:30px;font-weight:700;line-height:1.15}.f.good .fv{color:#15803d}.f.warn .fv{color:#d97706}.f.bad .fv{color:#dc2626}
.f b{display:block;margin-top:2px}.f p{margin:6px 0 0;font-size:13.5px}.fr{color:#59636e}.f details{margin-top:8px;font-size:13px}.f summary{cursor:pointer;color:#59636e}
.note{color:#59636e;font-size:13px;margin:0 4px 16px}a{color:#2f4bd0}
@media (prefers-color-scheme:dark){body{background:#0d1117;color:#e6edf3}.k,.card,table,.f{background:#161b22;border-color:#30363d}.t,.val{fill:#e6edf3}.grid{stroke:#21262d}th,td{border-color:#21262d}.lead,.k span,.note,th,.fr,.f summary,.stl{color:#9198a1}.stl b{color:#e6edf3}.hb,.hl .kb{background:#1f2a52;color:#9fb0ff}.hl .k{background:linear-gradient(180deg,#1a2140,#161b22 60%)}.spl{stroke:#8ea2ff}.spa,.spd{fill:#8ea2ff}.mkt{stroke:#161b22}a{color:#8ea2ff}}
.stn{fill:#f3f5ff;stroke:#c7d0ff}.stv{font-size:13.5px;font-weight:600;fill:#1f2328}.sti{color:#3d57d6}.fw{stroke:#8b95a5;stroke-width:1.8}.ahf{fill:#8b95a5}.lpl{font-size:12.5px;paint-order:stroke}
.hc{fill:#4f6bed}.yr{display:flex;align-items:center;gap:12px;margin-bottom:8px}.yr .stb{flex:1;height:18px}.yl{width:110px;font-size:13.5px}.yl em{color:#59636e;font-style:normal}.yv{width:110px;font-size:13px;text-align:right}h3{font-size:15px;margin:20px 0 10px}
.cl{list-style:none;padding:0;margin:8px 0 4px;font-size:13.5px}.cl li{display:flex;gap:7px;align-items:flex-start;margin-bottom:3px}.cl .good .ic{color:#15803d}.cl .bad .ic{color:#dc2626}.ex{display:flex;gap:7px;align-items:flex-start;font-size:13.5px}.ex b{display:inline;margin:0}.ex .ic{width:16px;height:16px;margin-top:2px;color:#59636e}.ex.good .ic{color:#15803d}.ex.bad .ic{color:#dc2626}.cl b{display:inline;margin:0}.cl em{font-style:normal;color:#59636e}.cl .ic{width:16px;height:16px;margin-top:2px}
.fp .ic{display:inline-block;width:14px;height:14px;vertical-align:-2px;color:#d97706}.cd{margin:12px 0 16px;font-size:13.5px}.cd summary{cursor:pointer;color:#59636e;margin-bottom:8px}.f table{margin-top:8px;font-size:12.5px}
.rg{stroke:#e4e6ea}.sc{display:flex;align-items:center;gap:12px}.sc b{font-size:26px}
.chip{display:inline-flex;align-items:center;gap:5px;font-size:12px;font-weight:600;padding:2px 8px;border-radius:999px;background:#eef0f2;color:#59636e;margin:0 6px 6px 0}.chip.bad{background:#fde8e8;color:#b91c1c}.chip.warn{background:#fdf0d9;color:#a15c07}.chip .ic{width:14px;height:14px}
.fa{font-weight:600}.fp{font-size:12px;color:#59636e}.dl{display:block;font-style:normal;font-size:12px;color:#59636e;margin-top:2px}code{background:#eef0f2;border-radius:4px;padding:0 4px;font-size:12px}
.how{background:#fff;border:1px dashed #cfd4db;border-radius:10px;padding:10px 16px;font-size:13.5px;color:#59636e;margin-bottom:16px}.how b{color:inherit}
.ok{list-style:none;padding:0;margin:0 0 16px;display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:6px 18px;font-size:14px}.ok li{display:flex;gap:8px;align-items:flex-start}.ok .ic{color:#15803d;margin-top:2px}
@media (prefers-color-scheme:dark){.stn{fill:#1a2140;stroke:#34407a}.stv{fill:#e6edf3}.sti{color:#9fb0ff}.fw{stroke:#6b7280}.ahf{fill:#9198a1}.rg{stroke:#30363d}.chip{background:#21262d;color:#c9d1d9}.fp,.dl,.how{color:#9198a1}.how{background:#161b22;border-color:#30363d}code{background:#21262d}.chip.bad{background:#4c1d1d;color:#fca5a5}.chip.warn{background:#4a3410;color:#fcd34d}}
.nd{margin:-8px 4px 16px;font-size:13px;color:#59636e}.nd summary{cursor:pointer}.nd p{margin:6px 0 0}.nd.grp{margin:12px 0 16px}.nd.grp summary{font-size:14px;margin-bottom:10px}.pop{color:#59636e;font-size:13px;margin:0 4px 16px}
.glance{background:#fff;border:1px solid #e4e6ea;border-left:4px solid #4f6bed;border-radius:10px;padding:12px 18px;margin-bottom:16px}.glance ol{margin:6px 0 0;padding-left:20px}.glance li{margin:3px 0}
.nav{position:sticky;top:0;z-index:5;display:flex;flex-wrap:wrap;gap:4px 16px;align-items:center;font-size:13px;padding:8px 0;margin-bottom:16px;background:#fafafa;border-bottom:1px solid #e4e6ea}.nav a{text-decoration:none}.nav button{font:inherit;font-size:12px;border:1px solid #cfd4db;border-radius:6px;background:#fff;color:inherit;padding:2px 8px;cursor:pointer}.nav .sp2{flex:1}
@media (prefers-color-scheme:dark){.nd,.pop{color:#9198a1}.glance,.nav button{background:#161b22;border-color:#30363d}.nav{background:#0d1117;border-color:#30363d}}
@media print{.nav{display:none}details::details-content{content-visibility:visible;height:auto!important}}
</style>
<h1>Development process · ${esc(m.repo ?? "")}</h1>
<p class="lead">${t.merged} merged pull requests, ${m.period.from} to ${m.period.to} (days in UTC) · generated ${m.generatedAt.slice(0, 16).replace("T", " ")} UTC · review rounds counted for “${esc(m.roundKind)}”</p>
${findings.length ? `<div class="glance"><b>At a glance</b><ol>${findings.slice(0, 4).map((x, i) => `<li><a href="#f${i}">${esc(x.title)}</a></li>`).join("")}</ol></div>` : ""}
<div class="kpis hl">${tile(t.merged, "merged pull requests", "merge", wk((w) => w.merged), was("merged", (v) => v))}${tile(num(e.leadMedianH, " h"), "lead time, median", "clock", wk((w) => w.efficiency.leadMedianH).slice(-8), was("leadMedianH", (v) => `${v} h`))}${tile(num(e.roundsMean), "review rounds per reviewed PR", "repeat", wk((w) => w.efficiency.roundsMean), was("roundsMean", (v) => v))}${tile(pct(ql.followUpExplicitShare), "fixed again by a linked fix", "wrench", wk((w) => w.quality.followUpExplicitShare), was("followUpExplicitShare", pct))}${tile(ci ? pct(ci.defaultBranchPush.failureRate) : "–", `failed CI on ${m.defaultBranch}`, "fail", wk((w) => w.mainCi.failureRate), was("mainFailureRate", pct))}${tile(ci && ci.all.hours ? pct(ci.all.hoursNotGreen / ci.all.hours) : "–", "CI hours not green", "zap", wk((w) => w.efficiency.ciHoursPerPr), was("notGreenShare", pct))}</div>
<p class="note">Lines: the value per merge week (last tile: CI hours per pull request).${prev ? ` Last report: ${prev.period.from} to ${prev.period.to}.` : ""}</p>
${m.meta ? `<p class="pop">Merged pull requests only (${t.merged}). Not in these numbers: ${m.meta.closedUnmerged} closed without a merge in the period, ${m.meta.openNow} open now, ${m.meta.openOlderThanAWeek} of them for more than a week.</p>` : ""}
<div class="card">${factory()}</div>
${findings.length ? `${h2("search", "Findings")}<div class="fs">${findings.map((f, i) => `<div id="f${i}" class="f ${["good", "warn", "bad"].includes(f.tone) ? f.tone : ""}">${f.value ? `<span class="fv">${["good", "warn", "bad"].includes(f.tone) ? icon(f.tone, 24) : ""}${esc(f.value)}</span>` : ""}<b>${esc(f.title)}</b>${f.recommendation ? `<p class="fr">→ ${esc(f.recommendation)}</p>` : ""}${f.evidence ? `<details><summary>Evidence</summary><p>${esc(f.evidence)}</p></details>` : ""}</div>`).join("")}</div>` : ""}
${results.length ? `${h2("bulb", `Suggestions · ${hits.length} of ${hits.length + passed.length} rules triggered`)}
<div class="kpis">${ring("flow", "Flow")}${ring("review", "Review")}${ring("ci", "CI")}${ring("quality", "Quality")}</div>
${m.ruleWindow ? `<p class="note">The rules judge the last ${m.ruleWindow.days} days (${m.ruleWindow.from} to ${m.ruleWindow.to}, ${m.ruleWindow.merged} merged pull requests), so that a suggestion describes the process as it runs now. The charts below cover the whole period.</p>` : ""}
<p class="note">Score per group: 100 × (1 − penalties ÷ (evaluated rules × 12)), with 12, 7 and 3 points for a high, medium and low rule. A rule counts once, however often it fired. The thresholds are coaching defaults unless a reference is named; change them in <code>config.json</code>.</p>
<div class="fs">${hits.slice(0, 3).map(card).join("")}</div>${hits.length > 3 ? `<details class="nd grp"><summary>${hits.length - 3} more suggestions (${[...new Set(hits.slice(3).map((r) => SEV[r.severity][1].toLowerCase()))].join(", ")})</summary><div class="fs">${hits.slice(3).map(card).join("")}</div></details>` : ""}
${passed.length ? `<h3>What works</h3><ul class="ok">${passed.map((r) => `<li>${icon("good")}<span>${esc(r.text)}${resolved.includes(r.id) ? " <b>(a suggestion of the last report, now settled)</b>" : ""}</span></li>`).join("")}</ul>` : ""}
${skipped.length ? `<p class="pop">Not evaluated: ${skipped.map((r) => `${esc(r.name)} (${esc(r.reason)})`).join("; ")}.</p>` : ""}` : ""}
${changes()}
${h2("trend", "Throughput")}
<div class="card">${bars({ keys: lastDays, values: lastDays.map((k) => m.days[k]?.merged ?? 0), title: "Merged per day · last 6 weeks", sub: "lighter bar = last day of the period, possibly incomplete", labelEvery: 3, markers: dayMarkers, dimLast: true })}</div>
<div class="card">${bars({ keys: weekKeys, values: wk((w) => w.merged), title: "Merged per week (from Monday)", sub: "lighter bar = current week", markers: weekMarkers, dimLast: true })}</div>
${m.markers.length > 3 ? `<p class="note">Changes marked in the charts: ${m.markers.map((mk, n) => `<b>${n + 1}</b> ${esc(mk.label)} (${short(mk.at)})`).join(" · ")}</p>` : ""}
${h2("gauge", "Efficiency")}
${phases()}
${m.leadHistogram ? `<div class="grid2" style="margin-bottom:16px"><div class="card half">${bars({ keys: m.leadHistogram.map((b) => b.name), values: m.leadHistogram.map((b) => b.count), title: "Lead time, distribution", sub: `pull requests by time from open to merge · 95th percentile ${num(m.phases?.lead.p95H, " h")}`, width: 530, height: 240, label: (k) => k.replace("under ", "<").replace("over ", ">").replace(" to ", "–").replace("days", "d").replace("day", "d").replace("week", "w").replace(" min", "m").replace(/ h/g, "h") })}</div><div class="half">${yieldRows()}</div></div>` : ""}
${heat()}
<div class="kpis">${tile(num(e.leadMedianH, " h"), "lead time open→merge, median", "clock")}${tile(num(e.leadP90H, " h"), "lead time, 90th percentile", "clock")}${tile(num(e.firstReviewMedianH, " h"), "until the first review, median", "eye")}${tile(num(e.roundsMean), "review rounds per reviewed PR", "repeat")}${tile(pct(e.threePlusShare), "PRs with 3 or more rounds", "repeat")}${tile(num(e.ciRunsPerPrMedian), "CI runs per PR, median", "play")}</div>
${stack(`What the ${e.laterRounds} later review rounds found`, [{ name: "nothing", value: e.laterClean, color: "#64748b" }, { name: "only non-blocking findings", value: e.laterNonBlocking, color: "#d97706" }, { name: "a blocking finding", value: e.laterBlocking, color: "#dc2626" }, { name: "not readable", value: e.laterUnknown, color: "#cbd5e1" }])}
${ci ? stack(`Where the ${ci.all.hours} CI hours went`, [{ name: "green runs", value: +(ci.all.hours - ci.all.hoursNotGreen).toFixed(1), color: "#15803d" }, { name: "cancelled or failed runs", value: ci.all.hoursNotGreen, color: "#dc2626" }]) : ""}
<div class="grid2">${small("Lead time, median (h)", "per merge week", wk((w) => w.efficiency.leadMedianH), " h")}${small("Review rounds, mean", "per merge week, reviewed PRs", wk((w) => w.efficiency.roundsMean))}${small("PRs with 2+ rounds (%)", "per merge week", wk((w) => p100(w.efficiency.multiRoundShare)), " %")}${small("CI runner-hours per PR, mean", "per merge week", wk((w) => w.efficiency.ciHoursPerPr), " h")}</div>
<p class="note">${e.laterAfterMergeOnly} later rounds followed nothing but merge commits of the base branch. First round blocking: ${pct(e.firstRoundBlockingShare)}.</p>
${m.classes ? `<h3>Process cost by risk class</h3>${table(["Risk class", "PRs", "Lead time (h, median)", "With a review", "Review rounds", "CI runs (median)", "CI hours per PR", "Passed first attempt"], Object.entries(m.classes).map(([c, v]) => [esc(c), v.merged, num(v.leadMedianH), pct(v.reviewedShare), num(v.roundsMean), num(v.ciRunsMedian), num(v.ciHoursPerPr), pct(v.firstPassShare)]))}<p class="note">${CLASS_HELP} “Sensitive” means migrations, authentication and security paths, workflows and deployment files; set <code>sensitivePattern</code> in <code>config.json</code> to fit the repository.</p>` : ""}
${h2("shield", "Quality")}
<div class="kpis">${tile(pct(ql.fixShare), "share of fix PRs", "wrench")}${tile(pct(ql.followUpExplicitShare), "PRs fixed again by a linked fix", "wrench")}${tile(num(ql.reverts), "reverts", "undo")}${tile(pct(ql.noReviewShare), "merged without any review", "eye")}${tile(pct(ql.fixWithoutTestShare), "fixes without a test file", "test")}${tile(ci ? pct(ci.defaultBranchPush.failureRate) : "–", `failed CI on ${m.defaultBranch}`, "fail")}</div>
<div class="grid2">${small("Fix PRs (%)", "per merge week", wk((w) => p100(w.quality.fixShare)), " %")}${small("PRs fixed again by a linked fix (%)", "by merge week of the fixed PR; the last week is still open", wk((w) => p100(w.quality.followUpExplicitShare)), " %")}${small(`Failed CI on ${m.defaultBranch} (%)`, "pushes, per week", wk((w) => p100(w.mainCi.failureRate)), " %")}${small("Source changes without a test file (%)", "per merge week", wk((w) => p100(w.quality.sourceWithoutTestShare)), " %")}</div>
${ql.followUpDefectShare !== undefined ? stack(`The ${Math.round(ql.followUpExplicitShare * t.merged)} pull requests that a later fix names`, [{ name: "named by a fix not worded as a review follow-up (possible defect)", value: Math.round(ql.followUpDefectShare * t.merged), color: "#dc2626" }, { name: "only planned follow-ups of review findings", value: Math.round(ql.followUpPlannedShare * t.merged), color: "#64748b" }]) : ""}
<p class="note">“Fixed again” counts a pull request that a later fix names by number within the window; with fixes that only touch the same files the share is ${pct(ql.followUpOverlapShare)} (an upper bound, shared files are not proof). Median time until the linked fix: ${num(ql.followUpMedianH, " h")}. ${ql.unresolvedThreadPrs} pull requests were merged with an unresolved thread.</p>
${m.hotspots?.length ? `<h3>Files that fixes keep returning to</h3>${table(["File", "Fix PRs", "All PRs"], m.hotspots.map((f) => [`<code>${esc(f.path)}</code>`, f.fixes, f.prs]))}` : ""}
${ci?.red?.periods ? `<p class="note">${esc(m.defaultBranch)} was red ${ci.red.periods} times, from the first failed push run to the next green one: ${num(ci.red.medianH, " h")} at the median, ${num(ci.red.longestH, " h")} at the longest, ${num(ci.red.totalH, " h")} in total.</p>` : ""}
${h2("users", "Reviewers")}
<div class="card">${bars({ keys: lastDays, series: kindNames.map((k, i) => ({ name: k, color: COLORS[i], values: lastDays.map((d) => m.days[d]?.kinds[k] ?? 0) })), title: "Who reviewed", sub: "merged PRs per day with at least one review of the kind; a PR can count in several", labelEvery: 3, markers: dayMarkers })}</div>
${table(["Reviewer", "PRs reviewed", "Share of all PRs", "PRs with a thread", "Threads", "Resolved", "Code changed afterwards"], Object.entries(m.reviewers).sort((a, b) => b[1].prs - a[1].prs).map(([k, v]) => [esc(k), v.prs, pct(v.prShare), v.prsWithThreads ?? "–", v.threads, v.threadsResolved, v.threadsJudged ? `${v.threadsOutdated} of ${v.threadsJudged} (${pct(v.threadsOutdated / v.threadsJudged)})` : "–"]))}
<p class="note">“Code changed afterwards”: the lines a thread points at were changed by a later commit (GitHub marks the thread outdated). A cheap sign that a finding was acted on, not proof: a rebase or an unrelated edit counts too. “Resolved” says nothing where the branch rules require every thread resolved.</p>
${m.labels?.reviewers && Object.keys(m.labels.reviewers).length ? `<h3>Blocks checked by hand</h3>${table(["Reviewer", "Labelled", "Right", "False alarm", "Unclear", "Right of the decided", "Labelled by"], Object.entries(m.labels.reviewers).map(([k, v]) => [esc(k), v.labelled, v.right, v.falseAlarm, v.unclear, `${v.right} of ${v.right + v.falseAlarm}`, Object.entries(v.by).map(([b, n]) => `${esc(b)} ${n}`).join(", ")]))}<p class="note">From <code>labels.tsv</code>. A hit rate holds only for a sample the analysis drew; cases picked by the labelling party show that such blocks exist, not how often.</p>` : ""}
${m.labels?.mainFailures && Object.keys(m.labels.mainFailures).length ? stack(`Labelled failures on ${m.defaultBranch}, by cause`, Object.entries(m.labels.mainFailures).map(([k, v], i) => ({ name: k, value: v, color: COLORS[i % 8] }))) : ""}
${m.laterYield ? `<h3>Which later rounds pay</h3>${table(["Risk class", "Later rounds", "With a readable result", "Found a blocker", "Share"], Object.entries(m.laterYield.byClass).sort((a, b) => (b[1].blockingShare ?? 0) - (a[1].blockingShare ?? 0)).map(([c, v]) => [esc(c), v.laterRounds, v.readable, v.blocking, pct(v.blockingShare)]))}
${m.laterYield.byRole ? `${table(["Review role", "Threads in round 1", "Threads in later rounds", "Share in later rounds", "Code changed afterwards"], Object.entries(m.laterYield.byRole).sort((a, b) => b[1].later - a[1].later).map(([r, v]) => [esc(r), v.first, v.later, pct(v.later / (v.first + v.later)), v.judged ? `${v.changedAfter} of ${v.judged}` : "–"]))}<p class="note">A thread is one blocking finding of the round reviewer, counted for the role it names. A role whose findings come mostly in later rounds is the one a rule against later rounds would silence.</p>` : `<p class="note">Set <code>roles.pattern</code> in <code>config.json</code> to see the same split by review role.</p>`}` : ""}
${m.authors && Object.keys(m.authors.classes).length ? `<h3>By author</h3>${table(["Author class", "PRs", "Changed lines (median)", "Lead time (h, median)", "Review rounds", "Passed first attempt", "Fixed again", "Fix PRs"], Object.entries(m.authors.classes).sort((a, b) => b[1].merged - a[1].merged).map(([c, v]) => [esc(c), v.merged, num(v.sizeMedian), num(v.leadMedianH), num(v.roundsMean), pct(v.firstPassShare), pct(v.followUpExplicitShare), pct(v.fixShare)]))}
<p class="note">Detected by: ${Object.entries(m.authors.signals).map(([k, n]) => `${esc(k)} ${n}`).join(", ") || "no AI mark found"}. A pull request without a mark is not proof of a human author: some tools leave none.</p>` : ""}
${m.cost ? ((PH, RV) => `<h3>What each step costs</h3>
<p>From ${esc(m.cost.since)}: <b>${U(m.cost.totalUsd)}</b> at list prices across ${m.cost.transcripts.toLocaleString("en-US")} local transcripts. Work in lanes ${U(m.cost.workUsd)}, review agents ${U(m.cost.reviewUsd)}, coordination ${U(m.cost.coordinationUsd)} (sessions that belong to no single worktree).</p>
${table(["Model", "Output tokens", "Cost"], Object.entries(m.cost.perModel).sort((a, b) => b[1].usd - a[1].usd).map(([k, v]) => [esc(k), v.out.toLocaleString("en-US"), U(v.usd)]))}
<h4>Implementation, fix and review per pull request</h4>
${table(["Risk class", ...["PRs", "With work transcript", "Implementation (median)", "min", "Fix after first review (median)", "min", "With review transcript", "Review (median)", "min", "All three (median)"]], [["all", m.cost.all], ...Object.entries(m.cost.byClass)].map(([k, v]) => PH(k, v)))}
${table(["Review rounds", ...["PRs", "With work transcript", "Implementation (median)", "min", "Fix after first review (median)", "min", "With review transcript", "Review (median)", "min", "All three (median)"]], Object.entries(m.cost.byRounds).map(([k, v]) => PH(k, v)))}
<p class="note">Implementation is the lane's work up to the pull request's first review round, fix is its work after it, review is the review agents that posted to the pull request. Each column has its own number of pull requests, because a lane transcript and a review transcript are found independently; "all three" counts only pull requests with both (${m.cost.all.withAll}). A branch that carried several pull requests is left out of the split.</p>
<h4>Review agents: price, duration, yield</h4>
<p>${m.cost.review.runs} review transcripts, ${m.cost.review.matchedToRound} tied to a review round of a merged pull request.</p>
${table(["By model", ...["Review runs", "Cost (median)", "Cost (p90)", "Active time (min, median)", "With a severity line", "Blocked", "Findings per run", "Cost per blocking run", "Passed as last round", "Of those: defect fix after merge"]], Object.entries(m.cost.review.byModel).map(([k, v]) => RV(k, v)))}
${table(["By model, first round only", ...["Review runs", "Cost (median)", "Cost (p90)", "Active time (min, median)", "With a severity line", "Blocked", "Findings per run", "Cost per blocking run", "Passed as last round", "Of those: defect fix after merge"]], Object.entries(m.cost.review.byModelFirstRound).map(([k, v]) => RV(k, v)))}
${table(["By role in the brief", ...["Review runs", "Cost (median)", "Cost (p90)", "Active time (min, median)", "With a severity line", "Blocked", "Findings per run", "Cost per blocking run", "Passed as last round", "Of those: defect fix after merge"]], Object.entries(m.cost.review.byRole).map(([k, v]) => RV(k, v)))}
${table(["By round", ...["Review runs", "Cost (median)", "Cost (p90)", "Active time (min, median)", "With a severity line", "Blocked", "Findings per run", "Cost per blocking run", "Passed as last round", "Of those: defect fix after merge"]], Object.entries(m.cost.review.byRound).map(([k, v]) => RV(k, v)))}
<p class="note">"Blocked" is the share of runs whose review carried a blocking finding, among the runs with a readable severity line. "Cost per blocking run" divides the cost of those runs by the number that blocked: what one blocking review costs, including the runs that found nothing. "Defect fix after merge" counts pull requests this run passed as their last round that later got a fix linked to them: a miss of the whole process, not proof the reviewer could have seen it. Whether a block was right is not in these numbers; that is the hand labelling in labels.tsv. Models review different work (the costlier one is likely given the harder pull requests), so read a model's row with its role and round.</p>
<h4>Costliest pull requests</h4>${table(["PR", "Title", "Total", "Implementation", "Fix", "Review", "Rounds"], m.cost.costliest.map((x) => ["#" + x.pr, esc(x.title), U(x.usd), U(x.impl), U(x.fix), U(x.review), num(x.rounds)]))}
<p class="note">Cost is what the tokens would cost on the API: ${esc(m.cost.priceNote ?? "prices from config.json")}${m.cost.unpriced?.length ? ` <b>No price is configured for ${esc(m.cost.unpriced.map((u) => u.model).join(", "))}: their tokens count as zero, so every cost figure here is too low.</b>` : ""} A subscription bills differently. Only Claude Code transcripts on the machine that ran the analysis are counted: other machines, Codex sessions and the review bots are missing, so totals are a lower bound. A session that sat on a branch for a long time puts all its tokens on that pull request, which is what the costliest rows usually show. Active time adds the gaps under five minutes between API messages. Read the medians.</p>`)((k, v) => [esc(k), v.prs, v.withWork, U(v.implUsd.median), num(v.implMin.median), U(v.fixUsd.median), num(v.fixMin.median), v.withReview, U(v.reviewUsd.median), num(v.reviewMin.median), U(v.totalUsd.median)], (k, v) => [esc(k), v.runs, U(v.usdMedian), U(v.usdP90), num(v.minMedian), v.judged, pct(v.blockingShare), num(v.findingsMean), U(v.usdPerBlockingRun), v.passedLast, pct(v.defectAfterPass)]) : ""}
${m.models && Object.keys(m.models.overall).length > 1 ? `<h3>By model of the author</h3>${table(["Model", "Seen", ...["PRs", "Changed lines (median)", "Lead time (h, median)", "First round blocked", "Review rounds", "Passed first attempt", "CI hours per PR", "Defect fix after merge", "Fixes without a test", "Cost per PR (USD, median)", "Active agent time (min, median)", "PRs with cost"]], Object.entries(m.models.overall).sort((a, b) => b[1].merged - a[1].merged).map(([k, v]) => [esc(k), esc(v.firstDay.slice(5) + " to " + v.lastDay.slice(5)), ...[v.merged, num(v.sizeMedian), num(v.leadMedianH), pct(v.firstRoundBlockingShare), num(v.roundsMean), pct(v.firstPassShare), num(v.ciHoursPerPr), pct(v.followUpDefectShare), pct(v.fixWithoutTestShare), num(v.usdMedian), num(v.activeMinMedian), v.withCost ?? 0]]))}
${Object.entries(m.models.byClass).map(([c, g]) => `<h4>${esc(c)}</h4>${table(["Model", ...["PRs", "Changed lines (median)", "Lead time (h, median)", "First round blocked", "Review rounds", "Passed first attempt", "CI hours per PR", "Defect fix after merge", "Fixes without a test", "Cost per PR (USD, median)", "Active agent time (min, median)", "PRs with cost"]], Object.entries(g).sort((a, b) => b[1].merged - a[1].merged).map(([k, v]) => [esc(k), ...[v.merged, num(v.sizeMedian), num(v.leadMedianH), pct(v.firstRoundBlockingShare), num(v.roundsMean), pct(v.firstPassShare), num(v.ciHoursPerPr), pct(v.followUpDefectShare), pct(v.fixWithoutTestShare), num(v.usdMedian), num(v.activeMinMedian), v.withCost ?? 0]]))}`).join("")}
<p class="note">The model is read from the co-author trailers of a pull request's commits; several names give "mixed". Work is not assigned to models at random, and models were in use at different times, so compare only within one risk class and with the dates in "Seen" in mind. Within a class, a model with fewer than ${m.models.minPrs} pull requests is left out. Tools that leave no trailer land in "no model mark".</p>` : ""}
${m.sample && m.sample.total ? ((S, Z) => `<h3>Review sample: every ${S.modulo}th pull request</h3>
${table(["Group (by number)", "Assigned", "Reviewed by it", "Fell back", "Mixed", "No review", "Changed lines (median)", "Lead time (h, median)", "p90", "First answer after (h)", "With a thread", "Threads per PR", "Pushes after the first answer", "With a failed CI run", "Defect fix after merge"],
  Object.entries(S.arms).map(([k, a]) => [esc(k), a.assigned, a.byAssigned, k === S.control ? "–" : a.fellBack, k === S.control ? "–" : a.mixed, a.noReview, num(a.sizeMedian), num(a.leadMedianH) + Z(k, "lead"), num(a.leadP90H), num(a.answerMedianH),
    `${a.withThreads} of ${a.answered}${Z(k, "withThreads")}`, num(a.threadsMean), num(a.pushesAfterMean), `${a.ciFailed} of ${a.ciJudged}${Z(k, "ciFailed")}`, `${a.defectFix} of ${a.assigned}${Z(k, "defectFix")}`]))}
<p class="note">Pull requests opened from ${esc(S.since)}: ${S.total}. A pull request belongs to a group by its number alone, whoever reviewed it in the end, so the groups differ only by chance and by the reviewer; "Fell back" counts those the bot did not answer and the ${esc(S.control)} took over, "Mixed" those both reviewed. ▲ and ▼ mark a difference to ${esc(S.control)} that is larger than chance explains (two-sided, 5 %); no mark means no clear difference, which with few pull requests says little${S.target ? `; the sample is planned to run until each bot has reviewed ${S.target}` : ""}. "With a thread" counts review threads of the group's reviewer: a bot opens a thread for every finding, the ${esc(S.control)} only for blocking ones, so that column compares how often the author had to answer, not how strict the reviewer is. Whether a finding was right is not in this table: read the threads. What the bots cost comes from their invoices, not from this report.${S.fellBackList.length ? ` Not answered by the bot: ${S.fellBackList.map((n) => "#" + n).join(", ")}.` : ""}</p>`)(m.sample, (k, f) => { const t = m.sample.tests[k]; return !t || !t.enough || Math.abs(t[f]) < 1.96 ? "" : t[f] > 0 ? " ▲" : " ▼"; }) : ""}
${m.asks?.length ? `<h3>Coaching asks</h3>${table(["Asked", "To", "Ask", "Metric", "Before", "After", "Verdict", "Asked so often"], [...m.asks].reverse().map((a) => [short(a.at) + a.at.slice(0, 4), esc(a.to ?? "–"), esc(a.ask), a.expectation ? esc(a.expectation.name) : "–", a.expectation ? (a.expectation.share ? pct(a.expectation.before) : num(a.expectation.before)) : "–", a.expectation ? (a.expectation.share ? pct(a.expectation.after) : num(a.expectation.after)) : "–", (a.expectation ? esc(a.expectation.verdict) : "no metric") + (a.dropped ? " · dropped" : a.escalated ? " · with the user" : ""), a.times > 1 ? `<b>${a.nth} of ${a.times}</b>` : "1"]))}<p class="note">Each ask is judged like a change with an expectation, from the day it was delivered: the metric it names should move in the stated direction within the window. An ask asked more than once is bold: the same thing had to be asked again.</p>` : ""}
${m.compare ? `<p class="note">${esc(m.compare.a)} and ${esc(m.compare.b)} on the same head: both block ${m.compare.both}, only ${esc(m.compare.a)} ${m.compare.onlyA}, only ${esc(m.compare.b)} ${m.compare.onlyB}, neither ${m.compare.neither}.</p>` : ""}
${ci ? `${h2("play", "CI")}${table(["Workflow", "Runs", "Failure rate", "Cancelled", "Re-run", "Median (min)", "p90 (min)", "Runner-hours", "of that not green"], Object.entries(ci.perWorkflow).slice(0, 12).map(([n, s]) => [esc(n), s.runs, pct(s.failureRate), pct(s.cancelledShare), pct(s.rerunShare), num(s.medianMin), num(s.p90Min), num(s.hours), num(s.hoursNotGreen)]))}
<p class="note">Durations are the last attempt of a run, start to end, and count wall time of the run, not the sum of its jobs. ${ci.all.rerunGreen} re-runs turned green: candidates for flaky tests.</p>` : ""}
${ci?.prBranches ? `${table(["Where", "Runs", "Failure rate", "Cancelled", "Re-run", "Median (min)", "Runner-hours", "of that not green"], [["Pull request branches", ci.prBranches], [`Pushes to ${m.defaultBranch}`, ci.defaultBranchPush]].map(([n, s]) => [esc(n), s.runs, pct(s.failureRate), pct(s.cancelledShare), pct(s.rerunShare), num(s.medianMin), num(s.hours), num(s.hoursNotGreen)]))}<p class="note">A cancelled run on a pull request branch is a superseded push. On the default branch it can be by design, where a newer merge replaces a waiting run.</p>` : ""}
${m.failures ? `<h3>Failed pushes to ${esc(m.failures.branch)}, last ${m.failures.days} days</h3>${m.failures.incomplete?.length ? `<p class="note"><strong>Incomplete:</strong> ${m.failures.incomplete.length} GitHub requests failed after their retries, so jobs, titles or pull requests below may be missing (listed in failures.json).</p>` : ""}${m.failures.defaultBranch.length ? table(["Run started (UTC)", "Merge", "Failed job › step"], [...m.failures.defaultBranch].reverse().map((r) => [`${r.url ? `<a href="${esc(r.url)}">` : ""}${r.at.slice(0, 16).replace("T", " ")}${r.url ? "</a>" : ""}`, `${r.pr ? prLink(r.pr) : `<code>${esc(r.sha)}</code>`} ${esc(r.title.slice(0, 80))}`, r.failed.map((j) => `${esc(j.job)} › ${esc(j.step ?? "–")}`).join("<br>") || "–"])) : `<p class="note">None.</p>`}
<p class="note">The cause is for a person to classify: a defect in that merge, a defect merged earlier that every later push inherits, a flaky test, or infrastructure. The same job failing on consecutive merges points at an inherited failure.</p>
${m.failures.flaky.length ? `<h3>Jobs that failed and then passed on a re-run</h3>${table(["Job › step", "Times", "Last seen (UTC)"], m.failures.flaky.slice(0, 15).map((j) => [`${esc(j.job)} › ${esc(j.step ?? "–")}`, j.count, j.lastSeen.slice(0, 16).replace("T", " ")]))}<p class="note">From the first attempt of ${m.failures.rerunsRead} runs that turned green on a later attempt. This names the job and step; the failing test is in the log of the example runs.</p>` : ""}` : ""}
${h2("search", "Outliers")}
${table(["Most review rounds", "Rounds", "Lead time (h)", "CI runs"], m.outliers.mostRounds.slice(0, 10).map((o) => [`${prLink(o.pr)} ${esc(o.title)}`, o.rounds, o.leadH, o.ciRuns]))}
${table(["Longest lead time", "Rounds", "Lead time (h)", "CI runs"], m.outliers.longestLead.slice(0, 10).map((o) => [`${prLink(o.pr)} ${esc(o.title)}`, o.rounds, o.leadH, o.ciRuns]))}
${h2("search", "How to read this report")}
<div class="how"><b>How to read this.</b> The numbers describe the process, not people. They compare this repository with its own past, not with other teams. No number here is a target: a speed figure is only good next to its quality figure. Merged pull requests only; the newest days are incomplete, a fix for them may still come.</div>
<script>const D=()=>[...document.querySelectorAll("details")];addEventListener("beforeprint",()=>D().forEach((d)=>{d.dataset.was=d.open?"1":"";d.open=true}));addEventListener("afterprint",()=>D().forEach((d)=>{d.open=d.dataset.was==="1"}));document.getElementById("xa").onclick=()=>D().forEach((d)=>(d.open=true));document.getElementById("ca").onclick=()=>D().forEach((d)=>(d.open=false));</script>
</html>`;
const LABEL = [[/^Lines: the value/, "What the lines on the tiles show"], [/^The rules judge/, "Which period the rules judge"], [/^Score per group/, "How the scores are computed"], [/^Each card compares/, "How before and after are compared"], [/^Changes marked/, "Key to the numbered change markers"],
  [/Fixed again. counts/, "How “fixed again” is counted"], [/Code changed afterwards.:/, "How to read “code changed afterwards”"], [/^Detected by/, "How author classes are detected"], [/^Implementation is the lane/, "How implementation, fix and review are split"], [/^.Blocked. is the share/, "How to read the review agent columns"],
  [/^Cost is what the tokens/, "What the cost figures include and leave out"], [/^The model is read/, "How the author's model is detected"], [/^Pull requests opened from/, "How the review sample is compared"], [/^Each ask is judged/, "How an ask is judged"], [/^Durations are/, "How CI durations are measured"], [/^The cause is for a person/, "Who classifies a failed push"], [/^From the first attempt/, "Where the list of flaky jobs comes from"]];
const plain = (x) => x.replace(/<[^>]+>/g, "").trim();
let out = html.replace(/<p class="note">([\s\S]*?)<\/p>/g, (all, body) => { const t = plain(body), hit = LABEL.find(([re]) => re.test(t));
  if (!hit && t.split(/\s+/).length <= 30) return all;
  return `<details class="nd"><summary>${hit ? hit[1] : "Method: " + esc(t.split(/\s+/).slice(0, 6).join(" ")) + " …"}</summary><p>${body}</p></details>`; });
out = out.replace(/<h3>What works<\/h3>(<ul class="ok">[\s\S]*?<\/ul>)/, (all, ul) => `<details class="nd grp"><summary>What works: ${(ul.match(/<li>/g) ?? []).length} rules passed</summary>${ul}</details>`);
out = out.replace(/<h4>Costliest pull requests<\/h4>(<table>[\s\S]*?<\/table>(?:<details class="nd">[\s\S]*?<\/details>)?)/, (all, t) => `<details class="nd grp"><summary>Costliest pull requests</summary>${t}</details>`);
out = out.replace(/(<h3>By model of the author<\/h3>)([\s\S]*?)(?=<h3>|<h2)/, (all, h, seg) => h + seg.replace(/<h4>([^<]+)<\/h4>(<table>[\s\S]*?<\/table>)/g, (a, name, t) => `<details class="nd grp"><summary>By model, ${name} pull requests only</summary>${t}</details>`));
const nav = [...out.matchAll(/<h2 id="([^"]+)"><span class="hb">[\s\S]*?<\/span>([^<]*)<\/h2>/g)].map((x) => `<a href="#${x[1]}">${x[2].split(" · ")[0]}</a>`).join("");
out = out.replace(/(<p class="lead">[\s\S]*?<\/p>)/, (all) => `${all}<nav class="nav">${nav}<span class="sp2"></span><button id="xa">Expand all</button><button id="ca">Collapse all</button></nav>`);
writeFileSync(outFile, out);
console.log(`written: ${outFile}`);

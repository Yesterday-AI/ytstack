// The analysed period, defined once. analyze.mjs and mine-failures.mjs read it from here and nowhere else.
//
// A working directory keeps the days of every earlier run, so "the period" is never "what lies in the directory":
// it is the days mined inside the bounds the caller gave (--since, --until). mine.mjs writes one file per day into
// prs/ and ci/, also for a day on which nothing happened, so a quiet day at either end belongs to the period.
//   from, to   first and last mined day inside the bounds (YYYY-MM-DD)
//   has(iso)   whether a day or timestamp lies in from..to
//   load(sub)  the rows of prs/ or ci/ whose day file lies inside the bounds
import { existsSync, readdirSync, readFileSync } from "node:fs";

const DAY = /^(\d{4}-\d\d-\d\d)\.jsonl$/;
export const dayPlus = (d, n) => new Date(Date.parse(`${d}T00:00:00Z`) + n * 864e5).toISOString().slice(0, 10);

export function periodOf(dir, since = "0000", until = "9999") {
  const inBounds = (d) => d >= since && d <= until;
  const files = (sub) => (existsSync(`${dir}/${sub}`) ? readdirSync(`${dir}/${sub}`).filter((f) => f.endsWith(".jsonl")).sort() : []);
  // a file that is not named after a day (older layouts) is read whole and filtered by its rows
  const load = (sub) => files(sub).filter((f) => !DAY.test(f) || inBounds(f.slice(0, 10)))
    .flatMap((f) => readFileSync(`${dir}/${sub}/${f}`, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)));
  const days = [...new Set(["prs", "ci"].flatMap(files).filter((f) => DAY.test(f)).map((f) => f.slice(0, 10)).filter(inBounds))].sort();
  const p = { since, until, from: days[0] ?? null, to: days.at(-1) ?? null, load, inBounds: (iso) => inBounds(String(iso ?? "").slice(0, 10)) };
  p.has = (iso) => Boolean(iso) && p.from !== null && String(iso).slice(0, 10) >= p.from && String(iso).slice(0, 10) <= p.to;
  // rows of a directory without day files still span a period: widen it to the days the caller found in them
  p.cover = (rowDays) => { const all = [...rowDays, ...days].filter(Boolean).sort(); p.from = all[0] ?? null; p.to = all.at(-1) ?? null; return p; };
  return p;
}

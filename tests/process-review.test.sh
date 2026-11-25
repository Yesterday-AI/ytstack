#!/usr/bin/env bash
# Tests for the process-review tools (tools/process-review/*.mjs, the scripts
# behind skills/process-review).
#
# Contract pinned here, on a synthetic fixture in the format mine.mjs writes
# (40 merged pull requests and 10 CI runs over ten days, as JSON lines):
#   - analyze.mjs writes metrics.json with the counts of the fixture, and with
#     --out it writes only that file (no history/, the working directory stays
#     as it was)
#   - a rule whose threshold is crossed on a large enough sample is "triggered";
#     a rule whose sample is too small is "not-evaluated" with the reason,
#     never "passed"
#   - a dated change with `expect` gets a verdict of its own
#   - labels.tsv is read into a hit rate per reviewer and into causes of failed
#     pushes
#   - a second run finds the first one as `previous`
#   - report.mjs writes one HTML file with the suggestions section and the
#     analyst's finding; daily.mjs prints the digest of the day asked for
#   - api.mjs exits 2 with a clear message when no token can be resolved
#
#   - a review after the merge does not make a pull request reviewed, a reused
#     branch name splits its CI runs by commit, a dropped ask marks its key
#   - mine-failures.mjs leaves the default-branch section empty when no push
#     run was mined
#   - the period is the mined days inside the bounds (period.mjs): quiet days at
#     both ends belong to it, days of an earlier run in the same directory do
#     not, and analyze.mjs and mine-failures.mjs agree on it
#   - what was not measured is not available, never zero, and no rule passes on it
#
# No network: mine.mjs is never run, mine-failures.mjs only on a fixture that
# needs no request. Node is the
# plugin's one optional runtime (DECISIONS 2026-11-18); without node 18 or
# newer the node cases are skipped and the suite stays green.
#
# Run: /bin/bash tests/process-review.test.sh   (exit 0 = all pass)

set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
TOOLS="$ROOT/tools/process-review"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$2" in *"$3"*) ok "$1";; *) bad "$1" "missing '$3'";; esac; }

echo "# files"
for f in api period mine mine-failures analyze rules report daily tool-versions; do
  [ -f "$TOOLS/$f.mjs" ] && ok "$f.mjs is shipped" || bad "$f.mjs is shipped"
done
[ -f "$ROOT/skills/process-review/SKILL.md" ] && ok "the skill is shipped" || bad "the skill is shipped"

NODE_MAJOR=$(node -v 2>/dev/null | sed 's/^v//; s/\..*//')
case "$NODE_MAJOR" in ''|*[!0-9]*) NODE_MAJOR=0 ;; esac
if [ "$NODE_MAJOR" -lt 18 ]; then
  ok "node 18 or newer not on PATH: analyze, report, digest and token cases skipped"
  echo "$PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]; exit $?
fi

T=$(mktemp -d "${TMPDIR:-/tmp}/ytpr.XXXXXX"); T=$(cd "$T" && pwd -P)
trap 'rm -rf "$T"' EXIT
D="$T/work"; mkdir -p "$D/prs" "$D/ci"

# ---- fixture: ten days, four merged pull requests a day. Until 5 March nothing
# is reviewed; from 6 March on a person approves each one. One push run on main
# per day, the one of 9 March fails. Numbers 1 to 40, all on base main.
n=0; d=1
while [ $d -le 10 ]; do
  day=$(printf '2026-03-%02d' $d)
  i=1
  while [ $i -le 4 ]; do
    n=$((n+1))
    if [ $d -ge 6 ]; then
      reviews="[{\"by\":\"rita\",\"bot\":false,\"state\":\"APPROVED\",\"at\":\"${day}T09:00:00Z\",\"head\":\"c${n}\",\"body\":\"fine\"}]"
    else
      reviews="[]"
    fi
    printf '{"number":%d,"title":"feat: change %d","body":"","createdAt":"%sT08:00:00Z","mergedAt":"%sT10:0%d:00Z","additions":10,"deletions":2,"changedFiles":1,"branch":"feat-%d","base":"main","author":"dev","authorBot":false,"bodyTail":"","coAuthors":[],"labels":[],"commitCount":1,"commits":[{"oid":"c%d","at":"%sT08:00:00Z","msg":"change %d"}],"reviews":%s,"comments":[],"threadCount":0,"threads":[],"files":["src/a%d.ts"]}\n' \
      "$n" "$n" "$day" "$day" "$i" "$n" "$n" "$day" "$n" "$reviews" "$n" >> "$D/prs/$day.jsonl"
    i=$((i+1))
  done
  concl=success; [ $d -eq 9 ] && concl=failure
  printf '{"id":%d,"name":"ci","event":"push","branch":"main","sha":"m%d","attempt":1,"status":"completed","conclusion":"%s","createdAt":"%sT11:00:00Z","startedAt":"%sT11:00:00Z","updatedAt":"%sT11:10:00Z"}\n' \
    "$((100+d))" "$d" "$concl" "$day" "$day" "$day" > "$D/ci/$day.jsonl"
  d=$((d+1))
done
cat > "$D/config.json" <<'EOF'
{
  "repo": "acme/shop",
  "changeWindowDays": 3,
  "changeMinSample": 5,
  "changes": [{ "at": "2026-03-06", "label": "every pull request is reviewed", "expect": { "metric": "noReview", "direction": "down" }, "decidedBy": "team" }]
}
EOF
{
  printf 'date\tkind\tref\tsubject\tlabel\tby\tnote\n'
  printf '# three blocks read by hand\n'
  printf '2026-03-07\tblock\t#21\thuman\tright\talice\tfixed as asked\n'
  printf '2026-03-07\tblock\t#22\thuman\tright\talice\tfixed as asked\n'
  printf '2026-03-08\tblock\t#25\thuman\tFalse Alarm\talice\twithdrawn\n'
  printf '2026-03-08\tblock\t#26\thuman\tnot sure\talice\t\n'
  printf '2026-03-09\tmain-failure\trun 109\t\tflaky test\tagent\tgreen on re-run\n'
} > "$D/labels.tsv"

# j <file> <js expression over m> -> the value, printed
j() { node -e 'const m = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); const v = eval(process.argv[2]); console.log(typeof v === "object" ? JSON.stringify(v) : String(v));' "$1" "$2" 2>&1; }

echo "# analyze.mjs --out writes only that file"
OUT=$(node "$TOOLS/analyze.mjs" "$D" --out "$T/side.json" 2>&1); EC=$?
eq "analyze --out: exit 0" 0 "$EC"
[ -f "$T/side.json" ] && ok "analyze --out: the named file is written" || bad "analyze --out: the named file is written"
[ ! -e "$D/metrics.json" ] && [ ! -e "$D/history" ] && ok "analyze --out: nothing is written into the working directory" || bad "analyze --out: nothing is written into the working directory"

echo "# analyze.mjs"
OUT=$(node "$TOOLS/analyze.mjs" "$D" 2>&1); EC=$?
eq "analyze: exit 0" 0 "$EC"
has "analyze: the summary names repository, count and period" "$OUT" "acme/shop: 40 merged pull requests, 2026-03-01 to 2026-03-10"
has "analyze: rounds are counted for the human reviewer" "$OUT" 'rounds counted for reviewer "human"'
M="$D/metrics.json"
[ -f "$M" ] && ok "analyze: metrics.json is written" || bad "analyze: metrics.json is written"
[ -f "$D/history/2026-03-10.json" ] && ok "analyze: the run is kept under history/" || bad "analyze: the run is kept under history/"
eq "metrics: 40 merged" 40 "$(j "$M" 'm.total.merged')"
eq "metrics: 20 reviewed" 20 "$(j "$M" 'm.total.efficiency.reviewed')"
eq "metrics: half merged without review" 0.5 "$(j "$M" 'm.total.quality.noReviewShare')"
eq "metrics: the default branch is main" main "$(j "$M" 'm.defaultBranch')"
eq "metrics: 10 CI runs" 10 "$(j "$M" 'm.ci.all.runs')"
eq "metrics: one failed push to main" 1 "$(j "$M" 'm.ci.defaultBranchPush.failure')"
eq "metrics: the risk class comes from the files" 40 "$(j "$M" 'm.classes["source code"].merged')"

echo "# rules"
rule() { j "$M" "(m.results.find((r) => r.id === '$1') || {}).$2"; }
eq "rule: merged-without-review is triggered" triggered "$(rule merged-without-review state)"
has "rule: the problem names count and denominator" "$(rule merged-without-review text)" "20 of 40 pull requests were merged without a review"
eq "rule: a sample of 40 is too small for high-fix-share" not-evaluated "$(rule high-fix-share state)"
eq "rule: the reason names both numbers" "only 40 in the sample, the rule needs 50" "$(rule high-fix-share reason)"
eq "rule: no finished later rounds -> not evaluated, not passed" not-evaluated "$(rule later-rounds-low-yield state)"
eq "rule: unresolved-threads passes" passed "$(rule unresolved-threads state)"
eq "score: the review group has one triggered rule" 1 "$(j "$M" 'm.scores.review.triggered')"

echo "# a dated change with expect"
eq "change: one entry" 1 "$(j "$M" 'm.changes.length')"
eq "change: 12 pull requests before" 12 "$(j "$M" 'm.changes[0].before.n')"
eq "change: 12 pull requests after" 12 "$(j "$M" 'm.changes[0].after.n')"
eq "change: the unreviewed share got better" better "$(j "$M" 'm.changes[0].rows.find((r) => r.key === "noReview").verdict')"
eq "change: the expectation is confirmed" confirmed "$(j "$M" 'm.changes[0].expectation.verdict')"
eq "change: who decided it is kept" team "$(j "$M" 'm.changes[0].decidedBy')"
eq "change: a complete window is not marked incomplete" false "$(j "$M" 'm.changes[0].incomplete')"

echo "# labels.tsv"
eq "labels: five lines read, header and comment skipped" 5 "$(j "$M" 'm.labels.total')"
eq "labels: four blocks for the reviewer" 4 "$(j "$M" 'm.labels.reviewers.human.labelled')"
eq "labels: hit rate is right of the decided (2 of 3)" 0.667 "$(j "$M" 'm.labels.reviewers.human.hitRate')"
eq "labels: one unclear block" 1 "$(j "$M" 'm.labels.reviewers.human.unclear')"
eq "labels: the failure cause is counted" 1 "$(j "$M" 'm.labels.mainFailures["flaky test"]')"

echo "# a second run"
eq "previous: none after the first run" undefined "$(j "$M" 'typeof m.previous')"
printf '{"number":41,"title":"fix: late","body":"","createdAt":"2026-03-11T08:00:00Z","mergedAt":"2026-03-11T10:00:00Z","additions":1,"deletions":1,"changedFiles":1,"branch":"fix-41","base":"main","author":"dev","authorBot":false,"bodyTail":"","coAuthors":[],"labels":[],"commitCount":1,"commits":[{"oid":"c41","at":"2026-03-11T08:00:00Z","msg":"late"}],"reviews":[],"comments":[],"threadCount":0,"threads":[],"files":["src/a41.ts"]}\n' > "$D/prs/2026-03-11.jsonl"
node "$TOOLS/analyze.mjs" "$D" >/dev/null 2>&1
eq "previous: the earlier period is kept" 2026-03-10 "$(j "$M" 'm.previous.period.to')"
eq "previous: its triggered rules are kept" true "$(j "$M" 'm.previous.triggered.includes("merged-without-review")')"
eq "history: the suggestion is open for two runs" 2 "$(rule merged-without-review openRuns)"

echo "# report.mjs"
printf '[{"value":"20 of 41","tone":"warn","title":"Merged without any review","recommendation":"Require a review for source changes.","evidence":"Fixture."}]\n' > "$D/findings.json"
OUT=$(node "$TOOLS/report.mjs" "$M" "$D/report.html" --findings "$D/findings.json" 2>&1); EC=$?
eq "report: exit 0" 0 "$EC"
[ -s "$D/report.html" ] && ok "report: the file is written" || bad "report: the file is written" "$OUT"
HTML=$(cat "$D/report.html" 2>/dev/null)
has "report: the suggestions section" "$HTML" "Suggestions · "
has "report: the triggered rule is a card" "$HTML" "Merges without any review"
has "report: the analyst's finding" "$HTML" "20 of 41"
has "report: the change and its expectation" "$HTML" "every pull request is reviewed"
has "report: the hand labels" "$HTML" "Blocks checked by hand"
case "$HTML" in *"src=\"http"*|*"href=\"http"*".css"*) bad "report: self-contained (no external script or stylesheet)" ;; *) ok "report: self-contained (no external script or stylesheet)" ;; esac
OUT=$(node "$TOOLS/report.mjs" 2>&1); eq "report: no arguments -> usage, exit 2" 2 "$?"

echo "# daily.mjs"
OUT=$(node "$TOOLS/daily.mjs" "$M" --day 2026-03-09 --out "$D/digest.md" 2>&1); EC=$?
eq "digest: exit 0" 0 "$EC"
has "digest: prints the day and the repository" "$OUT" "**Process digest 2026-03-09** · acme/shop"
has "digest: merged that day" "$OUT" "- Merged pull requests: **4**"
has "digest: the failed push on main" "$OUT" "1 of 1 runs"
[ -s "$D/digest.md" ] && ok "digest: --out writes the file" || bad "digest: --out writes the file"
OUT=$(node "$TOOLS/daily.mjs" "$M" --day 2026-03-03 2>&1); EC=$?
eq "digest: fewer than three days before -> exit 1" 1 "$EC"
has "digest: says what it needs" "$OUT" "at least three days before it"

echo "# a review after the merge, a reused branch name, a dropped ask"
# 41 gets a review two hours after its merge; 42 reuses 41's branch name. One CI run per commit on that branch.
printf '{"number":41,"title":"fix: late","body":"","createdAt":"2026-03-11T08:00:00Z","mergedAt":"2026-03-11T10:00:00Z","additions":1,"deletions":1,"changedFiles":1,"branch":"fix-41","base":"main","author":"dev","authorBot":false,"bodyTail":"","coAuthors":[],"labels":[],"commitCount":1,"commits":[{"oid":"c41","at":"2026-03-11T08:00:00Z","msg":"late"}],"reviews":[{"by":"rita","bot":false,"state":"APPROVED","at":"2026-03-11T12:00:00Z","head":"c41","body":"fine"}],"comments":[],"threadCount":0,"threads":[],"files":["src/a41.ts"]}\n' > "$D/prs/2026-03-11.jsonl"
printf '{"number":42,"title":"fix: again","body":"","createdAt":"2026-03-11T10:30:00Z","mergedAt":"2026-03-11T11:30:00Z","additions":1,"deletions":1,"changedFiles":1,"branch":"fix-41","base":"main","author":"dev","authorBot":false,"bodyTail":"","coAuthors":[],"labels":[],"commitCount":1,"commits":[{"oid":"c42","at":"2026-03-11T10:30:00Z","msg":"again"}],"reviews":[],"comments":[],"threadCount":0,"threads":[],"files":["src/a42.ts"]}\n' >> "$D/prs/2026-03-11.jsonl"
for s in 41 42; do
  printf '{"id":2%s,"name":"ci","event":"pull_request","branch":"fix-41","sha":"c%s","attempt":1,"status":"completed","conclusion":"success","createdAt":"2026-03-11T0%s:40:00Z","startedAt":"2026-03-11T0%s:40:00Z","updatedAt":"2026-03-11T0%s:50:00Z"}\n' "$s" "$s" "$((s-33))" "$((s-33))" "$((s-33))"
done > "$D/ci/2026-03-11.jsonl"
printf '[{"key":"review-all","at":"2026-03-07","ask":"Review every pull request","metric":"noReview","direction":"down"},{"key":"review-all","at":"2026-03-09","ask":"Review every pull request","metric":"noReview","direction":"down"},{"key":"review-all","at":"2026-03-10","dropped":true,"by":"user"}]\n' > "$D/asks.json"
node "$TOOLS/analyze.mjs" "$D" --out "$T/third.json" >/dev/null 2>&1
eq "review after merge: the pull request still counts as merged without review" 20 "$(j "$T/third.json" 'm.total.efficiency.reviewed')"
eq "reused branch: the earlier pull request keeps its own run" 1 "$(j "$T/third.json" 'm.outliers.mostCiRuns.find((x) => x.pr === 41).ciRuns')"
eq "reused branch: the later pull request gets only its own" 1 "$(j "$T/third.json" 'm.outliers.mostCiRuns.find((x) => x.pr === 42).ciRuns')"
eq "dropped ask: the decision is no ask of its own" 2 "$(j "$T/third.json" 'm.asks.length')"
eq "dropped ask: every ask of the key is marked" true "$(j "$T/third.json" 'm.asks.every((a) => a.dropped)')"
eq "fixes without a test: the rule's sample is the fixes that touch source" 2 "$(j "$T/third.json" '(m.results.find((r) => r.id === "fixes-without-tests") || {}).n ?? m.total.quality.sourceFixes')"
# an ask from before the period still counts, and the user's escalation marks its key
printf '[{"key":"red-main","at":"2026-02-20","ask":"Fix a red main first","metric":"mainFailed","direction":"down"},{"key":"red-main","at":"2026-03-08","ask":"Fix a red main first","metric":"mainFailed","direction":"down"},{"key":"red-main","at":"2026-03-10","escalated":true,"by":"user"}]\n' > "$D/asks.json"
: > "$D/prs/2026-03-13.jsonl"   # two mined days on which nothing merged
node "$TOOLS/analyze.mjs" "$D" --out "$T/fourth.json" >/dev/null 2>&1
eq "period: it ends on the last mined day, not on the last merge" 2026-03-13 "$(j "$T/fourth.json" 'm.period.to')"
eq "asks: an ask before the period counts in times" "1 2 of 2" "$(j "$T/fourth.json" 'm.asks.length + " " + m.asks[0].nth + " of " + m.asks[0].times')"
eq "asks: the user's escalation marks the key" true "$(j "$T/fourth.json" 'm.asks[0].escalated')"
node "$TOOLS/analyze.mjs" "$D" --since 2026-03-09 --out "$T/fifth.json" >/dev/null 2>&1
eq "asks: a decided key is kept when its asks left the period" "0 red-main escalated" "$(j "$T/fifth.json" 'm.asks.length + " " + m.askDecisions[0].key + " " + m.askDecisions[0].decision')"

echo "# mine-failures.mjs without a push run"
mkdir -p "$T/pronly/ci"; cp "$D/ci/2026-03-11.jsonl" "$T/pronly/ci/"
OUT=$(GITHUB_TOKEN=unused node "$TOOLS/mine-failures.mjs" acme/shop "$T/pronly" 2>&1); EC=$?
eq "mine-failures: no push run and no defaultBranch -> exit 0, no request" 0 "$EC"
eq "mine-failures: the default-branch section stays empty" 0 "$(j "$T/pronly/failures.json" 'm.defaultBranch.length')"
# more push runs on a release branch than on main: the base of the merged pull requests decides
mkdir -p "$T/bases/ci" "$T/bases/prs"; cp "$D/prs/2026-03-11.jsonl" "$T/bases/prs/"
for i in 1 2; do printf '{"id":30%s,"name":"ci","event":"push","branch":"release","sha":"r%s","attempt":1,"status":"completed","conclusion":"success","createdAt":"2026-03-11T0%s:00:00Z","startedAt":"2026-03-11T0%s:00:00Z","updatedAt":"2026-03-11T0%s:10:00Z"}\n' "$i" "$i" "$i" "$i" "$i"; done > "$T/bases/ci/2026-03-11.jsonl"
GITHUB_TOKEN=unused node "$TOOLS/mine-failures.mjs" acme/shop "$T/bases" >/dev/null 2>&1
eq "mine-failures: the default branch is the base of the merged pull requests" main "$(j "$T/bases/failures.json" 'm.branch')"

echo "# the period: quiet days at both ends, days of an earlier run in the same directory, unfinished runs"
# A working directory as a recurring run leaves it: February from an earlier run (pull requests, CI runs and its
# failures.json), then 1 to 10 April. Nothing merges on 1, 2, 9 and 10 April; April's CI runs never finished.
E="$T/edge"; mkdir -p "$E/prs" "$E/ci"
node -e '
const fs = require("fs"), dir = process.argv[1];
const pr = (n, day, h) => JSON.stringify({ number: n, title: `feat: change ${n}`, body: "", createdAt: `${day}T08:00:00Z`, mergedAt: `${day}T${h}:00:00Z`, additions: 5, deletions: 1, changedFiles: 1, branch: `feat-${n}`, base: day < "2026-03" ? "trunk" : "main", author: "dev", authorBot: false, bodyTail: "", coAuthors: [], labels: [], commitCount: 1, commits: [{ oid: `c${n}`, at: `${day}T08:00:00Z`, msg: "change" }], reviews: [], comments: [], threadCount: 0, threads: [], files: [`src/a${n}.ts`] });
const run = (id, day, o) => JSON.stringify({ id, name: "ci", event: "push", branch: "main", sha: `m${id}`, attempt: 1, status: "completed", conclusion: "success", createdAt: `${day}T11:00:00Z`, startedAt: `${day}T11:00:00Z`, updatedAt: `${day}T11:10:00Z`, ...o });
let n = 0;
const write = (day, prs, runs) => { fs.writeFileSync(`${dir}/prs/${day}.jsonl`, prs.map((p) => p + "\n").join("")); fs.writeFileSync(`${dir}/ci/${day}.jsonl`, runs.map((r) => r + "\n").join("")); };
write("2026-02-01", Array.from({ length: 30 }, (_, i) => pr(++n, "2026-02-01", 10 + (i % 9))), Array.from({ length: 5 }, (_, i) => run(900 + i, "2026-02-01", { branch: "trunk" })));
for (let d = 1; d <= 10; d++) { const day = `2026-04-${String(d).padStart(2, "0")}`, quiet = d <= 2 || d >= 9;
  write(day, quiet ? [] : Array.from({ length: 5 }, (_, i) => pr(++n, day, 10 + i)), quiet ? [] : Array.from({ length: 20 }, (_, i) => run(d * 100 + i, day, { status: "in_progress", conclusion: null, startedAt: null }))); }
fs.writeFileSync(`${dir}/config.json`, JSON.stringify({ changeMinSample: 5, changes: [{ at: "2026-04-02", label: "a change on a quiet day", expect: { metric: "lead", direction: "down" } }] }));
fs.writeFileSync(`${dir}/failures.json`, JSON.stringify({ repo: "acme/shop", at: "2026-02-02T00:00:00Z", days: 7, from: "2026-01-25", branch: "trunk", defaultBranch: [], rerunsRead: 0, flaky: [], incomplete: [] }));
' "$E"
node "$TOOLS/analyze.mjs" "$E" --since 2026-04-01 --until 2026-04-10 --out "$T/edge.json" >/dev/null 2>&1
eq "period: quiet days at both ends belong to it" "2026-04-01 2026-04-10" "$(j "$T/edge.json" 'm.period.from + " " + m.period.to')"
eq "period: the days of an earlier run stay out" "30 main" "$(j "$T/edge.json" 'm.total.merged + " " + m.defaultBranch')"
eq "period: a change on a quiet first day is kept, with a short baseline" "true too early" "$(j "$T/edge.json" 'm.changes[0].baselineShort + " " + m.changes[0].expectation.verdict')"
eq "period: the digest ends on the last day of the period" 2026-04-10 "$(j "$T/edge.json" 'm.daily.at(-1).day')"
eq "period: failure details of another period are not shown" "undefined 2026-02-02" "$(j "$T/edge.json" 'typeof m.failures + " " + m.failuresNotMined.to')"
eq "unmeasured: CI hours without a finished run are not available, not zero" "120 0 null" "$(j "$T/edge.json" 'm.ci.all.runs + " " + m.ci.all.completed + " " + m.ci.all.hours')"
eq "unmeasured: no CI rule passes on runs that never finished" "not-evaluated not-evaluated not-evaluated" "$(j "$T/edge.json" '["ci-hours-not-green", "ci-cancelled", "flaky-reruns"].map((id) => m.results.find((r) => r.id === id).state).join(" ")')"
node "$TOOLS/analyze.mjs" "$E" --out "$T/edge-all.json" >/dev/null 2>&1
eq "period: without bounds it is every mined day" "2026-02-01 60" "$(j "$T/edge-all.json" 'm.period.from + " " + m.total.merged')"
OUT=$(GITHUB_TOKEN=unused node "$TOOLS/mine-failures.mjs" acme/shop "$E" --since 2026-04-01 --until 2026-04-10 2>&1); EC=$?
eq "mine-failures: same period, no request needed -> exit 0" 0 "$EC"
eq "mine-failures: branch, bounds and window come from the period" "main 2026-04-01 2026-04-10 2026-04-03" "$(j "$E/failures.json" 'm.branch + " " + m.since + " " + m.until + " " + m.from')"

echo "# api.mjs without a token"
NODE_BIN=$(node -e 'console.log(process.execPath)')
mkdir -p "$T/empty" "$T/home"
OUT=$(env -i PATH="$T/empty" HOME="$T/home" "$NODE_BIN" "$TOOLS/api.mjs" 2>&1); EC=$?
eq "api: no token and no gh -> exit 2" 2 "$EC"
has "api: says how to supply one" "$OUT" "no GitHub token: set GITHUB_TOKEN"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

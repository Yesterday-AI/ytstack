#!/usr/bin/env bash
# Fixture: a small checkout of acme/shop with its pull request and CI data
# already mined into ./process-data, in the format tools/process-review/mine.mjs
# writes (a run has no GitHub access, so the case never mines). 21 days in
# March 2026, four merged pull requests a day. Until 7 March nothing is
# reviewed; from 8 March on, when the team started to require a review, a
# person approves each one. One push run on main per day, two of them failed.
# The skill has to analyse what is there, put the change of 8 March with its
# expectation into config.json, and render the report: the expectation comes
# out confirmed (28 unreviewed of 28 before, 0 of 28 after) and the rule
# "merges without any review" is still triggered for the period (28 of 84).
set -eu
git init -q . && git config user.email eval@ytstack.test && git config user.name eval
git config commit.gpgsign false
git remote add origin https://github.com/acme/shop.git
printf '# shop\n\nThe web shop of Acme.\n' > README.md
printf 'process-data/\n' > .gitignore
mkdir -p src process-data/prs process-data/ci
echo "// shop" > src/shop.ts
n=0; d=1
while [ $d -le 21 ]; do
  day=$(printf '2026-03-%02d' $d)
  i=1
  while [ $i -le 4 ]; do
    n=$((n+1))
    if [ $d -ge 8 ]; then
      reviews="[{\"by\":\"rita\",\"bot\":false,\"state\":\"APPROVED\",\"at\":\"${day}T09:00:00Z\",\"head\":\"c${n}\",\"body\":\"Looks right.\"}]"
    else
      reviews="[]"
    fi
    printf '{"number":%d,"title":"feat: change %d","body":"","createdAt":"%sT08:00:00Z","mergedAt":"%sT10:0%d:00Z","additions":10,"deletions":2,"changedFiles":1,"branch":"feat-%d","base":"main","author":"dev","authorBot":false,"bodyTail":"","coAuthors":[],"labels":[],"commitCount":1,"commits":[{"oid":"c%d","at":"%sT08:00:00Z","msg":"change %d"}],"reviews":%s,"comments":[],"threadCount":0,"threads":[],"files":["src/a%d.ts"]}\n' \
      "$n" "$n" "$day" "$day" "$i" "$n" "$n" "$day" "$n" "$reviews" "$n" >> "process-data/prs/$day.jsonl"
    i=$((i+1))
  done
  concl=success
  if [ $d -eq 4 ] || [ $d -eq 17 ]; then concl=failure; fi
  printf '{"id":%d,"name":"ci","event":"push","branch":"main","sha":"m%d","attempt":1,"status":"completed","conclusion":"%s","createdAt":"%sT11:00:00Z","startedAt":"%sT11:00:00Z","updatedAt":"%sT11:10:00Z"}\n' \
    "$((100+d))" "$d" "$concl" "$day" "$day" "$day" > "process-data/ci/$day.jsonl"
  d=$((d+1))
done
printf '{"repo":"acme/shop","since":"2026-03-01","until":"2026-03-21","at":"2026-03-22T06:00:00Z","closedUnmerged":3,"openNow":5,"openOlderThanAWeek":1}\n' > process-data/meta.json
git add -A && git commit -qm "chore: scaffold"

#!/usr/bin/env bash
# Tests for bin/ytstack-runtime: the sections "Run", "Release" and "Signals" of
# .ytstack/RUNTIME.md (format in docs/ux/runtime-format.md) and the instance of
# the product that "up" starts per worktree.
#
# Contract:
#   get      one value of "Run" or "Release"; exit 1 when the file, the section
#            or the key is missing; the section argument in any case
#   signals  one tab separated line per source: name, kind, read, scope; a bar
#            inside a command stays part of the command
#   check    a well-formed file passes and names its sections; free text in a
#            section and a section without a list line pass, and so does the
#            RUNTIME.md template of init-project and of adopt-brownfield; each
#            defect is named on its own, exit 1
#   up       starts the product on a free port of the range, waits for "ready",
#            prints URL, PORT, PID, LOG and COMMIT; state outside the checkout;
#            a second up prints the same instance; two directories get two
#            ports; a taken port is skipped; a start that exits and a ready
#            that never passes end with the log, exit 1 and nothing running
#   down     ends the process group, children included, after "stop" when set;
#            never touches a process that only carries a recorded pid; a zombie
#            (ended, not collected by its parent) counts as ended (Linux case)
#   status   the instance, or "not running" with exit 1
#
# The live cases need python3 (a tiny HTTP server) and are skipped without it.
#
# Run: /bin/bash tests/ytstack-runtime.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-runtime"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }
yes() { if "${@:2}" 2>/dev/null; then ok "$1"; else bad "$1"; fi; }
no()  { if "${@:2}" 2>/dev/null; then bad "$1"; else ok "$1"; fi; }

if [ ! -x "$BIN" ]; then
  bad "bin/ytstack-runtime exists and is executable"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ytruntime.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
LIVE=""; FOREIGN=""
# Whatever a failed case left running is stopped before the directory goes.
cleanup() {
  local d
  for d in $LIVE; do "$BASH" "$BIN" -C "$d" down >/dev/null 2>&1; done
  [ -z "$FOREIGN" ] || kill "$FOREIGN" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT
TAB=$(printf '\t')
# The state of every instance stays inside the fixture.
export CLAUDE_PLUGIN_DATA="$TMP/state"

# run <dir> <args...>: sets OUT (stdout + stderr) and EC. The script runs under
# the bash that runs this suite.
run() { local d="$1"; shift; OUT=$("$BASH" "$BIN" -C "$d" "$@" 2>&1); EC=$?; }
# project <name>: a directory with an empty .ytstack. Sets D and F (its RUNTIME.md).
project() { D="$TMP/$1"; F="$D/.ytstack/RUNTIME.md"; mkdir -p "$D/.ytstack"; }
# line <KEY>: the value of one "KEY: value" line of OUT
line() { printf '%s\n' "$OUT" | sed -n "s/^$1: //p" | sed -n 1p; }

# ---- 1. nothing there ---------------------------------------------------------
echo "# no RUNTIME.md, no sections"
project empty
run "$D" check;   eq "check without the file: exit 0" 0 "$EC"; eq "and says so" "runtime ok: no RUNTIME.md" "$OUT"
run "$D" signals; eq "signals without the file: exit 0" 0 "$EC"; eq "and prints nothing" "" "$OUT"
run "$D" get run start; eq "get without the file: exit 1" 1 "$EC"; has "and says so" "no RUNTIME.md" "$OUT"
run "$D" status;  eq "status without an instance: exit 1" 1 "$EC"; eq "and says so" "not running" "$OUT"
run "$D" down;    eq "down without an instance: exit 0" 0 "$EC"; eq "and says so" "not running" "$OUT"
run "$D" up;      eq "up without the file: exit 1" 1 "$EC"; has "and says so" "no RUNTIME.md" "$OUT"
mkdir -p "$TMP/bare"
run "$TMP/bare" check; eq "check without a .ytstack directory: exit 0" 0 "$EC"
no "and creates none" test -e "$TMP/bare/.ytstack"
run "$TMP/nowhere" check; eq "-C to a missing directory: exit 64" 64 "$EC"
run "$D" restart;         eq "unknown command: exit 64" 64 "$EC"

# The scaffold of init-project: the old sections, the three new headings with a
# line of free text each, no list line.
cat > "$F" <<'EOF'
# Runtime

Services, APIs, env vars, and ports used by shop.

## Services

- postgres: a list line outside the three sections is never read

## Run

(How the product starts in a worktree. Keys: docs/ux/runtime-format.md.)

## Release

(Where the deployed commit can be read.)

## Signals

(Where production reports errors.)
EOF
run "$D" check
eq "headings with free text and no list line pass" 0 "$EC"
eq "and count as no section" "runtime ok: no sections" "$OUT"
run "$D" get run start; eq "get from a section without a list line: exit 1" 1 "$EC"
has "and says that the section is missing" 'no "Run" section' "$OUT"
run "$D" up; eq "up without a Run section: exit 1" 1 "$EC"
has "and says so" 'no "Run" section' "$OUT"

# What the two scaffold skills write passes as it is.
# template <skill>: the fenced block under "#### RUNTIME.md" of that skill
template() {
  awk '
    /^#### / { on = ($0 == "#### RUNTIME.md"); next }
    on && index($0, "```") == 1 { if (inb) exit; inb = 1; next }
    inb { print }
  ' "$ROOT/skills/$1/SKILL.md"
}
for s in init-project adopt-brownfield; do
  project "scaffold-$s"; template "$s" > "$F"
  has "$s: the RUNTIME.md template has the three headings" "## Run|## Release|## Signals|" "$(grep -E '^## (Run|Release|Signals)$' "$F" | tr '\n' '|')"
  run "$D" check
  eq "$s: the template passes check untouched" "runtime ok: no sections" "$OUT"
done

# ---- 2. get, signals, check on a full file ------------------------------------
echo "# get, signals"
project full
cat > "$F" <<'EOF'
# Runtime

```markdown
## Run

- start: a heading inside a code fence is text
```

## Run

Needs Docker. Free text between the keys is not read.

- start: pnpm dev --port {port}
- ports: 4100-4199
- ready: curl -fsS http://localhost:{port}/healthz
- url: http://localhost:{port}
- logs: {log}
- needs: DATABASE_URL, a local Postgres (docker compose up -d db)
- stop: (default)

## Release

- target: production (https://app.example.com)
- deployed: curl -fsS https://app.example.com/version
- healthy: curl -fsS https://app.example.com/healthz
- settle: 180

## Signals

- errors | read: glitchtip-cli issues --project shop --since 24h --format tsv | kind: errors | scope: unhandled errors of the web app
- latency | read: ./ops/p95.sh --window 24h | sort -rn | head -5 | kind: performance
- pager | kind: alerts | read: pagerctl open

## Deploy target

- deployed: not read, the section ended
EOF
run "$D" check
eq "the example of the format passes" 0 "$EC"
eq "and its sections are named" "runtime ok: Run, Release, Signals" "$OUT"
run "$D" get run start;       eq "get run start" "pnpm dev --port {port}" "$OUT"
run "$D" get Run url;         eq "a value keeps its colons" "http://localhost:{port}" "$OUT"
run "$D" get RELEASE settle;  eq "the section argument in any case" "180" "$OUT"
run "$D" get release deployed; eq "get release deployed" "curl -fsS https://app.example.com/version" "$OUT"
run "$D" get run stop;        eq "the default of stop is printed as written" "(default)" "$OUT"
run "$D" get run healthy;     eq "a key of another section: exit 1" 1 "$EC"
has "and the missing key is named" 'no "healthy" in the "Run" section' "$OUT"
run "$D" get signals errors;  eq "get on Signals: exit 64" 64 "$EC"
run "$D" get run;             eq "get without a key: exit 64" 64 "$EC"
run "$D" signals
eq "signals: name, kind, read, scope; a bar in a command stays; - for no scope" "errors${TAB}errors${TAB}glitchtip-cli issues --project shop --since 24h --format tsv${TAB}unhandled errors of the web app
latency${TAB}performance${TAB}./ops/p95.sh --window 24h | sort -rn | head -5${TAB}-
pager${TAB}alerts${TAB}pagerctl open${TAB}-" "$OUT"

# ---- 3. check: each defect on its own -----------------------------------------
echo "# check: defects"
N=0
# defect <case> <text> : RUNTIME.md comes on stdin; check fails and names <text>
defect() {
  N=$((N + 1)); project "d$N"; cat > "$F"
  run "$D" check
  if [ "$EC" = 1 ]; then has "$1" "$2" "$OUT"; else bad "$1" "exit $EC: $OUT"; fi
}
RUN="## Run

- start: pnpm dev
- ready: curl -fsS http://localhost:3000/"
REL="## Release

- deployed: curl -fsS https://app.example.com/version"

defect "Run: a list line that is no key: value" 'line 5: Run: not a "- key: value" line: just start it' <<EOF
$RUN
- just start it
EOF
defect "Run: a key without a value" 'line 5: Run: not a "- key: value" line: url:' <<EOF
$RUN
- url:
EOF
defect "Run: a key outside the list" 'line 5: Run: unknown key "port"' <<EOF
$RUN
- port: 3000
EOF
defect "Run: a key twice" 'line 5: Run: the key "start" stands twice' <<EOF
$RUN
- start: pnpm start
EOF
defect "Run: a key line that lost its dash" 'line 5: Run: "url:" without the leading "- "' <<EOF
$RUN
url: http://localhost:3000
EOF
defect "Run without start" "Run: no start" <<'EOF'
## Run

- ready: curl -fsS http://localhost:3000/
EOF
defect "Run without ready" "Run: no ready" <<'EOF'
## Run

- start: pnpm dev
EOF
defect "{port} without ports" "Run: {port} is used, but there is no ports line" <<'EOF'
## Run

- start: pnpm dev --port {port}
- ready: curl -fsS http://localhost:3000/
EOF
defect "ports that is no range" 'line 5: Run: ports "4100" is not <first>-<last>' <<EOF
$RUN
- ports: 4100
EOF
defect "ports with first not below last" 'line 5: Run: ports "4199-4100" is not <first>-<last>' <<EOF
$RUN
- ports: 4199-4100
EOF
defect "Release: a key outside the list" 'line 4: Release: unknown key "rollback"' <<EOF
$REL
- rollback: ./deploy.sh --previous
EOF
defect "Release without deployed" "Release: no deployed" <<'EOF'
## Release

- target: production
EOF
defect "settle that is no number" 'line 4: Release: settle "3 minutes" is not a number of seconds' <<EOF
$REL
- settle: 3 minutes
EOF
defect "a signal without read" "line 3: Signals: errors: no read" <<'EOF'
## Signals

- errors | kind: errors
EOF
defect "a signal without kind" "line 3: Signals: errors: no kind" <<'EOF'
## Signals

- errors | read: ./errors.sh
EOF
defect "a kind outside the four" 'line 3: Signals: errors: kind "crashes" is not errors, performance, alerts or logs' <<'EOF'
## Signals

- errors | read: ./errors.sh | kind: crashes
EOF
defect "a signal name twice" 'line 4: Signals: the name "errors" is used twice' <<'EOF'
## Signals

- errors | read: ./errors.sh | kind: errors
- errors | read: ./more.sh | kind: logs
EOF
defect "a signal name that is no slug" 'line 3: Signals: the name "Web Errors" is not a lowercase slug' <<'EOF'
## Signals

- Web Errors | read: ./errors.sh | kind: errors
EOF
defect "a signal field outside the list" 'line 3: Signals: errors: unknown field "severity"' <<'EOF'
## Signals

- errors | read: ./errors.sh | kind: errors | severity: high
EOF
defect "a signal line without fields" 'line 3: Signals: errors: "./errors.sh" is not a "key: value" field' <<'EOF'
## Signals

- errors | ./errors.sh
EOF
# Built here, so that no token-looking literal sits in this file (the secret scan of CI reads it).
HEXTOK=$(printf '8f3a%.0s' 1 2 3 4 5 6 7 8)
defect "a token in a command" "line 4: Release: token-looking string" <<EOF
$REL
- healthy: curl -fsS -H "Authorization: Bearer $HEXTOK" https://app.example.com/healthz
EOF
defect "a token in the free text of a section" "line 5: Run: token-looking string" <<EOF
$RUN
The key is Zk9xT2pLbVdRc0hYdUFhR2ZCeU5lSXJDd1BvTDdNNEQ for now.
EOF
eq "one line per problem" 1 "$(printf '%s\n' "$OUT" | grep -c .)"

project outside
cat > "$F" <<EOF
# Runtime

## Environment variables

- API_KEY: $HEXTOK (outside the three sections nothing is read)

$REL
EOF
run "$D" check
eq "text outside the three sections is never read" "runtime ok: Release" "$OUT"

# A fence inside a section is free text as a whole: no heading, no key in it.
project fenced
cat > "$F" <<'EOF'
## Run

- start: pnpm dev
- ready: curl -fsS http://localhost:3000/

An example of the next section:

```markdown
## Release

- deployed: ./deploy.sh --now
```

## Signals

~~~
- example | read: ./not-a-source.sh | kind: errors
~~~

- errors | read: ./errors.sh | kind: errors
EOF
run "$D" check
eq "a fenced Release example inside Run is no Release section" "runtime ok: Run, Signals" "$OUT"
run "$D" get release deployed
eq "and get finds no Release in it" 1 "$EC"; has "and says so" 'no "Release" section' "$OUT"
run "$D" signals
eq "a fenced list line inside Signals is no source" "errors${TAB}errors${TAB}./errors.sh${TAB}-" "$OUT"
defect "a token inside a fence of a section" "line 7: Run: token-looking string" <<EOF
$RUN

\`\`\`
curl -H "Authorization: Bearer $HEXTOK" http://localhost:3000/
\`\`\`
EOF

# ---- 4. up, status, down against a real server --------------------------------
echo "# up, status, down"
if ! command -v python3 >/dev/null 2>&1; then
  echo "  skip - up, status, down: python3 is not installed"
  echo "$PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]; exit
fi

# listening <port>: something accepts a connection on 127.0.0.1
listening() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
# answers <port>: the product serves /healthz there
answers() { "$BASH" "$TMP/ready.sh" "$1" 2>/dev/null; }
# runs <pid>: the process runs and is no zombie (one that ended but was not
# collected, as under a PID 1 that collects nothing)
runs() {
  local s
  kill -0 "$1" 2>/dev/null || return 1
  if [ -r "/proc/$1/stat" ]; then s=$(sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f1)
  else s=$(ps -o stat= -p "$1" 2>/dev/null)
  fi
  case "$s" in *Z*) return 1 ;; esac
}
# gone <pid>: the process ended (waits up to five seconds)
gone() {
  local i=0
  while runs "$1" 2>/dev/null; do [ "$i" -lt 50 ] || return 1; sleep 0.1; i=$((i + 1)); done
}

cat > "$TMP/ready.sh" <<'EOF'
# One HTTP request without curl: exit 0 when /healthz answers 200.
exec 3<>"/dev/tcp/127.0.0.1/$1" || exit 1
printf 'GET /healthz HTTP/1.0\r\n\r\n' >&3
IFS= read -r first <&3
case "$first" in *" 200 "*) exit 0 ;; *) exit 1 ;; esac
EOF
# product <name> <extra Run lines>: a directory whose product is a small HTTP
# server with a child process. Sets D and F.
product() {
  project "$1"; LIVE="$LIVE $D"
  echo ok > "$D/healthz"
  cat > "$D/serve.sh" <<'EOF'
# The product: a child that outlives a kill of the parent alone, then the server.
echo "PORT=${PORT:-unset} arg=$1"
sleep 300 &
echo $! > child.pid
exec python3 -m http.server "$1" --bind 127.0.0.1
EOF
  cat > "$F" <<EOF
# Runtime

## Run

- start: bash serve.sh {port}
- ports: 27300-27319
- ready: bash "$TMP/ready.sh" {port}
- url: http://127.0.0.1:{port}/
${2:-}
EOF
}

product a
printf 'child.pid\nstopped.flag\n' > "$D/.gitignore"
( cd "$D" || exit 1
  git init -q -b main && git config user.email t@t.t && git config user.name t && git config commit.gpgsign false \
    && git add .gitignore healthz serve.sh .ytstack && git commit -qm base ) >/dev/null 2>&1
A="$D"; SHA=$(git -C "$A" rev-parse --short HEAD)
run "$A" up
eq "up: exit 0" 0 "$EC"
PORT_A=$(line PORT); PID_A=$(line PID); LOG_A=$(line LOG)
case "$PORT_A" in 273[01][0-9]) ok "PORT is one of the range" ;; *) bad "PORT is one of the range" "$OUT" ;; esac
eq "URL carries the port" "http://127.0.0.1:$PORT_A/" "$(line URL)"
eq "COMMIT is the commit of the checkout" "$SHA" "$(line COMMIT)"
yes "the product answers on that port" answers "$PORT_A"
yes "PID is a running process" runs "$PID_A"
case "$LOG_A" in "$TMP/state/"*) ok "LOG lies in the state directory, outside the checkout" ;; *) bad "LOG lies in the state directory, outside the checkout" "$LOG_A" ;; esac
eq "the start command got the port as argument and as PORT" "PORT=$PORT_A arg=$PORT_A" "$(sed -n 1p "$LOG_A")"
eq "the checkout holds nothing new" "" "$(git -C "$A" status --porcelain)"
FIRST="$OUT"
run "$A" up
eq "a second up prints the same instance" "$FIRST" "$OUT"
run "$A" status
eq "status: exit 0" 0 "$EC"
eq "status prints the instance" "$FIRST" "$OUT"

product b
B="$D"
run "$B" up
eq "up in a second directory: exit 0" 0 "$EC"
PORT_B=$(line PORT); PID_B=$(line PID)
if [ -n "$PORT_B" ] && [ "$PORT_B" != "$PORT_A" ]; then ok "two directories get two ports"; else bad "two directories get two ports" "$PORT_A and $PORT_B"; fi
yes "both products answer at once: the first" answers "$PORT_A"
yes "both products answer at once: the second" answers "$PORT_B"
eq "COMMIT outside a repository" "none" "$(line COMMIT)"
run "$B" down
eq "down: exit 0" 0 "$EC"
eq "down names what it stopped" "stopped: pid $PID_B, port $PORT_B" "$OUT"
no "the stopped product is gone" runs "$PID_B"
yes "the other one still answers" answers "$PORT_A"

CHILD_A=$(cat "$A/child.pid")
yes "the child of the product runs" runs "$CHILD_A"
run "$A" down
eq "down: exit 0" 0 "$EC"
no "down leaves no process: the server" runs "$PID_A"
no "down leaves no process: its child" runs "$CHILD_A"
no "the port is free again" listening "$PORT_A"
run "$A" status; eq "status after down: exit 1" 1 "$EC"; eq "and says so" "not running" "$OUT"
run "$A" down;   eq "down twice: exit 0" 0 "$EC";        eq "and says so" "not running" "$OUT"

# A port somebody else holds is skipped.
mkdir -p "$TMP/foreign"
( cd "$TMP/foreign" || exit 1; exec python3 -m http.server "$PORT_A" --bind 127.0.0.1 ) >/dev/null 2>&1 &
FOREIGN=$!
i=0; while ! listening "$PORT_A" && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
echo dirty >> "$A/healthz"
run "$A" up
eq "up beside a foreign listener: exit 0" 0 "$EC"
PORT_A2=$(line PORT)
if [ -n "$PORT_A2" ] && [ "$PORT_A2" != "$PORT_A" ]; then ok "the taken port is skipped"; else bad "the taken port is skipped" "$PORT_A2"; fi
yes "the product answers on the next one" answers "$PORT_A2"
eq "COMMIT says when the checkout differs from the commit" "$SHA (with uncommitted changes)" "$(line COMMIT)"
run "$A" down
yes "down does not touch the foreign listener" runs "$FOREIGN"
kill "$FOREIGN" 2>/dev/null; wait "$FOREIGN" 2>/dev/null; FOREIGN=""

# A stale instance file: the process is gone.
run "$A" up
PID_OF=$(line PID); eq "the start position is stable: the same port when it is free" "$PORT_A" "$(line PORT)"
kill -KILL -- "-$PID_OF" 2>/dev/null; gone "$PID_OF"
run "$A" status; eq "an instance whose process is gone: not running" "not running" "$OUT"
run "$A" up
eq "up over a stale instance file: exit 0" 0 "$EC"
PID_OF=$(line PID); PORT_A3=$(line PORT)
yes "and a new product answers" answers "$PORT_A3"
# The recorded pid now belongs to another process (here: another start time).
INST=$(grep -l "^pid=$PID_OF\$" "$TMP"/state/repos/*/worktrees/*/runtime/instance)
sed 's/^born=.*/born=another process/' "$INST" > "$INST.tmp" && cat "$INST.tmp" > "$INST" && rm -f "$INST.tmp"
run "$A" status; eq "a pid that another process carries: not running" "not running" "$OUT"
run "$A" down
eq "down says so" "not running" "$OUT"
yes "and ends nothing that it did not start" runs "$PID_OF"
kill -TERM -- "-$PID_OF" 2>/dev/null; gone "$PID_OF"

# stop: the command runs, and the group is ended as well.
product c "- stop: touch stopped.flag"
run "$D" up; PID_C=$(line PID)
run "$D" down
eq "down with a stop command: exit 0" 0 "$EC"
yes "the stop command ran in the checkout" test -f "$D/stopped.flag"
no "and the process is gone" runs "$PID_C"

# Under a parent that collects nothing (a container whose PID 1 is no init) an
# ended product stays a zombie, which kill -0 still reaches. A python3
# subreaper plays that parent: the product is orphaned to it and never
# collected. Linux only (prctl PR_SET_CHILD_SUBREAPER).
product z; Z="$D"
cat > "$TMP/subreaper.py" <<'EOF'
import ctypes, subprocess, sys
try:
    if ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) != 0: sys.exit(77)
except AttributeError:
    sys.exit(77)
sys.exit(subprocess.run(sys.argv[1:]).returncode)
EOF
OUT=$(python3 "$TMP/subreaper.py" "$BASH" -c '
  "$1" "$2" -C "$3" up >/dev/null 2>&1 || { echo "up failed"; exit 1; }
  "$1" "$2" -C "$3" status | sed -n "s/^PID: /pid=/p"
  "$1" "$2" -C "$3" down; echo "down=$?"
  "$1" "$2" -C "$3" status; echo "status=$?"
' _ "$BASH" "$BIN" "$Z" 2>&1); EC=$?
if [ "$EC" = 77 ]; then
  echo "  skip - zombies: no PR_SET_CHILD_SUBREAPER here (not Linux)"
else
  PID_Z=$(printf '%s\n' "$OUT" | sed -n 's/^pid=//p')
  has "down under a parent that collects nothing: exit 0" "down=0" "$OUT"
  has "and it names what it stopped" "stopped: pid $PID_Z," "$OUT"
  has "status then says not running" "not running
status=1" "$OUT"
fi

# ---- 5. up that fails ----------------------------------------------------------
echo "# up that fails"
project dies
cat > "$F" <<'EOF'
## Run

- start: bash -c 'echo cannot bind the port; exit 3'
- ready: false
- needs: DATABASE_URL
EOF
T0=$SECONDS
run "$D" up
eq "a start command that exits: exit 1" 1 "$EC"
has "it says that the command exited" "the start command exited" "$OUT"
has "it shows the end of the log" "cannot bind the port" "$OUT"
has "it repeats what the product needs" "needs, from RUNTIME.md: DATABASE_URL" "$OUT"
if [ $((SECONDS - T0)) -lt 10 ]; then ok "it does not wait for the timeout"; else bad "it does not wait for the timeout" "$((SECONDS - T0))s"; fi
run "$D" status; eq "nothing is recorded as running" "not running" "$OUT"

# hangs <name> <ready command>: a product that runs but is never ready
hangs() {
  project "$1"; LIVE="$LIVE $D"
  cat > "$F" <<EOF
## Run

- start: bash -c 'echo \$\$ > pid.txt; echo warming up; exec sleep 300'
- ready: $2
EOF
}
hangs never "bash -c 'echo no answer yet; exit 1'"
T0=$SECONDS
run "$D" up --timeout 2
eq "a ready that never passes: exit 1" 1 "$EC"
has "it names the timeout" '"ready" did not pass within 2s' "$OUT"
has "it shows what ready said" "no answer yet" "$OUT"
hasnt "it prints no job message of the shell" "Terminated" "$OUT"
has "it shows the end of the log" "warming up" "$OUT"
if [ $((SECONDS - T0)) -lt 10 ]; then ok "it ends at the timeout"; else bad "it ends at the timeout" "$((SECONDS - T0))s"; fi
no "what was started is stopped" runs "$(cat "$D/pid.txt")"
run "$D" status; eq "nothing is recorded as running" "not running" "$OUT"

hangs stuck "sleep 300"
T0=$SECONDS
run "$D" up --timeout 2
eq "a ready that hangs: exit 1" 1 "$EC"
hasnt "it prints no job message of the shell" "Terminated" "$OUT"
if [ $((SECONDS - T0)) -lt 10 ]; then ok "it cannot outlast the timeout"; else bad "it cannot outlast the timeout" "$((SECONDS - T0))s"; fi
no "what was started is stopped" runs "$(cat "$D/pid.txt")"

project broken
cat > "$F" <<'EOF'
## Run

- start: bash -c 'echo started > started.flag; exec sleep 300'
- ready: true
- port: 3000
EOF
run "$D" up
eq "up on a file that fails check: exit 1" 1 "$EC"
has "it names the problem" 'unknown key "port"' "$OUT"
no "and starts nothing" test -e "$D/started.flag"
run "$D" up --timeout soon; eq "a timeout that is no number: exit 64" 64 "$EC"

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

#!/usr/bin/env bash
# Tests for bin/ytstack-handover and skills/handover-step/template.sh: the
# staged script of a step only a human may perform.
#
# Contract:
#   new      an executable copy of the template with title and time filled;
#            an existing path is not overwritten
#   check    a well-formed script passes with its counts; each rule fails on
#            its own: syntax, the helper block, a raw command at top level,
#            mutate before confirm, a confirm of an earlier stage, a second
#            mutate behind one confirm, no stage,
#            sudo unannounced, a pipe into a shell, rm -rf, eval, a
#            token-looking assignment, an empty header field
#   runtime  without a terminal confirm stops the script, mutate does not run
#            and the receipt names what did not run; a failed check stops; a
#            mutate without a confirm is refused. With a pseudo terminal (when
#            python3 is there): yes runs the change, anything else stops,
#            done and skip are recorded, a second mutate behind one confirm
#            is refused.
#
# Run: /bin/bash tests/ytstack-handover.test.sh   (exit 0 = all pass; macOS bash 3.2)

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
BIN="$ROOT/bin/ytstack-handover"
TPL="$ROOT/skills/handover-step/template.sh"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   - $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL - $1${2:+ ($2)}"; }
eq()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected '$2' got '$3'"; fi; }
has() { case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "no '$2' in: $3" ;; esac; }
hasnt() { case "$3" in *"$2"*) bad "$1" "unexpected '$2' in: $3" ;; *) ok "$1" ;; esac; }

if [ ! -x "$BIN" ] || [ ! -f "$TPL" ]; then
  bad "bin/ytstack-handover is executable and the template exists"
  echo "$PASS passed, $FAIL failed"
  exit 1
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/ythandover.XXXXXX"); TMP=$(cd "$TMP" && pwd -P)
trap 'rm -rf "$TMP"' EXIT

N=0
# The stages of a fixture start below the template: its line k is line L+k of the script.
L=$(wc -l < "$TPL" | tr -d ' ')
# mk: a new script with a filled header and the stages from stdin. Sets P.
mk() {
  N=$((N + 1)); P="$TMP/s$N.sh"
  bash "$BIN" new "$P" --title "Test step $N" >/dev/null || return 1
  sed -e 's/^# Purpose:$/# Purpose: restart one deployment/' \
      -e 's/^# Prepared by:$/# Prepared by: test agent, for M001-S01-T01/' \
      -e 's/^# Changes:$/# Changes: one file under the temp directory/' \
      -e 's/^# Undo:$/# Undo: delete the file/' "$P" > "$P.tmp" && cat "$P.tmp" > "$P" && rm -f "$P.tmp"
  cat >> "$P"
}
# chk <script>: sets OUT (stdout + stderr) and EC
chk() { OUT=$(bash "$BIN" check "$1" 2>&1); EC=$?; }
# rejects <case> <text>: the stages on stdin fail the check, and it says <text>
rejects() {
  mk; chk "$P"
  if [ "$EC" = 1 ]; then has "$1" "$2" "$OUT"; else bad "$1" "exit $EC: $OUT"; fi
}
# receipt <script>: sets R (the receipt file), REC (its text) and DNR (its "Did not run" part)
receipt() {
  set -- "$1".receipt-*.txt
  R="$1"; REC=""; DNR=""
  [ -f "$R" ] || return 1
  REC=$(cat "$R")
  DNR=$(printf '%s\n' "$REC" | awk '/^Did not run:/ { on = 1; next } /^Ended:/ { on = 0 } on')
}

# ---- 1. new -------------------------------------------------------------------
echo "# new"
P="$TMP/new/dir/step.sh"
OUT=$(bash "$BIN" new "$P" --title "Rotate the signing key" 2>&1); EC=$?
eq "new writes the script" 0 "$EC"
eq "and prints its path" "$P" "$OUT"
if [ -x "$P" ]; then ok "the copy is executable"; else bad "the copy is executable"; fi
eq "the title is in the header" "# Handover: Rotate the signing key" "$(sed -n 2p "$P")"
case "$(grep '^# Prepared at:' "$P")" in
  "# Prepared at: 20"[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z) ok "the time of preparation is filled, in UTC" ;;
  *) bad "the time of preparation is filled, in UTC" "$(grep '^# Prepared at:' "$P")" ;;
esac
echo "keep me" > "$P"
OUT=$(bash "$BIN" new "$P" --title "Again" 2>&1); EC=$?
eq "an existing path is refused" 1 "$EC"
eq "and is not overwritten" "keep me" "$(cat "$P")"
bash "$BIN" new "$TMP/untitled.sh" >/dev/null 2>&1; eq "no title: exit 64" 64 "$?"
bash "$BIN" new "$TMP/inject.sh" --title "x
touch $TMP/injected" >/dev/null 2>&1
eq "a title with a line break stays one comment line" "$(wc -l < "$TPL" | tr -d ' ')" "$(wc -l < "$TMP/inject.sh" | tr -d ' ')"
bash "$BIN" publish >/dev/null 2>&1; eq "unknown command: exit 64" 64 "$?"

# ---- 2. check: a well-formed script --------------------------------------------
echo "# check: well-formed"
mk <<'EOF'
NS="shop-prod"
KUBECONFIG_FILE="/Users/someone/Projects/Infra2/clusters/Production-EU1/kubeconfig.yaml"

stage "Prove the target" "Reads the cluster and changes nothing."
check "the namespace exists" kubectl --kubeconfig "$KUBECONFIG_FILE" get namespace "$NS"
check "three pods run" bash -c 'kubectl get pods | grep -c Running'   # a pipe belongs inside the command

stage "Restart the checkout" "Restarts one deployment with sudo on the bastion."
confirm "Restart deployment checkout in $NS"
mutate "restart" sudo kubectl -n "$NS" rollout restart deployment checkout
check "the rollout finished" kubectl -n "$NS" rollout status deployment checkout

stage "Look at the shop" "A check by eye."
manual "Open the shop and place a test order"
EOF
chk "$P"
eq "a well-formed script passes" 0 "$EC"
eq "and its stages, mutations and manual steps are counted" "handover ok: 3 stages, 1 mutations, 1 manual steps" "$OUT"

mk <<'EOF'
stage "Look" "By eye."
manual "Open the page"
EOF
sed -e 's/^# Undo: .*/# Undo:/' "$P" > "$P.tmp" && cat "$P.tmp" > "$P"
awk '{ print } /^# Undo:$/ { print "#   1. the restart: nothing to undo"; print "#   2. the flag: set it back to off" }' "$P" > "$P.tmp" && cat "$P.tmp" > "$P"
chk "$P"
eq "a header field may continue on indented lines" "handover ok: 1 stages, 0 mutations, 1 manual steps" "$OUT"
bash "$BIN" check "$TMP/missing.sh" >/dev/null 2>&1; eq "an unreadable script: exit 64" 64 "$?"

# ---- 3. check: each rule on its own --------------------------------------------
echo "# check: defects"
rejects "a syntax error is named" "syntax: " <<'EOF'
stage "Look" "By eye."
manual "Open the page
EOF

mk <<'EOF'
stage "Change" "Creates one file."
confirm "Create the file"
mutate "create" touch /tmp/x
EOF
# shellcheck disable=SC2016
sed 's/"\$HO_CONFIRMED" -ne 1/1 -ne 1/' "$P" > "$P.tmp" && cat "$P.tmp" > "$P"
chk "$P"
eq "an edited helper block fails" 1 "$EC"
eq "and only that is reported" "helpers: the block between the two marker comments is missing or differs from skills/handover-step/template.sh" "$OUT"

rejects "a raw command at top level" "line $((L + 2)): raw command at top level" <<'EOF'
stage "Change" "Deletes one pod."
kubectl delete pod checkout-0
EOF
rejects "a command behind a variable is a raw command" "a variable in front of a command" <<'EOF'
stage "Change" "Creates one file."
FORCE=1 touch /tmp/x
EOF
rejects "a second marker pair hides nothing" "raw command at top level" <<'EOF'
stage "Look" "By eye."
# >>> ytstack-handover helpers >>>
touch /tmp/x
# <<< ytstack-handover helpers <<<
EOF
rejects "a chain after a helper call" "unquoted & at top level" <<'EOF'
stage "Look" "Reads only."
check "there" test -d /tmp && touch /tmp/x
EOF
rejects "a command substitution at top level" "command substitution runs before the helper sees it" <<'EOF'
TODAY="$(date +%F)"
stage "Look" "By eye."
manual "Open the page"
EOF
rejects "a call that continues on the next line" "runs past the end of the line" <<'EOF'
stage "Look" "Reads only."
check "there" test -d \
  /tmp
EOF
rejects "an assignment to a helper variable" "assignment to a variable of the helpers" <<'EOF'
stage "Change" "Creates one file."
HO_CONFIRMED=1
EOF
rejects "mutate before confirm" "line $((L + 2)): mutate without a confirm earlier in the same stage" <<'EOF'
stage "Change" "Creates one file."
mutate "create" touch /tmp/x
confirm "Create /tmp/x"
EOF
rejects "a confirm of an earlier stage does not carry over" "line $((L + 4)): mutate without a confirm earlier in the same stage" <<'EOF'
stage "Announce" "Asks."
confirm "Create /tmp/x"
stage "Change" "Creates one file."
mutate "create" touch /tmp/x
EOF
rejects "one confirm does not carry two mutates" "line $((L + 4)): a second mutate behind one confirm; every mutate takes a confirm of its own" <<'EOF'
stage "Change" "Creates two files."
confirm "Create /tmp/x"
mutate "create" touch /tmp/x
mutate "create another" touch /tmp/y
EOF
mk <<'EOF'
stage "Change" "Creates two files."
confirm "Create /tmp/x"
mutate "create" touch /tmp/x
check "it is there" test -f /tmp/x
confirm "Create /tmp/y"
mutate "create another" touch /tmp/y
EOF
chk "$P"
eq "two mutates, each behind its own confirm, pass" "handover ok: 1 stages, 2 mutations, 0 manual steps" "$OUT"
rejects "no stage" "no stage: a handover script has at least one" <<'EOF'
NS="shop-prod"
EOF
rejects "a call before the first stage" "manual before the first stage" <<'EOF'
manual "Open the page"
stage "Look" "By eye."
EOF
rejects "a confirm without a text" "confirm takes one text" <<'EOF'
stage "Change" "Creates one file."
confirm
EOF
rejects "a mutate without a command" "mutate takes a label and a command" <<'EOF'
stage "Change" "Creates one file."
confirm "Create the file"
mutate "create"
EOF
rejects "sudo that the stage does not announce" "line $((L + 3)): sudo, and the line of its stage does not say so" <<'EOF'
stage "Restart" "Restarts the web server."
confirm "Restart nginx on web-1"
mutate "restart" sudo systemctl restart nginx
EOF
rejects "a pipe into a shell" "pipe into a shell" <<'EOF'
stage "Install" "Installs the agent."
confirm "Install the agent on web-1"
mutate "install" bash -c 'curl -s https://example.com/install | sh'
EOF
rejects "rm -rf" "line $((L + 3)): rm -rf" <<'EOF'
stage "Clean" "Removes the cache."
confirm "Remove /var/cache/shop"
mutate "remove" rm -rf /var/cache/shop
EOF
rejects "eval" "line $((L + 2)): eval" <<'EOF'
stage "Look" "Reads only."
check "runs" eval "$CMD"
EOF
# Built here, so that no token-looking literal sits in this file.
B64=$(printf 'Ab1%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14)
HEX=$(printf 'a1%.0s' 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
rejects "a base64-looking string in an assignment" "line $((L + 1)): token-looking string in an assignment" <<EOF
API_KEY="$B64"
stage "Look" "By eye."
manual "Open the page"
EOF
hasnt "the token is not repeated in the report" "$B64" "$OUT"
rejects "a long hex run in an assignment" "token-looking string in an assignment" <<EOF
SECRET=$HEX
stage "Look" "By eye."
manual "Open the page"
EOF
mk <<'EOF'
stage "Look" "By eye."
manual "Open the page"
EOF
sed 's/^# Undo: .*/# Undo:/' "$P" > "$P.tmp" && cat "$P.tmp" > "$P"
chk "$P"
eq "an empty header field fails" 1 "$EC"
eq "and is named" "header: 'Undo:' is empty" "$OUT"

# ---- 4. runtime without a terminal ---------------------------------------------
echo "# runtime: no terminal"
MARK="$TMP/marker"
mk <<EOF
MARK="$MARK"
stage "Look" "Reads only."
check "the shell works" true
stage "Change" "Creates one file."
confirm "Create \$MARK"
mutate "create the file" touch "\$MARK"
check "it is there" test -f "\$MARK"
EOF
chk "$P"; eq "the fixture passes the check" 0 "$EC"
OUT=$(bash "$P" < /dev/null 2>&1); EC=$?
eq "confirm without a terminal stops the script" 1 "$EC"
if [ ! -e "$MARK" ]; then ok "the mutate did not run"; else bad "the mutate did not run"; fi
if receipt "$P"; then ok "a receipt file sits next to the script"; else bad "a receipt file sits next to the script" "$(ls "$TMP")"; fi
has "receipt: the title" "Handover receipt -- Test step $N" "$REC"
has "receipt: the start, in UTC" "Started: 20" "$REC"
has "receipt: the end, in UTC" "Ended:   20" "$REC"
has "receipt: the stage as written" "Stage 1 -- line $((L + 2)): stage \"Look\" \"Reads only.\"" "$REC"
has "receipt: the check that ran, with its exit code" "check    pass exit 0    line $((L + 3)): check \"the shell works\" true" "$REC"
has "receipt: the confirm got no answer" "confirm  no answer" "$REC"
has "receipt: where it stopped and why" "Result:  stopped in stage 2 at line $((L + 5)) -- confirm needs a person at a terminal" "$REC"
has "receipt: the mutate did not run, as written" "  line $((L + 6)): mutate \"create the file\" touch \"\$MARK\"" "$DNR"
has "receipt: nor the check after it" "  line $((L + 7)): check \"it is there\" test -f \"\$MARK\"" "$DNR"
hasnt "receipt: variable names, not their values" "$MARK" "$REC"
has "the receipt is shown on the terminal too" "Receipt file: $R" "$OUT"

mk <<'EOF'
stage "Look" "Reads only."
check "this one fails" false
check "never reached" true
EOF
OUT=$(bash "$P" < /dev/null 2>&1); EC=$?
eq "a failed check stops the script" 1 "$EC"
receipt "$P"
has "receipt: the failure with its exit code" "check    FAIL exit 1" "$REC"
has "receipt: nothing was changed in this stage" "a check failed (exit 1); nothing was changed in this stage" "$REC"
has "receipt: the check after it did not run" 'check "never reached" true' "$DNR"

mk <<EOF
stage "Change" "Creates one file."
mutate "create the file" touch "$MARK"
EOF
OUT=$(bash "$P" < /dev/null 2>&1); EC=$?
eq "a mutate without a confirm stops the script" 1 "$EC"
if [ ! -e "$MARK" ]; then ok "and does not run"; else bad "and does not run"; fi
receipt "$P"
has "receipt: the refusal" "mutate   refused" "$REC"

mk <<'EOF'
stage "Look" "Reads only."
check "the variable is set" test -n "$NOT_SET_ANYWHERE"
check "never reached" true
EOF
OUT=$(bash "$P" < /dev/null 2>&1); EC=$?
receipt "$P"
has "an unset variable ends the script with a receipt" "the shell ended the script" "$REC"
has "receipt: the call that died is listed as not run" 'check "the variable is set"' "$DNR"

OUT=$(bash < "$P" 2>&1); EC=$?
eq "a script piped into bash does not start" 1 "$EC"
has "and says how to start it" "start this file by its path" "$OUT"

# ---- 5. runtime with a pseudo terminal -----------------------------------------
# A person at a terminal, played by python3's pty module (the same on macOS and
# Linux; `script` takes different arguments on the two).
echo "# runtime: at a terminal"
# tty_run <script> <typed text>: sets EC
tty_run() {
  python3 - "$1" "$2" <<'PY'
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", sys.argv[1]])
os.write(fd, sys.argv[2].encode())
end = time.time() + 30
while time.time() < end:
    if not select.select([fd], [], [], 1)[0]:
        continue
    try:
        if not os.read(fd, 4096):
            break
    except OSError:
        break
else:
    os.kill(pid, 9)
status = os.waitpid(pid, 0)[1]
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 99)
PY
  EC=$?
}
if python3 -c 'import pty' >/dev/null 2>&1; then
  mk <<EOF
MARK="$MARK"
stage "Change" "Creates one file."
confirm "Create \$MARK"
mutate "create the file" touch "\$MARK"
stage "Look" "By eye."
manual "Look at the file"
manual "Look again"
EOF
  tty_run "$P" "yes
maybe
done
skip
"
  eq "yes, done and skip: the script completes" 0 "$EC"
  if [ -f "$MARK" ]; then ok "the confirmed mutate ran"; else bad "the confirmed mutate ran"; fi
  receipt "$P"
  has "receipt: the confirm" "confirm  yes" "$REC"
  has "receipt: the mutate with its exit code" "mutate   ok exit 0      line $((L + 4)): mutate \"create the file\" touch \"\$MARK\"" "$REC"
  has "receipt: the step done by hand" "manual   done           line $((L + 6)): manual \"Look at the file\"" "$REC"
  has "receipt: the skipped step" "manual   skipped        line $((L + 7)): manual \"Look again\"" "$REC"
  has "receipt: completed, with the skip counted" "Result:  completed, 1 step(s) by hand skipped" "$REC"
  eq "receipt: nothing was left" "  nothing" "$DNR"
  rm -f "$MARK"

  mk <<EOF
stage "Change" "Creates one file."
confirm "Create $MARK"
mutate "create the file" touch "$MARK"
EOF
  tty_run "$P" "y
"
  eq "anything but the full word stops the script" 1 "$EC"
  if [ ! -e "$MARK" ]; then ok "and the mutate does not run"; else bad "and the mutate does not run"; fi
  receipt "$P"
  has "receipt: declined" "confirm  declined" "$REC"

  mk <<EOF
stage "Change" "Fails on purpose."
confirm "Run a command that fails"
mutate "fails" false
confirm "Create $MARK"
mutate "create the file" touch "$MARK"
EOF
  tty_run "$P" "yes
"
  eq "a failed mutate stops the script" 1 "$EC"
  receipt "$P"
  has "receipt: the failed mutate with its exit code" "mutate   FAILED exit 1" "$REC"
  has "receipt: the mutate after it did not run" 'mutate "create the file"' "$DNR"

  # One yes carries one change. The file is not passed through `check` here:
  # the helpers have to refuse on their own when a script was never verified.
  mk <<EOF
stage "Change" "Creates two files."
confirm "Create $MARK"
mutate "create the file" touch "$MARK"
mutate "create a second file" touch "$MARK.2"
EOF
  tty_run "$P" "yes
"
  eq "a second mutate behind one confirm stops the script" 1 "$EC"
  if [ -f "$MARK" ] && [ ! -e "$MARK.2" ]; then ok "the first change ran, the second did not"; else bad "the first change ran, the second did not"; fi
  receipt "$P"
  has "receipt: the second mutate was refused" "mutate   refused        line $((L + 4)): mutate \"create a second file\"" "$REC"
  has "receipt: why it stopped" "a change without a confirm of its own in its stage is not run" "$REC"
  rm -f "$MARK" "$MARK.2"
else
  echo "  skip - python3 with the pty module is not available: the confirming path was not run"
fi

echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]

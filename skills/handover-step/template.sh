#!/usr/bin/env bash
# Handover: {{TITLE}}
#
# A step only a person may perform. An agent prepared this file and verified
# it without running it. You start it:   bash <path to this file>
# It asks before every change and leaves a receipt next to itself.
#
# Purpose:
# Prepared by:
# Prepared at: {{NOW}}
# Changes:
# Undo:

# >>> ytstack-handover helpers >>> do not edit this block: `ytstack-handover check` compares it with the template
set -u
HO_SELF="${BASH_SOURCE[0]:-}"
if [ ! -f "$HO_SELF" ]; then
  echo "handover: start this file by its path: bash <path to this file>" >&2
  exit 1
fi
HO_STAGE=0; HO_CONFIRMED=0; HO_CHANGED=0; HO_SKIPPED=0; HO_LINE=0; HO_RESULT=""; HO_REPLY=""
HO_RECEIPT="$HO_SELF.receipt-$(date -u +%Y%m%dT%H%M%SZ).txt"
if ! printf 'Handover receipt -- %s\nScript:  %s\nStarted: %s\n' "$(sed -n 's/^# Handover: //p' "$HO_SELF" | sed -n 1p)" \
  "$HO_SELF" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$HO_RECEIPT"; then
  echo "handover: cannot write the receipt $HO_RECEIPT; nothing was run" >&2
  exit 1
fi

# _ho_log <kind> <outcome>: one receipt line. The call is recorded as it is
# written in this file (variable names, not their values) and the output of a
# command is not recorded, so no secret reaches the receipt.
_ho_log() {
  printf '  %-8s %-14s line %s: %s\n' "$1" "$2" "$HO_LINE" "$(sed -n "${HO_LINE}p" "$HO_SELF")" >> "$HO_RECEIPT"
}
_ho_stop() {
  HO_RESULT="stopped in stage $HO_STAGE at line $HO_LINE -- $1"
  printf '\nSTOPPED: %s\n' "$1"
  exit 1
}
# _ho_ask: one line typed at the terminal, into HO_REPLY. Never read from
# stdin: a pipe or a file cannot answer, and without a terminal nobody did.
_ho_ask() {
  HO_REPLY=""
  [ -t 0 ] || return 1
  { read -r HO_REPLY < /dev/tty; } 2>/dev/null
}
# _ho_exit: the receipt, at every exit. What did not run is read from this
# file: every call below the line where the script ended.
_ho_exit() {
  local rc=$?
  trap - EXIT
  if [ -z "$HO_RESULT" ]; then
    if [ "$rc" -ne 0 ]; then HO_RESULT="stopped after line $HO_LINE -- the shell ended the script (exit $rc)"
    elif [ "$HO_SKIPPED" -gt 0 ]; then HO_RESULT="completed, $HO_SKIPPED step(s) by hand skipped"
    else HO_RESULT="completed"; fi
  fi
  {
    echo "Did not run:"
    awk -v from="$HO_LINE" '
      /^# <<< ytstack-handover helpers/ { on = 1; next }
      on && NR > from && /^[ \t]*(stage|check|confirm|mutate|manual)[ \t]/ { print "  line " NR ": " $0; n++ }
      END { if (!n) print "  nothing" }
    ' "$HO_SELF"
    echo "Ended:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Result:  $HO_RESULT"
  } >> "$HO_RECEIPT"
  printf '\n---------------- receipt ----------------\n'
  cat "$HO_RECEIPT"
  printf -- '-----------------------------------------\nReceipt file: %s\n' "$HO_RECEIPT"
}
trap _ho_exit EXIT
trap 'HO_RESULT="interrupted in stage $HO_STAGE at line $HO_LINE -- whether that call took effect is not known"; exit 130' INT TERM HUP

# stage "<title>" "<what happens in this stage, one sentence>"
stage() {
  HO_LINE=${BASH_LINENO[0]}; HO_STAGE=$((HO_STAGE + 1)); HO_CONFIRMED=0; HO_CHANGED=0
  printf '\n== Stage %s: %s ==\n%s\n' "$HO_STAGE" "$1" "$2"
  printf 'Stage %s -- line %s: %s\n' "$HO_STAGE" "$HO_LINE" "$(sed -n "${HO_LINE}p" "$HO_SELF")" >> "$HO_RECEIPT"
}
# check "<label>" <read-only command...>: a failure stops the script.
check() {
  local label="$1" rc; shift
  HO_LINE=${BASH_LINENO[0]}
  printf -- '-- check: %s\n' "$label"
  ( "$@" ); rc=$?
  if [ "$rc" -eq 0 ]; then printf '   pass\n'; _ho_log check "pass exit 0"; return 0; fi
  printf '   FAIL (exit %s)\n' "$rc"; _ho_log check "FAIL exit $rc"
  if [ "$HO_CHANGED" -eq 0 ]; then _ho_stop "a check failed (exit $rc); nothing was changed in this stage"; fi
  _ho_stop "a check failed (exit $rc) after $HO_CHANGED change(s) of this stage had run"
}
# confirm "<exactly what will be changed, and where>": only the word yes goes on.
confirm() {
  HO_LINE=${BASH_LINENO[0]}
  printf '\nABOUT TO CHANGE: %s\nType yes to go on, anything else stops: ' "$1"
  if ! _ho_ask; then _ho_log confirm "no answer"; _ho_stop "confirm needs a person at a terminal; nothing was confirmed"; fi
  if [ "$HO_REPLY" != yes ]; then _ho_log confirm "declined"; _ho_stop "not confirmed"; fi
  HO_CONFIRMED=1; _ho_log confirm "yes"
}
# mutate "<label>" <changing command...>: runs only after a confirm in this stage.
mutate() {
  local label="$1" rc; shift
  HO_LINE=${BASH_LINENO[0]}
  if [ "$HO_CONFIRMED" -ne 1 ]; then _ho_log mutate "refused"; _ho_stop "a change without a confirm in its stage is not run"; fi
  printf -- '-- change: %s\n' "$label"
  ( "$@" ); rc=$?
  HO_CHANGED=$((HO_CHANGED + 1))
  if [ "$rc" -ne 0 ]; then
    printf '   FAILED (exit %s)\n' "$rc"; _ho_log mutate "FAILED exit $rc"
    _ho_stop "a change failed (exit $rc); see Undo in the header of this file"
  fi
  printf '   done\n'; _ho_log mutate "ok exit 0"
}
# manual "<what to do by hand>": waits for the word done or skip.
manual() {
  HO_LINE=${BASH_LINENO[0]}
  printf '\nBY HAND: %s\n' "$1"
  while :; do
    printf 'Type done when it is done, or skip: '
    if ! _ho_ask; then _ho_log manual "no answer"; _ho_stop "a step by hand needs a person at a terminal"; fi
    case "$HO_REPLY" in
      "done") _ho_log manual "done"; return 0 ;;
      "skip") HO_SKIPPED=$((HO_SKIPPED + 1)); _ho_log manual "skipped"; return 0 ;;
    esac
  done
}
# <<< ytstack-handover helpers <<<

# One call per line, nothing else at top level (plain assignments and comments are fine):
#   stage   "<title>" "<what happens in this stage, one sentence>"
#   check   "<label>" <read-only command...>
#   confirm "<exactly what will be changed, and where>"
#   mutate  "<label>" <the changing command...>
#   manual  "<what to do by hand>"

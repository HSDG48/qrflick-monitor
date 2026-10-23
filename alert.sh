#!/usr/bin/env bash
# Turns one run's results into alerts. A check alerts only after failing in
# 2 consecutive runs; the per-check streak is kept in state/streaks (restored
# from the previous run's cache). Alert = one open issue labelled monitor-alert,
# which GitHub emails to the repo owner; it is commented on and closed on recovery.
# Needs GH_TOKEN and GH_REPO.
set -euo pipefail

RESULTS="$1"
THRESHOLD=2
LABEL="monitor-alert"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GH_REPO}/actions/runs/${GITHUB_RUN_ID:-0}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

mkdir -p state
touch state/streaks
declare -A prev=()
while read -r n c; do [[ -n "${n:-}" ]] && prev[$n]=$c; done < state/streaks

: > state/streaks.new
alerting=()
any_fail=0
while read -r name verdict detail; do
  if [[ "$verdict" == "FAIL" ]]; then
    any_fail=1
    count=$(( ${prev[$name]:-0} + 1 ))
  else
    count=0
  fi
  echo "$name $count" >> state/streaks.new
  if (( count >= THRESHOLD )); then
    alerting+=("- **$name** (failed $count runs in a row): $detail")
  fi
done < "$RESULTS"
mv state/streaks.new state/streaks

{
  echo "### QRflick monitor"
  echo '```'
  cat "$RESULTS"
  echo '```'
  echo "Failure streaks: $(tr '\n' ' ' < state/streaks)"
} >> "$SUMMARY"

open=$(gh issue list --label "$LABEL" --state open --json number --jq '.[0].number // empty')

if (( ${#alerting[@]} > 0 )); then
  if [[ -z "$open" ]]; then
    gh label create "$LABEL" --color B60205 --description "QRflick monitor alert" --force >/dev/null
    body=$(printf 'QRflick checks are failing (2+ consecutive runs).\n\n%s\n\nFull results:\n```\n%s\n```\nRun: %s\n\nThis issue closes itself when every check passes again.' \
      "$(printf '%s\n' "${alerting[@]}")" "$(cat "$RESULTS")" "$RUN_URL")
    gh issue create --title "QRflick monitor: checks failing" --label "$LABEL" --body "$body"
    echo "Alert raised." >> "$SUMMARY"
  else
    echo "Alert already open: #$open" >> "$SUMMARY"
  fi
elif [[ -n "$open" && "$any_fail" == 0 ]]; then
  gh issue comment "$open" --body "Recovered: every check passed at $(date -u '+%Y-%m-%d %H:%M UTC'). Run: $RUN_URL"
  gh issue close "$open"
  echo "Recovered, closed #$open." >> "$SUMMARY"
fi

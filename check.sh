#!/usr/bin/env bash
# Runs every check in checks.conf once and prints one line per check:
#   <name> OK|FAIL <detail>
# Exit code: 0 when all pass, 1 when any fail.
# SIMULATE_FAILURE=<name> replaces that check's expectation with a wrong one (alert drill).
set -uo pipefail

CONF="${1:-checks.conf}"
UA="QRflickUptimeBot/1.0 (+https://github.com/HSDG48/qrflick-monitor)"
failed=0

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

while IFS='|' read -r name method url status expect max; do
  name=$(trim "$name")
  [[ -z "$name" || "$name" == \#* ]] && continue
  method=$(trim "$method"); url=$(trim "$url"); status=$(trim "$status")
  expect=$(trim "$expect"); max=$(trim "$max")
  if [[ "${SIMULATE_FAILURE:-}" == "$name" ]]; then
    expect="location=https://wrong.example/simulated-failure"
  fi

  headers=$(mktemp); body=$(mktemp)
  if [[ "$method" == "HEAD" ]]; then
    meta=$(curl -sS -I -m 15 -A "$UA" -o "$headers" -w '%{http_code} %{time_total}' "$url" 2>&1)
  else
    meta=$(curl -sS -m 15 -A "$UA" -D "$headers" -o "$body" -w '%{http_code} %{time_total}' "$url" 2>&1)
  fi
  code=${meta%% *}; secs=${meta##* }

  problem=""
  if [[ ! "$code" =~ ^[0-9]{3}$ ]]; then
    problem="request error: $meta"
  elif [[ "$code" != "$status" ]]; then
    problem="status $code, expected $status"
  elif [[ "$expect" == location=* ]]; then
    got=$(grep -i '^location:' "$headers" | head -1 | cut -d' ' -f2- | tr -d '\r')
    [[ "$got" != "${expect#location=}" ]] && problem="Location '$got', expected '${expect#location=}'"
  elif [[ "$expect" == body=* ]]; then
    grep -qF "${expect#body=}" "$body" || problem="page is missing '${expect#body=}'"
  fi
  if [[ -z "$problem" ]] && awk -v t="$secs" -v m="$max" 'BEGIN { exit !(t > m) }'; then
    problem="slow: ${secs}s, limit ${max}s"
  fi
  rm -f "$headers" "$body"

  if [[ -n "$problem" ]]; then
    echo "$name FAIL $url: $problem"
    failed=1
  else
    echo "$name OK ${code} in ${secs}s"
  fi
done < "$CONF"

exit "$failed"

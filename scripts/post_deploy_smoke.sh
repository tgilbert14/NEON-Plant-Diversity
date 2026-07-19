#!/usr/bin/env bash

# Cold-start-aware semantic production check. Posit host error pages can return
# HTTP 200, so the Connect response must contain the appStatus readiness shell.

set -uo pipefail

MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-10}"
SLEEP_BASE="${SMOKE_SLEEP_BASE:-5}"
CONNECT_TIMEOUT="${SMOKE_CONNECT_TIMEOUT:-15}"
MAX_TIME="${SMOKE_MAX_TIME:-45}"
TOTAL_DEADLINE="${SMOKE_TOTAL_DEADLINE:-780}"
APP_MARKER="${SMOKE_APP_MARKER:-id=\"appStatus\"}"
COVER_MARKER="${SMOKE_COVER_MARKER:-NEON Plant Diversity Explorer}"
failed=0
deadline_at=$((SECONDS + TOTAL_DEADLINE))

check_release_receipt() {
  local label="$1" url="$2" expected="" path="" body code actual remaining request_max
  if [[ "$label" == *"app" ]]; then
    expected="${SMOKE_APP_RECEIPT:-}"
    path="runtime-receipt.txt"
  else
    expected="${SMOKE_COVER_RECEIPT:-}"
    path="cover-receipt.txt"
  fi
  if [[ -z "$expected" ]]; then
    if [[ "${SMOKE_REQUIRE_RECEIPTS:-0}" == "1" ]]; then
      echo "DOWN [$label] expected release receipt was not configured"
      return 1
    fi
    return 0
  fi
  remaining=$((deadline_at - SECONDS))
  if ((remaining <= 0)); then
    echo "DOWN [$label] shared smoke deadline elapsed before release-receipt verification"
    return 1
  fi
  request_max=$MAX_TIME
  ((request_max > remaining)) && request_max=$remaining
  body=$(mktemp)
  code=$(curl -sS -o "$body" -w '%{http_code}' -L \
    --connect-timeout "$CONNECT_TIMEOUT" --max-time "$request_max" \
    -A 'ddl-plant-diversity-semantic-smoke/1.0' "${url%/}/$path" 2>/dev/null || echo "000")
  actual=$(tr -d '\r\n' < "$body")
  rm -f "$body"
  if [[ ! "$code" =~ ^(2|3)[0-9][0-9]$ || "$actual" != "$expected" ]]; then
    echo "DOWN [$label] release receipt does not match the promoted candidate"
    return 1
  fi
  echo "ok [$label] exact release receipt $expected"
}

check_browser_ready() {
  local label="$1" url="$2" driver="" target browser_timeout remaining
  driver=$(command -v chromedriver || true)
  if [[ -z "$driver" ]]; then
    echo "DOWN [$label] semantic browser requested but ChromeDriver is unavailable"
    return 1
  fi
  target="${url%/}/?site=${SMOKE_SITE:-SRER}"
  remaining=$((deadline_at - SECONDS))
  browser_timeout="${SMOKE_BROWSER_TIMEOUT:-150}"
  ((browser_timeout > remaining)) && browser_timeout=$remaining
  if ((browser_timeout <= 0)); then
    echo "DOWN [$label] shared smoke deadline elapsed before browser readiness"
    return 1
  fi
  python3 scripts/chromedriver_semantic_smoke.py \
    --url "$target" \
    --site "${SMOKE_SITE:-SRER}" \
    --timeout "$browser_timeout" \
    --driver "$driver"
}

check_one() {
  local label="$1" url="$2" body attempt code nap marker remaining request_max
  body=$(mktemp)
  marker="$COVER_MARKER"
  [[ "$label" == *"app"* ]] && marker="$APP_MARKER"

  for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
    remaining=$((deadline_at - SECONDS))
    if ((remaining <= 0)); then
      echo "wait [$label] shared smoke deadline elapsed"
      break
    fi
    request_max=$MAX_TIME
    ((request_max > remaining)) && request_max=$remaining
    code=$(curl -sS -o "$body" -w '%{http_code}' -L \
      --connect-timeout "$CONNECT_TIMEOUT" --max-time "$request_max" \
      -A 'ddl-plant-diversity-semantic-smoke/1.0' "$url" 2>/dev/null || echo "000")
    if [[ "$code" =~ ^(2|3)[0-9][0-9]$ ]]; then
      if grep -Eqi 'startup error|application failed to start|application error|service unavailable' "$body"; then
        echo "wait [$label] HTTP $code but host error page detected ($attempt/$MAX_ATTEMPTS)"
      elif ! grep -Fq "$marker" "$body"; then
        echo "wait [$label] HTTP $code but semantic marker is absent ($attempt/$MAX_ATTEMPTS)"
      else
        echo "ok [$label] HTTP $code + application shell marker (attempt $attempt)"
        if ! check_release_receipt "$label" "$url"; then
          echo "wait [$label] shell is live but the exact promoted receipt is not yet published ($attempt/$MAX_ATTEMPTS)"
        elif [[ "$label" == *"app" && "${SMOKE_BROWSER:-0}" == "1" ]]; then
          if check_browser_ready "$label" "$url"; then
            rm -f "$body"
            return 0
          fi
          echo "wait [$label] application shell is live but browser readiness is not yet complete ($attempt/$MAX_ATTEMPTS)"
        else
          rm -f "$body"
          return 0
        fi
      fi
    else
      echo "wait [$label] HTTP $code ($attempt/$MAX_ATTEMPTS)"
    fi
    ((attempt >= MAX_ATTEMPTS)) && break
    remaining=$((deadline_at - SECONDS))
    ((remaining <= 1)) && break
    nap=$((SLEEP_BASE * attempt))
    ((nap > 40)) && nap=40
    ((nap >= remaining)) && nap=$((remaining - 1))
    ((nap > 0)) && sleep "$nap"
  done
  rm -f "$body"
  echo "DOWN [$label] semantic health not reached"
  return 1
}

if [[ $# -eq 0 ]]; then
  echo "usage: $0 '<label>=<url>' ..." >&2
  exit 2
fi

for spec in "$@"; do
  label="${spec%%=*}"
  url="${spec#*=}"
  if [[ -z "$label" || -z "$url" || "$url" == "$spec" ]]; then
    echo "invalid smoke target: $spec" >&2
    exit 2
  fi
  if ! check_one "$label" "$url"; then failed=1; fi
done

if [[ "$failed" -ne 0 ]]; then
  echo "post-deploy semantic smoke FAILED" >&2
  exit 1
fi
echo "post-deploy semantic smoke PASSED"

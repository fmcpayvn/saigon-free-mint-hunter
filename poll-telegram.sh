#!/usr/bin/env bash
# poll-telegram.sh — standalone watcher for free-mint alerts.
# Polls the public Telegram channel page for @agentidmintalerts every 5 seconds
# and prints new posts whose text contains "free" (case-insensitive).
# No API token, no login, no dependencies beyond curl + grep.
# State lives in $STATE_FILE (default: ./agentidmintalerts_last.txt).
set -u
CHANNEL="${CHANNEL:-agentidmintalerts}"
INTERVAL="${INTERVAL:-5}"
STATE_FILE="${STATE_FILE:-./agentidmintalerts_last.txt}"
KEYWORD="${KEYWORD:-free}"

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*"; }

if [ ! -f "$STATE_FILE" ]; then
  echo "0" > "$STATE_FILE"
fi

while true; do
  PAGE="$(curl --fail --silent --show-error --max-time 15 "https://t.me/s/${CHANNEL}" || true)"
  if [ -z "$PAGE" ]; then
    log "telegram fetch failed, retrying in ${INTERVAL}s"
    sleep "$INTERVAL"
    continue
  fi
  MAX_ID="$(printf '%s' "$PAGE" | grep -oE "data-post=\"${CHANNEL}/[0-9]+\"" | grep -oE '[0-9]+' | sort -n | tail -1 || true)"
  LAST="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
  if [ -n "$MAX_ID" ] && [ "$MAX_ID" -gt "$LAST" ]; then
    echo "$MAX_ID" > "$STATE_FILE"
    POST_TEXT="$(printf '%s' "$PAGE" | grep -oiE 'free[^<]{0,200}' | head -1 || true)"
    if printf '%s' "$PAGE" | grep -qi "$KEYWORD"; then
      log "NEW POST #${MAX_ID} (was ${LAST}) — keyword '${KEYWORD}' present: ${POST_TEXT}"
      log "ACTION: run recon — node recon.js <url> --contract <address>"
    else
      log "new post #${MAX_ID} (was ${LAST}) — no keyword, skipped"
    fi
  fi
  sleep "$INTERVAL"
done

#!/usr/bin/env bash
#
# Measures the free tier spin-down behaviour of the Render service:
#   - warm latency over 5 consecutive requests
#   - three cold starts, each after 21 minutes without traffic
#   - whether a note written before the first spin-down survives
#
# The service spins down after 15 idle minutes, so each wait is 21.
# The whole run takes a little over an hour. Output: cloud/latency.txt
set -uo pipefail

URL="https://quicknotes-0-1-0.onrender.com"
OUT="cloud/latency.txt"
IDLE=1260

log() { echo "$*" | tee -a "$OUT"; }

: > "$OUT"
log "target:  $URL"
log "started: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
log ""

log "== warm, 5 consecutive requests to /health =="
for i in 1 2 3 4 5; do
  t=$(curl -s -o /dev/null -w '%{time_total}' "$URL/health")
  log "  warm $i: ${t}s"
done
log ""

log "== write a note, then let the service spin down =="
created=$(curl -s -X POST -H 'Content-Type: application/json' \
  -d '{"title":"before spin down","body":"does this survive"}' "$URL/notes")
log "  POST /notes -> $created"
log "  present now: $(curl -s "$URL/notes" | grep -c 'before spin down') (1 = yes, 0 = no)"
log ""

for n in 1 2 3; do
  log "== idle ${IDLE}s, then cold request #$n =="
  sleep "$IDLE"
  log "  waking at $(date -u '+%H:%M:%SZ')"
  t=$(curl -s -o /dev/null -w '%{time_total}' "$URL/health")
  log "  cold $n:        ${t}s"
  log "  health:         $(curl -s "$URL/health")"
  log "  note survived:  $(curl -s "$URL/notes" | grep -c 'before spin down') (1 = yes, 0 = no)"
  log ""
done

log "finished: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"

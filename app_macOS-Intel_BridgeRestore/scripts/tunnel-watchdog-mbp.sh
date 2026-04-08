#!/bin/bash
# tunnel-watchdog-mbp.sh — MBP side tunnel monitor
# Watches port 2222. When tunnel-pro opens it from the mini, auto-runs tunnel-mini.
# VERSION: v1.0.4-alpha (Build 26A05)
HOST="[MacBook-Pro-i9]"
LOG="$HOME/Library/Logs/BridgeRestore/tunnel-watchdog-mbp.log"
mkdir -p "$HOME/Library/Logs/BridgeRestore"
TS()  { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $HOST $*" | tee -a "$LOG"; }

log "=== tunnel-watchdog-mbp starting ==="
LAST_STATE="unknown"

while true; do
  # Primary check: is tunnel port open?
  nc -z -G 3 localhost 2222 2>/dev/null && PORT_STATE="OPEN" || PORT_STATE="CLOSED"
  # Secondary: is bridge0 at correct IP?
  BRIDGE_IP=$(ipconfig getifaddr bridge0 2>/dev/null)
  [[ "$BRIDGE_IP" == "192.168.2.1" ]] && BRIDGE_OK="OK" || BRIDGE_OK="WRONG:${BRIDGE_IP:-NONE}"
  # IS still running?
  IS_PID=$(pgrep -f InternetSharing | head -1)

  STATE="${PORT_STATE}"

  if [[ "$STATE" != "$LAST_STATE" ]]; then
    log "port 2222: $LAST_STATE → $STATE | bridge0:$BRIDGE_OK | IS:${IS_PID:-DOWN}"

    if [[ "$STATE" == "OPEN" ]]; then
      # Check we don't already have an active tunnel session
      if ! ssh -O check macmini 2>/dev/null | grep -q "master running"; then
        log "Tunnel port opened — running tunnel-mini"
        /usr/local/bin/tunnel-mini >> "$LOG" 2>&1 &
        osascript -e 'display notification "Tunnel port 2222 opened — tunnel-mini starting" with title "Bridge Watchdog"' 2>/dev/null
      else
        log "Port open, ControlMaster already active — skipping tunnel-mini"
      fi
    fi

    if [[ "$STATE" == "CLOSED" ]]; then
      log "Tunnel port closed — waiting for mini to reconnect"
      osascript -e 'display notification "Tunnel port 2222 closed — waiting for mini" with title "Bridge Watchdog"' 2>/dev/null
    fi

    if [[ -z "$IS_PID" ]]; then
      log "WARN: IS not running — open System Settings → General → Sharing"
      osascript -e 'display notification "Internet Sharing is DOWN — open Sharing settings" with title "Bridge Watchdog" sound name "Basso"' 2>/dev/null
    fi

    LAST_STATE="$STATE"
  fi

  sleep 8
done

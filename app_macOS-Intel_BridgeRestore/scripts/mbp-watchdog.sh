#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  mbp-watchdog.sh — MBP SIDE ONLY (MacBookPro16,1)                      ║
# ║  Managed by local.mbp-watchdog.plist (installed by install-on-mbp.sh)  ║
# ║                                                                          ║
# ║  Every 20 s:                                                             ║
# ║    1. Verify bridge0 = 192.168.2.1 (fix if wrong)                       ║
# ║    2. Check if port 2222 is open (mini tunnel is up)                     ║
# ║    3. Check if ControlMaster is alive (ssh -O check macmini)             ║
# ║    4. If port open but CM dead → auto-run tunnel-mini.sh                 ║
# ║    5. macOS notifications on connect / disconnect / persistent fail      ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Identity guard ────────────────────────────────────────────────────────────
_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
_MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
if [[ "$_UUID" != "$_MBP_UUID" ]]; then
  echo "❌ mbp-watchdog.sh is MBP-only. This machine: $_MODEL"
  exit 1
fi

# ── Config ────────────────────────────────────────────────────────────────────
GATEWAY_IP="192.168.2.1"
TUNNEL_PORT=2222
SSH_KEY="$HOME/.ssh/id_ed25519"
CM_PATH="$HOME/.ssh/cm/macmini"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$APP_DIR/scripts"
LOG="$HOME/Library/Logs/BridgeRestore/mbp-watchdog.log"
INTERVAL=20
FAIL_NOTIFY_THRESHOLD=5

mkdir -p "$HOME/logs" "$HOME/.ssh/cm"

DT()     { date '+%H:%M %d/%m/%y'; }
TS()     { date '+%Y-%m-%d %H:%M:%S'; }
log()    { echo "[$(TS)] $*" >> "$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"Bridge Restore\"" 2>/dev/null || true; }

# ── Checks ────────────────────────────────────────────────────────────────────
cm_alive() {
  ssh -o ControlPath="$CM_PATH" -o BatchMode=yes -o ConnectTimeout=4 \
    -o StrictHostKeyChecking=no -p "$TUNNEL_PORT" akmacks@localhost \
    "echo ok" 2>/dev/null | grep -q "ok"
}

port_open() {
  nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null
}

fix_bridge() {
  local CURR; CURR=$(ipconfig getifaddr bridge0 2>/dev/null)
  if [[ "$CURR" != "$GATEWAY_IP" ]]; then
    sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null && \
      log "bridge0 restored to $GATEWAY_IP (was ${CURR:-NONE})"
  fi
}

# ── Main loop ─────────────────────────────────────────────────────────────────
log "=== mbp-watchdog starting | INTERVAL=${INTERVAL}s | $_MODEL ==="

LAST_STATE=""
FAIL_COUNT=0

while true; do
  fix_bridge

  if port_open; then
    if cm_alive; then
      if [[ "$LAST_STATE" != "UP" ]]; then
        MINI_HOST=$(ssh -o ControlPath="$CM_PATH" -p "$TUNNEL_PORT" \
          -o BatchMode=yes -o ConnectTimeout=3 akmacks@localhost "hostname" 2>/dev/null)
        log "CONNECTED → ${MINI_HOST:-mini} via localhost:$TUNNEL_PORT"
        notify "🔗 [$(DT)] Mini connected: ${MINI_HOST:-mini}"
        LAST_STATE="UP"
        FAIL_COUNT=0
      fi

    else
      # Port open but CM dead — mini connected but ControlMaster stale
      log "Port $TUNNEL_PORT open but ControlMaster dead — rebuilding"
      notify "🔄 [$(DT)] Reconnecting to mini..."
      ssh -O exit macmini 2>/dev/null || true
      sleep 1
      bash "$SCRIPTS_DIR/tunnel-mini.sh" >> "$LOG" 2>&1
      sleep 4

      if cm_alive; then
        MINI_HOST=$(ssh -o ControlPath="$CM_PATH" -p "$TUNNEL_PORT" \
          -o BatchMode=yes -o ConnectTimeout=3 akmacks@localhost "hostname" 2>/dev/null)
        log "ControlMaster restored → ${MINI_HOST:-mini} ✓"
        notify "✅ [$(DT)] Re-connected: ${MINI_HOST:-mini}"
        LAST_STATE="UP"
        FAIL_COUNT=0
      else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        log "WARN: tunnel-mini.sh ran but CM still dead (fail #$FAIL_COUNT)"
        if [[ "$FAIL_COUNT" -ge "$FAIL_NOTIFY_THRESHOLD" ]]; then
          notify "⚠️ [$(DT)] Tunnel failing ($FAIL_COUNT times) — run bridge-restore --diag"
          FAIL_COUNT=0
        fi
        LAST_STATE="FAIL"
      fi
    fi

  else
    # Port not open — mini tunnel not up yet
    if [[ "$LAST_STATE" == "UP" ]]; then
      log "Mini disconnected (port $TUNNEL_PORT closed)"
      notify "🔴 [$(DT)] Mini tunnel closed"
      LAST_STATE="DOWN"
    elif [[ -z "$LAST_STATE" ]]; then
      log "Waiting for mini to open tunnel on port $TUNNEL_PORT..."
      LAST_STATE="DOWN"
    fi
  fi

  sleep "$INTERVAL"
done

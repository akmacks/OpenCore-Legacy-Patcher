#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  MINI BRIDGE WATCHDOG  v1.0.3 (Build 26A07)                             ║
# ║  app_macOS-Intel_BridgeRestore — CLIENT SIDE ONLY                       ║
# ║                                                                          ║
# ║  Self-healing launchd watchdog for Mac mini (Macmini5,3).               ║
# ║  Monitors bridge0 state and restores IP/ARP without touching en2.        ║
# ║                                                                          ║
# ║  CRITICAL RULES:                                                         ║
# ║  1. Never bounce en2 — tears down XDomain TB session (10+ s outage)     ║
# ║  2. Never bounce bridge0 — unnecessary if IP can be assigned directly    ║
# ║  3. ARP EHOSTDOWN fix: clear stale ARP for gateway, let it re-resolve   ║
# ║                                                                          ║
# ║  Recovery sequence:                                                      ║
# ║    1. Restore bridge0 IP (192.168.2.2) if drifted — non-destructive     ║
# ║    2. Kill APIPA probe loop on en0 if present                           ║
# ║    3. If gateway unreachable: clear EHOSTDOWN ARP, re-probe             ║
# ║    4. Restart tunnel-pro if not running                                  ║
# ║    5. Log drop events with count for diagnosis                           ║
# ║                                                                          ║
# ║  Deploy from MBP: bash scripts/install-mini-watchdog.sh                 ║
# ║  Logs:   ~/Library/Logs/BridgeRestore/mini-watchdog.log                 ║
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Identity guard — CLIENT ONLY ──────────────────────────────────────────
MY_UUID=$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | \
          awk -F'"' '/IOPlatformUUID/{print $4}')
GATEWAY_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
if [[ "$MY_UUID" == "$GATEWAY_UUID" ]]; then
  echo "[mini-watchdog] ERROR: running on GATEWAY — this script is CLIENT only. Exiting." >&2
  exit 1
fi

# ── Config ────────────────────────────────────────────────────────────────
CLIENT_IP="192.168.2.2"
GATEWAY_IP="192.168.2.1"
GATEWAY_MAC="82:93:89:41:c8:04"   # MBP en4 MAC — direct TB interface
TUNNEL_PORT="2222"
TUNNEL_SCRIPT="$HOME/scripts/tunnel-pro.sh"
LOG_DIR="$HOME/Library/Logs/BridgeRestore"
LOG="$LOG_DIR/mini-watchdog.log"
STATE_FILE="$HOME/.config/bridge-restore/watchdog.state"
MAX_LOG_LINES=2000

# ── Setup ─────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$(dirname "$STATE_FILE")"
touch "$LOG" "$STATE_FILE"

# Trim log if too large
LINE_COUNT=$(wc -l < "$LOG" 2>/dev/null || echo 0)
if (( LINE_COUNT > MAX_LOG_LINES )); then
  tail -$((MAX_LOG_LINES / 2)) "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

# ── Helpers ───────────────────────────────────────────────────────────────
log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [mini-watchdog] $*"
  echo "$msg" >> "$LOG"
}

state_get() { grep "^$1=" "$STATE_FILE" 2>/dev/null | cut -d= -f2 || echo "${2:-0}"; }
state_set() {
  grep -v "^$1=" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null
  echo "$1=$2" >> "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

bridge0_ip() {
  ifconfig bridge0 2>/dev/null | awk '/inet /{print $2}' | head -1
}

bridge0_status() {
  ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}' | head -1
}

tunnel_alive() {
  pgrep -f "ssh.*-R ${TUNNEL_PORT}" > /dev/null 2>&1
}

gateway_reachable() {
  # Real L1/L2 liveness check. bridge0 retains its IP even when the physical
  # TB link is dead. Ping the MBP gateway to prove the link carries traffic.
  ping -c 2 -W 1000 -q "$GATEWAY_IP" > /dev/null 2>&1
}

# ── Non-destructive IP restore ─────────────────────────────────────────────
# SAFE: only touches bridge0 IP assignment, never bounces en2 or bridge0.
restore_bridge0_ip() {
  local curr; curr=$(bridge0_ip)
  if [[ "$curr" != "$CLIENT_IP" ]]; then
    log "bridge0 IP wrong (${curr:-none}) — restoring $CLIENT_IP"
    sudo ifconfig bridge0 "$CLIENT_IP" netmask 255.255.255.0 2>/dev/null && \
      log "bridge0 IP restored ✓" || log "WARN: bridge0 IP restore failed"
    sleep 1
  fi
}

kill_apipa_loop() {
  # BCM5722 Ethernet (en0) with APIPA 169.254.x.x causes configd probe loop
  # every ~30s that disturbs bridge0 — disable service to stop it
  local APIPA; APIPA=$(ifconfig en0 2>/dev/null | grep "inet 169\.254")
  if [[ -n "$APIPA" ]]; then
    log "APIPA detected on en0 — disabling Ethernet to stop configd probe loop"
    sudo networksetup -setnetworkserviceenabled "Ethernet" off 2>/dev/null && \
      log "Ethernet disabled ✓" || log "WARN: could not disable Ethernet"
  fi
}

# ── ARP EHOSTDOWN recovery ─────────────────────────────────────────────────
# When macOS repeatedly fails to ARP for a host, it marks the IP as EHOSTDOWN.
# Subsequent sendto() calls fail immediately — even ARP is suppressed.
# Fix: delete the stale entry and seed a static ARP entry for the gateway.
# Static ARP bypasses ARP resolution entirely, so EHOSTDOWN can't block it.
recover_gateway_arp() {
  log "ARP recovery: clearing EHOSTDOWN state for $GATEWAY_IP"
  sudo arp -d "$GATEWAY_IP" 2>/dev/null || true
  # Seed static ARP — bypasses dynamic ARP resolver entirely.
  # GATEWAY_MAC is MBP's en4 MAC (direct TB interface, fixed MAC).
  sudo arp -s "$GATEWAY_IP" "$GATEWAY_MAC" 2>/dev/null || true
  log "ARP seeded: $GATEWAY_IP → $GATEWAY_MAC (static)"
  sleep 2
}

restart_tunnel_pro() {
  pkill -f "ssh.*-R ${TUNNEL_PORT}" 2>/dev/null
  sleep 2
  if [[ -x "$TUNNEL_SCRIPT" ]]; then
    log "Restarting tunnel-pro..."
    nohup bash "$TUNNEL_SCRIPT" >> "$LOG" 2>&1 &
    sleep 5
    if tunnel_alive; then
      log "tunnel-pro restarted ✓ (PID $(pgrep -f "ssh.*-R ${TUNNEL_PORT}" | head -1))"
      return 0
    else
      log "WARN: tunnel-pro failed to start — MBP may be unreachable"
      return 1
    fi
  else
    log "WARN: $TUNNEL_SCRIPT not found or not executable"
    return 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────
LAST_STATE=$(state_get "BRIDGE_STATE" "unknown")
DROP_COUNT=$(state_get "DROP_COUNT" "0")
CONSECUTIVE_FAIL=$(state_get "CONSECUTIVE_FAIL" "0")

# Always kill APIPA loop regardless of bridge state
kill_apipa_loop

# Step 1: Ensure bridge0 has the right IP (safe, instant, non-destructive)
restore_bridge0_ip

# Step 2: Check real gateway reachability
CURRENT_IP=$(bridge0_ip)
CURRENT_STATUS=$(bridge0_status)

if [[ "$CURRENT_IP" == "$CLIENT_IP" ]] && gateway_reachable; then
  # ── Healthy ─────────────────────────────────────────────────────────────
  if [[ "$LAST_STATE" != "ok" ]]; then
    log "Bridge RECOVERED — IP=$CURRENT_IP status=$CURRENT_STATUS gateway=reachable ✓"
    state_set "BRIDGE_STATE" "ok"
    state_set "CONSECUTIVE_FAIL" "0"
    state_set "LAST_OK" "$(date +%s)"
  fi

  # Ensure static ARP for gateway stays seeded (prevents EHOSTDOWN buildup)
  ARP_ENTRY=$(arp -n "$GATEWAY_IP" 2>/dev/null | grep "$GATEWAY_MAC" | grep permanent)
  if [[ -z "$ARP_ENTRY" ]]; then
    sudo arp -s "$GATEWAY_IP" "$GATEWAY_MAC" 2>/dev/null || true
  fi

  # Keep tunnel alive even when bridge is healthy
  if ! tunnel_alive; then
    log "Bridge OK but tunnel-pro not running — restarting"
    restart_tunnel_pro
  fi

  exit 0
fi

# ── Not healthy: gateway unreachable (may be ARP EHOSTDOWN or real L1 dead)
DROP_COUNT=$(( DROP_COUNT + 1 ))
CONSECUTIVE_FAIL=$(( CONSECUTIVE_FAIL + 1 ))
state_set "DROP_COUNT" "$DROP_COUNT"
state_set "CONSECUTIVE_FAIL" "$CONSECUTIVE_FAIL"
state_set "BRIDGE_STATE" "down"
state_set "LAST_DROP" "$(date +%s)"

log "━━━ BRIDGE DOWN #${DROP_COUNT} | status=${CURRENT_STATUS:-?} ip=${CURRENT_IP:-none} | consecutive=${CONSECUTIVE_FAIL} ━━━"

# Step 3: ARP recovery — clear EHOSTDOWN and seed static gateway ARP.
# This self-heals without cable replug when the XDomain TX path is intact.
recover_gateway_arp
sleep 3
if gateway_reachable; then
  log "ARP recovery WORKED — gateway now reachable without cable replug ✓"
  state_set "BRIDGE_STATE" "ok"
  state_set "CONSECUTIVE_FAIL" "0"
  restart_tunnel_pro
  exit 0
fi

# Step 4: Still failing — log defeat, physical replug may be needed
log "FAIL: ARP recovery did not restore gateway — drop #${DROP_COUNT}, consecutive=${CONSECUTIVE_FAIL}"
log "INFO: physical TB cable replug will reset XDomain and clear ARP state"
log "INFO: MBP mbp-tb-restore daemon will auto-fix MBP side on replug"
log "FAIL: bridge0 status=$(bridge0_status) ip=$(bridge0_ip)"

# Still try tunnel if bridge is partially alive
if [[ -n "$(bridge0_ip)" ]] && ! tunnel_alive; then
  log "Attempting tunnel-pro despite degraded bridge..."
  restart_tunnel_pro
fi

exit 1

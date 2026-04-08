#!/bin/bash
# bridge-drop-monitor.sh — Mini side only
# Watches bridge0, logs state changes, auto-restarts tunnel-pro on recovery
# VERSION: v1.0.4-alpha (Build 26A05)
HOST="[Mac-mini-Server-i7]"
LOG="$HOME/Library/Logs/BridgeRestore/bridge-drop.log"
mkdir -p "$HOME/Library/Logs/BridgeRestore"
TS()  { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $HOST $*" | tee -a "$LOG"; }
log "=== bridge-drop-monitor v2 starting ==="
LAST_STATE="unknown"
while true; do
  BRIDGE_IP=$(ifconfig bridge0 2>/dev/null | awk '/inet /{print $2}')
  BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
  TUNNEL_PID=$(pgrep -f "ssh.*-R 2222" | head -1)
  if [[ -z "$BRIDGE_IP" ]] || [[ "$BRIDGE_ST" != "active" ]]; then
    STATE="DOWN"
  else
    STATE="UP"
  fi
  if [[ "$STATE" != "$LAST_STATE" ]]; then
    ARP_MBP=$(arp -n 192.168.2.1 2>/dev/null | grep -o '[0-9a-f:]*:[0-9a-f:]*' | head -1 || echo "incomplete")
    log "bridge0: $LAST_STATE → $STATE | IP:${BRIDGE_IP:-NONE} | tunnel:${TUNNEL_PID:-NONE} | arp_mbp:${ARP_MBP}"
    if [[ "$STATE" == "DOWN" ]]; then
      osascript -e 'display notification "bridge0 went DOWN" with title "Bridge Monitor"' 2>/dev/null
    fi
    if [[ "$STATE" == "UP" ]] && [[ -z "$TUNNEL_PID" ]]; then
      log "bridge0 recovered — auto-starting tunnel-pro in 5s"
      sleep 5
      nohup /usr/local/bin/tunnel-pro >> "$LOG" 2>&1 &
      osascript -e 'display notification "bridge0 recovered — tunnel-pro restarting" with title "Bridge Monitor"' 2>/dev/null
    fi
    LAST_STATE="$STATE"
  fi
  sleep 5
done

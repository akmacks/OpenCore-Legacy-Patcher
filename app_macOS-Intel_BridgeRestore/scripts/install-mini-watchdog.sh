#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  INSTALL MINI BRIDGE WATCHDOG  v1.0.2 (Build 26A07)                     ║
# ║  Run this ON THE MBP to deploy the watchdog to the mini via tunnel.     ║
# ║                                                                          ║
# ║  Prerequisites: tunnel-pro running on mini (port 2222 open on MBP).     ║
# ║  Usage:         bash install-mini-watchdog.sh                            ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Identity guard — MBP/GATEWAY only ────────────────────────────────────
MY_UUID=$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F'"' '/IOPlatformUUID/{print $4}')
GATEWAY_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
if [[ "$MY_UUID" != "$GATEWAY_UUID" ]]; then
  echo "ERROR: run this on the MBP (gateway), not the mini" >&2; exit 1
fi

PROJ="$HOME/dev/projects/apps/app_macOS-Intel_BridgeRestore"
SCRIPT_SRC="$PROJ/scripts/mini-bridge-watchdog.sh"
PLIST_SRC="$PROJ/launchd/local.mini-bridge-watchdog.plist"

SSH="ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no -p 2222 akmacks@localhost"
SCP_SEND() {
  # Sends a local file to mini via tunnel using cat (avoids scp sftp dependency)
  local SRC="$1" DST="$2"
  $SSH "cat > $DST" < "$SRC"
}

echo "=== Installing mini-bridge-watchdog v1.0.2 via tunnel ==="

# Verify tunnel is open
if ! nc -z localhost 2222 2>/dev/null; then
  echo "ERROR: port 2222 not open — tunnel-pro must be running on mini first" >&2
  echo "Tip: SSH to mini directly and run: bash ~/scripts/tunnel-pro.sh &" >&2
  exit 1
fi
echo "✓ Tunnel open on :2222"

# Create dirs on mini
$SSH "mkdir -p ~/scripts ~/Library/Logs/BridgeRestore ~/.config/bridge-restore"
echo "✓ Dirs created on mini"

# Send watchdog script
SCP_SEND "$SCRIPT_SRC" "~/scripts/mini-bridge-watchdog.sh"
$SSH "chmod +x ~/scripts/mini-bridge-watchdog.sh"
echo "✓ Script deployed: ~/scripts/mini-bridge-watchdog.sh"

# Send plist
SCP_SEND "$PLIST_SRC" "~/Library/LaunchAgents/local.mini-bridge-watchdog.plist"
echo "✓ Plist deployed: ~/Library/LaunchAgents/local.mini-bridge-watchdog.plist"

# Reload agent (unload old, load new)
$SSH "launchctl unload ~/Library/LaunchAgents/local.mini-bridge-watchdog.plist 2>/dev/null || true"
sleep 1
$SSH "launchctl load -w ~/Library/LaunchAgents/local.mini-bridge-watchdog.plist 2>/dev/null"
sleep 2

# Verify
if $SSH "launchctl list | grep -q local.mini-bridge-watchdog"; then
  echo "✓ Watchdog daemon running on mini (every 30s)"
else
  echo "WARN: launchctl load may have failed on mini"
  echo "Tip: on mini, run: launchctl load -w ~/Library/LaunchAgents/local.mini-bridge-watchdog.plist"
fi

echo ""
echo "=== Install complete ==="
echo "Monitor: ssh -p 2222 akmacks@localhost 'tail -f ~/Library/Logs/BridgeRestore/mini-watchdog.log'"
echo "Stop:    ssh -p 2222 akmacks@localhost 'launchctl bootout gui/\$(id -u) ~/Library/LaunchAgents/local.mini-bridge-watchdog.plist'"

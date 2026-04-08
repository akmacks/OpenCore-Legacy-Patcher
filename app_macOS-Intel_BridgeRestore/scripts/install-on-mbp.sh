#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  install-on-mbp.sh — GATEWAY (MBP) SIDE ONLY                           ║
# ║  Installs permanent auto-connect infrastructure on MacBookPro16,1       ║
# ║                                                                          ║
# ║  What it installs:                                                       ║
# ║    1. /usr/local/bin/{tunnel-mini,bridge-restore} symlinks/wrappers     ║
# ║    2. local.mbp-watchdog   — auto-runs tunnel-mini when port 2222 opens ║
# ║    3. local.nat-persist    — restores NAT + ip_forwarding on every boot ║
# ║    4. /etc/pf.anchors/bridge-restore — persistent NAT rules             ║
# ║                                                                          ║
# ║  Requires: passwordless sudo (/etc/sudoers.d/akmacks-nopasswd)          ║
# ╚══════════════════════════════════════════════════════════════════════════╝

set -e

# ── Identity guard ────────────────────────────────────────────────────
_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
_MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
_MBP_MODEL="MacBookPro16,1"

if [[ "$_UUID" != "$_MBP_UUID" ]] || [[ "$_MODEL" != "$_MBP_MODEL" ]]; then
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ❌  WRONG MACHINE — REFUSING TO RUN                 ║"
  echo "║  install-on-mbp.sh is MBP-only (MacBookPro16,1)    ║"
  printf "║  This machine: %-38s║\n" "$_MODEL"
  echo "║  For the Mini, run: install-on-mini.sh              ║"
  echo "╚══════════════════════════════════════════════════════╝"
  exit 1
fi

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$APP_DIR/scripts"
LAUNCHD_DIR="$APP_DIR/launchd"
LOG="$HOME/Library/Logs/BridgeRestore/install-on-mbp.log"
mkdir -p "$HOME/logs" "$HOME/Library/LaunchAgents"

DT()  { date '+%H:%M %d/%m/%y'; }
log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
ok()  { log "✅ $*"; }
fail(){ log "❌ $*"; }

echo "=== install-on-mbp.sh | $_MODEL | $(DT) ==="
log "=== MBP install starting ==="


# ════════════════════════════════════════════════════════════════════════
# STEP 1 — /usr/local/bin wrappers
# ════════════════════════════════════════════════════════════════════════
echo ""
echo "[1/5] Installing /usr/local/bin command wrappers"

sudo tee /usr/local/bin/tunnel-mini > /dev/null << WRAPPER
#!/bin/bash
exec bash "$SCRIPTS_DIR/tunnel-mini.sh" "\$@"
WRAPPER
sudo chmod +x /usr/local/bin/tunnel-mini

sudo tee /usr/local/bin/bridge-restore > /dev/null << WRAPPER
#!/bin/bash
exec bash "$SCRIPTS_DIR/bridge-restore-app.sh" "\$@"
WRAPPER
sudo chmod +x /usr/local/bin/bridge-restore

sudo tee /usr/local/bin/tunnel-mini-status > /dev/null << WRAPPER
#!/bin/bash
exec bash "$SCRIPTS_DIR/bridge-restore-app.sh" --status
WRAPPER
sudo chmod +x /usr/local/bin/tunnel-mini-status

ok "/usr/local/bin/{tunnel-mini,bridge-restore,tunnel-mini-status} installed"

# ════════════════════════════════════════════════════════════════════════
# STEP 2 — Persistent NAT rules at /etc/pf.anchors/bridge-restore
# ════════════════════════════════════════════════════════════════════════
echo ""
echo "[2/5] Writing persistent NAT rules to /etc/pf.anchors/bridge-restore"

UPLINKS=""
for IFACE in en0 en43 en1; do
  IP=$(ipconfig getifaddr "$IFACE" 2>/dev/null)
  [[ -n "$IP" ]] && UPLINKS+="nat on $IFACE inet from 192.168.2.0/24 to any -> ($IFACE)\n"
done
[[ -z "$UPLINKS" ]] && UPLINKS="nat on en0 inet from 192.168.2.0/24 to any -> (en0)\n"
UPLINKS+="pass all\n"

printf "$UPLINKS" | sudo tee /etc/pf.anchors/bridge-restore > /dev/null
ok "NAT rules written to /etc/pf.anchors/bridge-restore"

if ! sudo grep -q "bridge-restore" /etc/pf.conf 2>/dev/null; then
  sudo tee -a /etc/pf.conf > /dev/null << 'PF'

# Bridge Restore NAT anchor — added by install-on-mbp.sh
anchor "bridge-restore"
load anchor "bridge-restore" from "/etc/pf.anchors/bridge-restore"
PF
  ok "pf.conf updated with bridge-restore anchor"
else
  ok "pf.conf already has bridge-restore anchor"
fi

# ════════════════════════════════════════════════════════════════════════
# STEP 3 — nat-persist LaunchAgent plist
# ════════════════════════════════════════════════════════════════════════
echo ""
echo "[3/5] Installing nat-persist LaunchAgent"

cat > "$LAUNCHD_DIR/local.nat-persist.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>local.nat-persist</string>
    <key>ProgramArguments</key><array>
        <string>/bin/bash</string><string>-c</string>
        <string>
LOG="$HOME/Library/Logs/BridgeRestore/nat-persist.log"
mkdir -p "$HOME/logs"
log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }
log "=== nat-persist starting ==="
sudo /usr/sbin/sysctl -w net.inet.ip.forwarding=1 >> "$LOG" 2>&1 &amp;&amp; log "ip_forwarding=1" || log "WARN: ip_forwarding failed"
TRIES=0
while ! /sbin/ifconfig bridge0 &amp;>/dev/null &amp;&amp; [[ $TRIES -lt 12 ]]; do sleep 5; TRIES=$((TRIES+1)); done
if /sbin/ifconfig bridge0 &amp;>/dev/null; then
  CURR=$(/usr/sbin/ipconfig getifaddr bridge0 2>/dev/null)
  if [[ "$CURR" != "192.168.2.1" ]]; then
    sudo /sbin/ifconfig bridge0 192.168.2.1 netmask 255.255.255.0 2&gt;&gt;"$LOG" &amp;&amp; log "bridge0 = 192.168.2.1" || log "WARN: bridge0 set failed"
  else
    log "bridge0 = 192.168.2.1 OK"
  fi
else
  log "WARN: bridge0 not present after 60s — TB cable may not be connected"
fi
sudo /sbin/pfctl -f /etc/pf.anchors/bridge-restore 2&gt;&gt;"$LOG" || true
sudo /sbin/pfctl -e 2&gt;&gt;"$LOG" || true
log "pf anchor loaded"; log "=== nat-persist done ==="
        </string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/nat-persist.log</string>
    <key>StandardErrorPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/nat-persist.log</string>
    <key>EnvironmentVariables</key><dict>
        <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key><string>/Users/akmacks</string>
    </dict>
</dict></plist>
PLIST
ok "local.nat-persist.plist written to launchd/"

# ════════════════════════════════════════════════════════════════════════
# STEP 4 — mbp-watchdog script + LaunchAgent plist
# ════════════════════════════════════════════════════════════════════════
echo ""
echo "[4/5] Installing mbp-watchdog"

# The watchdog script lives in scripts/ alongside the other scripts.
# It is NOT inlined here — it's written as a first-class file by this installer
# if the repo copy isn't already present. Normally it will already be there.
if [[ ! -f "$SCRIPTS_DIR/mbp-watchdog.sh" ]]; then
  fail "mbp-watchdog.sh not found at $SCRIPTS_DIR — run git pull or copy it manually"
  exit 1
fi
chmod +x "$SCRIPTS_DIR/mbp-watchdog.sh"
ok "mbp-watchdog.sh executable ✓"

cat > "$LAUNCHD_DIR/local.mbp-watchdog.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>Label</key><string>local.mbp-watchdog</string>
    <key>ProgramArguments</key><array>
        <string>/bin/bash</string>
        <string>$SCRIPTS_DIR/mbp-watchdog.sh</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
    <key>ThrottleInterval</key><integer>10</integer>
    <key>StandardOutPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/mbp-watchdog.log</string>
    <key>StandardErrorPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/mbp-watchdog.log</string>
    <key>EnvironmentVariables</key><dict>
        <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key><string>/Users/akmacks</string>
    </dict>
</dict></plist>
PLIST
ok "local.mbp-watchdog.plist written to launchd/"

# ════════════════════════════════════════════════════════════════════════
# STEP 5 — Load all LaunchAgents
# ════════════════════════════════════════════════════════════════════════
echo ""
echo "[5/5] Loading LaunchAgents"

for PLIST_NAME in local.nat-persist local.mbp-watchdog; do
  SRC="$LAUNCHD_DIR/$PLIST_NAME.plist"
  DEST="$HOME/Library/LaunchAgents/$PLIST_NAME.plist"
  cp "$SRC" "$DEST"
  launchctl unload "$DEST" 2>/dev/null || true
  if launchctl load "$DEST" 2>/dev/null; then
    ok "$PLIST_NAME loaded"
  else
    fail "$PLIST_NAME failed to load — try: launchctl bootstrap gui/$(id -u) $DEST"
  fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║         ✅  MBP BRIDGE RESTORE INSTALL COMPLETE                     ║"
echo "║                                                                      ║"
echo "║  Commands available in any terminal:                                 ║"
echo "║    tunnel-mini        — restore bridge + open ControlMaster         ║"
echo "║    bridge-restore     — full restore (or --status / --diag)         ║"
echo "║    tunnel-mini-status — quick connection status                      ║"
echo "║                                                                      ║"
echo "║  LaunchAgents running:                                               ║"
echo "║    local.nat-persist  — keeps NAT + ip_forwarding on every boot     ║"
echo "║    local.mbp-watchdog — auto-connects when mini tunnel opens        ║"
echo "║                                                                      ║"
echo "║  Logs:                                                               ║"
echo "║    ~/Library/Logs/BridgeRestore/nat-persist.log                                            ║"
echo "║    ~/Library/Logs/BridgeRestore/mbp-watchdog.log                                           ║"
echo "║    ~/Library/Logs/BridgeRestore/tunnel-mini.log                                            ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
log "=== install-on-mbp complete | $(DT) ==="

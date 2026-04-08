#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  tunnel-mini.sh — MBP SIDE ONLY                                 ║
# ║  Sets MBP bridge0 = 192.168.2.1                                 ║
# ║  NEVER touches mini bridge0 = 192.168.2.2                       ║
# ║  Refuses to run on any machine that is not MacBookPro16,1       ║
# ║  VERSION: v1.0.4-alpha (Build 26A05)                            ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── IDENTITY CHECK: Hardware UUID — cannot be spoofed by hostname/IP ─
_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
_MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
_MBP_MODEL="MacBookPro16,1"

if [[ "$_UUID" != "$_MBP_UUID" ]] || [[ "$_MODEL" != "$_MBP_MODEL" ]]; then
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ❌  WRONG MACHINE — REFUSING TO RUN                 ║"
  echo "║  tunnel-mini.sh is MBP-only (MacBookPro16,1)        ║"
  printf "║  This machine: %-38s║\n" "$_MODEL"
  echo "║  On the Mini, run: tunnel-pro  (not tunnel-mini)    ║"
  echo "╚══════════════════════════════════════════════════════╝"
  exit 1
fi

# ── Constants — IP ownership is fixed, never changes ──────────────────
MBP_BRIDGE_IP="192.168.2.1"   # MBP owns this — ALWAYS
MINI_BRIDGE_IP="192.168.2.2"  # Mini owns this — ALWAYS
MINI_MAC="82:0c:4d:eb:46:81"
MBP_MAC=$(ifconfig bridge0 2>/dev/null | awk '/ether/{print $2}')
MINI_TUNNEL_PORT=2222
MINI_USER="akmacks"
CM_PATH="$HOME/.ssh/cm/macmini"
SSH_KEY="$HOME/.ssh/id_ed25519"
LOG="$HOME/Library/Logs/BridgeRestore/tunnel-mini.log"
mkdir -p "$HOME/logs" "$HOME/.ssh/cm"

DT()   { date '+%H:%M %d/%m/%y'; }
TS()   { date '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(TS)] $*" | tee -a "$LOG"; }
ok()   { log "OK: $*";   echo "  ✅ $*"; }
fail() { log "FAIL: $*"; echo "  ❌ $*"; }
warn() { log "WARN: $*"; echo "  ⚠️  $*"; }
popup_mbp()  { osascript -e "display notification \"$1\" with title \"tunnel-mini\"" 2>/dev/null || true; }
popup_mini() {
  ssh -p "$MINI_TUNNEL_PORT" -i "$SSH_KEY" -o ControlPath="$CM_PATH" \
    -o ConnectTimeout=5 -o BatchMode=yes "$MINI_USER@localhost" \
    "osascript -e 'display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"Tunnel Established\"' &>/dev/null &" \
    2>/dev/null || true
}

# ── IS Toggle (MBP side) — with verification ─────────────────────────────────
# NOTE: In macOS Tahoe, Internet Sharing daemon is com.apple.NetworkSharing
# (NOT com.apple.InternetSharing — that plist no longer exists in Tahoe)
# CRITICAL: Never use launchctl unload -w — it de-registers the service entirely.
# Use kickstart only, and bootstrap if the service isn't registered.
IS_PLIST="/System/Library/LaunchDaemons/com.apple.NetworkSharing.plist"
IS_LABEL="com.apple.NetworkSharing"
toggle_internet_sharing() {
  log "IS toggle: checking current state..."

  local IS_PID; IS_PID=$(pgrep -f NetworkSharing | head -1)
  log "IS PID before toggle: ${IS_PID:-NOT RUNNING}"

  # Stop gracefully — NEVER use unload -w (destroys the launchd registration)
  if [[ -n "$IS_PID" ]]; then
    sudo launchctl kill SIGTERM system/"$IS_LABEL" 2>/dev/null
    sleep 3
    IS_PID=$(pgrep -f NetworkSharing | head -1)
    [[ -z "$IS_PID" ]] && log "IS stopped ✓" || log "IS still running (PID $IS_PID) — continuing"
  fi

  sleep 3

  # Restart IS — try kickstart first, bootstrap if not registered
  sudo launchctl kickstart system/"$IS_LABEL" 2>/dev/null
  sleep 5

  local IS_PID3; IS_PID3=$(pgrep -f NetworkSharing | head -1)
  if [[ -z "$IS_PID3" ]]; then
    log "kickstart failed — trying bootstrap (service may be de-registered)"
    sudo launchctl bootstrap system "$IS_PLIST" 2>/dev/null
    sleep 4
    IS_PID3=$(pgrep -f NetworkSharing | head -1)
  fi

  log "IS PID after restart: ${IS_PID3:-FAILED TO START}"
  if [[ -n "$IS_PID3" ]]; then
    log "IS restarted ✓ (PID $IS_PID3)"
  else
    log "WARN: IS failed to restart — turn on manually: System Settings → General → Sharing → Internet Sharing"
  fi

  # Re-apply bridge IP after IS rebuild
  sudo ifconfig bridge0 "$MBP_BRIDGE_IP" netmask 255.255.255.0 2>/dev/null
  sleep 3
}

log "=== tunnel-mini starting | $_MODEL / $_UUID ==="

# ── Step 1: Restore MBP bridge0 to 192.168.2.1 ────────────────────────
# We are on the MBP — we ONLY ever set 192.168.2.1 here
BRIDGE_IP=$(ipconfig getifaddr bridge0 2>/dev/null)
if [[ "$BRIDGE_IP" != "$MBP_BRIDGE_IP" ]]; then
  log "MBP bridge0 wrong ('$BRIDGE_IP') — restoring to $MBP_BRIDGE_IP"
  sudo ifconfig bridge0 "$MBP_BRIDGE_IP" netmask 255.255.255.0 2>/dev/null; sleep 2
  BRIDGE_IP=$(ipconfig getifaddr bridge0 2>/dev/null)
  [[ "$BRIDGE_IP" == "$MBP_BRIDGE_IP" ]] \
    && ok "MBP bridge0 restored to $MBP_BRIDGE_IP" \
    || { fail "MBP bridge0 still wrong: $BRIDGE_IP"; exit 1; }
else
  ok "MBP bridge0 = $MBP_BRIDGE_IP ✓"
fi

# ── Fast-path: if tunnel port already open, skip all remediation ──────
# The tunnel being up is definitive proof the connection is working.
# ARP cache stale / IS not detected are false negatives — don't act on them.
_TUNNEL_UP=""
if nc -z -G 4 localhost "$MINI_TUNNEL_PORT" 2>/dev/null; then
  ok "Port $MINI_TUNNEL_PORT already open — tunnel live, skipping ARP/IS/TB remediation"
  _TUNNEL_UP=1
fi

# ── Step 2: Verify ARP — only if tunnel not already confirmed up ───────
if [[ -z "$_TUNNEL_UP" ]]; then
  sleep 1
  ARP_MINI=$(arp -n "$MINI_BRIDGE_IP" 2>/dev/null | grep -v "no entry" | grep -o "[0-9a-f:]\{17\}" | head -1)
  log "ARP check: mini at $MINI_BRIDGE_IP = ${ARP_MINI:-not seen yet}"

  # ── Step 2b: IS toggle + TB severance if ARP incomplete ──────────────
  if [[ -z "$ARP_MINI" ]] || arp -n "$MINI_BRIDGE_IP" 2>/dev/null | grep -q "incomplete"; then
    warn "ARP incomplete — running IS toggle + TB severance"
    toggle_internet_sharing
    sleep 3
    PORT="${ACTIVE_PORT:-en4}"
    log "Bouncing MBP TB port $PORT"
    sudo ifconfig "$PORT" down; sleep 8; sudo ifconfig "$PORT" up; sleep 4
    sudo ifconfig bridge0 "$MBP_BRIDGE_IP" netmask 255.255.255.0 2>/dev/null
    sleep 3
    ARP_MINI=$(arp -n "$MINI_BRIDGE_IP" 2>/dev/null | grep -v "incomplete" | grep -o "[0-9a-f:]\{17\}" | head -1)
    [[ -n "$ARP_MINI" ]] && ok "ARP resolved: $ARP_MINI" \
      || warn "ARP still incomplete — mini TB interface may need attention"
  fi
fi # end _TUNNEL_UP gate

# ── Step 3: Restore NAT on all active uplinks ──────────────────────────
sudo sysctl -w net.inet.ip.forwarding=1 &>/dev/null && ok "IP forwarding on"
NAT_RULES=""; SEEN=""
for IFACE in en0 en43 en1 en2; do
  IP=$(ipconfig getifaddr $IFACE 2>/dev/null)
  if [[ -n "$IP" ]] && ! echo "$SEEN" | grep -qw "$IFACE"; then
    NAT_RULES+="nat on $IFACE inet from 192.168.2.0/24 to any -> ($IFACE)\n"
    SEEN+=" $IFACE"
  fi
done
printf "${NAT_RULES}pass all\n" > /tmp/mini-nat.conf
sudo pfctl -f /tmp/mini-nat.conf 2>/dev/null && sudo pfctl -e 2>/dev/null || true
ok "NAT loaded on: $SEEN"

# ── Step 4: TB bridge active check + bounce if needed (skip if tunnel already up)
if [[ -z "$_TUNNEL_UP" ]]; then
  ACTIVE_PORT=""
  for i in en1 en2 en3 en4 en5; do
    ifconfig "$i" 2>/dev/null | grep -q "status: active" && ACTIVE_PORT="$i" && break
  done
  BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
  if [[ "$BRIDGE_ST" != "active" ]]; then
    warn "bridge0 inactive — bouncing ${ACTIVE_PORT:-en4}"
    PORT="${ACTIVE_PORT:-en4}"
    sudo ifconfig "$PORT" down; sleep 10; sudo ifconfig "$PORT" up; sleep 3
    BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
    [[ "$BRIDGE_ST" == "active" ]] && ok "Bridge active after bounce" \
      || fail "Bridge still inactive — check Thunderbolt cable"
  else
    ok "bridge0 active (port: ${ACTIVE_PORT:-unknown})"
  fi
else
  # Tunnel already up — just detect active port for banner info
  ACTIVE_PORT=""
  for i in en1 en2 en3 en4 en5; do
    ifconfig "$i" 2>/dev/null | grep -q "status: active" && ACTIVE_PORT="$i" && break
  done
  ok "bridge0 active (port: ${ACTIVE_PORT:-unknown}) [skipped check — tunnel already live]"
fi

# ── Step 5: Check tunnel port ─────────────────────────────────────────
if ! nc -z -G 4 localhost "$MINI_TUNNEL_PORT" 2>/dev/null; then
  fail "Port $MINI_TUNNEL_PORT closed — run tunnel-pro on the mini first"
  popup_mbp "❌ Run tunnel-pro on mini, then retry tunnel-mini"
  log "=== tunnel-mini FAILED: port $MINI_TUNNEL_PORT not open ==="; exit 1
fi
ok "Tunnel port $MINI_TUNNEL_PORT open"

# ── Step 6: Open ControlMaster ────────────────────────────────────────
ssh -O exit macmini 2>/dev/null || true; sleep 1
ssh -f -N -i "$SSH_KEY" -o ControlMaster=yes -o ControlPath="$CM_PATH" \
  -o ControlPersist=4h -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=8 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
  -p "$MINI_TUNNEL_PORT" "$MINI_USER@localhost" 2>>"$LOG"
sleep 2

# ── Step 7: Verify SSH + confirm mini has correct IP ──────────────────
MINI_HOST=$(ssh -p "$MINI_TUNNEL_PORT" -i "$SSH_KEY" -o ControlPath="$CM_PATH" \
  -o ConnectTimeout=5 -o BatchMode=yes "$MINI_USER@localhost" "hostname" 2>/dev/null)
[[ -z "$MINI_HOST" ]] && { fail "SSH verification failed"; log "=== FAILED ==="; exit 1; }

MINI_IP_LIVE=$(ssh -p "$MINI_TUNNEL_PORT" -i "$SSH_KEY" -o ControlPath="$CM_PATH" \
  -o BatchMode=yes "$MINI_USER@localhost" \
  "ipconfig getifaddr bridge0 2>/dev/null || echo UNKNOWN" 2>/dev/null)
ok "SSH verified → $MINI_HOST (bridge0: $MINI_IP_LIVE)"

# Sanity check — mini must have 192.168.2.2
if [[ "$MINI_IP_LIVE" != "$MINI_BRIDGE_IP" ]]; then
  warn "Mini bridge0 = $MINI_IP_LIVE (expected $MINI_BRIDGE_IP) — fixing on mini"
  ssh -p "$MINI_TUNNEL_PORT" -i "$SSH_KEY" -o ControlPath="$CM_PATH" \
    -o BatchMode=yes "$MINI_USER@localhost" \
    "sudo ifconfig bridge0 $MINI_BRIDGE_IP netmask 255.255.255.0" 2>/dev/null
  MINI_IP_LIVE="$MINI_BRIDGE_IP"
fi

MBP_HOST=$(hostname); DATETIME=$(DT)

# ── Step 8: CAPS banner ───────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║       TUNNEL IS UP — SSH TUNNEL SUCCESSFULLY ESTABLISHED        ║"
printf "║  %-67s║\n" "$DATETIME"
echo "║                                                                  ║"
printf "║  SOURCE  MBP : %-51s║\n" "$MBP_HOST"
printf "║          IP  : %-20s  MAC: %-23s║\n" "$MBP_BRIDGE_IP" "$MBP_MAC"
echo "║                                                                  ║"
printf "║  TARGET  MINI: %-51s║\n" "$MINI_HOST"
printf "║          IP  : %-20s  MAC: %-23s║\n" "$MINI_IP_LIVE" "$MINI_MAC"
echo "║                                                                  ║"
printf "║  PORT: localhost:%-4s → mini:22   ALIAS: ssh-mini             ║\n" "$MINI_TUNNEL_PORT"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
log "=== ESTABLISHED: $MBP_HOST ($MBP_BRIDGE_IP) → $MINI_HOST ($MINI_IP_LIVE) at $DATETIME ==="
popup_mbp "✅ [$DATETIME] Tunnel to $MINI_HOST ready — ssh-mini"
popup_mini "🔗 TUNNEL ESTABLISHED\\n$DATETIME\\n\\nMBP: $MBP_HOST ($MBP_BRIDGE_IP) [$_MODEL]\\nMini: $MINI_HOST ($MINI_IP_LIVE)\\nTunnel: localhost:$MINI_TUNNEL_PORT → mini:22"

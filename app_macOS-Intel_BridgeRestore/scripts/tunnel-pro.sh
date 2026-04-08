#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  tunnel-pro.sh — MINI SIDE ONLY                                  ║
# ║  Sets Mini bridge0 = 192.168.2.2                                 ║
# ║  NEVER touches MBP bridge0 = 192.168.2.1                        ║
# ║  Refuses to run on MacBookPro16,1                                ║
# ║  VERSION: v1.0.4-alpha (Build 26A05)                            ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── IDENTITY CHECK: Hardware UUID + Model — absolute first ────────────
_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
_MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
_MINI_MODEL="Macmini5,3"

if [[ "$_UUID" == "$_MBP_UUID" ]] || [[ "$_MODEL" != "$_MINI_MODEL" ]]; then
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║  ❌  WRONG MACHINE — REFUSING TO RUN                 ║"
  echo "║  tunnel-pro.sh is Mini-only (Macmini5,3)            ║"
  printf "║  This machine: %-38s║\n" "$_MODEL"
  echo "║  On the MBP, run: tunnel-mini  (not tunnel-pro)     ║"
  echo "╚══════════════════════════════════════════════════════╝"
  exit 1
fi

# ── Constants ─────────────────────────────────────────────────────────
MINI_BRIDGE_IP="192.168.2.2"  # Mini owns this — ALWAYS
MBP_IP="192.168.2.1"          # MBP owns this — ALWAYS
MBP_USER="akmacks"
MINI_MAC="82:0c:4d:eb:46:81"
TUNNEL_PORT=2222
SSH_KEY="$HOME/.ssh/id_ed25519"
LOG="$HOME/Library/Logs/BridgeRestore/tunnel-pro.log"
mkdir -p "$HOME/logs"

DT()   { date '+%H:%M %d/%m/%y'; }
TS()   { date '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(TS)] $*" | tee -a "$LOG"; }
ok()   { log "OK: $*";   echo "  ✅ $*"; }
fail() { log "FAIL: $*"; echo "  ❌ $*"; }
warn() { log "WARN: $*"; echo "  ⚠️  $*"; }
popup_mini() { osascript -e "display notification \"$1\" with title \"tunnel-pro\"" 2>/dev/null || true; }
popup_mbp() {
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=6 \
    -o BatchMode=yes "$MBP_USER@$MBP_IP" \
    "osascript -e 'display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"Tunnel Established\"' &>/dev/null &" \
    2>/dev/null || true
}

log "=== tunnel-pro starting | $_MODEL / $_UUID ==="

# ── Step 1: Ensure Mini bridge0 = 192.168.2.2 ────────────────────────
# We are on the Mini — we ONLY ever set 192.168.2.2 here
CURR=$(ipconfig getifaddr bridge0 2>/dev/null)
if [[ "$CURR" != "$MINI_BRIDGE_IP" ]]; then
  log "Mini bridge0 wrong ('$CURR') — restoring $MINI_BRIDGE_IP"
  sudo ifconfig bridge0 "$MINI_BRIDGE_IP" netmask 255.255.255.0 2>/dev/null; sleep 2
  CURR=$(ipconfig getifaddr bridge0 2>/dev/null)
  [[ "$CURR" == "$MINI_BRIDGE_IP" ]] \
    && ok "Mini bridge0 = $MINI_BRIDGE_IP ✓" \
    || { fail "Mini bridge0 still wrong: $CURR"; exit 1; }
else
  ok "Mini bridge0 = $MINI_BRIDGE_IP ✓"
fi

# ── Step 2: Detect TB port + bounce if inactive ───────────────────────
ACTIVE_PORT=""
for i in en1 en2 en3 en4 en5; do
  ifconfig "$i" 2>/dev/null | grep -q "status: active" && ACTIVE_PORT="$i" && break
done
BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
if [[ "$BRIDGE_ST" != "active" ]]; then
  warn "bridge0 inactive — bouncing ${ACTIVE_PORT:-en3}"
  PORT="${ACTIVE_PORT:-en3}"
  sudo ifconfig "$PORT" down; sleep 10; sudo ifconfig "$PORT" up; sleep 4
  BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
  [[ "$BRIDGE_ST" == "active" ]] && ok "Bridge active after bounce" \
    || fail "Bridge still inactive — reseat Thunderbolt cable"
else
  ok "bridge0 active (port: ${ACTIVE_PORT:-unknown})"
fi

# ── Step 3: Check MBP reachable via SSH port (not ping — blocked by NAT) ─────
if ! nc -z -G 5 "$MBP_IP" 22 2>/dev/null; then
  fail "MBP SSH port not reachable at $MBP_IP:22"
  popup_mini "❌ [$(DT)] MBP unreachable — check Thunderbolt cable"
  log "=== tunnel-pro FAILED: MBP unreachable ==="; exit 1
fi
ok "MBP reachable at $MBP_IP (SSH port open)"

# ── Step 4: Kill stale, open fresh tunnel ────────────────────────────
pkill -f "ssh.*-R $TUNNEL_PORT" 2>/dev/null || true; sleep 1
ssh -f -R "$TUNNEL_PORT:localhost:22" -i "$SSH_KEY" \
  -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=10 "$MBP_USER@$MBP_IP" "sleep 7200" >> "$LOG" 2>&1
sleep 3

TUNNEL_PID=$(pgrep -f "ssh.*-R $TUNNEL_PORT" | head -1)
[[ -z "$TUNNEL_PID" ]] && { fail "Tunnel died immediately"; popup_mini "❌ Tunnel failed"; log "=== FAILED ==="; exit 1; }
ok "Tunnel running (PID $TUNNEL_PID)"

# ── Step 5: Gather details + banner ──────────────────────────────────
MINI_HOST=$(hostname)
MBP_HOST=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=5 -o BatchMode=yes "$MBP_USER@$MBP_IP" \
  "hostname" 2>/dev/null || echo "$MBP_IP")
MBP_MAC=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
  -o ConnectTimeout=5 -o BatchMode=yes "$MBP_USER@$MBP_IP" \
  "ifconfig bridge0 2>/dev/null | awk '/ether/{print \$2}'" 2>/dev/null || echo "unknown")
DATETIME=$(DT)

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║       TUNNEL IS UP — SSH TUNNEL SUCCESSFULLY ESTABLISHED        ║"
printf "║  %-67s║\n" "$DATETIME"
echo "║                                                                  ║"
printf "║  SOURCE  MINI: %-51s║\n" "$MINI_HOST"
printf "║          IP  : %-20s  MAC: %-23s║\n" "$MINI_BRIDGE_IP" "$MINI_MAC"
echo "║                                                                  ║"
printf "║  TARGET  MBP : %-51s║\n" "$MBP_HOST"
printf "║          IP  : %-20s  MAC: %-23s║\n" "$MBP_IP" "$MBP_MAC"
echo "║                                                                  ║"
printf "║  TUNNEL PID: %-8s   MBP localhost:%-4s → mini:22          ║\n" "$TUNNEL_PID" "$TUNNEL_PORT"
echo "║  Now run tunnel-mini on MBP to complete the connection          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
log "=== ESTABLISHED: $MINI_HOST ($MINI_BRIDGE_IP) → $MBP_HOST ($MBP_IP) PID=$TUNNEL_PID at $DATETIME ==="
popup_mini "✅ [$DATETIME] Tunnel to $MBP_HOST (PID $TUNNEL_PID)"
popup_mbp "🔗 TUNNEL ESTABLISHED\\n$DATETIME\\n\\nMini: $MINI_HOST ($MINI_BRIDGE_IP) [$_MODEL]\\nMBP: $MBP_HOST ($MBP_IP)\\nNow run: tunnel-mini on MBP"

echo "Tunnel active. Press Ctrl+C to close."
wait "$TUNNEL_PID" 2>/dev/null
log "=== tunnel-pro ENDED: PID $TUNNEL_PID at $(DT) ==="

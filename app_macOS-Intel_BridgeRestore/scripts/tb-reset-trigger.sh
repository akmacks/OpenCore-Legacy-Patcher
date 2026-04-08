#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  TB-RESET TRIGGER  v1.0.0 (Build 26A06)                                 ║
# ║  Bridge Restore — tool_macOS-Universal_tb-reset module wrapper           ║
# ║                                                                          ║
# ║  Invokes the compiled tb-reset IOKit tool to perform a true physical     ║
# ║  L1 Thunderbolt reset via PCIe re-probe. Falls back to ifconfig bounce   ║
# ║  if the binary is not yet compiled/installed.                            ║
# ║                                                                          ║
# ║  Usage (called from bridge-restore-app.sh --sever):                      ║
# ║    bash tb-reset-trigger.sh [--port en4] [--dry-run]                    ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_DIR="$SCRIPT_DIR/../tools/tb-reset"
BINARY_PATHS=(
    "/usr/local/bin/tb-reset"
    "$TOOL_DIR/tb-reset"
    "$SCRIPT_DIR/../../../tools/tool_macOS-Universal_tb-reset/build/tb-reset"
)

LOG_FILE="${BR_LOG:-$HOME/logs/bridge-restore.log}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [tb-reset] $*" | tee -a "$LOG_FILE"; }

# ── Find compiled binary ───────────────────────────────────────────────────
BINARY=""
for p in "${BINARY_PATHS[@]}"; do
    if [[ -x "$p" ]]; then BINARY="$p"; break; fi
done

# ── Execute or fallback ────────────────────────────────────────────────────
if [[ -n "$BINARY" ]]; then
    log "Using compiled tb-reset binary: $BINARY"
    sudo "$BINARY" "$@" 2>&1 | tee -a "$LOG_FILE"
    EXIT=${PIPESTATUS[0]}
    if [[ $EXIT -eq 0 ]]; then
        log "tb-reset probe sent — waiting 15 s for L1 renegotiation..."
        sleep 15
        log "Restoring bridge0 IP after reset"
        sudo ifconfig bridge0 "${GATEWAY_IP:-192.168.2.1}" netmask 255.255.255.0 2>/dev/null || true
    else
        log "WARN: tb-reset exited $EXIT — falling back to ifconfig bounce"
        goto_fallback=1
    fi
else
    log "WARN: tb-reset binary not found — compile with: make -C \$TOOL_DIR"
    log "Falling back to L2 ifconfig port bounce"
    goto_fallback=1
fi

# ── L2 fallback ───────────────────────────────────────────────────────────
if [[ "${goto_fallback:-0}" -eq 1 ]]; then
    ACTIVE_PORT=""
    for i in en1 en2 en3 en4; do
        ifconfig "$i" 2>/dev/null | grep -q "status: active" && ACTIVE_PORT="$i" && break
    done
    ACTIVE_PORT="${ACTIVE_PORT:-en4}"
    log "Fallback: bouncing $ACTIVE_PORT"
    sudo ifconfig "$ACTIVE_PORT" down; sleep 10; sudo ifconfig "$ACTIVE_PORT" up; sleep 5
    sudo ifconfig bridge0 "${GATEWAY_IP:-192.168.2.1}" netmask 255.255.255.0 2>/dev/null || true
fi

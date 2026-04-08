#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  rescue-bot — Offline network/interface diagnostics tool        ║
# ║  Uses local Ollama models (no internet required)                ║
# ║  Models: llama3.2:3b (fast) | qwen3:4b (reasoning)             ║
# ║  VERSION: v0.1.0 (Build 26A05)                                  ║
# ╚══════════════════════════════════════════════════════════════════╝

OLLAMA_URL="http://localhost:11434"
# Preferred models in priority order — first available wins
PREFERRED_MODELS=("gpt-oss:20b" "qwen3:4b" "qwen2.5:1.5b" "llama3.2:3b" "gemma2:2b")
LOG_DIR="$HOME/Library/Logs/BridgeRestore"
mkdir -p "$LOG_DIR"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $*" | tee -a "$LOG_DIR/rescue-bot.log"; }

# ── Check which model is available ───────────────────────────────
pick_model() {
  local available; available=$(curl -s "$OLLAMA_URL/api/tags" 2>/dev/null | \
    python3 -c "import sys,json; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]" 2>/dev/null)
  if [[ -z "$available" ]]; then echo ""; return; fi
  for m in "${PREFERRED_MODELS[@]}"; do
    echo "$available" | grep -q "^${m}$" && echo "$m" && return
  done
  echo "$available" | head -1
}

# ── Collect diagnostics ──────────────────────────────────────────
collect_diagnostics() {
  echo "=== $(date) | macOS $(sw_vers -productVersion) | $(uname -m) ==="
  # Use ioreg instead of system_profiler — much faster on old hardware
  local UUID; UUID=$(ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/{gsub(/[^A-Z0-9-]/,"",$3); print $3}')
  local ROLE; [[ "$UUID" == "4B4DFAAB-B77A-5B8F-BE93-85E6F990529F" ]] && ROLE="HOST(MBP)" || ROLE="CLIENT(Mini)"
  echo "--- role: $ROLE ---"
  echo "--- bridge0 ---"
  ifconfig bridge0 2>/dev/null | grep -E "inet |status:|ether|member"
  echo "--- ARP ---"
  arp -n 192.168.2.1 2>/dev/null; arp -n 192.168.2.2 2>/dev/null
  echo "--- tunnel port ---"
  nc -z -G 3 localhost 2222 2>/dev/null && echo "2222: OPEN" || echo "2222: CLOSED"
  echo "--- IS process ---"
  pgrep -f InternetSharing 2>/dev/null && echo "IS: RUNNING" || echo "IS: DOWN"
  echo "--- active ifaces ---"
  for i in en0 en1 en2 en3 en4 en43 bridge0; do
    ip=$(ipconfig getifaddr $i 2>/dev/null)
    st=$(ifconfig $i 2>/dev/null | awk '/status:/{print $2}')
    [[ -n "$ip" || "$st" == "active" ]] && echo "$i: ip=${ip:-none} status=${st:-unknown}"
  done
  echo "--- recent log (last 8) ---"
  if [[ "$ROLE" == "HOST(MBP)" ]]; then
    tail -8 "$HOME/Library/Logs/BridgeRestore/tunnel-watchdog-mbp.log" 2>/dev/null || echo "no watchdog log"
  else
    tail -8 "$HOME/Library/Logs/BridgeRestore/bridge-drop.log" 2>/dev/null || echo "no drop log"
  fi
}

# ── Ask Ollama to diagnose ────────────────────────────────────────
# On CLIENT (mini): never run inference locally — offload to MBP via tunnel
# On HOST (MBP): run locally with hard 90s timeout
ask_ollama() {
  local model="$1"; local diag="$2"
  local prompt="You are a macOS network diagnostics expert. This machine runs macOS Tahoe (macOS 26) on Intel hardware with a Thunderbolt Bridge to a second Mac.

IMPORTANT: Only suggest macOS commands. Never suggest Linux commands like 'ip link', 'ip addr', 'nmcli', or 'link up'. macOS uses: ifconfig, networksetup, ipconfig, arp, ping, nc, pfctl, launchctl, pgrep, system_profiler, networksetup.

The Thunderbolt Bridge uses:
- bridge0 interface with IP 192.168.2.1 (HOST/MBP) or 192.168.2.2 (CLIENT/Mini)
- Internet Sharing (IS) runs on the HOST only — pgrep -f InternetSharing
- Tunnel: reverse SSH — mini runs 'tunnel-pro' → MBP port 2222 opens
- Restore commands: 'tunnel-mini' (on MBP), 'tunnel-pro' (on Mini)

Analyse the diagnostics below. State what is wrong in one sentence, then give exactly 3 numbered steps using only real macOS commands.

Diagnostics:
$diag"

  local MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
  local THIS_UUID; THIS_UUID=$(ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/{gsub(/[^A-Z0-9-]/,"",$3); print $3}')

  if [[ "$THIS_UUID" != "$MBP_UUID" ]]; then
    # CLIENT: never run inference locally — offload to MBP via tunnel
    if nc -z -G 3 192.168.2.1 22 &>/dev/null; then
      echo "📡 Offloading analysis to MBP (gpt-oss:20b via tunnel)..."
      local escaped_prompt; escaped_prompt=$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
      ssh -p 2222 -i ~/.ssh/id_ed25519 -o BatchMode=yes -o ConnectTimeout=5 akmacks@localhost \
        "curl -s --max-time 90 http://localhost:11434/api/generate \
          -d '{\"model\":\"gpt-oss:20b\",\"prompt\":$escaped_prompt,\"stream\":false}' \
          2>/dev/null | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('response','No response'))\"" 2>/dev/null \
        || echo "⚠️  Could not reach MBP Ollama. Raw diagnostics above are your guide."
    else
      echo "⚠️  No tunnel to MBP — AI analysis unavailable offline."
      echo "    Copy the diagnostics above and paste into Claude or another AI assistant."
    fi
  else
    # HOST (MBP): run locally, hard 90s timeout
    curl -s --max-time 90 "$OLLAMA_URL/api/generate" \
      -d "{\"model\":\"$model\",\"prompt\":$(echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),\"stream\":false}" \
      2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('response','No response'))" \
      || echo "⚠️  Ollama timed out (90s). Run 'rescue-bot status' for raw diagnostics."
  fi
}

# ── Main ──────────────────────────────────────────────────────────
case "${1:-diagnose}" in
  diagnose|diag)
    log "=== RescueBot diagnostic session ==="
    MODEL=$(pick_model)
    if [[ -z "$MODEL" ]]; then
      echo "❌ No Ollama model available. Is Ollama running? Try: ollama serve"
      echo "   Raw diagnostics (no AI):"
      collect_diagnostics
      exit 1
    fi
    echo "🤖 Model: $MODEL  (timeout: 90s)"
    echo "📋 Collecting diagnostics..."
    DIAG=$(collect_diagnostics)
    echo "$DIAG"
    echo ""
    echo "⏳ Sending to $MODEL for analysis — please wait..."
    echo "━━━ AI Analysis ($MODEL) ━━━"
    ask_ollama "$MODEL" "$DIAG"
    ;;
  status)
    collect_diagnostics
    ;;
  models)
    curl -s "$OLLAMA_URL/api/tags" 2>/dev/null | python3 -c "import sys,json; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]" || echo "Ollama not running"
    ;;
  *)
    echo "Usage: rescue-bot [diagnose|status|models]"
    ;;
esac

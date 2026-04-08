#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  status-check.sh — Phase 1a data layer                         ║
# ║  Runs all 7 status checks, outputs JSON to stdout               ║
# ║  Works on BOTH MBP (HOST) and mini (CLIENT)                     ║
# ║  VERSION: v1.0.4-alpha (Build 26A05)                            ║
# ╚══════════════════════════════════════════════════════════════════╝

# ── Identity ──────────────────────────────────────────────────────
MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
THIS_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
THIS_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')

if [[ "$THIS_UUID" == "$MBP_UUID" ]]; then
  ROLE="HOST"; FRIENDLY="Pro"
  MY_BRIDGE_IP="192.168.2.1"; PEER_BRIDGE_IP="192.168.2.2"
  TUNNEL_PORT=2222; TUNNEL_HOST="localhost"
else
  ROLE="CLIENT"; FRIENDLY="Mini"
  MY_BRIDGE_IP="192.168.2.2"; PEER_BRIDGE_IP="192.168.2.1"
  TUNNEL_PORT=2222; TUNNEL_HOST="$PEER_BRIDGE_IP"
fi

TS() { date '+%Y-%m-%d %H:%M:%S'; }

# ── Check functions — each returns: status|value|detail ──────────

check_host_ip() {
  local ip; ip=$(ipconfig getifaddr bridge0 2>/dev/null)
  if [[ "$ip" == "$MY_BRIDGE_IP" ]]; then
    echo "green|$ip|bridge0 correct"
  elif [[ -n "$ip" ]]; then
    echo "yellow|$ip|bridge0 wrong (expected $MY_BRIDGE_IP)"
  else
    echo "red|NONE|bridge0 missing"
  fi
}

check_client_ip() {
  local arp; arp=$(arp -n "$PEER_BRIDGE_IP" 2>/dev/null)
  local mac; mac=$(echo "$arp" | grep -o '[0-9a-f:]*:[0-9a-f:]*' | head -1)
  if [[ -n "$mac" ]] && ! echo "$arp" | grep -q "incomplete"; then
    echo "green|$PEER_BRIDGE_IP|MAC:$mac"
  elif echo "$arp" | grep -q "incomplete"; then
    echo "yellow|$PEER_BRIDGE_IP|ARP incomplete"
  else
    echo "red|NONE|no ARP entry"
  fi
}

check_internet() {
  if nc -z -G 3 1.1.1.1 443 2>/dev/null; then
    echo "green|reachable|1.1.1.1:443 open"
  elif nc -z -G 6 8.8.8.8 53 2>/dev/null; then
    echo "yellow|slow|8.8.8.8:53 open (slow)"
  else
    echo "red|down|no internet"
  fi
}

check_ssh_tunnel() {
  if [[ "$ROLE" == "HOST" ]]; then
    # HOST: check reverse tunnel port on localhost
    if nc -z -G 3 localhost "$TUNNEL_PORT" 2>/dev/null; then
      echo "green|localhost:$TUNNEL_PORT|port open"
    else
      echo "red|closed|port $TUNNEL_PORT not open"
    fi
  else
    # CLIENT: check MBP SSH port reachable (port 22, not 2222 — loopback only)
    if nc -z -G 3 "$PEER_BRIDGE_IP" 22 2>/dev/null; then
      echo "green|$PEER_BRIDGE_IP:22|MBP SSH reachable"
    else
      echo "red|$PEER_BRIDGE_IP:22|MBP SSH unreachable"
    fi
  fi
}

check_controlmaster() {
  if [[ "$ROLE" == "HOST" ]]; then
    if ssh -O check macmini 2>&1 | grep -q "Master running"; then
      echo "green|active|ControlMaster running"
    elif nc -z -G 3 localhost "$TUNNEL_PORT" 2>/dev/null; then
      echo "yellow|port open|no ControlMaster"
    else
      echo "red|none|tunnel down"
    fi
  else
    # On client: check if outbound SSH tunnel is alive
    local tpid; tpid=$(pgrep -f "ssh.*-R $TUNNEL_PORT" | head -1)
    [[ -n "$tpid" ]] && echo "green|PID:$tpid|tunnel-pro running" \
                     || echo "red|none|tunnel-pro not running"
  fi
}

check_is() {
  if [[ "$ROLE" == "HOST" ]]; then
    local pid; pid=$(pgrep -f InternetSharing | head -1)
    [[ -n "$pid" ]] && echo "green|running|PID:$pid" \
                    || echo "red|DOWN|open Sharing settings"
  else
    echo "grey|N/A|IS runs on HOST only"
  fi
}

check_bridge_status() {
  local st; st=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
  local ip; ip=$(ifconfig bridge0 2>/dev/null | awk '/inet /{print $2}')
  if [[ "$st" == "active" ]] && [[ "$ip" == "$MY_BRIDGE_IP" ]]; then
    echo "green|$ip|bridge0 active"
  elif [[ "$st" == "active" ]]; then
    echo "yellow|$ip|active but wrong IP"
  else
    echo "red|DOWN|bridge0 inactive"
  fi
}

# ── Run all checks ─────────────────────────────────────────────────

R_HOST_IP=$(check_host_ip)
R_BRIDGE=$(check_bridge_status)
R_PEER=$(check_client_ip)
R_INTERNET=$(check_internet)
R_TUNNEL=$(check_ssh_tunnel)
R_CM=$(check_controlmaster)
R_IS=$(check_is)

# Parse helper: "status|value|detail" → fields
f1() { echo "$1" | cut -d'|' -f1; }
f2() { echo "$1" | cut -d'|' -f2; }
f3() { echo "$1" | cut -d'|' -f3; }

# ── JSON output ────────────────────────────────────────────────────
cat << ENDJSON
{
  "timestamp": "$(TS)",
  "role": "$ROLE",
  "friendly": "$FRIENDLY",
  "model": "$THIS_MODEL",
  "checks": {
    "host_ip":    { "status": "$(f1 "$R_HOST_IP")",  "value": "$(f2 "$R_HOST_IP")",  "detail": "$(f3 "$R_HOST_IP")"  },
    "bridge":     { "status": "$(f1 "$R_BRIDGE")",    "value": "$(f2 "$R_BRIDGE")",    "detail": "$(f3 "$R_BRIDGE")"    },
    "peer_ip":    { "status": "$(f1 "$R_PEER")",      "value": "$(f2 "$R_PEER")",      "detail": "$(f3 "$R_PEER")"      },
    "internet":   { "status": "$(f1 "$R_INTERNET")",  "value": "$(f2 "$R_INTERNET")",  "detail": "$(f3 "$R_INTERNET")"  },
    "tunnel":     { "status": "$(f1 "$R_TUNNEL")",    "value": "$(f2 "$R_TUNNEL")",    "detail": "$(f3 "$R_TUNNEL")"    },
    "controlmaster": { "status": "$(f1 "$R_CM")",     "value": "$(f2 "$R_CM")",        "detail": "$(f3 "$R_CM")"        },
    "is":         { "status": "$(f1 "$R_IS")",        "value": "$(f2 "$R_IS")",        "detail": "$(f3 "$R_IS")"        }
  },
  "summary": {
    "all_green": $(( $(echo "$R_HOST_IP $R_BRIDGE $R_PEER $R_INTERNET $R_TUNNEL $R_CM $R_IS" | tr ' ' '\n' | grep -c "^red") == 0 )) ,
    "red_count": $(echo "$R_HOST_IP $R_BRIDGE $R_PEER $R_INTERNET $R_TUNNEL $R_CM $R_IS" | tr ' ' '\n' | grep -c "^red"),
    "grey_count": $(echo "$R_HOST_IP $R_BRIDGE $R_PEER $R_INTERNET $R_TUNNEL $R_CM $R_IS" | tr ' ' '\n' | grep -c "^grey")
  }
}
ENDJSON

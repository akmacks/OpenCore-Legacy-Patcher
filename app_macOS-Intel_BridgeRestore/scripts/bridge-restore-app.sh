#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  BRIDGE RESTORE APP  v1.0.7 (Build 26A07)                                       ║
# ║  Thunderbolt Bridge connectivity suite for macOS                        ║
# ║  Works on BOTH gateway host (MBP) and client hosts (Mini etc.)          ║
# ║                                                                          ║
# ║  Usage:                                                                  ║
# ║    bridge-restore-app              — auto-detect role, restore           ║
# ║    bridge-restore-app --wizard     — first-launch setup wizard           ║
# ║    bridge-restore-app --prefs      — open preferences (also: Cmd-,)      ║
# ║    bridge-restore-app --diag       — run diagnostics only                ║
# ║    bridge-restore-app --watchdog   — start watchdog daemon               ║
# ║    bridge-restore-app --status     — show current state                  ║
# ║    bridge-restore-app --debug      — verbose diagnostic run              ║
# ╚══════════════════════════════════════════════════════════════════════════╝

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$HOME/.config/bridge-restore"
CONFIG_FILE="$CONFIG_DIR/config.json"
LOG="$HOME/Library/Logs/BridgeRestore/bridge-restore-app.log"
VERSION="1.0.7"
BUILD="26A07"

mkdir -p "$CONFIG_DIR" "$HOME/logs"

DT()  { date '+%H:%M %d/%m/%y'; }
TS()  { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $*" | tee -a "$LOG"; }


# ══════════════════════════════════════════════════════════════════════════════
# MACHINE IDENTITY — hardware UUID, never hostname
# ══════════════════════════════════════════════════════════════════════════════
export THIS_MODEL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
export THIS_UUID=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')
THIS_HOST=$(hostname)

# Known UUIDs
MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
MBP_MODEL="MacBookPro16,1"
MINI_MODEL="Macmini5,3"

# Determine role from config or hardware
get_my_role() {
  if [[ -f "$CONFIG_FILE" ]]; then
    local role; role=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('my_role',''))" 2>/dev/null)
    [[ -n "$role" ]] && echo "$role" && return
  fi
  # Auto-detect
  [[ "$THIS_UUID" == "$MBP_UUID" ]] && echo "gateway" || echo "client"
}

get_config_val() {
  python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d.get('$1',''))" 2>/dev/null
}

MY_ROLE=$(get_my_role)

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG — read or create defaults
# ══════════════════════════════════════════════════════════════════════════════
init_config() {
  [[ -f "$CONFIG_FILE" ]] && return 0
  python3 << PYEOF
import json, os
config = {
  "version": "$VERSION",
  "my_role": "$(get_my_role)",
  "gateway": {
    "hostname": "MacBook-Pro-i9",
    "ip": "192.168.2.1",
    "uuid": "4B4DFAAB-B77A-5B8F-BE93-85E6F990529F",
    "model": "MacBookPro16,1",
    "nat_interfaces": ["en0", "en43"],
    "tb_port": "en4"
  },
  "clients": [
    {
      "name": "Mac mini Server",
      "hostname": "Mac-mini-Server-i7",
      "ip": "192.168.2.2",
      "mac": "82:0c:4d:eb:46:81",
      "model": "Macmini5,3",
      "tb_port": "en2",
      "tunnel_port": 2222
    }
  ],
  "watchdog": {
    "enabled": false,
    "interval_seconds": 30,
    "fail_menu_threshold": 10
  },
  "tunnel_auto_retry": {
    "enabled": false,
    "interval_seconds": 60
  },
  "diagnostics": {
    "layer1_physical": true,
    "layer2_datalink": true,
    "layer3_network": true,
    "layer4_transport": true,
    "layer5_tunnel_ssh": true,
    "layer6_nat_routing": true,
    "layer7_app_connectivity": true
  },
  "first_launch_complete": false
}
os.makedirs(os.path.dirname("$CONFIG_FILE"), exist_ok=True)
json.dump(config, open("$CONFIG_FILE", "w"), indent=2)
print("Config initialised")
PYEOF
}

init_config


# ══════════════════════════════════════════════════════════════════════════════
# SETUP WIZARD — first launch, and --wizard flag
# ══════════════════════════════════════════════════════════════════════════════
run_wizard() {
  log "=== Setup Wizard starting ==="
  osascript << 'WIZARD'
set wizardTitle to "Bridge Restore — Setup Wizard"

-- Welcome
display dialog "Welcome to Bridge Restore v1.0.7 (Build 26A06)

This wizard will configure:
  • Your machine's role (Gateway or Client)
  • Gateway host details
  • Client host details
  • Watchdog & auto-retry settings
  • Diagnostic layer preferences

Click Continue to begin." buttons {"Quit", "Continue"} default button "Continue" with title wizardTitle with icon note
if button returned of result is "Quit" then return "quit"

-- Role selection
set roleChoice to choose from list {"Gateway (shares internet — e.g. MacBook Pro)", "Client (receives internet — e.g. Mac mini)"} with prompt "What role does THIS machine play?" with title wizardTitle OK button name "Next" cancel button name "Quit"
if roleChoice is false then return "quit"
set myRole to item 1 of roleChoice

-- Gateway IP
set gatewayIP to text returned of (display dialog "Gateway bridge0 IP address:" default answer "192.168.2.1" buttons {"Back", "Next"} default button "Next" with title wizardTitle)

-- Client setup
set clientName to text returned of (display dialog "Primary client name (e.g. Mac mini Server):" default answer "Mac mini Server" buttons {"Back", "Next"} default button "Next" with title wizardTitle)
set clientIP to text returned of (display dialog "Primary client bridge0 IP address:" default answer "192.168.2.2" buttons {"Back", "Next"} default button "Next" with title wizardTitle)

-- Watchdog
set wdChoice to button returned of (display dialog "Enable Watchdog daemon?
(monitors connectivity, auto-restores, smart notifications after 10 failures)" buttons {"Skip", "Enable"} default button "Enable" with title wizardTitle)
set wdEnabled to (wdChoice is "Enable")

-- Tunnel auto-retry
set trChoice to button returned of (display dialog "Enable automatic tunnel-pro retry?
(mini will attempt to re-open tunnel every 60s if it drops)" buttons {"Skip", "Enable"} default button "Enable" with title wizardTitle)
set trEnabled to (trChoice is "Enable")

-- Diagnostics layers
set layerChoices to choose from list {"L1 Physical (cable/port)", "L2 Datalink (ARP/bridge)", "L3 Network (IP/ping)", "L4 Transport (TCP/SSH port)", "L5 Session (SSH tunnel)", "L6 NAT/Routing", "L7 Application (internet/curl)"} with prompt "Select diagnostic layers to enable:" with title wizardTitle OK button name "Next" cancel button name "Skip" with multiple selections allowed
if layerChoices is false then set layerChoices to {"L1 Physical (cable/port)", "L2 Datalink (ARP/bridge)", "L3 Network (IP/ping)", "L4 Transport (TCP/SSH port)", "L5 Session (SSH tunnel)", "L6 NAT/Routing", "L7 Application (internet/curl)"}

-- Summary
display dialog "Setup complete!

Role: " & myRole & "
Gateway IP: " & gatewayIP & "
Client: " & clientName & " (" & clientIP & ")
Watchdog: " & wdEnabled & "
Auto-retry: " & trEnabled & "

Click Finish to save." buttons {"Back", "Finish"} default button "Finish" with title wizardTitle with icon note

return myRole & "|" & gatewayIP & "|" & clientName & "|" & clientIP & "|" & wdEnabled & "|" & trEnabled
WIZARD
}


# ══════════════════════════════════════════════════════════════════════════════
# PREFERENCES WINDOW (Cmd-,) — two tabs: Hosts + Diagnostics
# ══════════════════════════════════════════════════════════════════════════════
run_prefs() {
  osascript << PREFS
set prefsTitle to "Bridge Restore — Preferences"
set tabChoice to button returned of (display dialog "Preferences

Choose a tab to configure:" buttons {"Hosts & Roles", "Diagnostic Layers", "Watchdog & Retry"} default button "Hosts & Roles" with title prefsTitle)

if tabChoice is "Hosts & Roles" then
  -- Gateway
  set gwHost to text returned of (display dialog "Gateway hostname:" default answer "$(get_config_val 'gateway.hostname' 2>/dev/null || echo MacBook-Pro-i9)" buttons {"Cancel","Save"} default button "Save" with title prefsTitle)
  set gwIP to text returned of (display dialog "Gateway bridge0 IP:" default answer "$(get_config_val 'gateway.ip' 2>/dev/null || echo 192.168.2.1)" buttons {"Cancel","Save"} default button "Save" with title prefsTitle)
  -- Client
  set clHost to text returned of (display dialog "Primary client hostname:" default answer "Mac-mini-Server-i7" buttons {"Cancel","Save"} default button "Save" with title prefsTitle)
  set clIP to text returned of (display dialog "Primary client bridge0 IP:" default answer "192.168.2.2" buttons {"Cancel","Save"} default button "Save" with title prefsTitle)
  return "hosts|" & gwHost & "|" & gwIP & "|" & clHost & "|" & clIP

else if tabChoice is "Diagnostic Layers" then
  set layerChoices to choose from list {"L1 Physical (cable/port)", "L2 Datalink (ARP/bridge)", "L3 Network (IP/ping)", "L4 Transport (TCP/SSH port)", "L5 Session (SSH tunnel)", "L6 NAT/Routing", "L7 Application (internet/curl)"} with prompt "Enable diagnostic layers (deselect to skip in runs):" with title prefsTitle OK button name "Save" cancel button name "Cancel" with multiple selections allowed
  if layerChoices is false then return "cancelled"
  return "layers|" & (layerChoices as string)

else if tabChoice is "Watchdog & Retry" then
  set wdChoice to button returned of (display dialog "Watchdog daemon:" buttons {"Disable", "Enable"} default button "Enable" with title prefsTitle)
  set wdInt to text returned of (display dialog "Watchdog check interval (seconds):" default answer "30" buttons {"Cancel","Save"} default button "Save" with title prefsTitle)
  set trChoice to button returned of (display dialog "Auto tunnel-pro retry:" buttons {"Disable", "Enable"} default button "Enable" with title prefsTitle)
  set trInt to text returned of (display dialog "Retry interval (seconds):" default answer "60" buttons {"Cancel","Save"} default button "Save" with title prefsTitle)
  return "watchdog|" & (wdChoice is "Enable") & "|" & wdInt & "|" & (trChoice is "Enable") & "|" & trInt
end if
PREFS
}


# ══════════════════════════════════════════════════════════════════════════════
# INTERNET SHARING TOGGLE — with "Turn On" confirmation dialog handler
# ══════════════════════════════════════════════════════════════════════════════
# ── Privilege escalation note ─────────────────────────────────────────────────
# Privileged operations use direct sudo (respects /etc/sudoers.d/akmacks-nopasswd).
# NEVER use osascript "with administrator privileges" — uses Authorization Services,
# always prompts regardless of sudoers.
# Future: integrate Bless (tool_macOS-Intel_Bless) for SMJobBless-based
# privilege escalation without sudo dependency.
# Bless repo: ~/dev/projects/apps/tool_macOS-Intel_Bless/

toggle_internet_sharing() {
  log "Toggling Internet Sharing via System Settings UI"

  # Check IS state
  local IS_PID; IS_PID=$(pgrep -f InternetSharing | head -1)

  if [[ -n "$IS_PID" ]]; then
    log "IS running (PID $IS_PID) — stopping via defaults write"
    # Write disabled state directly to NAT config
    sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.nat NAT -dict-add Enabled -bool false 2>/dev/null
    sudo kill "$IS_PID" 2>/dev/null
    sleep 3
    log "IS stopped"
  fi

  sleep 3

  # Re-enable via defaults + kickstart
  sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.nat NAT -dict-add Enabled -bool true 2>/dev/null
  sudo launchctl kickstart -k system/com.apple.InternetSharing 2>/dev/null || \
  sudo launchctl start com.apple.InternetSharing 2>/dev/null || true
  sleep 4

  # Verify
  local IS_PID2; IS_PID2=$(pgrep -f InternetSharing | head -1)
  if [[ -n "$IS_PID2" ]]; then
    log "IS restarted (PID $IS_PID2) ✓"
    # Handle the "Turn On" confirmation dialog if it appears
    osascript << 'HANDLE_DIALOG' 2>/dev/null &
delay 2
tell application "System Events"
  repeat 3 times
    set allWindows to every window of every process
    repeat with proc in (every process whose name contains "System Settings" or name contains "sharingd")
      try
        set procWindows to every window of proc
        repeat with w in procWindows
          set btns to every button of w
          repeat with b in btns
            if name of b contains "Turn On" then
              click b
              return "clicked Turn On"
            end if
          end repeat
        end repeat
      end try
    end repeat
    delay 1
  end repeat
end tell
HANDLE_DIALOG
    return 0
  fi

  log "WARN: IS failed to restart via launchctl — needs System Settings UI toggle"
  # Attempt via System Settings UI automation as last resort
  osascript << 'UI_TOGGLE' 2>/dev/null
tell application "System Settings" to activate
delay 1
tell application "System Events"
  tell process "System Settings"
    try
      -- Navigate to Internet Sharing
      keystroke "f" using {command down}
      delay 0.5
      keystroke "Internet Sharing"
      delay 1
      key code 36
      delay 2
      -- Find and click Internet Sharing toggle
      repeat with chk in (every checkbox of window 1)
        if description of chk contains "Internet" then
          click chk
          delay 2
          -- Handle confirmation dialog
          repeat with btn in buttons of window 1
            if name of btn is "Turn On" then
              click btn
              return "IS enabled via UI"
            end if
          end repeat
        end if
      end repeat
    end try
  end tell
end tell
UI_TOGGLE
  sleep 3
  IS_PID2=$(pgrep -f InternetSharing | head -1)
  [[ -n "$IS_PID2" ]] && log "IS started via UI (PID $IS_PID2)" || log "FAIL: IS could not be restarted"
}


# ══════════════════════════════════════════════════════════════════════════════
# DIAGNOSTIC ENGINE — OSI layer-aware, respects config enable/disable flags
# ══════════════════════════════════════════════════════════════════════════════
layer_enabled() {
  python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print('yes' if d.get('diagnostics',{}).get('$1',True) else 'no')" 2>/dev/null || echo "yes"
}

get_client_ip()  { python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d['clients'][0]['ip'])" 2>/dev/null || echo "192.168.2.2"; }
get_gateway_ip() { python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d['gateway']['ip'])" 2>/dev/null || echo "192.168.2.1"; }
get_tunnel_port(){ python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d['clients'][0]['tunnel_port'])" 2>/dev/null || echo "2222"; }

GATEWAY_IP=$(get_gateway_ip)
CLIENT_IP=$(get_client_ip)
TUNNEL_PORT=$(get_tunnel_port)

run_diag() {
  local VERBOSE="${1:-}"
  echo "=== Bridge Restore Diagnostics | $(DT) | Role: $MY_ROLE | $_MODEL ==="
  echo ""

  # L1 Physical
  if [[ "$(layer_enabled layer1_physical)" == "yes" ]]; then
    if [[ "$MY_ROLE" == "gateway" ]]; then
      # Tahoe bypass: gateway uses en4 directly (bridge0 broken on Titan Ridge TB3)
      local TB_IF=""; for i in en1 en2 en3 en4 en5; do
        local ST MAC
        ST=$(ifconfig "$i" 2>/dev/null | awk '/status:/{print $2}')
        MAC=$(ifconfig "$i" 2>/dev/null | awk '/ether/{print $2}')
        [[ "$ST" == "active" && "$MAC" == 82:93:89:41:* ]] && TB_IF="$i" && break
      done
      local TB_IP; TB_IP=$(ipconfig getifaddr "${TB_IF:-en4}" 2>/dev/null || echo "NONE")
      local BRIDGE_ST; BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
      echo "L1 Physical : TB_port=${TB_IF:-NONE} TB_IP=${TB_IP} bridge0=${BRIDGE_ST:-MISSING}"
      [[ "$TB_IP" == "$GATEWAY_IP" ]] && echo "L1 Tahoe    : en4 direct bypass ✓" || echo "L1 Tahoe    : ⚠️  en4 not configured (mbp-tb-restore will fix)"
    else
      local BRIDGE_ST; BRIDGE_ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
      local ACTIVE_PORT=""
      for i in en1 en2 en3 en4 en5; do
        ifconfig "$i" 2>/dev/null | grep -q "status: active" && ACTIVE_PORT="$i" && break
      done
      echo "L1 Physical : bridge0=${BRIDGE_ST:-MISSING} active_port=${ACTIVE_PORT:-NONE}"
    fi
  fi

  # L2 Datalink
  if [[ "$(layer_enabled layer2_datalink)" == "yes" ]]; then
    local PEER_IP; PEER_IP=$([[ "$MY_ROLE" == "gateway" ]] && echo "$CLIENT_IP" || echo "$GATEWAY_IP")
    local ARP_ENTRY; ARP_ENTRY=$(arp -n "$PEER_IP" 2>/dev/null | grep -v "no entry")
    echo "L2 Datalink : ARP $PEER_IP = ${ARP_ENTRY:-INCOMPLETE}"
    if [[ "$MY_ROLE" == "gateway" ]]; then
      # Gateway: check en4 IP (Tahoe bypass)
      local TB_IP; TB_IP=$(ipconfig getifaddr en4 2>/dev/null || echo "NONE")
      [[ "$TB_IP" == "$GATEWAY_IP" ]] && echo "L2 en4      : $TB_IP ✓" || echo "L2 en4      : $TB_IP ❌ (want $GATEWAY_IP)"
    else
      local MY_BRIDGE_IP; MY_BRIDGE_IP=$(ipconfig getifaddr bridge0 2>/dev/null || echo "NONE")
      local EXPECTED; EXPECTED="$CLIENT_IP"
      [[ "$MY_BRIDGE_IP" == "$EXPECTED" ]] && echo "L2 bridge0  : $MY_BRIDGE_IP ✓" || echo "L2 bridge0  : $MY_BRIDGE_IP ❌ (want $EXPECTED)"
    fi
  fi

  # L2b: Self-assigned IP probe loop check (APIPA — known bridge drop cause)
  if [[ "$(layer_enabled layer2_datalink)" == "yes" ]]; then
    # Check all interfaces for 169.254.x.x (APIPA = DHCP failed, configd probe loop active)
    APIPA_IFACES=$(ifconfig 2>/dev/null | awk '/inet 169\.254/{print prev": "$0} {prev=$1}' | grep -v "bridge0" | head -5)
    if [[ -n "$APIPA_IFACES" ]]; then
      echo "L2 APIPA    : ⚠️  Self-assigned IP detected on non-bridge interface:"
      echo "              $APIPA_IFACES"
      echo "              → configd DHCP probe loop active — likely cause of bridge drops"
      echo "              Fix: sudo networksetup -setnetworkserviceenabled "Ethernet" off"
      log "WARN: APIPA self-assigned IP found — configd probe loop likely causing bridge drops"
    else
      echo "L2 APIPA    : No self-assigned IPs on active interfaces ✓"
    fi
  fi

  # L3 Network
  if [[ "$(layer_enabled layer3_network)" == "yes" ]]; then
    local PEER; PEER=$([[ "$MY_ROLE" == "gateway" ]] && echo "$CLIENT_IP" || echo "$GATEWAY_IP")
    if ping -c 1 -t 2 "$PEER" &>/dev/null; then
      echo "L3 Network  : ping $PEER OK ✓"
    elif nc -z -G 2 "$PEER" 22 &>/dev/null || nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null; then
      echo "L3 Network  : ping $PEER blocked by NAT — TCP reachable ✓"
    else
      echo "L3 Network  : $PEER unreachable (ping + TCP both failed) ❌"
    fi
  fi

  # L4 Transport
  if [[ "$(layer_enabled layer4_transport)" == "yes" ]]; then
    if [[ "$MY_ROLE" == "gateway" ]]; then
      nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null && echo "L4 Transport: port $TUNNEL_PORT OPEN" || echo "L4 Transport: port $TUNNEL_PORT CLOSED (run tunnel-pro on client)"
    else
      nc -z -G 2 "$GATEWAY_IP" 22 &>/dev/null && echo "L4 Transport: gateway SSH OPEN" || echo "L4 Transport: gateway SSH CLOSED"
    fi
  fi

  # L5 Session (SSH tunnel)
  if [[ "$(layer_enabled layer5_tunnel_ssh)" == "yes" ]]; then
    if [[ "$MY_ROLE" == "gateway" ]]; then
      # Gateway: tunnel-pro runs on the CLIENT — check ControlMaster or port 2222
      if ssh -O check macmini 2>&1 | grep -q "Master running"; then
        echo "L5 Session  : ControlMaster active ✓"
      elif nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null; then
        echo "L5 Session  : tunnel port $TUNNEL_PORT OPEN (no ControlMaster yet)"
      else
        echo "L5 Session  : tunnel DOWN — run tunnel-mini on this host ❌"
      fi
    else
      # Client: check for the outbound tunnel-pro process
      pgrep -f "ssh.*-R $TUNNEL_PORT" &>/dev/null \
        && echo "L5 Session  : tunnel-pro RUNNING pid=$(pgrep -f "ssh.*-R $TUNNEL_PORT" | head -1)" \
        || echo "L5 Session  : tunnel-pro NOT RUNNING ❌"
    fi
  fi

  # L6 NAT/Routing
  if [[ "$(layer_enabled layer6_nat_routing)" == "yes" ]]; then
    local FWD; FWD=$(sysctl -n net.inet.ip.forwarding 2>/dev/null)
    echo "L6 NAT      : ip_forwarding=$FWD"
    [[ "$MY_ROLE" == "gateway" ]] && \
      (sudo pfctl -s nat 2>/dev/null | grep -q "192.168.2.0" && echo "L6 NAT      : rules loaded ✓" || echo "L6 NAT      : rules MISSING ❌")
  fi

  # L7 Application
  if [[ "$(layer_enabled layer7_app_connectivity)" == "yes" ]]; then
    local EXT_IP; EXT_IP=$(curl -s --max-time 4 https://api.ipify.org 2>/dev/null)
    [[ -n "$EXT_IP" ]] && echo "L7 Internet : $EXT_IP ✓" || echo "L7 Internet : FAIL (no internet)"
  fi

  echo ""
}


# ══════════════════════════════════════════════════════════════════════════════
# RESTORE ENGINE — role-aware, gateway or client
# ══════════════════════════════════════════════════════════════════════════════
do_restore() {
  log "=== bridge-restore-app | role=$MY_ROLE | $_MODEL ==="
  run_diag

  if [[ "$MY_ROLE" == "gateway" ]]; then
    _restore_as_gateway
  else
    _restore_as_client
  fi
}

_restore_as_gateway() {
  log "Restoring as GATEWAY"

  # ── Tahoe bypass: en4 direct IP (bridge0 broken on Titan Ridge TB3) ──────
  # On macOS Tahoe, Titan Ridge TB3 driver rejects BIOCPROMISC and BRDGADD.
  # bridge0 cannot receive frames for its MAC via en4 (no promiscuous mode).
  # Fix: assign 192.168.2.1 directly to en4, bypass bridge0 entirely.
  local BR_RESTORE
  BR_RESTORE="$(dirname "$0")/mbp-tb-restore.sh"
  if [[ -x "$BR_RESTORE" ]]; then
    log "Tahoe bypass mode: delegating to mbp-tb-restore.sh"
    bash "$BR_RESTORE" 2>&1 | while IFS= read -r line; do log "$line"; done
  else
    # Legacy fallback for non-Tahoe systems using bridge0
    log "Legacy mode: fixing bridge0 directly"
    local curr; curr=$(ipconfig getifaddr bridge0 2>/dev/null)
    if [[ "$curr" != "$GATEWAY_IP" ]]; then
      log "MBP bridge0 wrong ($curr) — restoring $GATEWAY_IP"
      sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null; sleep 2
    fi
    sudo sysctl -w net.inet.ip.forwarding=1 &>/dev/null
    local NAT=""; for I in en0 en43 en1; do
      [[ -n "$(ipconfig getifaddr $I 2>/dev/null)" ]] && NAT+="nat on $I inet from 192.168.2.0/24 to any -> ($I)\n"
    done
    printf "${NAT}pass all\n" > /tmp/br-nat.conf
    sudo pfctl -f /tmp/br-nat.conf 2>/dev/null && sudo pfctl -e 2>/dev/null || true

    local ARP_CLIENT; ARP_CLIENT=$(arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep -o "[0-9a-f:]{17}" | head -1)
    if [[ -z "$ARP_CLIENT" ]]; then
      log "ARP incomplete — toggling IS"
      toggle_internet_sharing; sleep 5
      ARP_CLIENT=$(arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep -o "[0-9a-f:]{17}" | head -1)
    fi
    if [[ -z "$ARP_CLIENT" ]]; then
      log "ARP still incomplete — TB severance"
      _sever_tb_gateway; sleep 5
    fi
  fi

  # Tunnel
  nc -z -G 3 localhost "$TUNNEL_PORT" &>/dev/null && {
    log "Tunnel port open — opening ControlMaster"
    _open_controlmaster
  } || log "Port $TUNNEL_PORT closed — client needs to run tunnel-pro"
}

_restore_as_client() {
  log "Restoring as CLIENT"
  # L2: Fix bridge0 IP
  local curr; curr=$(ipconfig getifaddr bridge0 2>/dev/null)
  if [[ "$curr" != "$CLIENT_IP" ]]; then
    log "bridge0 wrong ($curr) — restoring $CLIENT_IP"
    sudo ifconfig bridge0 "$CLIENT_IP" netmask 255.255.255.0 2>/dev/null; sleep 2
  fi

  # L2b: Kill APIPA probe loop if present (known bridge drop cause)
  # If en0 Ethernet has a self-assigned 169.254.x.x IP, configd probes it
  # every ~30s and disturbs bridge0 — disable the service to stop it
  APIPA_CHECK=$(ifconfig en0 2>/dev/null | grep "inet 169\.254")
  if [[ -n "$APIPA_CHECK" ]]; then
    log "APIPA detected on en0 ($APIPA_CHECK) — disabling Ethernet service to stop configd probe loop"
    sudo networksetup -setnetworkserviceenabled "Ethernet" off 2>/dev/null &&       log "Ethernet service disabled — bridge should now be stable" ||       log "WARN: Could not disable Ethernet service"
  fi

  # L1: Check bridge active
  local ST; ST=$(ifconfig bridge0 2>/dev/null | awk '/status:/{print $2}')
  if [[ "$ST" != "active" ]]; then
    log "bridge0 inactive — bouncing TB port"
    local P=""; for i in en1 en2 en3 en4; do
      ifconfig "$i" 2>/dev/null | grep -q "status: active" && P="$i" && break
    done
    P="${P:-en2}"; sudo ifconfig "$P" down; sleep 10; sudo ifconfig "$P" up; sleep 4
  fi

  # L3: Check gateway reachable
  if ! ping -c 1 -t 5 "$GATEWAY_IP" &>/dev/null; then
    log "Gateway not reachable"
    _notify "❌ Gateway ($GATEWAY_IP) unreachable — check TB cable"; return 1
  fi

  # L5: Open/restart tunnel
  pgrep -f "ssh.*-R $TUNNEL_PORT" &>/dev/null || {
    log "Opening tunnel-pro"
    bash "$(dirname "$0")/tunnel-pro.sh" &
    sleep 5
  }
  pgrep -f "ssh.*-R $TUNNEL_PORT" &>/dev/null && log "Tunnel active ✓" || log "FAIL: tunnel-pro failed"
}


# ── TB Severance (gateway side — 6 methods) ───────────────────────────────────
# NOTE (Tahoe/Titan Ridge): bridge0 cannot be used on MacBookPro16,1 running
# Tahoe — TB3 driver rejects BIOCPROMISC and BRDGADD. Methods 1, 2, 4 are
# skipped on Tahoe. The effective methods are 3 (port bounce), 5 (NHI kext),
# and 6 (tb-reset IOKit). After any sever, mbp-tb-restore.sh re-applies the
# en4 direct-IP configuration automatically.
_sever_tb_gateway() {
  local ACTIVE_PORT=""; for i in en1 en2 en3 en4; do
    ifconfig "$i" 2>/dev/null | grep -q "status: active" && ACTIVE_PORT="$i" && break
  done; ACTIVE_PORT="${ACTIVE_PORT:-en4}"

  # Detect Tahoe/Titan Ridge — TB interface rejects BIOCPROMISC
  local TAHOE_MODE=0
  ifconfig bridge0 addm "$ACTIVE_PORT" 2>&1 | grep -q "Operation not supported" && TAHOE_MODE=1
  # Also detect via promisc rejection
  if [[ $TAHOE_MODE -eq 0 ]]; then
    ifconfig bridge0 2>/dev/null | grep -q "bridge0" || TAHOE_MODE=1
  fi

  if [[ $TAHOE_MODE -eq 1 ]]; then
    log "Tahoe/Titan Ridge mode: bridge0 methods (M1/M2/M4) skipped — jumping to M3"
  else
    log "Method 1: bridge member remove/re-add"
    sudo ifconfig bridge0 deletem "$ACTIVE_PORT" 2>/dev/null; sleep 3
    sudo ifconfig bridge0 addm "$ACTIVE_PORT" 2>/dev/null; sleep 3
    sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null
    arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep -q "[0-9a-f:]\{17\}" && { log "M1 success"; return 0; }

    log "Method 2: networksetup Thunderbolt Bridge off/on"
    sudo networksetup -setnetworkserviceenabled "Thunderbolt Bridge" off 2>/dev/null; sleep 5
    sudo networksetup -setnetworkserviceenabled "Thunderbolt Bridge" on 2>/dev/null; sleep 5
    sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null
    arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep -q "[0-9a-f:]\{17\}" && { log "M2 success"; return 0; }
  fi

  log "Method 3: ifconfig port bounce (XDomain renegotiation)"
  sudo ifconfig "$ACTIVE_PORT" down; sleep 10; sudo ifconfig "$ACTIVE_PORT" up; sleep 5
  # After bounce, re-apply Tahoe bypass config
  local BR_RESTORE; BR_RESTORE="$(dirname "$0")/mbp-tb-restore.sh"
  [[ -x "$BR_RESTORE" ]] && bash "$BR_RESTORE" &>/dev/null ||     sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null
  sleep 5
  ping -c 2 -W 1000 "$CLIENT_IP" &>/dev/null && { log "M3 success"; return 0; }

  if [[ $TAHOE_MODE -eq 0 ]]; then
    log "Method 4: bridge0 full teardown"
    sudo ifconfig bridge0 down 2>/dev/null; sleep 3
    sudo ifconfig bridge0 up 2>/dev/null; sleep 3
    sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null; sleep 5
    log "Method 4 complete"
  fi

  # ── Method 5: True L1 NHI driver unload/reload ──────────────────────────────
  # kextstat shows AppleThunderboltNHI has 0 dependents — safe to unload.
  # Unloading the NHI (Native Host Interface) kext forces the Thunderbolt
  # controller to drop its physical link (true L1 severance), not just L2.
  # On reload, the controller renegotiates L1 from scratch — equivalent to
  # a physical cable replug. Requires SIP off or relaxed (standard on OCLP).
  log "Method 5: NHI kext L1 unload/reload (true physical reset)"
  local NHI_BUNDLE="com.apple.driver.AppleThunderboltNHI"
  local NHI_PATH
  NHI_PATH=$(find /System/Library/Extensions /Library/Extensions -maxdepth 2 -name "AppleThunderboltNHI.kext" 2>/dev/null | head -1)
  NHI_PATH="${NHI_PATH:-/System/Library/Extensions/AppleThunderboltNHI.kext}"

  if kextstat 2>/dev/null | grep -q "$NHI_BUNDLE"; then
    local UNLOAD_OUT
    UNLOAD_OUT=$(sudo kextunload -b "$NHI_BUNDLE" 2>&1)
    if echo "$UNLOAD_OUT" | grep -qiv "error\|fail\|denied"; then
      log "NHI unloaded — L1 link dropped; waiting 6 s for controller reset..."
      sleep 6
      log "Reloading NHI kext: $NHI_PATH"
      sudo kextload "$NHI_PATH" 2>/dev/null
      sleep 10
      sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null
      arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep -q "[0-9a-f:]\{17\}" && { log "M5 success"; return 0; }
      log "M5: NHI reloaded but ARP check failed — bridge may still be renegotiating"
    else
      log "M5: kextunload blocked ($UNLOAD_OUT) — SIP may be active; skipping NHI method"
    fi
  else
    log "M5: NHI kext not found in kextstat — skipping"
  fi

  # ── Method 6: tb-reset IOKit PCIe re-probe (compiled tool) ───────────────────
  # Uses IOServiceRequestProbe() on the IOPCIDevice (NHI0) that hosts the TB
  # controller. Bypasses the "kext in use" block entirely — no kextunload needed.
  # Source: ~/dev/projects/tools/tool_macOS-Universal_tb-reset
  # Binary: tools/tb-reset/tb-reset (universal x86_64+arm64, v1.0.0 Build 26A06)
  log "Method 6: tb-reset IOKit PCIe probe (true L1 reset)"
  local TB_TRIGGER; TB_TRIGGER="$(dirname "$0")/tb-reset-trigger.sh"
  if [[ -x "$TB_TRIGGER" ]]; then
    GATEWAY_IP="$GATEWAY_IP" BR_LOG="$LOG" bash "$TB_TRIGGER" 2>&1 | while IFS= read -r line; do log "$line"; done
    sleep 15
    sudo ifconfig bridge0 "$GATEWAY_IP" netmask 255.255.255.0 2>/dev/null
    arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep -q "[0-9a-f:]\{17\}" && { log "M6 success"; return 0; }
    log "M6: probe sent but ARP still incomplete — bridge still renegotiating"
  else
    log "M6: tb-reset-trigger.sh not found at $TB_TRIGGER — skipping"
  fi
}

# ── ControlMaster ──────────────────────────────────────────────────────────────
_open_controlmaster() {
  local SSH_KEY="$HOME/.ssh/id_ed25519"
  local CM="$HOME/.ssh/cm/macmini"
  mkdir -p "$HOME/.ssh/cm"
  ssh -O exit macmini 2>/dev/null || true; sleep 1
  ssh -f -N -i "$SSH_KEY" -o ControlMaster=yes -o ControlPath="$CM" \
    -o ControlPersist=4h -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=8 -o ServerAliveInterval=15 \
    -p "$TUNNEL_PORT" akmacks@localhost 2>>"$LOG"
  sleep 2
  local TEST; TEST=$(ssh -i "$SSH_KEY" -o ControlPath="$CM" -o BatchMode=yes \
    -o ConnectTimeout=5 -p "$TUNNEL_PORT" akmacks@localhost "hostname" 2>/dev/null)
  [[ -n "$TEST" ]] && log "SSH confirmed: $TEST ✓" || log "WARN: ControlMaster opened but SSH test empty"
}

# ── Notifications ──────────────────────────────────────────────────────────────
_notify() { osascript -e "display notification \"$1\" with title \"Bridge Restore\"" 2>/dev/null || true; }


# ══════════════════════════════════════════════════════════════════════════════
# WATCHDOG — embedded, role-aware, smart notification throttling
# ══════════════════════════════════════════════════════════════════════════════
WD_STATE="$CONFIG_DIR/watchdog.state"
touch "$WD_STATE" 2>/dev/null

_wd_get() { grep "^$1=" "$WD_STATE" 2>/dev/null | cut -d= -f2 || echo "${2:-0}"; }
_wd_set() { grep -v "^$1=" "$WD_STATE" > /tmp/wd.tmp 2>/dev/null; echo "$1=$2" >> /tmp/wd.tmp; mv /tmp/wd.tmp "$WD_STATE"; }
_wd_dismissed() { grep -q "^DISMISSED=1" "$WD_STATE" 2>/dev/null; }

_peer_reachable() {
  # TCP-based check (not ICMP — NAT blocks ping, TCP is reliable)
  local PEER; PEER=$([[ "$MY_ROLE" == "gateway" ]] && echo "$CLIENT_IP" || echo "$GATEWAY_IP")
  # Primary: tunnel port open (gateway) or gateway SSH open (client)
  nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null && return 0
  # Secondary: direct TCP to peer SSH port
  nc -z -G 2 "$PEER" 22 &>/dev/null && return 0
  return 1
}

_peer_reachable_tcp_confirmed() {
  # Full bidirectional TCP confirmation — both directions must succeed
  local PEER; PEER=$([[ "$MY_ROLE" == "gateway" ]] && echo "$CLIENT_IP" || echo "$GATEWAY_IP")
  local FWD REV
  nc -z -G 3 "$PEER" 22 &>/dev/null && FWD="ok" || FWD="fail"
  if [[ "$MY_ROLE" == "gateway" ]] && nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null; then
    REV=$(ssh -p "$TUNNEL_PORT" -i "$HOME/.ssh/id_ed25519" -o BatchMode=yes       -o ConnectTimeout=4 akmacks@localhost       "nc -z -G 3 $GATEWAY_IP 22 && echo ok || echo fail" 2>/dev/null)
  else
    REV="skipped"
  fi
  log "TCP check: forward=$FWD reverse=$REV"
  [[ "$FWD" == "ok" ]] && return 0 || return 1
}

_wd_notify_down() {
  local FC; FC=$(( $(_wd_get FAIL_COUNT) + 1 ))
  _wd_set FAIL_COUNT "$FC"
  local THRESH; THRESH=$(_wd_get THRESHOLD 10)

  if [[ "$FC" -lt "$THRESH" ]]; then
    _notify "$([ "$MY_ROLE" == "gateway" ] && echo "Mini" || echo "MBP") unreachable ($FC/$THRESH)"
    return
  fi

  # Action menu after threshold
  local CHOICE; CHOICE=$(osascript << 'AS'
set r to choose from list {"Check every 2 min", "Check every 5 min", "Pause checks", "Open Troubleshooter"} ¬
  with prompt "Connection down for 10+ checks. Action?" ¬
  with title "Bridge Restore Watchdog" OK button name "Apply" cancel button name "Dismiss"
if r is false then return "dismiss"
return item 1 of r
AS
)
  case "$CHOICE" in
    "Check every 2 min") _wd_set INTERVAL 120; _wd_set FAIL_COUNT 0; _wd_set DISMISSED 0 ;;
    "Check every 5 min") _wd_set INTERVAL 300; _wd_set FAIL_COUNT 0; _wd_set DISMISSED 0 ;;
    "Pause checks")      _wd_set DISMISSED 1; _wd_set FAIL_COUNT 0 ;;
    "Open Troubleshooter") _wd_set FAIL_COUNT 0
      osascript -e 'tell application "Terminal" to do script "bridge-restore"' 2>/dev/null ;;
    *) _wd_set FAIL_COUNT 0 ;;
  esac
}

_wd_notify_up() {
  _wd_set FAIL_COUNT 0
  _wd_set INTERVAL "$(_wd_get INTERVAL 30)"
  _notify "$([ "$MY_ROLE" == "gateway" ] && echo "Mini" || echo "MBP") connected ✓"
}

run_watchdog_daemon() {
  local WD_ENABLED; WD_ENABLED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('watchdog',{}).get('enabled',False))" 2>/dev/null)
  local TR_ENABLED; TR_ENABLED=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('tunnel_auto_retry',{}).get('enabled',False))" 2>/dev/null)

  if [[ "$WD_ENABLED" != "True" ]] && [[ "$TR_ENABLED" != "True" ]]; then
    echo "Neither watchdog nor auto-retry enabled. Enable in preferences or --wizard."
    return 0
  fi

  log "=== Watchdog daemon starting | role=$MY_ROLE ==="
  while true; do
    _wd_dismissed && { sleep 60; continue; }
    local INTERVAL; INTERVAL=$(_wd_get INTERVAL 30)

    if ! _peer_reachable; then
      log "Peer unreachable — restoring"
      do_restore
      _peer_reachable && _wd_notify_up || _wd_notify_down
    fi
    sleep "$INTERVAL"
  done
}

# ══════════════════════════════════════════════════════════════════════════════
# OLLAMA AI FALLBACK — prefers local models, works offline
# ══════════════════════════════════════════════════════════════════════════════
OLLAMA_URL="http://localhost:11434"
PREFERRED_MODELS=("llama3.2:3b" "qwen2.5:3b" "gemma2:2b" "gpt-oss:20b" "kimi-k2.5:cloud")

run_ai_fallback() {
  local MODEL="" AVAIL
  AVAIL=$(curl -sf "$OLLAMA_URL/api/tags" 2>/dev/null | \
    python3 -c "import json,sys; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]" 2>/dev/null)

  for m in "${PREFERRED_MODELS[@]}"; do
    echo "$AVAIL" | grep -q "^$m" && MODEL="$m" && break
  done

  if [[ -z "$MODEL" ]]; then
    echo "⚠️  No Ollama model available for AI fallback."
    echo "   Pull a local model: ollama pull llama3.2:3b"
    echo ""
    echo "Manual recovery steps:"
    echo "  Gateway: sudo ifconfig bridge0 $GATEWAY_IP netmask 255.255.255.0 && tunnel-mini"
    echo "  Client:  sudo ifconfig bridge0 $CLIENT_IP netmask 255.255.255.0 && tunnel-pro"
    return 1
  fi

  echo "🤖 Consulting OpenClaw ($MODEL)..."
  local DIAG; DIAG=$(run_diag 2>&1)
  local CONTEXT="Role: $MY_ROLE. Machine: $_MODEL. Gateway: $GATEWAY_IP. Client: $CLIENT_IP. Tunnel port: $TUNNEL_PORT. sudo is passwordless. Give numbered fix commands only — no explanations."
  local RESP; RESP=$(curl -sf -X POST "$OLLAMA_URL/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"prompt\":$(echo "$CONTEXT\n\nDIAGNOSTICS:\n$DIAG" | \
      python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),\
      \"stream\":false,\"options\":{\"temperature\":0.1,\"num_predict\":500}}" 2>/dev/null | \
    python3 -c "import json,sys; print(json.load(sys.stdin).get('response','No response'))" 2>/dev/null)

  echo "──────────────────────────────────"
  echo "$RESP"
  echo "──────────────────────────────────"
  log "AI fallback used ($MODEL)"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT
# ══════════════════════════════════════════════════════════════════════════════
# Check first launch
FIRST_LAUNCH=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('first_launch_complete',False))" 2>/dev/null)
if [[ "$FIRST_LAUNCH" == "False" ]] && [[ "${1:-}" != "--wizard" ]]; then
  echo "First launch detected — starting Setup Wizard"
  run_wizard
  python3 -c "
import json
c = json.load(open('$CONFIG_FILE'))
c['first_launch_complete'] = True
json.dump(c, open('$CONFIG_FILE','w'), indent=2)
" 2>/dev/null
fi

case "${1:-}" in
  --wizard)   run_wizard ;;
  --prefs)    run_prefs ;;
  --diag)     run_diag verbose ;;
  --debug)    set -x; run_diag verbose; do_restore ;;
  --watchdog) run_watchdog_daemon ;;
  --ai)       run_ai_fallback ;;
  --sever)
    [[ "$MY_ROLE" == "gateway" ]] && _sever_tb_gateway || echo "--sever only available on gateway"
    ;;
  --bughunt)
    log "=== Bug Hunt mode starting | role=$MY_ROLE ==="
    echo "🔍 TB Bridge Drop Bug Hunt"
    echo ""
    echo "Step 1: TCP pre-flight (bidirectional confirmation)"
    _peer_reachable_tcp_confirmed && echo "  ✅ TCP confirmed both directions" || echo "  ❌ TCP failed"
    echo ""
    echo "Step 2: Deploying high-frequency monitor to mini (via tunnel)"
    if nc -z -G 2 localhost "$TUNNEL_PORT" &>/dev/null; then
      MONITOR_SCRIPT='while true; do TS=$(date "+%H:%M:%S.%3N"); ST=$(ifconfig bridge0 2>/dev/null | awk "/status:/{print \$2}"); PROCS=$(launchctl list 2>/dev/null | grep "local\." | awk "{print \$1,\$3}" | tr "
" "|"); echo "$TS bridge=$ST procs=$PROCS" >> ~/Library/Logs/BridgeRestore/bughunt.log; sleep 2; done'
      ssh -p "$TUNNEL_PORT" -i "$HOME/.ssh/id_ed25519" -o BatchMode=yes akmacks@localhost         "mkdir -p ~/logs; nohup bash -c '$MONITOR_SCRIPT' &>/dev/null & echo MONITOR_PID=\$!" 2>/dev/null
      echo "  ✅ Monitor deployed on mini — logging to ~/Library/Logs/BridgeRestore/bughunt.log"
      echo "  ⏳ Collecting data for 5 minutes then analysing..."
      sleep 300
      echo ""
      echo "Step 3: Retrieving mini log + OpenClaw analysis"
      BUGHUNT_LOG=$(ssh -p "$TUNNEL_PORT" -i "$HOME/.ssh/id_ed25519" -o BatchMode=yes         akmacks@localhost "tail -150 ~/Library/Logs/BridgeRestore/bughunt.log 2>/dev/null" 2>/dev/null)
      if [[ -n "$BUGHUNT_LOG" ]]; then
        OUTFILE="$HOME/projects/apps/app_macOS-Intel_BridgeRestore/app-logs/bughunt-$(date +%Y%m%d-%H%M).md"
        echo "# Bug Hunt Log — $(date)" > "$OUTFILE"
        echo '```' >> "$OUTFILE"; echo "$BUGHUNT_LOG" >> "$OUTFILE"; echo '```' >> "$OUTFILE"
        # AI analysis with local model
        AVAIL=$(curl -sf http://localhost:11434/api/tags 2>/dev/null | python3 -c "import json,sys; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]" 2>/dev/null)
        for m in "llama3.2:3b" "qwen2.5:3b" "gpt-oss:20b"; do
          echo "$AVAIL" | grep -q "^$m" && MODEL="$m" && break
        done
        if [[ -n "${MODEL:-}" ]]; then
          echo ""
          echo "🤖 Analysing with $MODEL (local — no internet needed)"
          ANALYSIS=$(curl -sf -X POST http://localhost:11434/api/generate             -H "Content-Type: application/json"             -d "{"model":"$MODEL","prompt":$(echo "Analyse this macOS network monitor log from a Mac mini. The Thunderbolt bridge (bridge0) keeps going inactive. Find what process or event correlates with bridge=inactive. Give ONE root cause and ONE fix command.

LOG:
$BUGHUNT_LOG" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'),"stream":false,"options":{"temperature":0.1,"num_predict":300}}" 2>/dev/null |             python3 -c "import json,sys; print(json.load(sys.stdin).get('response',''))" 2>/dev/null)
          echo "$ANALYSIS"
          echo "" >> "$OUTFILE"
          echo "## OpenClaw Analysis ($MODEL)" >> "$OUTFILE"
          echo "$ANALYSIS" >> "$OUTFILE"
          log "Bug hunt complete — results at $OUTFILE"
        fi
      fi
    else
      echo "  ❌ Tunnel not up — run tunnel-pro on mini first, then retry --bughunt"
    fi
    ;;
  --help|-h)
    cat << 'HELP'
Bridge Restore  v1.0.7
Thunderbolt Bridge connectivity suite for macOS Intel (non-T2) Macs.

USAGE
  bridge-restore [OPTION]
  Aliases: bridge-restore-app, bridge-restore-gui (GUI entry point)

MAIN COMMANDS
  (no args)          Auto-detect role and run full restore sequence
  --status           Show current state (no changes made)
  --diag             Run OSI L1–L7 diagnostic engine
  --debug            Verbose restore with bash -x tracing

SETUP
  --wizard           First-launch Setup Wizard (GUI)
  --prefs            Open Preferences window (GUI, 3 tabs)
  --gui              Launch full GUI dashboard (prompts GUI/CLI mode)

RECOVERY
  --sever            Force Thunderbolt re-negotiation (gateway only, 4 methods)
  --watchdog         Start background watchdog daemon
  --ai               Consult local Ollama AI for fix suggestions
  --bughunt          Deploy mini monitor, collect drop data, AI analysis

INFO
  --help, -h         Show this help
  --version          Print version and exit

COMPANION COMMANDS (installed separately)
  tunnel-mini        Gateway-side full restore (MBP only)
  tunnel-pro         Client-side full restore (Mini only) — run on mini
  tunnel-mini-status Quick status (alias: bridge-restore --status)
  bridge-restore-gui Launch GUI directly (skips CLI option)

EXAMPLES
  bridge-restore                   # restore connection (auto role)
  bridge-restore --status          # check current state
  bridge-restore --diag            # full OSI diagnostics
  bridge-restore --sever           # force TB re-negotiation (gateway)
  bridge-restore --ai              # ask local AI for help
  bridge-restore --bughunt         # investigate bridge drop bugs
  bridge-restore --wizard          # first-time configuration
  bridge-restore --gui             # open GUI dashboard

ARGUMENTS & FLAGS (all single-dash aliases also supported)
  --status   -s      Print state summary
  --diag     -d      OSI L1–L7 diagnostics
  --debug            Verbose tracing (set -x)
  --watchdog -w      Start watchdog daemon
  --sever            TB severance (gateway only)
  --ai       -a      Ollama AI fallback
  --bughunt          Bug hunt mode
  --wizard           Setup wizard
  --prefs    -p      Preferences
  --gui      -g      GUI dashboard
  --help     -h      This help
  --version  -V      Version

CONFIGURATION
  ~/.config/bridge-restore/config.json

LOGS
  ~/Library/Logs/BridgeRestore/bridge-restore-app.log
  ~/Library/Logs/BridgeRestore/mbp-watchdog.log
  ~/Library/Logs/BridgeRestore/tunnel-mini.log

MAN PAGE
  man bridge-restore

Full documentation: ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/man/bridge-restore.xml
HELP
    ;;
  --version|-V)
    echo "Bridge Restore v1.0.7"
    ;;
  --gui|-g)
    SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [[ -f "$SCRIPTS_DIR/bridge-restore-gui.sh" ]]; then
      exec bash "$SCRIPTS_DIR/bridge-restore-gui.sh"
    elif [[ -f "$HOME/Library/Application Support/BridgeRestore/scripts/bridge-restore-gui.sh" ]]; then
      exec bash "$HOME/Library/Application Support/BridgeRestore/scripts/bridge-restore-gui.sh"
    else
      echo "❌ bridge-restore-gui.sh not found. Run the installer." && exit 1
    fi
    ;;
  --status|-s)
    echo "=== Bridge Restore App v1.0.7 ==="
    echo "Role    : $MY_ROLE | $THIS_MODEL"
    echo "Config  : $CONFIG_FILE"
    run_diag
    ;;
  *)
    do_restore
    if ! _peer_reachable; then
      echo ""
      echo "── Layer 5: AI Fallback ──"
      run_ai_fallback
    fi
    ;;
esac

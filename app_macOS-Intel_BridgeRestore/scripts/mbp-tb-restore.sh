#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  MBP TB RESTORE  v1.0.0 (Build 26A07)                                   ║
# ║  GATEWAY SIDE — MacBook Pro i9 (MacBookPro16,1)                         ║
# ║                                                                          ║
# ║  Fixes Thunderbolt Bridge after cable replug on macOS Tahoe.            ║
# ║  Root cause: Titan Ridge TB3 driver rejects promiscuous mode,            ║
# ║  breaking bridge0. Fix: assign 192.168.2.1 directly to en4,             ║
# ║  add route and NAT rules.                                                ║
# ║                                                                          ║
# ║  Run via launchd or manually after cable replug.                         ║
# ╚══════════════════════════════════════════════════════════════════════════╝

GATEWAY_IP="192.168.2.1"
CLIENT_IP="192.168.2.2"
CLIENT_MAC="82:0c:4d:eb:46:81"
SUBNET="192.168.2.0/24"
LOG="$HOME/Library/Logs/BridgeRestore/mbp-tb-restore.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [mbp-tb-restore] $*" | tee -a "$LOG"; }

find_active_tb() {
    for iface in en1 en2 en3 en4 en5 en6; do
        STATUS=$(ifconfig "$iface" 2>/dev/null | awk '/status:/{print $2}')
        MAC=$(ifconfig "$iface" 2>/dev/null | awk '/ether/{print $2}')
        # TB interfaces use Apple sequential MACs 82:93:89:41:c8:xx
        if [[ "$STATUS" == "active" && "$MAC" == 82:93:89:41:* ]]; then
            echo "$iface"
            return 0
        fi
    done
    return 1
}

log "Starting TB restore..."

# Find active TB interface
ACTIVE_TB=$(find_active_tb)
if [[ -z "$ACTIVE_TB" ]]; then
    log "WARN: No active TB interface found — waiting 10s"
    sleep 10
    ACTIVE_TB=$(find_active_tb)
    [[ -z "$ACTIVE_TB" ]] && { log "FAIL: No TB interface after wait"; exit 1; }
fi
log "Active TB interface: $ACTIVE_TB"

# Assign gateway IP directly to TB interface
CURRENT_IP=$(ifconfig "$ACTIVE_TB" 2>/dev/null | awk '/inet /{print $2}')
if [[ "$CURRENT_IP" != "$GATEWAY_IP" ]]; then
    log "Assigning $GATEWAY_IP to $ACTIVE_TB"
    sudo ifconfig "$ACTIVE_TB" "$GATEWAY_IP" netmask 255.255.255.0 up
fi

# Fix route: ensure 192.168.2.0/24 routes via TB interface, not bridge0
ROUTE_IF=$(netstat -rn 2>/dev/null | awk '/^192\.168\.2/{print $NF}' | head -1)
if [[ "$ROUTE_IF" != "$ACTIVE_TB" ]]; then
    log "Fixing route: $SUBNET via $ACTIVE_TB (was $ROUTE_IF)"
    sudo route delete "$SUBNET" 2>/dev/null
    sudo route add "$SUBNET" -interface "$ACTIVE_TB"
fi

# Seed ARP entry for mini
ARP_ENTRY=$(arp -n "$CLIENT_IP" 2>/dev/null | grep -v incomplete | grep "$CLIENT_MAC")
if [[ -z "$ARP_ENTRY" ]]; then
    log "Seeding ARP: $CLIENT_IP → $CLIENT_MAC"
    sudo arp -d "$CLIENT_IP" 2>/dev/null
    sudo arp -s "$CLIENT_IP" "$CLIENT_MAC"
fi

# Enable IP forwarding
sudo sysctl -w net.inet.ip.forwarding=1 > /dev/null 2>&1

# NAT: share internet to 192.168.2.0/24
# Works with en43 (Belkin USB-C LAN) or en0 (Wi-Fi) as uplink
log "Applying NAT rules"
printf 'nat on en43 from 192.168.2.0/24 to any -> (en43)\nnat on en0 from 192.168.2.0/24 to any -> (en0)\npass all\n' \
    | sudo pfctl -f - 2>/dev/null
sudo pfctl -e 2>/dev/null

# Verify
sleep 2
PING_RESULT=$(ping -c 2 -W 1000 "$CLIENT_IP" 2>&1 | tail -1)
log "Ping to mini: $PING_RESULT"
ping -c 2 -W 1000 "$CLIENT_IP" > /dev/null 2>&1 && \
    log "TB RESTORE OK — $GATEWAY_IP ↔ $CLIENT_IP ✓" || \
    log "WARN: ping still failing — manual check needed"

exit 0

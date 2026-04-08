#!/bin/bash
# reconnect-mini.sh - restore connection + internet to Mac mini
# REVERSE TUNNEL METHOD - reliable regardless of bridge/ARP issues
#
# STEP 1 - On mini terminal first run: tunnel-pro
# STEP 2 - Then run this script on MBP (or just run: tunnel-mini)

echo "[1/3] Enabling NAT + IP forwarding..."
sudo sysctl -w net.inet.ip.forwarding=1

# NAT on ALL active uplink interfaces (en0=Wi-Fi, en43=Belkin USB-C LAN)
# Detect active uplinks dynamically and NAT on each
NAT_RULES=""
for IFACE in en0 en43 en1; do
  IP=$(ipconfig getifaddr $IFACE 2>/dev/null)
  if [[ -n "$IP" ]] && [[ "$IFACE" != "bridge0" ]]; then
    NAT_RULES+="nat on $IFACE inet from 192.168.2.0/24 to any -> ($IFACE)\n"
    echo "  NAT on $IFACE ($IP)"
  fi
done
printf "${NAT_RULES}pass all\n" > /tmp/mini-nat.conf
sudo pfctl -f /tmp/mini-nat.conf && sudo pfctl -e 2>/dev/null || true
echo "  NAT rules loaded"

echo "[2/3] Opening ControlMaster via reverse tunnel..."
ssh -O exit macmini 2>/dev/null || true
ssh -f -N -i ~/.ssh/id_ed25519 \
  -o ControlMaster=yes -o ControlPath=~/.ssh/cm/macmini \
  -o ControlPersist=2h -o StrictHostKeyChecking=accept-new \
  -p 2222 akmacks@localhost

echo "[3/3] Testing SSH + internet on mini..."
ssh -i ~/.ssh/id_ed25519 -o ControlPath=~/.ssh/cm/macmini \
  -p 2222 akmacks@localhost \
  "hostname && curl -s --max-time 4 https://api.ipify.org && echo ' (internet OK)' || echo ' (internet FAIL)'"
echo ""
echo "Ready. Use: ssh-mini"

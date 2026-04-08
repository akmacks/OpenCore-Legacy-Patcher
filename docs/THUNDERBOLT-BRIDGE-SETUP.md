# Thunderbolt Bridge Ñ Mac mini to MacBook Pro Connection Guide
## Project: OpenClaw / OCLP 3.0.0 Dev  |  Last verified: 2026-03-27

---

## Machine Reference
| Item               | Value                        |
|--------------------|------------------------------|
| MBP hostname       | MacBook-Pro-i9               |
| MBP bridge0 IP     | 192.168.2.1                  |
| MBP en4 IP         | 192.168.2.1 (active TB port) |
| Mini hostname      | Mac-mini-Server-i7           |
| Mini bridge0 IP    | 192.168.2.2 (static)         |
| Mini bridge0 MAC   | 82:0c:4d:eb:46:81            |
| SSH alias (MBP)    | macmini (port 2222, localhost)|
| SSH alias (mini)   | pro (192.168.2.1)            |
| SSH key (MBP)      | ~/.ssh/id_ed25519             |
| SSH key (mini)     | ~/.ssh/id_ed25519             |
| ControlMaster      | ~/.ssh/cm/macmini            |

---

## RELIABLE METHOD Ñ Reverse SSH Tunnel (USE THIS)

The bridge0/ARP/pf approach is unreliable. The reverse tunnel always works
because the mini initiates the connection to the MBP (ARD proves this direction
is always stable). The MBP then SSHes back through the tunnel.

### Step 1 Ñ On mini terminal:
  tunnel-pro
  (located at /usr/local/bin/tunnel-pro and ~/tunnel-pro.sh)
  This runs: ssh -R 2222:localhost:22 pro
  Leave this terminal open Ñ closing it kills the tunnel.

### Step 2 Ñ On MBP (or Claude via Desktop Commander):
  ~/scripts/reconnect-mini.sh
  This runs: NAT + IP forwarding + ControlMaster via port 2222

### That's it. SSH macmini then works for all subsequent commands.

---

## Mini commands
  tunnel-pro   open reverse tunnel to MBP (run first each session)
  ssh-pro      SSH directly into MBP
  ssh pro      same as above

## MBP commands
  ssh macmini              SSH into mini via reverse tunnel
  ~/scripts/reconnect-mini.sh   full reconnect in one shot

---

## MBP ~/.ssh/config
Host macmini
  HostName localhost
  Port 2222
  User akmacks
  IdentityFile ~/.ssh/id_ed25519
  ControlMaster auto
  ControlPath ~/.ssh/cm/macmini
  ControlPersist 2h
  ServerAliveInterval 15
  ServerAliveCountMax 4
  StrictHostKeyChecking accept-new

## Mini ~/.ssh/config
Host pro
  HostName 192.168.2.1
  User akmacks
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking accept-new
  ServerAliveInterval 15
  ServerAliveCountMax 4

---

## Internet Sharing + NAT (for mini internet access)
Run on MBP after tunnel is up:
  sudo sysctl -w net.inet.ip.forwarding=1
  printf 'nat on en0 from 192.168.2.0/24 to any -> (en0)
pass all
' | sudo pfctl -f - && sudo pfctl -e

This is included in ~/scripts/reconnect-mini.sh automatically.

---

## Port conflict fix (if tunnel-pro says 'remote port forwarding failed')
On MBP: sudo kill $(lsof -ti :2222)
Then re-run tunnel-pro on mini.

---

## Sudoers (no password prompts)
MBP:  /etc/sudoers.d/akmacks-nopasswd   akmacks ALL=(ALL) NOPASSWD: ALL
Mini: /etc/sudoers.d/akmacks-nopasswd   akmacks ALL=(ALL) NOPASSWD: ALL

---

## Thunderbolt port notes
The active TB port on MBP shifts depending on which physical port the cable
is plugged into. Internet Sharing always rebuilds bridge0 using its preferred
ports and ignores the active one. This is why the bridge approach fails.
The reverse tunnel bypasses this entirely.

Active port detection (if needed):
  for i in en1 en2 en3 en4 en5; do printf '$i: '; ifconfig $i 2>/dev/null | grep -o 'status: [a-z]*'; done

---

## What NOT to do
- Do not rely on bridge0 being active Ñ it fights Internet Sharing
- Do not use sudo arp -s as primary connection method Ñ expires constantly
- Do not use pfctl -d globally Ñ kills NAT needed for mini internet
- Do not use DHCP on mini bridge Ñ bootpd (IS DHCP server) is unreliable

---
Generated: 2026-03-27 | OpenClaw / OCLP 3.0.0 project
# Bridge Restore — Session Handoff
## v1.0.3 | Build 26A07 | 2026-04-07

---

## ⚡ CRITICAL TAHOE DISCOVERIES (updated 2026-04-07)

### 1. Titan Ridge TB3 bridge0 is PERMANENTLY BROKEN on Tahoe — USE DIRECT en4 IP

**Root cause confirmed:** `BIOCPROMISC: Operation not supported on socket` on en4 (Titan Ridge TB3).
The TB3 driver on Tahoe/MacBookPro16,1 rejects promiscuous mode entirely. This silently breaks
bridge0 in two ways:
- bridge0 MAC (82:93:89:41:c8:01, from inactive en1) ≠ en4 MAC (82:93:89:41:c8:04)
- Frames from mini addressed to bridge0's MAC arrive on en4 → dropped (en4 not in promisc)
- `ifconfig bridge0 addm en4` → `BRDGADD en4: Operation not supported on socket` — TB interfaces
  cannot be bridge members at all on Tahoe/Titan Ridge.

**Fix (permanent, working):**
- Bypass bridge0: assign 192.168.2.1 **directly** to en4
- Fix route: `sudo route delete 192.168.2.0/24; sudo route add 192.168.2.0/24 -interface en4`
- Seed static ARP: `sudo arp -s 192.168.2.2 82:0c:4d:eb:46:81` (scoped to en4)
- pfctl NAT on uplinks (en43, en0), IP forwarding on

**Implemented as:** `scripts/mbp-tb-restore.sh` + `launchd/local.mbp-tb-restore.plist` (StartInterval=30)

### 2. ARP EHOSTDOWN — the cause of recurring "host is down" failures

When the mini repeatedly fails to ARP for 192.168.2.1 (e.g. bad route on MBP side, or route
pointing to bridge0 instead of en4), macOS marks the IP as EHOSTDOWN. All subsequent `sendto()`
calls fail immediately — ARP is suppressed entirely. This makes it look like the TB link is dead
even when both sides are correctly configured.

**Fix:** `sudo arp -d 192.168.2.1` to clear EHOSTDOWN, then seed static ARP:
`sudo arp -s 192.168.2.1 82:93:89:41:c8:04`

**Automated fix:** mini-bridge-watchdog v1.0.3 does this every 30s. Seeds static ARP for the MBP's
en4 MAC (82:93:89:41:c8:04) as a permanent entry on bridge0, preventing EHOSTDOWN from accumulating.

### 3. Mini en2 (Light Ridge TB1) SUPPORTS promiscuous mode — bridge0 works on mini

Mini's en2: `flags=8963<UP,BROADCAST,SMART,RUNNING,PROMISC,SIMPLEX,MULTICAST>` — PROMISC ✓
Mini's bridge0 works correctly. Macmini5,3's older Light Ridge TB1 controller supports promisc.
The asymmetry: MBP (TB3/Titan Ridge) can't promisc, Mini (TB1/Light Ridge) can.

### 4. Internet Sharing daemon renamed in Tahoe
- **Tahoe name: `com.apple.NetworkSharing`** → `/System/Library/LaunchDaemons/com.apple.NetworkSharing.plist`
- Binary still `/usr/libexec/InternetSharing`
- `launchctl bootstrap` blocked by SIP — **IS can only be started via Settings app**
- `launchctl kill SIGTERM system/com.apple.NetworkSharing` works to stop it
- **IS is NOT used** in the current fix — pfctl NAT replaces it

### 5. Never bounce en2 on the mini
- `ifconfig en2 down/up` tears down the XDomain TB session — 10+ second dead window
- Software `ifconfig down/up` does NOT fully renegotiate XDomain
- Only physical cable replug fully resets XDomain
- mini-bridge-watchdog v1.0.3 **never** bounces en2 or bridge0

---

## CURRENT STATE (2026-04-07 ~16:30)

| Component | Status | Notes |
|---|---|---|
| MBP en4 | 192.168.2.1 ✅ | Direct IP, bypasses bridge0 |
| MBP bridge0 | Not used for TB ✅ | Deliberately bypassed |
| Mini bridge0 | 192.168.2.2 ✅ | Active, en2 as member |
| Mini internet | 0% loss to 1.1.1.1 ✅ | NAT via pfctl on MBP |
| Tunnel port 2222 | OPEN ✅ | tunnel-pro running on mini |
| local.mbp-tb-restore | Running ✅ | Every 30s, auto-applies MBP-side fix |
| local.mini-bridge-watchdog | Running ✅ | v1.0.3, every 30s, seeds ARP |
| local.bridge-drop-monitor | Running ✅ | mini, watches + restarts tunnel-pro |
| local.bridge-ip | Running ✅ | mini, keeps bridge0 = 192.168.2.2 |
| local.mbp-watchdog | REMOVED from mini ✅ | Was MBP-side script, wrongly deployed |
| Git | Committed ✅ | commit 4727965 — v1.0.3 |

---

## HOW TO RECOVER WHEN BRIDGE DROPS

### After cable replug (normal case — everything auto-heals):
1. Unplug TB cable → wait 5s → replug
2. `local.mbp-tb-restore` fires within 30s → en4 gets 192.168.2.1, route fixed, NAT applied
3. `local.bridge-ip` fires on mini → bridge0 gets 192.168.2.2
4. `local.mini-bridge-watchdog` fires → seeds static ARP (192.168.2.1 → 82:93:89:41:c8:04)
5. `local.bridge-drop-monitor` fires on mini → restarts tunnel-pro
6. Everything up within ~60s. No typing required.

### If ping to 192.168.2.2 fails on MBP (no cable replug needed):
The ARP EHOSTDOWN on the mini is cleared every 30s by mini-bridge-watchdog. Just wait 30-60s.
Or: `ssh -p 2222 akmacks@localhost "sudo arp -d 192.168.2.1; sudo arp -s 192.168.2.1 82:93:89:41:c8:04"`

### Manual emergency recovery (MBP side):
```bash
bash ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts/mbp-tb-restore.sh
```

### Manual emergency recovery (mini side — type at mini terminal):
```bash
sudo ifconfig bridge0 192.168.2.2 netmask 255.255.255.0 up
sudo arp -d 192.168.2.1 2>/dev/null
sudo arp -s 192.168.2.1 82:93:89:41:c8:04
ping -c 3 192.168.2.1
```

---

## KEY FILE LOCATIONS

### MBP (gateway)
```
~/dev/projects/apps/app_macOS-Intel_BridgeRestore/
├── scripts/
│   ├── mbp-tb-restore.sh         ← THE FIX — Tahoe TB3 bridge bypass
│   ├── mini-bridge-watchdog.sh   v1.0.3 — ARP self-healing, no en2 bounce
│   ├── install-mini-watchdog.sh  deploys via SSH tunnel from MBP
│   ├── bridge-restore-app.sh     v1.0.6 main app
│   └── tunnel-mini.sh / tunnel-pro.sh
├── launchd/
│   ├── local.mbp-tb-restore.plist     ← runs mbp-tb-restore.sh every 30s
│   └── local.mini-bridge-watchdog.plist
└── docs/
    ├── SESSION-HANDOFF.md  ← YOU ARE HERE
    ├── TAHOE-DEV-LOG.md
    └── TROUBLESHOOTING.md

~/Library/LaunchAgents/
└── local.mbp-tb-restore.plist    ← LOADED AND RUNNING on MBP

~/Library/Logs/BridgeRestore/
└── mbp-tb-restore.log            ← daemon activity log
```

### Mini (client)
```
~/scripts/
├── mini-bridge-watchdog.sh   v1.0.3 — deployed via tunnel
└── tunnel-pro.sh

~/Library/LaunchAgents/
├── local.bridge-ip.plist              keeps bridge0 = 192.168.2.2
├── local.bridge-drop-monitor.plist    monitors + restarts tunnel-pro
├── local.mini-bridge-watchdog.plist   v1.0.3 — ARP self-healing
└── local.tunnel-pro.plist             auto-restarts tunnel-pro

~/Library/Logs/BridgeRestore/
├── mini-watchdog.log        ← watchdog activity
└── bridge-drop.log          ← drop history
```

---

## NEXT SESSION PRIORITIES

1. **Stability monitoring** — watch the logs over 24h to confirm no drops:
   ```bash
   # MBP side
   tail -f ~/Library/Logs/BridgeRestore/mbp-tb-restore.log
   # Mini side (via tunnel)
   ssh -p 2222 akmacks@localhost 'tail -f ~/Library/Logs/BridgeRestore/mini-watchdog.log'
   ```

2. **If drops still occur** — the remaining failure mode is XDomain TX going one-way.
   The watchdog's ARP recovery handles the EHOSTDOWN case. If XDomain itself breaks,
   only a cable replug fixes it. The daemons handle everything after replug automatically.

3. **Deploy project to mini** (nice-to-have, not urgent):
   ```bash
   ssh -p 2222 akmacks@localhost "mkdir -p ~/dev/projects/apps"
   ssh -p 2222 akmacks@localhost "cat > ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts/bridge-restore-app.sh" \
     < ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts/bridge-restore-app.sh
   ```

4. **KNOWN DEFERRED:** tb-reset IOKit tool, OPENCLAW gateway — deferred, not blocking

---

## IMPORTANT MAC ADDRESSES (do not change)

| Machine | Interface | MAC | Role |
|---------|-----------|-----|------|
| MBP | en4 | 82:93:89:41:c8:04 | Active TB port — direct 192.168.2.1 |
| MBP | en1 | 82:93:89:41:c8:01 | Inactive TB port (was bridge0 MAC) |
| Mini | en2 | 82:0c:4d:eb:46:81 | TB port = bridge0 MAC |
| Mini | bridge0 | 82:0c:4d:eb:46:81 | Same as en2 |

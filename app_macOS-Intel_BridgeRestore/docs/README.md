# bridge-restore-project
## OpenClaw / OCLP 3.0.0 — Thunderbolt Bridge Connectivity Suite
### Version: 1.0.0-alpha | Date: 2026-03-28

A complete toolkit for maintaining, diagnosing, and auto-restoring the
Thunderbolt Bridge connection between MacBook Pro (i9, 2019) and
Mac mini Server (Late 2011, Macmini5,3) running macOS Tahoe.

---

## Project Structure

```
bridge-restore-project/
├── scripts/
│   ├── tunnel-mini.sh          ← MBP-side tunnel + IS toggle + TB severance
│   ├── tunnel-pro.sh           ← Mini-side reverse SSH tunnel
│   ├── bridge-restore.sh       ← Mini-side AI-powered restore (4 L2/L3 methods)
│   ├── mini-watchdog.sh        ← MBP-side connectivity monitor + smart alerts
│   ├── pro-watchdog.sh         ← Mini-side connectivity monitor + smart alerts
│   ├── machine-identity.sh     ← Shared hardware UUID identity library
│   ├── reconnect-mini.sh       ← Quick MBP-side NAT + ControlMaster restore
│   └── install-on-mini.sh      ← One-shot deployment to Mac mini
├── launchd/
│   ├── local.bridge-ip.plist   ← Mini: keeps bridge0 at 192.168.2.2
│   ├── local.tunnel-pro.plist  ← Mini: auto-restarts tunnel-pro
│   └── local.mini-watchdog.plist ← MBP: runs mini-watchdog daemon
└── docs/
    ├── README.md               ← This file
    ├── MACHINE-IDENTITY.md     ← Hardware UUIDs and IP ownership
    ├── TROUBLESHOOTING.md      ← Known failure modes and fixes
    └── OPENCLAW-DEBRIEF.md     ← Full project handoff for OpenClaw/Claude
```

---

## Machine Identity (CRITICAL — never swap these IPs)

| Machine | Model | UUID | bridge0 IP |
|---|---|---|---|
| MacBook Pro | MacBookPro16,1 | 4B4DFAAB-B77A-5B8F-BE93-85E6F990529F | **192.168.2.1** |
| Mac mini | Macmini5,3 | (model check sufficient) | **192.168.2.2** |

All scripts verify hardware UUID/Model before executing — wrong machine = refused.

---

## Quick Start

**On Mac mini:**
```bash
tunnel-pro          # Open reverse SSH tunnel to MBP
bridge-restore      # AI-powered full restore (4 L2/L3 severance methods)
bridge-restore --diag  # Diagnose only
pro-watchdog --daemon  # Run continuous MBP monitor
```

**On MacBook Pro:**
```bash
tunnel-mini         # Complete tunnel + NAT + IS toggle
ssh-mini            # SSH into mini
mini-watchdog --daemon  # Run continuous mini monitor
```

---

## Reconnection Flow

```
Mini: tunnel-pro
  → sets bridge0 = 192.168.2.2
  → bounces TB port if inactive
  → opens ssh -R 2222:localhost:22 → MBP
  → CAPS banner + popup on MBP

MBP: tunnel-mini
  → hardware UUID check (refuses on Mini)
  → sets bridge0 = 192.168.2.1
  → IS toggle if ARP incomplete
  → NAT on en0 + en43
  → opens ControlMaster via port 2222
  → CAPS banner + popup on Mini
```

---

## Smart Watchdog Behaviour
After 10 consecutive failures, shows macOS dialog:
- "Check every 2 min"
- "Check every 5 min"
- "Pause checks"
- "Open Troubleshooter" → launches bridge-restore

---

## Installation

Deploy to mini (run on MBP after tunnel-mini succeeds):
```bash
bash ~/scripts/install-on-mini.sh
```

Load launchd agents on mini:
```bash
launchctl load ~/Library/LaunchAgents/local.bridge-ip.plist
launchctl load ~/Library/LaunchAgents/local.tunnel-pro.plist
```

---
Generated: 2026-03-28 | OpenClaw Legacy Patcher project

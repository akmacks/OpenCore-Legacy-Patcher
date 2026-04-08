# OpenClaw Handover Brief — Bridge Restore Project
## Build 26A05 | Updated 2026-04-03
## For: OpenClaw (KimiDev-2.5 cloud, or llama3.2:3b / qwen3:4b offline)

---

## YOUR ROLE
You are the Worker. Claude (Anthropic) is the Director.
Your job: execute diagnostics, fix scripts, and report back with structured results.
When offline: use llama3.2:3b (fast) or qwen3:4b (reasoning) via Ollama at localhost:11434.
When online: KimiDev-2.5 via localhost:18789.

---

## MACHINES

| Role    | Model        | Bridge IP   | Hostname               | Username |
|---------|-------------|-------------|------------------------|----------|
| Gateway | MBP 16,1    | 192.168.2.1 | MacBook-Pro-i9         | akmacks  |
| Client  | Macmini5,3  | 192.168.2.2 | Mac-mini-Server-i7     | akmacks  |

---

## CRITICAL TAHOE FACTS (2026-04-03 discoveries)

1. **Internet Sharing = com.apple.NetworkSharing** (not InternetSharing) in Tahoe launchd
   - Binary still called `/usr/libexec/InternetSharing` — use `pgrep -f InternetSharing`
   - **Cannot be started from CLI** — SIP blocks it. Only Settings app can start it.
   - Stop: `launchctl kill SIGTERM system/com.apple.NetworkSharing`
   - NEVER: `launchctl unload -w` — de-registers the service permanently

2. **TB port bounce is useless on a fixed cable** — `ifconfig enX down/up` is L2 only.
   Physical replug is the only real L1 fix. Remove all TB bounce code.

3. **bridge0 drops ~every 30-90 min** — brief (~10s) Tahoe configd reconfiguration events.
   Self-recovering. Fix: auto-restart tunnel-pro when bridge0 comes back up.

4. **launchctl unload/load** = broken for system daemons on Tahoe. Use `bootout`/`kickstart`.
   For user LaunchAgents: `launchctl bootout gui/$(id -u)/service.label`

---

## CURRENT ARCHITECTURE

```
Mini (client)                          MBP (gateway)
bridge0 = 192.168.2.2                  bridge0 = 192.168.2.1
bridge-drop-monitor (watching)          tunnel-watchdog-mbp (watching port 2222)
  ↓ bridge0 recovers                     ↓ port 2222 opens
  → auto-starts tunnel-pro               → auto-runs tunnel-mini
  → logs to bridge-drop.log              → logs to tunnel-watchdog-mbp.log
```

### Key files on mini
```
/usr/local/bin/tunnel-pro               — reverse SSH tunnel to MBP
/usr/local/bin/bridge-drop-monitor      — v2: watches bridge0, auto-restarts tunnel
~/Library/LaunchAgents/local.bridge-drop-monitor.plist
~/Documents/GitHub/app_macOS-Intel_BridgeRestore/  — synced repo (rsync from MBP)
~/Library/Logs/BridgeRestore/bridge-drop.log       — drop event log
```

### Key files on MBP
```
/usr/local/bin/tunnel-mini              — completes the tunnel from MBP side
~/dev/projects/apps/app_macOS-Intel_BridgeRestore/  — source of truth repo
~/Library/LaunchAgents/local.tunnel-watchdog-mbp.plist — auto-runs tunnel-mini
~/Library/Logs/BridgeRestore/tunnel-watchdog-mbp.log
```

---

## REPO STRUCTURE
```
app_macOS-Intel_BridgeRestore/
├── scripts/
│   ├── tunnel-mini.sh          — MBP side tunnel
│   ├── tunnel-pro.sh           — mini side tunnel
│   ├── bridge-drop-monitor.sh  — mini watcher (v2)
│   ├── tunnel-watchdog-mbp.sh  — MBP watcher (new)
│   └── bridge-restore-app.sh   — main app
├── logs/                       — session logs
├── logs-dev/                   — dev notes
├── logs-fix/                   — fix records + screenshots
└── docs/
    ├── SESSION-HANDOFF.md      — current state, always read this first
    └── OPENCLAW-HANDOVER.md    — this file
```

---

## OFFLINE DIAGNOSTICS (no internet required)

```bash
# Check connection status
nc -z -G 3 localhost 2222 && echo "TUNNEL UP" || echo "TUNNEL DOWN"
arp -n 192.168.2.2
pgrep -f InternetSharing && echo "IS RUNNING" || echo "IS DOWN"

# Read drop log
cat ~/Library/Logs/BridgeRestore/bridge-drop.log | tail -20

# Ask local LLM to diagnose
curl -s localhost:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Diagnose this macOS Thunderbolt Bridge drop log: $(cat ~/Library/Logs/BridgeRestore/bridge-drop.log | tail -20)",
  "stream": false
}' | python3 -c "import sys,json; print(json.load(sys.stdin)['response'])"
```

---

## RESCUE SEQUENCE (bridge totally down)

1. `arp -n 192.168.2.2` — if incomplete, bridge0 on mini is down
2. Try ARD → mini Terminal: `sudo ifconfig bridge0 192.168.2.2 netmask 255.255.255.0 up`
3. If ARD also down: **physical replug of Thunderbolt cable (5 seconds)**
4. Wait for ARP: `until arp -n 192.168.2.2 | grep -qE "([0-9a-f]{2}:){5}"; do sleep 2; done`
5. Mini should auto-restart tunnel-pro via bridge-drop-monitor
6. MBP watchdog auto-runs tunnel-mini when port 2222 opens

---

## UPDATE: 2026-04-07 — v1.0.6 Build 26A06

### What changed this session
- **tb-reset IOKit tool** created: `~/dev/projects/tools/tool_macOS-Universal_tb-reset/`
  - Universal binary (x86_64 + arm64), Xcode project ready to build
  - Achieves true L1 Thunderbolt reset via `IOServiceRequestProbe()` on `IOPCIDevice NHI0`
  - Confirmed: `kextunload` blocked by `-603946984` (`kOSKextReturnInUse`) on Tahoe
  - IOKit class corrected: `AppleThunderboltNHIType3` (not `AppleThunderboltNHI`)
- **Bridge Restore** bumped to v1.0.6 / Build 26A06 across all files
- **`_sever_tb_gateway()`** now has 6 methods; Method 6 calls `tb-reset-trigger.sh`
- **`CHANGELOG.md`** created — full version history from 1.0.0 to 1.0.6
- **Session logs** updated: TAHOE-DEV-LOG.md, SESSION-HANDOFF.md, this file

### tb-reset tool — OpenClaw context
The tb-reset tool is a compiled IOKit binary, NOT a shell script. OpenClaw should NOT
attempt to modify or re-implement it in shell. If L1 reset fails, the fallback is:
1. Physical cable replug (always works)
2. Mini-side tb-reset watchdog (next build item)

### Pending work for OpenClaw
1. Xcode compile + live test of tb-reset with cable connected
2. Mini-side self-healing watchdog: launchd agent that detects bridge0 loss,
   runs `sudo tb-reset` on the mini itself, restarts tunnel-pro
3. Deploy full project to mini `~/dev/` (see SESSION-HANDOFF.md DEPLOY section)
4. Analyse bridge-drop.log to find root cause of 2–3 min drop cycle

### Critical reminder: never run Ollama inference on mini
`qwen3:4b` inference freezes 2011 hardware. Always offload to MBP via tunnel.
Never kill Ollama process — it's shared infrastructure.

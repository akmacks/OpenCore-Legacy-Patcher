# OCLP 3.0.0 Tahoe (macOS 26) Development Log
**Branch:** `macos-next`
**Target Machine:** Mac mini Server (Late 2011) — `Macmini5,3` — Intel Core i7 Sandy Bridge
**Target OS:** macOS Tahoe 26.3.1 (Build `25D2128`, Darwin 25.3.0)
**Development Host:** MacBook Pro 16,1 (2019) — macOS Tahoe 26.x
**Developer:** akmacks

---

## Objective

Get OCLP 3.0.0 (`macos-next` branch) to boot and apply root patches to a
`Macmini5,3` running macOS Tahoe 26.3.1 — enabling Sandy Bridge non-T2 Intel Macs on Tahoe.

---

# SESSION 1 — 2026-03-22
## EFI Build, GPU Patches, SSH, USB HID

### Environment Setup
- Python 3.14.3 (Homebrew), wxPython 4.2.5, all deps satisfied
- OCLP GUI launched on MBP, Custom Model = `Macmini5,3`

### EFI Build
- GUI build succeeded; key kexts present: USB-Map-Tahoe, CryptexFixup, AMFIPass,
  AppleIntelCPUPowerManagement, AirportBrcmFixup ✅

### Issue: Privileged Helper Tool (Return Code 166)
Running from source without Apple Developer Team ID — helper refuses to mount EFI.
**Workaround:** Manually mount EFI and copy files with sudo.


### Code Changes — Session 1

| File | Change |
|---|---|
| `constants.py` | Added `is_patching_external_volume: bool = False` |
| `sys_patch/patchsets/detect.py` | OS ceiling extended to Tahoe; external volume bypass |
| `wx_gui/gui_main_menu.py` | External volume detection in Post-Install |
| `sys_patch/patchsets/hardware/misc/modern_audio.py` | Tahoe audio fallback to `15.2` PSP folder |
| `support/subprocess_wrapper.py` | Direct sudo bypass for dev (no Privileged Helper) |
| `sys_patch/patchsets/hardware/misc/usb11.py` | Added `Macmini5,1/2/3` — fixes dead keyboard/mouse |

### Root Patching via SSH + Target Disk Mode
1. Enable SSH on mini while in TDM: `sudo touch ".../private/var/db/.RemoteLoginEnabled"`
2. Boot mini, SSH in from MBP, transfer OCLP repo + Universal-Binaries.dmg via rsync
3. Mount Universal-Binaries.dmg on mini
4. Stub out GUI auto_patcher imports (avoids wx cascade)
5. Run: `sudo /usr/local/bin/python3.14 /tmp/patch_mini.py`

### Session 1 Results
- ✅ OC EFI boots
- ✅ Intel HD 3000 GPU patches applied — colour login screen confirmed
- ✅ USB HID fixed (Synergy killed, usb11.py patched)
- ✅ Apple Remote Desktop connected
- ❌ Ethernet not working (no kext injection for BCM5722)
- ❌ No internet on mini

---

# SESSION 2 — 2026-03-23
## Thunderbolt Bridge Connectivity Attempts

### Tailscale — FAILED
`tailscale up` hung (NoState) — needs working internet first.

### Thunderbolt Direct Cable
- Self-assigned link-local IPs negotiated (MBP: 169.254.63.91, mini: 169.254.94.19)
- MBP Internet Sharing active on bridge0 (192.168.2.1)
- Mac mini manually assigned 192.168.2.2
- Ping: 100% packet loss — ARP resolution failure across bridge
- Session ended unresolved

---

# SESSION 3 — 2026-03-27
## Reverse Tunnel Established, Docs Written

- Abandoned bridge0/ARP/pf method (unreliable due to TB port shifting)
- Implemented reverse SSH tunnel: mini → MBP via `tunnel-pro` / `reconnect-mini.sh`
- `tunnel-pro` runs: `ssh -R 2222:localhost:22 pro` (mini initiates outbound to MBP)
- MBP SSHes back via `ssh macmini` (localhost:2222)
- sudoers NOPASSWD set up on MBP
- Wrote THUNDERBOLT-BRIDGE-SETUP.md and SESSION-HANDOFF.md


---

# SESSION 4 — 2026-03-27
## Ethernet Fix: BCM5722 Kernel Patch Applied to Live EFI

### Desktop Commander Now on Mac mini
Session opened from Mac mini browser. Desktop Commander MCP connected directly
to mini — no SSH tunnel needed for shell access. This is now the primary dev
interface for mini-side work.

### Repo Audit — Corrected File Paths
Session notes had wrong paths. Actual structure:

| Old (wrong) | Actual |
|---|---|
| `data/model_array.py` | `datasets/model_array.py` |
| `sys_patch/patchsets/hardware/ethernet/` | **Does not exist** |
| `sys_patch/patchsets/hardware/usb/usb11.py` | `sys_patch/patchsets/hardware/misc/usb11.py` |

Ethernet support is **EFI-injection only** via `efi_builder/networking/wired.py`.
There is no root-patch patchset for Ethernet.

### Ethernet Investigation Deep Dive

**`smbios_data.py` for Macmini5,3:**
```python
"Ethernet Chipset": "Broadcom"
```
This routes `_prebuilt_assumption()` in `wired.py` to inject `CatalinaBCM5701Ethernet.kext`.

**Critical finding:** `CatalinaBCM5701Ethernet.kext` Info.plist already contains:
```xml
<string>pci14e4,1682</string>
```
`pci14e4,1682` IS the BCM5722 device ID. **No new kext needed.**

**Live EFI audit results:**
- `CatalinaBCM5701Ethernet.kext` present in live EFI ✅
- Kext enabled in config.plist, MinKernel=20.0.0 ✅
- Kext binary valid: Mach-O 64-bit x86_64, 429KB ✅
- Kext NOT in kextstat at boot ❌
- Kernel binary patch: **completely absent** ❌ ← ROOT CAUSE


### Fix Applied: Kernel Binary Patch Added to Live EFI

`CatalinaBCM5701Ethernet.kext` requires a binary patch to work on Big Sur+ kernels.
Without it, the hardware ID check silently fails at load time — kext never attaches.

**Patch added to `/Volumes/EFI/EFI/OC/config.plist` via Python plistlib:**

| Field | Value |
|---|---|
| Identifier | `com.apple.iokit.CatalinaBCM5701Ethernet` |
| Enabled | true |
| Arch | x86_64 |
| MinKernel | 20.0.0 |
| MaxKernel | (none) |
| Find | `e8ca9effff66898300050000` (12 bytes) |
| Replace | `b8b416000066898300050000` (12 bytes) |
| Count | 0 (patch all occurrences) |

**Source:** AppleLife.ru thread on patching BCM5701Ethernet, referenced in
`samuelnotfound/AppleBCM57XXEthernet` GitHub repo.

**Note:** PlistBuddy was used first but created a bad ASCII-encoded duplicate.
Detected and removed via Python. Final state verified: 4 patches total, 1 BCM entry.

**After reboot, verify with:**
```bash
kextstat | grep -i "BCM\|5701\|catali"
system_profiler SPEthernetDataType
ifconfig en0
```

### Additional Setup — Session 4
- sudoers NOPASSWD added to Mac mini: `/etc/sudoers.d/akmacks-nopasswd`
- ICMP ping fails through NAT but is not an indicator of no internet (confirmed working)

---

## TODO — Next Session Priority Order

1. **[ ] Reboot and verify Ethernet** — check kextstat + system_profiler
2. **[ ] If patch works:** Apply OCLP root patches (fixes GPU, audio, Wi-Fi, BT)
3. **[ ] If patch fails:** Check if Tahoe (Darwin 25) changed binary offset; update Find/Replace
4. **[ ] Source-level fix:** Add BCM5701 kernel patch to OCLP EFI build automatically
5. **[ ] Fix duplicate** `is_patching_external_volume` in constants.py
6. **[ ] Sync usb11.py** Macmini5,x change from MBP to mini repo
7. **[ ] Wi-Fi, Audio, Bluetooth** after Ethernet + root patches confirmed

---

## Overall Hardware Status

| Component | Status | Notes |
|---|---|---|
| macOS Tahoe boot | ✅ Working | OC EFI on disk0s1 |
| Intel HD 3000 GPU | ✅ Patches applied | Sandy Bridge kexts injected |
| USB HID | ✅ Working | Synergy removed, usb11.py patched |
| Apple Remote Desktop | ✅ Working | Connects from MBP |
| SSH (reverse tunnel) | ✅ Working | tunnel-pro workflow |
| Internet on mini | ✅ Working | TB bridge NAT (ICMP blocked, Safari/Claude fine) |
| OCLP root patches | ❌ Never applied | No AppliedPatches.plist |
| Ethernet BCM5722 | ⏳ Pending reboot | Kernel patch added to EFI config |
| Wi-Fi BCM43xx | ❓ Unknown | Kexts in EFI, root patches not applied |
| Audio ALC892 | ❓ Unknown | AppleALC in EFI, root patches not applied |
| Bluetooth | ❌ Not working | BlueToolFixup in EFI, root patches not applied |
| Tailscale | ❌ NoState | Needs Ethernet first |

---

## Key Learnings

1. **Ping failure ≠ no internet.** macOS NAT blocks ICMP. Don't chase ping failures.
2. **CatalinaBCM5701Ethernet already supports BCM5722** — `pci14e4,1682` is in the kext.
   The missing piece was the Big Sur+ kernel binary patch, not a new kext.
3. **Desktop Commander on mini = direct shell.** Open Claude from mini browser → no tunnels needed.
4. **Real repo paths differ from session notes.** Always grep to confirm before editing.
5. **Use Python plistlib for config.plist edits** — PlistBuddy mishandles binary data fields.
6. **EFI files are owned by akmacks** — direct writes without sudo work fine.
# SESSION 5 — 2026-03-28
## Bridge-Restore Project + Deployment, TB Bounce Fix, MBP Aliases

### Context
Session started on Mac mini (Desktop Commander connected directly).
Tunnel dropped repeatedly during session. Connection finally restored by physically
reseating the Thunderbolt cable — this identified the root cause.

### Root Cause of Repeated TB Drops
The Thunderbolt physical link-layer negotiation drops silently while the bridge0
interface retains its IP. Reseating the cable forces L1 re-negotiation.
**Software equivalent:** `sudo ifconfig <TB_port> down && sleep 10 && sudo ifconfig <TB_port> up`
This is now automated in both tunnel scripts.

### bridge-restore Project Created
Full project at `~/scripts/` on both machines (matching paths).

**Files on Mac mini `~/scripts/`:**
- `tunnel-pro.sh` — mini→MBP reverse tunnel with TB bounce, CAPS banner, dual popups
- `bridge-restore.sh` — AI-powered restore with Ollama fallback
- `/usr/local/bin/tunnel-pro` — system command (updated)

**Files on MBP `~/scripts/`:**
- `tunnel-mini.sh` — MBP→mini ControlMaster with TB bounce, CAPS banner, dual popups
- `bridge-restore.sh` — MBP-side diagnosis and restore
- `install-on-mini.sh` — deployment script
- `reconnect-mini.sh` — quick restore (existing, updated)

### LaunchAgents on Mac mini (auto-start on boot)
- `local.bridge-ip` — keeps bridge0 at 192.168.2.2, checks every 20s
- `local.tunnel-pro` — auto-restarts tunnel-pro if it exits (ThrottleInterval 20s)

### Shell Aliases Added

**Mac mini `~/.zshrc`:**
```
tunnel-pro     → bash ~/scripts/tunnel-pro.sh
bridge-restore → bash ~/scripts/bridge-restore.sh
bridge-status  → bash ~/scripts/bridge-restore.sh --status
bridge-diag    → bash ~/scripts/bridge-restore.sh --diag
bridge-ai      → bash ~/scripts/bridge-restore.sh --ai
ssh-pro        → ssh akmacks@192.168.2.1
```

**MBP `~/.zshrc`:**
```
tunnel-mini        → bash ~/scripts/tunnel-mini.sh
ssh-mini           → ssh -p 2222 akmacks@localhost
mini-status        → remote bridge status check
bridge-restore-mini → triggers bridge-restore on mini remotely
```

### Tunnel Confirmation Behaviour (both scripts)
When tunnel succeeds both scripts now:
1. Print CAPS banner in terminal with full IP/MAC/bridge details of both machines
2. Show macOS notification on source machine
3. Show modal `display dialog` popup on TARGET machine with full connection details

### Ollama / OpenClaw Local LLM
- `llama3.2:3b` pull initiated on mini in background (~2GB)
- `bridge-restore.sh --ai` sends diagnosis to local LLM for fix suggestions
- Model preference order: llama3.2:3b → qwen2.5:3b → gemma2:2b → kimi-k2.5:cloud

### Deployment Method
scp fails via reverse tunnel (no sftp subsystem). Used `ssh ... "cat > file" < localfile`
pattern successfully for all file transfers.

### Session 5 Connectivity Timeline
- TB bridge dropped multiple times (L1 negotiation failure)
- Restored each time by: physical cable reseat OR `ifconfig <port> down/up`
- tunnel-pro typo `19.168.2.1` was pre-existing (now fixed in both scripts)
- Final state: tunnel up, all scripts deployed, launchd agents running


---

# SESSION 6 — 2026-03-28 (continued)
## Machine Identity Guards, IP Corruption Fix, Script Rewrites

### Root Cause of IP Corruption
Multiple times during sessions 5-6, the MBP bridge0 was set to 192.168.2.2
(the Mini's IP) instead of 192.168.2.1 (MBP's correct IP). Root cause:

1. Scripts that ran `ifconfig bridge0 <IP>` were deployed to both machines
2. Without reliable machine detection, the wrong script ran on the wrong machine
3. Hostname-based guards (`*MacBook*`) failed because hostnames are unreliable
4. Desktop Commander is connected to the MBP — commands I thought were
   going to the mini were running locally on the MBP

### Permanent Fix — Hardware UUID Guard
All scripts now check Hardware UUID and Model Identifier as the ABSOLUTE
FIRST operation before any variables or network commands:

| Machine | Model Identifier | Hardware UUID |
|---|---|---|
| MBP | MacBookPro16,1 | 4B4DFAAB-B77A-5B8F-BE93-85E6F990529F |
| Mini | Macmini5,3 | (detected at runtime — model check sufficient) |

### IP Ownership — Fixed and Immutable
- MBP bridge0 = 192.168.2.1 — ALWAYS. Only tunnel-mini.sh sets this.
- Mini bridge0 = 192.168.2.2 — ALWAYS. Only tunnel-pro.sh sets this.
- Scripts refuse to run on the wrong machine via hardware UUID check.

### Script Guards Summary
| Script | Runs on | Refuses on | Sets IP |
|---|---|---|---|
| tunnel-mini.sh | MBP only | Mini (Macmini5,3) | 192.168.2.1 |
| tunnel-pro.sh | Mini only | MBP (UUID check) | 192.168.2.2 |
| bridge-restore.sh | Mini only | MBP (UUID check) | 192.168.2.2 |

### ARP Verification Added
tunnel-mini.sh now reads ARP table to confirm mini's MAC at 192.168.2.2
before opening ControlMaster. If mini IP is wrong after SSH connects,
it corrects it remotely via SSH.

### Claude's Lesson
Desktop Commander is connected to the MBP throughout this project.
When user says "I am now on the mini", that means they are TYPING from
the mini — but DC still controls MBP unless explicitly re-confirmed.
ALWAYS run hardware identity check before any network-modifying command.


---

# SESSION 7 — 2026-03-28 (evening)
## Bridge Restore App v1.0.0-alpha — Full Redesign and Compile

### Issues Resolved This Session

#### 1. IS "Turn On" Confirmation Dialog
- Root cause: osascript launchctl toggle doesn't handle Tahoe's UI confirmation prompt
- Fix: New `toggle_internet_sharing()` uses `defaults write` to set NAT Enabled directly,
  plus spawns background AppleScript watcher to auto-click "Turn On" if dialog appears
- Additional UI automation fallback via System Settings AppleScript

#### 2. osascript Password Prompts
- Root cause: `/etc/sudoers.d/akmacks-nopasswd` file was missing (cleared by system event)
- Fix: Recreated via `sudo sh -c 'echo "akmacks ALL=(ALL) NOPASSWD: ALL" > ...'`
- sudo -n confirmed working without password

#### 3. App Redesign — Role-Aware Architecture
New `bridge-restore-app.sh` (701 lines) replaces all previous fragmented scripts:

**Role detection:** Hardware UUID + Model Identifier determines gateway vs client
- Gateway: MacBookPro16,1 / UUID 4B4DFAAB — shares internet, owns 192.168.2.1
- Client: Macmini5,3 — receives internet, owns 192.168.2.2

**Setup Wizard (`--wizard`):** AppleScript GUI prompts for:
- Role selection (gateway/client)
- Gateway + client hostnames and IPs
- Watchdog on/off
- Tunnel auto-retry on/off
- OSI diagnostic layer selection

**Preferences (`--prefs`, Cmd-,):** Three tabs:
1. Hosts & Roles — hostname/IP configuration
2. Diagnostic Layers — enable/disable L1-L7 per run
3. Watchdog & Retry — interval and threshold settings

**OSI Layer Diagnostic Engine:**
Each of L1-L7 can be individually enabled/disabled in config:
- L1 Physical: bridge0 status, active TB port
- L2 Datalink: ARP peer, bridge0 IP ownership check
- L3 Network: ping (with note that ICMP blocked by NAT is normal)
- L4 Transport: tunnel port / SSH port check
- L5 Session: tunnel-pro process check
- L6 NAT/Routing: ip_forwarding, pfctl rules
- L7 Application: external internet via curl

**TB Severance (4 methods, --sever flag):**
1. bridge member deletem/addm
2. networksetup Thunderbolt Bridge off/on
3. ifconfig port down/up
4. bridge0 full teardown/rebuild

**Watchdog embedded (--watchdog):**
- Role-aware: gateway watches client, client watches gateway
- After 10 failures: AppleScript dialog with 4 options
- State persisted in ~/.config/bridge-restore/watchdog.state

**Ollama AI fallback (--ai):**
- Prefers local models: llama3.2:3b → qwen2.5:3b → gpt-oss:20b → kimi-k2.5:cloud
- Works offline with any local model
- Falls back to manual instructions if no model available

#### 4. Debug Test Results (20:22 28/03/26)
```
L1 Physical : bridge0=active active_port=en4       ✅
L2 Datalink : ARP 192.168.2.2 incomplete           ❌ mini not responding
L2 bridge0  : 192.168.2.1                          ✅ MBP correct
L3 Network  : ping FAIL (NAT blocks ICMP)          ⚠️  normal
L4 Transport: port 2222 CLOSED                     ❌ mini needs tunnel-pro
L5 Session  : tunnel-pro NOT RUNNING               ❌
L6 NAT      : ip_forwarding=1, rules loaded        ✅
L7 Internet : 101.188.215.55                       ✅
```
Root cause confirmed: mini TB interface not responding at L2 (ARP incomplete).
All MBP-side configuration is correct. Fix requires tunnel-pro on mini.

#### 5. Intermittent ~28 Ping Failure
Observed: internet works for ~28 pings then drops.
Hypothesis: local.tunnel-pro launchd on mini repeatedly bouncing TB interface.
Fix needed: check if mini's launchd agent is causing bridge restarts.
TODO: add dampening/backoff to local.tunnel-pro launchd ThrottleInterval.

### Project Structure (compiled to ~/dev/projects/apps/bridge-restore/)
```
bridge-restore/
├── scripts/
│   ├── bridge-restore-app.sh   ← MAIN APP (701 lines)
│   ├── tunnel-mini.sh          ← MBP-side tunnel
│   ├── tunnel-pro.sh           ← Mini-side tunnel
│   ├── machine-identity.sh     ← Shared UUID library
│   ├── reconnect-mini.sh       ← Quick NAT restore
│   └── install-on-mini.sh      ← Mini deployment
├── launchd/
│   ├── local.bridge-ip.plist
│   ├── local.tunnel-pro.plist
│   └── local.mini-watchdog.plist
├── docs/
│   ├── README.md
│   ├── MACHINE-IDENTITY.md
│   ├── TROUBLESHOOTING.md
│   └── (session docs copied)
├── config/                     ← runtime, gitignored
├── .gitignore
└── package.json
```

### System Commands Installed (MBP)
- `/usr/local/bin/bridge-restore-app` → main app
- `/usr/local/bin/tunnel-mini` → MBP tunnel
- `/usr/local/bin/bridge-restore` → mini-side diag
- `/usr/local/bin/mini-watchdog` → MBP watchdog
- `/usr/local/bin/pro-watchdog` → mini watchdog


---

## Sessions 9–10: MBP Persistence + v1.1.0 Package (2026-03-29)

### Session 9 — MBP-side persistence infrastructure
**Commit:** `8dc441e`

Added the missing MBP-side permanent setup (client side was already persistent via install-on-mini.sh):

- **install-on-mbp.sh** (225 lines): MBP launchd installer
  - Writes /usr/local/bin wrappers: tunnel-mini, bridge-restore, tunnel-mini-status
  - Writes /etc/pf.anchors/bridge-restore + hooks into /etc/pf.conf
  - Deploys and loads local.nat-persist and local.mbp-watchdog LaunchAgents

- **mbp-watchdog.sh** (120 lines): Persistent MBP-side daemon
  - 20s loop: checks port 2222 open (mini tunnel active)
  - Checks ControlMaster liveness
  - Auto-fires tunnel-mini.sh when mini connects or CM drops
  - macOS notifications on connect/disconnect/persistent fail

- **local.mbp-watchdog.plist**: KeepAlive launchd agent
- **local.nat-persist.plist**: RunAtLoad — ip_forwarding + bridge0 + pf rules

- **bridge-restore.skill**: Claude developer context skill created and installed
  at ~/.openclaw/workspace/skills/bridge-restore/

### Session 10 — v1.1.0 package, GUI, man page, aliases
**Commits:** `6818ff7`, `2d01da0`

#### BridgeRestore-1.1.0.pkg (built, verified, ready to install)
- 44 KB, 29 payload files
- Standard macOS installer with Welcome/License/Conclusion HTML pages
- Distribution.xml: x86_64 + macOS 14+ guards
- **preinstall**: version detection, Archive & Install / Install Over / Cancel dialog,
  zips existing to ~/Library/Application Support/BridgeRestore/archives/
- **postinstall**: scripts deploy, /usr/local/bin wrappers, 4 LaunchAgents, man page,
  pf anchor, Dock prompt (Add to Dock / Open Now / Skip)
- **preremove**: agent unload + wrapper cleanup
- To install: `open releases/BridgeRestore-1.1.0.pkg`
- To rebuild: `bash pkg-build/build-pkg.sh`

#### BridgeRestore.app bundle
- /Applications/BridgeRestore.app (CFBundleIdentifier: com.openclaw.bridge-restore)
- LSMinimumSystemVersion: 14.0, LSArchitecturePriority: x86_64
- Launcher: bash → bridge-restore-gui.sh

#### bridge-restore-gui.sh (416 lines)
Full AppleScript GUI:
- Launch dialog: GUI Mode / CLI Mode / Quit
- CLI Mode: opens Terminal window titled "Bridge-Restore", shows --help
- GUI Mode: live status header (bridge0 IP, tunnel state, CM state, peer hostname)
- Dashboard panels: Restore / Diagnostics / Watchdog / AI Assist / Bug Hunt /
  Preferences / Logs / Help (About/Quick Start/All Commands/Troubleshooting/Man Page)

#### bridge-restore-app.sh updates
- `--help` expanded to 60-line full reference with all flags, aliases, examples
- `--version` / `-V` added
- `--gui` / `-g` added (launches GUI)
- Short aliases: `-s -d -w -a -g -p -h -V`

#### Documentation
- **man/bridge-restore.1**: Complete Unix man page (245 lines, 7 sections)
- **man/bridge-restore.xml**: Full XML reference (236 lines, 7 sections, all commands/flags)

#### Aliases & shell integration
- **bridge-restore-aliases.sh** (59 lines): 29 aliases
  - `br`, `br-status`, `br-diag`, `br-gui`, `br-sever`, `br-ai`, `br-bughunt`
  - `br-watchdog`, `br-watchdog-start`, `br-watchdog-stop`
  - `br-logs`, `br-logs-all`, `br-logs-mini`
  - `tm` (tunnel-mini), `tms`, `ssh-mini`, `ssh-mini-cmd`
  - `br-build`, `br-install-pkg`, `br-aliases`
- ~/.zshrc updated: replaced old scattered aliases with `source bridge-restore-aliases.sh`

### Current component status

| Component | Status |
|---|---|
| BridgeRestore-1.1.0.pkg | ✅ Built — ❌ NOT YET INSTALLED |
| install-on-mbp.sh | ✅ Written — ❌ NOT YET RUN |
| OCLP root patches on mini | ❌ NEVER applied under Tahoe |
| BCM5722 Ethernet | ⏳ Kernel patch in config.plist — reboot needed |
| Tailscale on mini | ❌ Not authenticated |

### Remaining ~/home cleanup (pending approval)
See CLEANUP-PLAN.md for the full audit and proposed actions.

---

## Session 11: ~/dev/ migration + home cleanup (2026-03-29)

### ~/home cleanup completed
- Deleted (junk): `~/default.profraw`, `~/getting-started/`, `~/myenv/`, `~/vw/`, `~/myproject/`
- Archived then deleted (legacy bridge-restore work):
  - `legacy-home-scripts-20260329-112351.zip` (88 KB) → ~/Library/Application Support/BridgeRestore/archives/
    Contents: bridge-restore/, bridge-restore-project/, fix-bridge.sh, scripts/
  - `legacy-openclaw-logs-20260329-112355.zip` (12 KB)
    Contents: logs/openclaw/, logs/scripts/
- Kept: `~/electrum/` (user decision), `~/go/`, `~/.mono/`, `~/.agents/`, `~/.claude/`

### ~/dev/ directory structure
User created `~/dev/` as canonical development root and `~/Developer/` for Apple/Xcode projects.

### ~/projects/ → ~/dev/projects/ migration
- `~/projects/` moved to `~/dev/projects/` via `mv`
- Backward-compat symlink: `~/projects → ~/dev/projects`
- Bulk path update across **31 files** via `sed -i`:
  - All app-app-logs, docs, scripts, man pages, launchd plists
  - .zshrc, bridge-restore-aliases.sh, skill SKILL.md + references
  - pkg-build payload copies
- `projects/README.md` rewritten to document new ~/dev/ structure
- `docs/CLEANUP-PLAN.md` updated to COMPLETE status
- All aliases verified loading clean in fresh zsh session with new paths

### New canonical structure
```
~/dev/                          ← Development root (created 2026-03-29)
├── projects/                   ← All projects (moved from ~/projects/)
│   └── apps/app_macOS-Intel_BridgeRestore/  ← Bridge Restore (active)
~/Developer/                    ← Apple/Xcode formal projects only
~/projects → ~/dev/projects     ← symlink (backward compat)
```

### Git commit: all 16 modified + new files staged for final commit

---

## Session 12: L1 Reset Research + tb-reset IOKit Tool (2026-04-07)

### Problem under investigation
Mac mini (Macmini5,3) loses Thunderbolt Bridge connection every 2–3 minutes.
Only recovery: physical cable replug. Software methods (ifconfig, networksetup,
bridge teardown) all operate at L2 only and do not trigger L1 renegotiation.

### Layer 1 research findings

**kextunload blocked:** `sudo kextunload -b com.apple.driver.AppleThunderboltNHI`
returns `-603946984` = `kOSKextReturnInUse`. The `0` reference count in `kextstat`
only counts kext-to-kext dependencies. Active `IOService` instances bound to real
hardware also hold retain counts and block unload — by kernel design.

**Actual IOKit class hierarchy on MacBookPro16,1:**
```
IOPCIDevice "NHI0@0"         ← PROBE TARGET
  AppleThunderboltHAL
    AppleThunderboltNHIType3
      IOThunderboltPort @N   (×12, one per physical port)
        AppleThunderboltIP   (only when bridge is UP — carries BSD name)
```
Class name is `AppleThunderboltNHIType3`, NOT `AppleThunderboltNHI`.
Two NHI controllers on MBP16,1 (one per TB3 chip, 2 ports each).

**TB4 adapter architecture:** The TB4/TB3→TB2 active adapter maintains two
independent L1 segments. MBP-side software resets do not propagate cleanly
through the adapter's retimer IC to the mini's Light Ridge TB1 controller.

**No thunderboltd on Intel Tahoe:** Unlike Apple Silicon, Intel Macs handle
all Thunderbolt management entirely in-kernel (NHI kext). No user-space daemon.

**IOServiceRequestProbe approach:** Calling `IOServiceRequestProbe()` on the
`IOPCIDevice NHI0` parent causes the PCIe bridge to re-enumerate its bus,
which tears down the NHI IOService tree cleanly (releasing the retain lock)
and forces the controller to renegotiate L1 from cold-start. This bypasses
the `kext in use` block entirely since it operates at the PCIe layer above
the NHI rather than trying to unload the kext directly.

### New tool: tool_macOS-Universal_tb-reset

**Location:** `~/dev/projects/tools/tool_macOS-Universal_tb-reset/`
**Binary:** Universal (x86_64 + arm64), compiled clean 0 errors, 0 warnings
**Xcode project:** `tb-reset.xcodeproj` generated via xcodegen 2.45.3

Source files:
- `Sources/main.c` — CLI entry, arg parsing, auto-select bridge0 TB port
- `Sources/tb_detect.c/.h` — IOKit port detection, bridge0 membership check,
  AppleThunderboltHAL scan with BSD-name fallback when link is down
- `Sources/tb_probe.c/.h` — IOServiceRequestProbe with PCIe-parent walk,
  NHI-direct fallback, kIOServiceInteractionAllowed flag

**IOKit constants corrected during development:**
- `kIOServiceRequired` → does not exist in Tahoe SDK; correct: `kIOServiceInteractionAllowed`
- `kIOMasterPortDefault` → deprecated macOS 12; replaced with `kIOMainPortDefault`

**Dry-run output confirmed (both NHIs detected with link down):**
```
Detected Thunderbolt interfaces (2):
  [0]  iface=(NHI0 — link down)  HAL=AppleThunderboltHAL  PCIe=NHI0
  [1]  iface=(NHI1 — link down)  HAL=AppleThunderboltHAL  PCIe=NHI0
```

### Bridge Restore integration

- `tools/tb-reset/tb-reset` — compiled binary deployed as module
- `tools/tb-reset/README.md` — module documentation
- `scripts/tb-reset-trigger.sh` — wrapper: finds binary, falls back to ifconfig bounce
- `_sever_tb_gateway()` updated: now has **6 methods** (was 4; M5 NHI kextunload,
  M6 tb-reset IOKit probe added this session)
- `CHANGELOG.md` created (was missing; covers all versions back to 1.0.0)

### Version bump
- `bridge-restore-app.sh`: 1.0.4-alpha/26A05 → **1.0.6/26A06**
- `bridge-restore-panel.swift`, `.js`, `bridge-restore-gui.sh`: all updated
- `package.json`: 1.0.2-alpha → 1.0.6
- Build number regression corrected (script had stale 26A03; actual last was 26A05 → now 26A06)

### Connection status during session
- Mini drops occurring every 2–3 minutes (faster than normal ~30–90 min pattern)
- Suggests adapter firmware cycling (TB3↔TB1 negotiation instability)
- Physical cable reseats restored connection; mini reachable at 192.168.2.2 directly

### Pending
- Compile tb-reset in Xcode and test live `sudo tb-reset` on connected cable
- Deploy full project to mini `~/dev/` once connection stable
- Build mini-side self-healing L1 watchdog (launchd + tb-reset on mini)

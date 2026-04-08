# OPENCLAW FULL PROJECT DEBRIEFING
## For: OpenClaw (Claude Code Pro — local instance on Mac mini / MBP)
## Written by: Claude (Anthropic, cloud) + Adam Macks (akmacks)
## Date: 2026-03-28
## Purpose: Complete context brief so OpenClaw can continue development autonomously

---

## HOW TO READ THIS DOCUMENT

This is your complete onboarding document. Read it top to bottom before taking
any action. It covers:
1. What machines exist and how they connect
2. What has been built, changed, and why
3. Where every file lives (including relocated ones)
4. What is broken and what is working
5. Exactly what to do next

---

## PART 1 — MACHINES

### MacBook Pro ("MBP", "pro", "i9")
- Model: MacBook Pro 16,1 (2019, T2 chip)
- Hostname: MacBook-Pro-i9
- User: akmacks | sudo: NOPASSWD
- OS: macOS Tahoe 26.x
- IP (TB bridge): 192.168.2.1
- OCLP repo: ~/Documents/Github/OpenCore-Legacy-Patcher/  (git, branch: macos-next)
- Scripts: ~/scripts/
- Logs: ~/logs/
- OpenClaw config: ~/.openclaw/
- Desktop Commander MCP: RUNNING (this is how Claude controls MBP shell)

### Mac mini Server ("mini", "mms", "OC mini")
- Model: Mac mini Server (Late 2011) — Macmini5,3
- Hostname: Mac-mini-Server-i7
- User: akmacks | sudo: NOPASSWD 
- OS: macOS Tahoe 26.3.1 (Build 25D2128, Darwin 25.3.0)
- CPU: Intel Core i7-2635QM (Sandy Bridge)
- GPU: Intel HD 3000 + AMD Radeon HD 6630M
- IP (TB bridge): 192.168.2.2 | MAC: 82:0c:4d:eb:46:81
- Scripts: ~/scripts/  (SAME PATH as MBP — intentional)
- Logs: ~/logs/
- Desktop Commander MCP: RUNNING on mini too
- Ollama: installed, llama3.2:3b pulling in background


---

## PART 2 — CONNECTIVITY ARCHITECTURE

### How MBP ↔ Mini communicate
The mini has NO working Ethernet (being fixed — see Part 4).
Internet comes from MBP via Thunderbolt Bridge + macOS Internet Sharing (NAT).

```
Internet → MBP Wi-Fi (en0) → NAT/pfctl → bridge0 → TB cable → mini bridge0
                                                   ↕
                              Reverse SSH tunnel (port 2222)
                              mini runs: ssh -R 2222:localhost:22 akmacks@192.168.2.1
                              MBP SSHes: ssh -p 2222 akmacks@localhost
```

### Known failure mode
The Thunderbolt physical link drops silently — bridge0 retains its IP but
L1 negotiation fails. Fix: `sudo ifconfig en4 down && sleep 10 && sudo ifconfig en4 up`
Both tunnel scripts (tunnel-pro.sh, tunnel-mini.sh) do this automatically.

### Commands to restore connection
On mini: `tunnel-pro`   → opens reverse tunnel to MBP, shows CAPS banner + popup on both
On MBP:  `tunnel-mini`  → completes ControlMaster, NAT, popup on mini

### Ping note
`ping 8.8.8.8` FAILS through NAT. This is NORMAL. Safari/Claude work fine.
Do not chase ping failures as a connectivity problem.

---

## PART 3 — FILE LOCATIONS (CANONICAL)

### MBP ~/scripts/  (primary scripts — deploy to mini via SSH)
```
~/scripts/
├── tunnel-mini.sh       ← MBP side: NAT + TB bounce + ControlMaster + popup
├── tunnel-pro.sh        ← Mini side: bridge IP + TB bounce + reverse tunnel + popup
├── bridge-restore.sh    ← MBP: AI-powered restore with Ollama fallback
├── install-on-mini.sh   ← Deploy scripts to mini (run once after tunnel up)
├── reconnect-mini.sh    ← Quick NAT+ControlMaster restore
├── mini-watchdog.sh     ← Daemon: watches for mini drop, auto-reconnects
└── mini-launchd/        ← LaunchAgent plists for mini deployment
```

### MBP ~/logs/
```
~/logs/
├── tunnel-mini.log      ← Every tunnel-mini run (success/fail with timestamp)
├── mini-watchdog.log    ← Watchdog daemon activity
├── scripts/             ← Reserved for future script logs
└── openclaw/            ← RELOCATED: formerly stray oc_*.txt and mini_*.txt files
    ├── oc_doctor.txt
    ├── oc_fix.txt        (and 15 others — see Part 6)
    └── patch_mini.py
```

### MBP ~/bridge-restore/  (older version — superseded by ~/scripts/)
```
~/bridge-restore/
├── README.md
├── bridge-restore.sh    ← older version, use ~/scripts/ version instead
├── diagnose.sh
├── ollama-agent.sh
├── install.sh
└── logs/
```

### MBP ~/.openclaw/  (OpenClaw config and logs)
```
~/.openclaw/
├── openclaw.json        ← main config
├── logs/                ← gateway.log, node.log, etc.
├── extensions/          ← plugins (bluebubbles, telegram, etc.)
├── memory/
├── agents/
└── OPENCLAW-DEBRIEF.md  ← THIS FILE
```

### Mini ~/scripts/  (deployed copies of MBP scripts)
```
~/scripts/
├── tunnel-pro.sh        ← system command at /usr/local/bin/tunnel-pro
└── bridge-restore.sh    ← AI-powered restore with Ollama
```

### Mini LaunchAgents (auto-start on boot)
```
~/Library/LaunchAgents/
├── local.bridge-ip.plist   ← keeps bridge0 at 192.168.2.2 every 20s
└── local.tunnel-pro.plist  ← auto-restarts tunnel-pro if it exits
```

### OCLP Project docs (MBP)
```
~/Documents/Github/OpenCore-Legacy-Patcher/docs/
├── TAHOE-DEV-LOG.md        ← MAIN DEV LOG: all 5 sessions
├── SESSION-HANDOFF.md      ← Context brief for next Claude session
└── THUNDERBOLT-BRIDGE-SETUP.md ← TB bridge setup and lessons
```


---

## PART 4 — OCLP 3.0.0 PROJECT STATUS

### Goal
Make OCLP 3.0.0 (branch: macos-next) run macOS Tahoe on Mac mini Server (Macmini5,3).
Contribute fixes upstream to Dortania once stable.

### Git state
Repo: ~/Documents/Github/OpenCore-Legacy-Patcher/
Branch: macos-next (HEAD: dba48072f "unblock tahoe")
Status: 4 files modified (uncommitted working tree), no custom commits yet

### Source changes made (working tree, not committed)

| File | Change | Why |
|---|---|---|
| constants.py | Added is_patching_external_volume flag (has duplicate at line 151/152 — needs cleanup) | Bypass security checks when patching TDM volume |
| sys_patch/patchsets/detect.py | OS ceiling extended to Tahoe | OCLP refused to patch Tahoe targets |
| wx_gui/gui_main_menu.py | External volume detection in Post-Install | Companion to constants.py flag |
| sys_patch/patchsets/hardware/misc/modern_audio.py | Fallback to 15.2 PSP folder for AppleHDA.kext | No Tahoe-specific PSP assets yet in 1.9.5 |

### NOT YET in mini repo (only on MBP working tree)
- sys_patch/patchsets/hardware/misc/usb11.py — Added Macmini5,1/2/3 — fixes dead keyboard/mouse

### CRITICAL: Correct file paths (old session notes were wrong)
- datasets/model_array.py  (NOT data/)
- sys_patch/patchsets/hardware/misc/usb11.py  (NOT sys_patch/patchsets/hardware/usb/)
- NO ethernet patchset directory — Ethernet is EFI-only via efi_builder/networking/wired.py

### EFI on Mac mini (disk0s1, /Volumes/EFI)
OpenCore EFI is installed on the mini's internal disk.
Key kexts in /Volumes/EFI/EFI/OC/Kexts/:
  CatalinaBCM5701Ethernet — contains pci14e4,1682 (BCM5722 device ID) ✅
  IO80211FamilyLegacy + IOSkywalkFamily — Wi-Fi stack
  AirportBrcmFixup — Wi-Fi fix
  AppleALC — Audio
  BlueToolFixup — Bluetooth
  Lilu, AMFIPass, RestrictEvents, CryptexFixup, RSRHelper

### Kernel patch in config.plist (CRITICAL — applied Session 4)
```
Kernel:Patch[0]:
  Identifier: com.apple.iokit.CatalinaBCM5701Ethernet
  Enabled:    true
  Arch:       x86_64
  MinKernel:  20.0.0
  Find:       e8ca9effff66898300050000
  Replace:    b8b416000066898300050000
```
This patch is required for CatalinaBCM5701Ethernet.kext to load on Big Sur+.
Without it the kext silently fails to attach at boot.

### OCLP root patches — NEVER APPLIED
/Library/Application Support/com.dortania.OpenCore-Legacy-Patcher/AppliedPatches.plist
DOES NOT EXIST. GPU, Wi-Fi, Audio, BT all depend on root patches being applied.


---

## PART 5 — HARDWARE STATUS (Mac mini)

| Component | Status | Notes |
|---|---|---|
| macOS Tahoe 26.3.1 boot | ✅ Working | OC EFI on disk0s1 |
| Intel HD 3000 GPU patches | ✅ Applied | Sandy Bridge kexts injected via root patch |
| Colour login screen | ✅ Confirmed | |
| USB HID (keyboard + mouse) | ✅ Working | Synergy removed; usb11.py patched |
| Apple Remote Desktop | ✅ Working | Access from MBP |
| SSH tunnel | ✅ Working | tunnel-pro + tunnel-mini workflow |
| Internet via TB NAT | ✅ Working | Safari/Claude confirmed. Ping ICMP blocked (normal) |
| Ethernet BCM5722 | ⏳ PENDING TEST | Kernel patch in EFI. Mini needs reboot to test |
| Wi-Fi BCM43xx | ❓ Unknown | EFI kexts present, root patches never applied |
| Audio ALC892 | ❓ Unknown | AppleALC in EFI, root patches never applied |
| Bluetooth | ❌ Not working | BlueToolFixup in EFI, root patches never applied |
| Tailscale | ❌ NoState | Needs Ethernet first |
| OCLP root patches | ❌ Never applied | THIS IS THE NEXT BIG TASK |
| llama3.2:3b (Ollama) | ⏳ Pulling | Background pull ~2GB |

---

## PART 6 — STRAY LOG FILES (RELOCATED)

These files were previously cluttering ~/  (home root). Moved to ~/logs/openclaw/.
They are OpenClaw/Claude Code diagnostic outputs from previous work sessions.

Location: /Users/akmacks/logs/openclaw/
Files: bb_url_update.txt, mini_doctor.txt, mini_doctor2-4.txt,
       mini_node.txt, mini_result.txt, mini_tg.txt, mini_tg_update.txt,
       mini_which.txt, oc_channels.txt, oc_doctor.txt, oc_doctor2.txt,
       oc_doctor_final.txt, oc_fix.txt, oc_fix2.txt, patch_mini.py

### Why they ended up in ~/
OpenClaw was launched from ~/ as CWD, so all relative file writes landed there.

### Prevention
Alias added to ~/.zshrc:
  alias openclaw='cd "$HOME/.openclaw" && openclaw; cd - > /dev/null'
This ensures OpenClaw always runs from ~/.openclaw/ as CWD.
All future relative-path output goes to ~/.openclaw/ not ~/.

---

## PART 7 — SHELL ALIASES (BOTH MACHINES)

### MBP ~/.zshrc
```bash
alias tunnel-mini='bash ~/scripts/tunnel-mini.sh'
alias ssh-mini='ssh -p 2222 akmacks@localhost'
alias mini-status='ssh -p 2222 -o ConnectTimeout=5 -o BatchMode=yes akmacks@localhost "bash ~/scripts/bridge-restore.sh --status" 2>/dev/null || echo "Mini unreachable"'
alias bridge-restore-mini='ssh -p 2222 -o ConnectTimeout=5 akmacks@localhost "bash ~/scripts/bridge-restore.sh"'
alias openclaw='cd "$HOME/.openclaw" && openclaw; cd - > /dev/null'
```

### Mini ~/.zshrc
```bash
alias tunnel-pro='bash ~/scripts/tunnel-pro.sh'
alias bridge-restore='bash ~/scripts/bridge-restore.sh'
alias bridge-status='bash ~/scripts/bridge-restore.sh --status'
alias bridge-diag='bash ~/scripts/bridge-restore.sh --diag'
alias bridge-ai='bash ~/scripts/bridge-restore.sh --ai'
alias ssh-pro='ssh akmacks@192.168.2.1'
```


---

## PART 8 — IMMEDIATE TASK LIST (PRIORITY ORDER)

### 1. TEST ETHERNET (do this first after next mini reboot)
```bash
# On MBP, after running tunnel-mini:
ssh-mini "kextstat | grep -iE 'BCM|5701|catali'; system_profiler SPEthernetDataType | head -20"
```
Expected: com.apple.iokit.CatalinaBCM5701Ethernet in kextstat + hardware detected.
If kext NOT loading: the Find bytes may have shifted in Darwin 25.
Debug: `otool -tv /Volumes/EFI/EFI/OC/Kexts/CatalinaBCM5701Ethernet.kext/Contents/MacOS/CatalinaBCM5701Ethernet | grep -B5 -A5 "e8ca9e"`

### 2. APPLY OCLP ROOT PATCHES
```bash
ssh-mini "sudo /usr/local/bin/python3.14 ~/Documents/Github/OpenCore-Legacy-Patcher/OpenCore-Patcher-GUI.command"
```
OR via CLI patching. This fixes: GPU colour, Audio, Wi-Fi, Bluetooth.

### 3. FIX constants.py DUPLICATE LINE
File: opencore_legacy_patcher/constants.py
Lines 151-152 both contain: self.is_patching_external_volume: bool = False
Remove the duplicate.

### 4. SYNC usb11.py TO MINI REPO
File: opencore_legacy_patcher/sys_patch/patchsets/hardware/misc/usb11.py
Add Macmini5,1, Macmini5,2, Macmini5,3 to the USB 1.1 patchset.
(Already done on MBP working tree — just needs syncing to mini.)

### 5. AUTHENTICATE TAILSCALE
```bash
ssh-mini "tailscale up"
```
Requires Ethernet working first (Step 1).

### 6. COMMIT ALL SOURCE CHANGES TO GIT
Once Ethernet + root patches confirmed working, commit all working tree changes
with a clear commit message, then push to origin fork.

### 7. BAKE ETHERNET KERNEL PATCH INTO OCLP SOURCE
The kernel patch for CatalinaBCM5701Ethernet currently lives only in the EFI
config.plist. It should be automatically added during EFI build for pre-Ivy Bridge
models. Target file: efi_builder/networking/wired.py or a new patch application step.

---

## PART 9 — KEY TECHNICAL LEARNINGS

1. Ping failure ≠ no internet. macOS NAT blocks ICMP. Confirm with Safari/curl.

2. CatalinaBCM5701Ethernet.kext already supports BCM5722 (pci14e4,1682 in Info.plist).
   No new kext needed. Only the Big Sur+ kernel binary patch was missing.

3. OCLP "Ethernet Chipset: Broadcom" in smbios_data routes to CatalinaBCM5701 via
   _prebuilt_assumption() in wired.py. This is correct for Macmini5,3.

4. Thunderbolt bridge drops silently at L1. Software fix: ifconfig <port> down/up.
   Both tunnel scripts now do this automatically.

5. scp fails via reverse tunnel (no sftp subsystem). Use:
   ssh -p 2222 ... "cat > ~/dest/file" < ~/source/file

6. PlistBuddy mishandles binary data in config.plist. Always use Python plistlib.

7. EFI files on mini are owned by akmacks — no sudo needed for direct writes.

8. detect.py is at sys_patch/patchsets/detect.py (not top-level detections/).
   model_array.py is at datasets/model_array.py (not data/).

9. OpenClaw launched from ~/ writes output to ~/. Fix: alias to cd ~/.openclaw first.

10. When Desktop Commander is running on mini and Claude session is opened FROM mini
    browser, Claude has direct shell access without any SSH tunnel.

---

## PART 10 — SESSION HISTORY LINKS

- Session 1 (2026-03-22): https://claude.ai/chat/aee6f07c-e9b4-47ad-aca4-ffd76a19df4f
- Session 2 (2026-03-23): https://claude.ai/chat/3c791c6b-be12-4f24-850f-270b44db9fb7
- Sessions 3-5 (2026-03-27/28): See Project "OpenClaw Legacy Patcher" in Claude.ai

Full dev log: ~/Documents/Github/OpenCore-Legacy-Patcher/docs/TAHOE-DEV-LOG.md
Session handoff: ~/Documents/Github/OpenCore-Legacy-Patcher/docs/SESSION-HANDOFF.md
TB bridge setup: ~/Documents/Github/OpenCore-Legacy-Patcher/docs/THUNDERBOLT-BRIDGE-SETUP.md

---
Generated: 2026-03-28 by Claude (Anthropic) for OpenClaw handoff
Do not treat inferred items as confirmed — run diagnostics before acting.

---

## CRITICAL CORRECTION — Sessions 5/6 (2026-03-28)

### IP Ownership (immutable — never swap these)
| Machine | bridge0 IP | Model | UUID |
|---|---|---|---|
| MBP (MacBook Pro i9) | **192.168.2.1** | MacBookPro16,1 | 4B4DFAAB-B77A-5B8F-BE93-85E6F990529F |
| Mini (Mac mini Server) | **192.168.2.2** | Macmini5,3 | (model check sufficient) |

### What Went Wrong
Scripts without hardware identity checks ran on the wrong machine and
corrupted the MBP's bridge0 IP (set it to 192.168.2.2 instead of 192.168.2.1).
Desktop Commander is connected to the MBP at all times unless explicitly stated.

### All Scripts Now Have Hardware UUID Guard
The guard runs FIRST — before any variables or ifconfig commands:
- tunnel-mini.sh: requires MacBookPro16,1 + UUID 4B4DFAAB — refuses on Mini
- tunnel-pro.sh: requires Macmini5,3 — refuses on MBP
- bridge-restore.sh: requires Macmini5,3 — refuses on MBP

### For Future Claude Sessions
ALWAYS run this before any network command:
  system_profiler SPHardwareDataType | grep -E "Model Identifier|Hardware UUID"
Expected MBP output: MacBookPro16,1 / 4B4DFAAB-B77A-5B8F-BE93-85E6F990529F
If different — you are on the mini. Adjust all commands accordingly.


---

## PART 11 — BRIDGE RESTORE APP (Session 7, 2026-03-28)

### App Location
`~/dev/projects/apps/bridge-restore/` — ready for GitHub/VS Code/Xcode

### Entry Point
```bash
bridge-restore-app              # auto-detect role, restore
bridge-restore-app --wizard     # setup wizard
bridge-restore-app --prefs      # preferences (Hosts / Diagnostics / Watchdog)
bridge-restore-app --diag       # diagnostics across all OSI layers
bridge-restore-app --debug      # verbose
bridge-restore-app --watchdog   # start watchdog daemon
bridge-restore-app --ai         # Ollama AI fallback
bridge-restore-app --sever      # force TB severance (4 methods, gateway only)
```

### Role Detection
Hardware UUID + Model Identifier — checked FIRST before any command.
Config stored at `~/.config/bridge-restore/config.json`

### Key Architecture Decisions
1. **Single app, dual-role** — same script, detects gateway vs client from hardware
2. **OSI layer diagnostics** — L1-L7 individually toggleable in config/prefs
3. **IS toggle uses defaults write** — more reliable than launchctl on Tahoe
4. **IS "Turn On" dialog** — auto-clicked via background AppleScript watcher
5. **Watchdog embedded** — not a separate process; `--watchdog` flag activates it
6. **Local LLM first** — AI fallback prefers offline models over cloud

### Intermittent Bridge Failure After ~28 Pings
- Observed: internet drops after ~28 pings even when manually restored
- Hypothesis: mini's `local.tunnel-pro` launchd keeps bouncing TB interface
- Fix: increase ThrottleInterval in local.tunnel-pro.plist to 120+s, or check
  if tunnel-pro's bridge bounce logic triggers on an already-working bridge

### Next Steps for App Development
1. SwiftUI wrapper — native macOS app with MenuBar icon
2. Preferences window in Swift (replaces AppleScript dialogs)
3. Keychain for credential storage
4. Notarization for distribution outside dev environment
5. Auto-update via Sparkle

### File Naming Convention (matching ~/dev/projects/apps/)
Current: `bridge-restore` (lowercase)
Suggest rename to: `app_macOS-Intel_BridgeRestore` for consistency


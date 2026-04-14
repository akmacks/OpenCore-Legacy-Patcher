# OCLP 3.0.0 Dev — Session Handoff
---

## ⚠️ SESSION 19 UPDATE — 2026-04-13 (TDM repair)

### ROOT CAUSE OF 3-DAY BREAKAGE FOUND AND FIXED

**`local.nat-persist.plist` was incorrectly installed on the Mac mini.**
This is a GATEWAY-ONLY agent. On the mini it was:
- Setting bridge0 to **192.168.2.1** (the MBP's IP) on every reboot
- Enabling IP forwarding (making mini act as a router)  
- Loading `nat on en0 from 192.168.2.0/24 → (en0)` PF rules (broken: en0/BCM5722 is disabled)

This fought `local.bridge-ip.plist` on every boot, causing non-deterministic IP assignment and
broken tunnel establishment after every reboot. **Friday night's "more support" changes
accidentally installed the MBP's nat-persist onto the mini.**

### FIXES APPLIED (via TDM, 2026-04-13)

1. `local.nat-persist.plist` → `local.nat-persist.plist.disabled` on mini ✅
2. `/etc/pf.anchors/bridge-restore` on mini → replaced with `pass all` (no more client NAT) ✅
3. `local.bridge-ip.plist` on MBP → renamed to `.disabled` (was setting MBP bridge0 to 192.168.2.2) ✅
4. `RemoteLogin.plist` written to mini Data volume → ensures sshd starts on boot ✅
5. `tunnel-pro.sh` on MBP repo updated → ioreg identity check + ifconfig bridge0 IP fix ✅

### CURRENT STATE (post-TDM-repair)

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | ✅ | Boots, auto-login |
| OpenCore EFI | ✅ | WhateverGreen headless (ig-platform-id 0x10030000) |
| VNC/Screen Sharing | 🟡 | Framebuffer renders, Finder/Dock not running |
| USB keyboard (direct) | ❌ | UHCI ABI mismatch — use USB 2.0 hub with TT |
| USB via hub | ✅ | Hub with Transaction Translator required |
| SSH (TB bridge) | ✅ (expected) | Should recover post-reboot now nat-persist removed |
| Tailscale | 🟡 | Should recover once bridge/internet is up |
| OCLP root patches | ❌ | Not applied — waiting on Tahoe-compatible UHCI kext binaries |

### DO NOT RE-INSTALL nat-persist ON THE MINI
The plist remains as `.disabled` for reference. The mini is a CLIENT — it has no internet 
to share. NAT lives only on the MBP (gateway).

### BOOT SEQUENCE AFTER REPAIR (expected)
1. Mini boots → auto-login
2. `local.bridge-ip` loops every 20s → sets bridge0 = 192.168.2.2
3. `local.tunnel-pro` starts → ioreg identity check (~1s) → connects to 192.168.2.1:22 → opens reverse tunnel on MBP port 2222
4. `local.mini-bridge-watchdog` runs every 30s → monitors, restarts tunnel-pro if needed
5. MBP: run `tunnel-mini` to complete ControlMaster setup


## For: OpenClaw (local Ollama on MBP) or next Claude instance
## Generated: 2026-04-13 | Session 18 closed
## Project: OpenCore Legacy Patcher

---

## ⚠️ CURRENT SITUATION — READ THIS FIRST

**Mac mini is UP.** Auto-login working. VNC shows desktop (login screen background).
SSH reachable at `192.168.2.2` or `100.86.233.5`.

**VNC is partially working** — framebuffer now renders 1920×1080 via WhateverGreen headless mode.
Finder and Dock are NOT running — desktop session is incomplete.
Mouse movements via VNC may not sync with physical display.

**WhateverGreen is ENABLED** in headless framebuffer mode (ig-platform-id 0x10030000).
**Do NOT enable full GPU acceleration** — causes kernel panics on Macmini5,3 with Tahoe.

**USB keyboard is non-functional.** All 4 rear USB ports are dead without UHCI kext support.
**Workaround: plug keyboard into a USB 2.0 hub first**, then plug hub into the mini.

**Do NOT attempt OCLP root patches until Tahoe-compatible UHCI kext binaries exist.**

---

## MACHINES

Mac mini (TARGET — currently in TDM)
  hostname:   Mac-mini-Server-i7
  model:      Macmini5,3 (Late 2011 Server)
  user:       akmacks
  sudo:       NOPASSWD
  OS:         macOS Tahoe 26.4 (Build 25E246, Darwin 25.3.0)
  OCLP repo:  ~/OpenCore-Legacy-Patcher/
  CPU:        Intel Core i7-2635QM (Sandy Bridge)
  GPU:        Intel HD 3000 + AMD Radeon HD 6630M
  Ethernet:   Broadcom BCM57765 (BROKEN — kext not matching)
  Wi-Fi:      BCM4331 (kext loaded, no interface)
  Audio:      ALC892 (unknown)
  Internet:   Via Thunderbolt bridge from MBP (NAT) — currently down

MacBook Pro (controller / MCP-connected)
  hostname:   MacBook-Pro-i9
  user:       akmacks
  OCLP repo:  ~/Documents/Github/OpenCore-Legacy-Patcher/
  Bridge IP:  192.168.2.1

---

## TDM RECOVERY STEPS

### 1. Confirm TDM disk visible
```bash
diskutil list
# Find external disk ~500GB-1TB — note its identifier (e.g., disk8)
```

### 2. Mount mini volumes
```bash
# List APFS containers on mini disk
diskutil apfs list

# Mount the data volume (usually "Server HD")
sudo diskutil mount disk8s4   # adjust identifier
# Also mount EFI if you need to change boot-args
sudo diskutil mount disk8s1
```

### 3. Roll back APFS snapshot
```bash
MINI_VOL="/Volumes/Server HD"   # adjust if named differently
sudo mount -uw "$MINI_VOL"
sudo bless --mount "$MINI_VOL" --last-sealed-snapshot
```
> IMPORTANT: `diskutil apfs revertSnapshot` does NOT exist on Tahoe.
> bless --last-sealed-snapshot is the ONLY supported rollback method.

### 4. Verify SSH will be enabled on reboot
```bash
# Check if RemoteLogin plist exists on mini's volume
find /Volumes/Server\ HD/Library/Preferences -name "*RemoteLogin*" 2>/dev/null
# If missing:
sudo defaults write /Volumes/Server\ HD/Library/Preferences/SystemConfiguration/com.apple.RemoteLogin RemoteLogin -bool true
```

### 5. Unmount mini disk and reboot mini
```bash
sudo diskutil unmountDisk disk8   # use mini's disk identifier
# Then use mini's power button or hold it down to reboot
```

### 6. Restore tunnel from MBP
```bash
# Wait ~60s for mini to boot, then:
ssh akmacks@192.168.2.2 'nohup tunnel-pro &>/dev/null &'
# or if bridge not up yet:
~/scripts/reconnect-mini.sh
# Then verify:
ssh -p 2222 akmacks@localhost hostname
```

### 7. Post-recovery state verification
```bash
ssh -p 2222 akmacks@localhost << 'REMOTE'
echo "=== UUID ===" && ioreg -rd1 -c IOPlatformExpertDevice | awk -F'"' '/UUID/{print $4}'
echo "=== kexts ===" && kextstat | grep -E "UHCI|SandyBridge|HD3000|Airport|Bluetooth|HDA|BCM"
echo "=== bridge ===" && ifconfig bridge0 | awk '/inet /{print $2}'
echo "=== tailscale ===" && tailscale ip -4 2>/dev/null || echo "down"
echo "=== internet ===" && ping -c 1 8.8.8.8 | tail -2
REMOTE
```

---

## CURRENT STATE (Session 18 end — 2026-04-13)

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | ✅ | Booted, auto-login working |
| OpenCore EFI | ✅ | disk0s1, WhateverGreen ENABLED (headless) |
| Boot snapshot | ✅ | XID 2415851 + tmutil snapshot 2026-04-13-161247 |
| WhateverGreen | ✅ | Headless framebuffer mode, ig-platform-id 0x10030000 |
| Intel HD 3000 GPU | 🟡 | Framebuffer only (1920×1080), NO hardware acceleration |
| VNC/Screen Sharing | 🟡 | Renders desktop, Finder/Dock not running |
| USB keyboard (wired) | ❌ | UHCI kexts ABI-incompatible with Tahoe — use USB hub workaround |
| USB 2.0 via hub | ✅ | Works if keyboard connected via USB 2.0 hub with TT |
| OCLP root patches | ❌ | Not applied — see USB section below |
| Internet (TB bridge NAT) | ✅ | SSH reachable at 192.168.2.2 |
| Tailscale | ✅ | 100.86.233.5 |
| SSH (direct bridge) | ✅ | akmacks@192.168.2.2 |
| Ethernet BCM57765 | ❌ | CatalinaBCM5701 not loading — device ID mismatch |
| Wi-Fi BCM4331 | 🟡 | AirPortBrcmFixup loaded, no interface |
| Bluetooth | 🟡 | BlueToolFixup loaded, pairing untested |
| Audio ALC892 | ❓ | AppleALC loaded but unverified |
| openclawadmin user | ❌ | Created in-session but did not persist through reboot |

## USB ARCHITECTURE ON Macmini5,3 (CRITICAL for OCLP 3.0.0)

**Topology confirmed in Session 17:**
- EHC1 + EHC2 (EHCI, USB 2.0): mapped by USB-Map.kext to internal ports ONLY (Bluetooth, UsbConnector=255)
- All 4 rear USB panel ports: UHCI companion controllers (Intel 6 Series, device IDs: 0x1c28–0x1c2f)
- Without UHCI drivers, rear USB is completely dead — ioreg IOUSB plane shows NO child devices

**Why 12.6.2-USB payload kexts fail on Tahoe (vtable ABI mismatch):**
```
AppleUSBOHCI:   superclass AppleUSBHostPort has 333 vtable entries; kext expects 332
AppleUSBUHCI:   superclass AppleUSB20HostController has 376 entries; kext expects 375
```
These binaries were compiled against macOS 12.6 (Monterey) IOUSBHostFamily.
Tahoe's IOUSBHostFamily has an updated ABI — one vtable entry added to each superclass.

**What OCLP 3.0.0 must do for USB 1.1 support on Sandy Bridge:**
1. Recompile AppleUSBUHCI + AppleUSBUHCIPCI against Tahoe's IOUSBHostFamily headers
   (OHCI is not needed — Sandy Bridge is UHCI only)
2. OR: Add OpenCore kernel patches to fix vtable offsets at load time (as older OCLP does for older compat)

**Immediate workaround (no kexts needed):**
USB hub with Transaction Translator → keyboard works through EHCI without UHCI.

---

## PRIORITY WORK AFTER RECOVERY

Pulled from AGENT-COORDINATION.md (do not start until recovery complete):

### P1 — Ethernet BCM57765

The real chip is BCM57765, but the EFI kext is `CatalinaBCM5701Ethernet.kext`.
This may be a device ID mismatch. Investigation needed:

```bash
# On mini post-recovery:
ioreg -l | grep -i "BCM\|ethernet\|network" | grep -i "vendor\|product\|device"
# Check kernel log for kext rejection:
log show --last 5m --predicate 'process == "kernel"' | grep -i "BCM\|ethernet\|5701\|57765"
# Check what device IDs CatalinaBCM5701 declares:
kextutil -n -v /Volumes/EFI/EFI/OC/Kexts/CatalinaBCM5701Ethernet.kext 2>&1 | head -40
```

If device ID mismatch confirmed: add BCM57765 device ID to the kext's IOKitPersonalities
in Info.plist (edit on MBP, deploy via rsync).

### P2 — Wi-Fi BCM4331 (legacy_wireless root patch)

```bash
# On mini, from OCLP repo:
cd ~/OpenCore-Legacy-Patcher
sudo /usr/local/bin/python3.14 -c "
from opencore_legacy_patcher.sys_patch import sys_patch
# run legacy_wireless patchset only
"
# Or use the filter script approach from run_usb11_patch.py as template
```

### P3 — Audio (ALC892)

```bash
kextstat | grep -i "audio\|HDA\|ALC"
system_profiler SPAudioDataType
```

---

## OCLP REPO STATUS (MBP copy — macos-next branch)

Latest commit: Session 19 close — USB-Map Tahoe fix, 26A03 release  
Branch: `macos-next`  
Remote: `https://github.com/akmacks/OpenCore-Legacy-Patcher`  

Files modified vs upstream Dortania (do not overwrite):
1. `opencore_legacy_patcher/support/subprocess_wrapper.py` — sudo bypass
2. `opencore_legacy_patcher/sys_patch/sys_patch.py` — preflight skip missing payloads
3. `opencore_legacy_patcher/sys_patch/patchsets/hardware/misc/usb11.py` — Macmini5,x exception
4. `opencore_legacy_patcher/constants.py` — `legacy_accel_support` Tahoe fix
5. `opencore_legacy_patcher/sys_patch/patchsets/hardware/misc/legacy_wireless.py` — XNU cap fix

---

## DEV TOOLS ON MINI

| Tool | Location | Notes |
|------|----------|-------|
| patch runner | `~/run_usb11_patch.py` | Template for filtered patch runs |
| python3.14 | `/usr/local/bin/python3.14` | Required for OCLP |
| KDK | `/Library/Developer/KDKs/KDK_26.4_25E246.kdk` | Already installed |
| MetallibSupportPkg | `/Library/Application Support/Dortania/MetallibSupportPkg/` | Sequoia 15.4 |
| tunnel-pro | `/usr/local/bin/tunnel-pro` | Starts reverse SSH to MBP |

---

## RSYNC (mini ↔ MBP)

```bash
# MBP → mini (push)
rsync -avz ~/Documents/Github/OpenCore-Legacy-Patcher/ \
  -e "ssh -p 2222" akmacks@localhost:~/OpenCore-Legacy-Patcher/

# mini → MBP (pull)
rsync -avz -e "ssh -p 2222" akmacks@localhost:~/OpenCore-Legacy-Patcher/ \
  ~/Documents/Github/OpenCore-Legacy-Patcher/
```

---

## KEY GOTCHAS (Tahoe-specific)

- `diskutil apfs revertSnapshot` — DOES NOT EXIST on Tahoe. Use `bless --last-sealed-snapshot`
- `system_profiler` — takes 30+ seconds on 2011 hardware. Use `ioreg` for UUID
- `ipconfig getifaddr bridge0` — fails silently on Tahoe bridge interfaces. Use `ifconfig bridge0 | awk '/inet /{print $2}'`
- `launchctl load/bootstrap` — fails with I/O error 5 for system daemons on Tahoe. Use `sudo /usr/sbin/sshd` directly
- Never run Ollama inference locally on the mini — `qwen3:4b` freezes 2011 hardware
- Never `pkill -f ollama` — Ollama is shared infrastructure

---

## SESSION HISTORY

Session 1–12: Initial connectivity, GPU patches, Synergy removal  
Session 13: KDK forensic, v3.0.0-alpha (26A02), coordination docs  
Session 14–15 (Apr 9): Root patch attempt → freeze → rollback planned  
Session 15 (Apr 10): TDM rollback to XID 2239951  
Session 16 (Apr 10): USB 1.1 re-patch, stable desktop 36+ min  
Session 17 (Apr 12): TDM recovery, USB architecture fully documented, ABI mismatch root-caused  
Session 18 (Apr 13): Framebuffer breakthrough — WhateverGreen headless mode enables VNC, desktop session partial (Finder/Dock not running)
Session 19 (Apr 13): USB no-power root-caused (USB-Map Tahoe key format), fixed, USB 1.0+2.0 confirmed working; LaunchAgent set repaired; WhateverGreen headless reverted  

Claude session links:
Session 1: https://claude.ai/chat/aee6f07c-e9b4-47ad-aca4-ffd76a19df4f
Session 2: https://claude.ai/chat/3c791c6b-be12-4f24-850f-270b44db9fb7

---

## AGENT PROTOCOL REMINDERS

1. Hardware UUID check FIRST — every session, before any network command
2. Do NOT increment version numbers autonomously
3. Do NOT run Ollama inference on the mini
4. Do NOT pkill ollama
5. Append to STATUS-FEED.md on session open AND close
6. Update AGENT-COORDINATION.md current state at session close
7. Git commit + push before ending session

---

---

## SESSION 19 — TDM REPAIR + USB FIX (2026-04-13)

### What Was Fixed

**1. LaunchAgent root cause (3-day tunnel breakage)**
- `local.nat-persist.plist` on mini → renamed `.disabled` via TDM
  - Was setting mini's bridge0 to 192.168.2.1 (MBP's IP), enabling IP forwarding, loading NAT rules
- `local.bridge-ip.plist` on MBP → renamed `.disabled`
  - Was overwriting MBP bridge0 to 192.168.2.2 (mini's IP) every 20s
- `/etc/pf.anchors/bridge-restore` on mini → replaced with `# CLIENT ONLY\npass all`

**2. WhateverGreen headless framebuffer reverted**
- Removed `PciRoot(0x0)/Pci(0x2,0x0)` DeviceProperties from `/Volumes/EFI/EFI/OC/config.plist`
  - Had `ig-platform-id: AAADEA==` (0x10030000) + framebuffer-patch-enable + framebuffer-stolenmem
  - Was causing WindowServer SIGABRT crash loop (consecutiveCrashCount=5) on every boot

**3. USB no-power fix (primary achievement)**
- Root cause: `USB-Map.kext` in EFI used pre-Tahoe key names
  - `UsbConnector` and `port` → not read by Tahoe IOUSBHostFamily 1.2
  - Result: zero `AppleUSBEHCIPort` instances → EHC1/EHC2 entered D3 suspend → VBUS cut
- Fix: copied `USB-Map-Tahoe.kext` Info.plist format (uses `usb-port-type` / `usb-port-number`)
  - `cp Build-Folder/.../USB-Map-Tahoe.kext/Contents/Info.plist /Volumes/EFI/EFI/OC/Kexts/USB-Map.kext/Contents/Info.plist`
- Result confirmed: USB 1.0 direct + USB 2.0 hub both working
  - EHC1 enumerated: IR Receiver, Microsoft Nano Transceiver, Apple USB Keyboard/Mouse hub

### Current EFI State (post Session 19)

| Key | Value |
|---|---|
| Boot snapshot | XID 2415851 |
| WhateverGreen DeviceProperties | Removed |
| USB-Map format | Tahoe (usb-port-type / usb-port-number) |
| kUSBCompanion | false (both EHC1, EHC2) |
| Boot args | `keepsyms=1 debug=0x100 -lilubetaall ipc_control_port_options=0 -nokcmismatchpanic amfi_get_out_of_my_way=0x1` |

### Pending Next Session

1. **BCM57765 Ethernet** — kext loaded, not coming up; check kernel log + ioreg on live boot
2. **Rsync repos** — mini OCLP repo needs sync from MBP (3+ commits behind)
3. **tunnel-pro.sh update on mini** — ioreg/ifconfig fixes in MBP repo, not yet on mini (symlink → bridge-restore repo)
4. **OCLP patcher run** — run 26A03 patcher on mini to verify clean apply


*Updated: 2026-04-13 | Claude (Cowork session 19 — closed)*
*Verify all state with live diagnostics — do not assume memory is current*

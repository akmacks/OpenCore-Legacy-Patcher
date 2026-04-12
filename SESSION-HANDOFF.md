# OCLP 3.0.0 Dev — Session Handoff
## For: OpenClaw (local Ollama on MBP) or next Claude instance
## Generated: 2026-04-12 | Session 17 closed
## Project: OpenCore Legacy Patcher

---

## ⚠️ CURRENT SITUATION — READ THIS FIRST

**Mac mini is UP.** Booted to Finder. SSH reachable at `192.168.2.2`.
Tunnel-pro may need restarting: `ssh akmacks@192.168.2.2 'nohup tunnel-pro &>/dev/null &'`

**USB keyboard is non-functional.** All 4 rear USB ports are dead without UHCI kext support.
**Workaround: plug keyboard into a USB 2.0 hub first**, then plug hub into the mini.
Any hub with a Transaction Translator (virtually all USB 2.0 hubs) bridges the keyboard
through EHCI without needing UHCI drivers. No kexts required.

**Do NOT attempt OCLP root patches until Tahoe-compatible UHCI kext binaries exist.**
The 12.6.2-USB payload kexts have vtable ABI mismatches against Tahoe's IOUSBHostFamily.
See USB ARCHITECTURE section below for full details.

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

## CURRENT STATE (Session 17 end — 2026-04-12)

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | ✅ | Booted to Finder, stable |
| OpenCore EFI | ✅ | disk0s1 (disk0 = internal SSD) |
| Boot snapshot | ✅ | XID 2415851 (bless snapshot, not sealed) |
| USB keyboard (wired) | ❌ | UHCI kexts ABI-incompatible with Tahoe — use USB hub workaround |
| USB 2.0 via hub | ✅ | Works if keyboard connected via USB 2.0 hub with TT |
| Sandy Bridge GPU (HD3000) | ❌ | NOT patched — GPU patches cause system crashes on this hardware |
| High Sierra GVA | ❌ | NOT patched — blocked with GPU |
| OCLP root patches | ❌ | Not applied — see USB section below |
| Internet (TB bridge NAT) | ✅ | SSH reachable at 192.168.2.2 |
| Tailscale | 🔴 | Not authenticated this session |
| SSH (direct bridge) | ✅ | akmacks@192.168.2.2 |
| Reverse tunnel | 🟡 | May need restart: `nohup tunnel-pro &>/dev/null &` |
| Ethernet BCM57765 | ❌ | CatalinaBCM5701 not loading — device ID mismatch |
| Wi-Fi BCM4331 | 🟡 | AirportBrcmFixup loaded, no en1 yet |
| Bluetooth | 🟡 | BlueToolFixup loaded, pairing untested |
| Audio ALC892 | ❓ | Not patched |

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

Latest commit: `0d86f1090` — "Session 16 final close — full coordination infrastructure"  
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
*Generated: 2026-04-12 ~16:30 AEST | Claude (Cowork session 17 — closed)*
*Verify all state with live diagnostics — do not assume memory is current*

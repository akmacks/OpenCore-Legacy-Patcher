# OCLP 3.0.0-alpha — Agent Coordination Document
**Project:** OpenCore Legacy Patcher fork for Intel non-T2 Macs / macOS Tahoe  
**Repo:** https://github.com/akmacks/OpenCore-Legacy-Patcher  
**Branch:** macos-next  
**Last updated:** 2026-04-12 11:45 AEST  
**Updated by:** Claude (Cowork session 17 — recovery open)  

---

## PURPOSE OF THIS DOCUMENT

This is the single shared coordination file for all AI agents working on this
project: Claude (claude.ai), OpenClaw (local Ollama on MBP), Claude Code (Xcode/
Codex sessions), and any future agents. Any agent that reads this file has a
complete picture of current status, pending work, and how to hand off to the next.

Agents MUST append to `docs/STATUS-FEED.md` when they complete any unit of work.
Agents MUST update this file's "Current State" section when session ends.
Agents MUST NOT increment version numbers autonomously.

---

## MACHINES

| Role | Model | ID | Bridge IP | Tailscale IP | SSH |
|------|-------|----|-----------|--------------|-----|
| MBP (gateway/dev) | MacBookPro16,1 | T2 Mac | 192.168.2.1 | 100.88.164.12 | direct |
| Mini (target) | Macmini5,3 | Sandy Bridge | 192.168.2.2 | 100.86.233.5 | port 2222 (tunnel) or 192.168.0.111 (Ethernet, when up) |

SSH to mini from MBP: `ssh -p 2222 akmacks@localhost` (after tunnel-pro on mini)  
Or direct: `ssh akmacks@192.168.2.2` (TB bridge) / `ssh akmacks@192.168.0.111` (Ethernet)  
Mini OCLP repo: `~/OpenCore-Legacy-Patcher/`  
MBP OCLP repo: `~/Documents/Github/OpenCore-Legacy-Patcher/`  

---

## CURRENT STATE (as of 2026-04-10 session 16 close)

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | 🔴 FROZEN | Froze Fri night — needs TDM rollback |
| OpenCore EFI | ✅ Active | On disk0s1 |
| USB 1.1 (OHCI/UHCI) | ✅ Patched | AppleUSBUHCI loaded (as of Session 16) |
| Sandy Bridge GPU | ✅ Patched | Stable (as of Session 16) |
| High Sierra GVA | ✅ Patched | Loaded (as of Session 16) |
| Ethernet BCM57765 | ❌ Not loading | CatalinaBCM5701 absent from kextstat |
| Wi-Fi BCM4331 | 🟡 Partial | AirportBrcmFixup loaded, no en1 interface |
| Bluetooth | 🟡 Loaded | BlueToolFixup loaded, pairing untested |
| Audio ALC892 | ❓ Unknown | modern_audio skipped (missing payload) |
| SSH access | ❌ Down | Mini frozen — tunnel not running |
| Internet | ❌ Down | TB bridge down (mini in TDM) |
| Tailscale | ❓ Unknown | Was 100.86.233.5 — status unknown while frozen |
| APFS snapshot | ❓ Unknown | XID 2239951 was last sealed; Apr 11 may have created new one |
| TDM disk | ❌ Not visible | TB cable reseat required on MBP |

---

## PRIORITY WORK QUEUE

Agents pick tasks from top to bottom. Mark in-progress with your agent name.

### 🔴 P1 — Ethernet (BCM57765 / pci14e4,16b4)

**Problem:** `CatalinaBCM5701Ethernet.kext` injected via EFI but not loading on XNU 25.
- Device confirmed present: `pci14e4,16b4` in ioreg ✅
- IONameMatch includes `pci14e4,16b4` ✅
- MinKernel: 20.0.0, MaxKernel: empty ✅
- `amfi_get_out_of_my_way=0x7ff` added to boot-args ✅
- Still not in kextstat ❌

**Next steps:**
1. Check kernel log at boot for kext rejection: `log show --last boot | grep -i "BCM5701\|CatalinaBCM\|kext.*reject\|deny"`
2. Verify kext binary is correctly signed/unsigned for injection
3. Check if `SecureBootModel: Disabled` in OC config is actually taking effect
4. Consider adding kext to `ForceKextsToLoad` array in OC config
5. Alternative: derive fresh Find/Replace kernel patch from KDK_26.4_25E246.kdk

**Files:**
- EFI kext: `/Volumes/EFI/EFI/OC/Kexts/CatalinaBCM5701Ethernet.kext`
- OC config: `/Volumes/EFI/EFI/OC/config.plist`
- KDK: `/Library/Developer/KDKs/KDK_26.4_25E246.kdk`

### 🟡 P2 — Wi-Fi (BCM4331 / pci14e4,4331)

**Problem:** `AirportBrcmFixup 2.1.9` loaded but no `en1` interface appears.
- Likely needs `IO80211FamilyLegacy.kext` root patch (legacy_wireless.py patchset)
- Bug 2 fix already committed (XNU cap at sequoia value in legacy_wireless.py)
- Root patch not yet applied for wireless

**Next steps:**
1. Run legacy_wireless root patch (filter same as USB approach)
2. Reboot and check for en1 interface
3. Verify Wi-Fi networks visible in menu bar

### 🟡 P3 — Audio (ALC892)

**Problem:** `modern_audio.py` patch skipped — AppleHDA.kext missing from 15.2 payload.
- Sequoia fallback (15.4) may work — investigate
- Check if `AppleALC.kext` in EFI is loading and matching ALC892

**Next steps:**
1. `kextstat | grep -i "audio\|HDA\|ALC"`
2. `system_profiler SPAudioDataType`
3. If AppleALC loaded but no sound: check layout-id in OC config

### 🟢 P4 — Bluetooth pairing test

BlueToolFixup 2.6.9 + IOBluetoothFamily 9.0 both loaded.
Just needs a physical test — pair a device and verify.

---

## CURRENT STATE — Session 19 close (2026-04-13)

| Area | Status | Notes |
|---|---|---|
| Boot | ✅ Stable | OpenCore, snapshot XID 2415851 |
| Tunnel | ✅ Up | 192.168.2.1↔192.168.2.2, reverse SSH :2222 |
| USB (via hub) | ✅ Working | USB-Map-Tahoe format, EHC1/EHC2 ACPI renames applied (EH01/EH02) |
| Keyboard/Mouse | ✅ Working | Via USB hub |
| GPU (HD 3000) | ✅ Patched | kexts injected |
| WhateverGreen | ✅ Clean | Headless framebuffer removed from EFI |
| LaunchAgents | ✅ Clean | nat-persist.disabled (mini), bridge-ip.disabled (MBP) |
| Ethernet BCM57765 | 🔴 Dead | Kext loaded, device not coming up — next target |
| Wi-Fi BCM4331 | ⚠️ Unknown | Root patch applied, not verified |
| Audio ALC892 | ⚠️ Unknown | Fallback kext, not verified |
| OCLP repo (MBP) | ✅ Current | macos-next, 26A04 — Session 21 docs written |
| OCLP repo (mini) | ⚠️ Needs sync | rsync pending after session close |

## PRIORITY WORK QUEUE

### 🔴 P1 — Ethernet BCM57765

Kext `CatalinaBCM5701Ethernet.kext` is in EFI and kernel patch is active, but device is not
coming up. Investigation needed on live boot:

```bash
# SSH to mini
ssh -p 2222 akmacks@localhost

# Check if kext matched device
kextstat | grep -i "BCM\|5701\|ethernet"
ioreg -p IOService -c IOEthernetController -r -w 0 | head -40

# Kernel log for matching errors
log show --last 5m --predicate 'process == "kernel"' 2>&1 | grep -iE "BCM|5701|57765|ethernet"

# Check device ID in IORegistry
ioreg -l | grep -iE "pci14e4|BCM|ethernet" | grep -i "vendor\|product\|device\|class"
```

### 🟡 P2 — Wi-Fi BCM4331

`IO80211FamilyLegacy.kext` + `IOSkywalkFamily.kext` in EFI. Check if associated or just loaded:

```bash
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I
kextstat | grep -i "wireless\|80211\|brcm"
```

### 🟡 P3 — Audio ALC892

`AppleALC.kext` in EFI with layout-id 90. Verify:

```bash
kextstat | grep -i "audio\|HDA\|ALC"
system_profiler SPAudioDataType 2>/dev/null
```

### 🟢 P4 — Snapshot Lock & OCLP Patcher Test

After BCM57765 investigation:
1. Create named APFS snapshot: `sudo tmutil localsnapshot /`
2. Note snapshot UUID for rollback reference
3. Run OCLP patcher 26A03 on mini to verify it applies cleanly

---

## CODE BUGS (both fixed in commit 7d28f4d)


| # | File | Bug | Status |
|---|------|-----|--------|
| 1 | `constants.py` | `legacy_accel_support` missing `os_data.tahoe` | ✅ Fixed |
| 2 | `legacy_wireless.py` | XNU payload key requests `12.7.2-25` (doesn't exist) | ✅ Fixed |

---

## DEV TOOLS ON MINI

| Tool | Location | Purpose |
|------|----------|---------|
| run_patch_complete.py | `~/run_patch_complete.py` | Full patch runner (wx stub) |
| run_usb11_patch.py | `~/run_usb11_patch.py` | USB 1.1 only filter |
| Universal-Binaries.dmg | `~/OpenCore-Legacy-Patcher/payloads/` | Payload source |
| KDK | `/Library/Developer/KDKs/KDK_26.4_25E246.kdk` | Kernel debug kit |
| python3.14 | `/usr/local/bin/python3.14` | Required for OCLP scripts |

---

## AGENT HANDOFF PROTOCOL

When ending a session, every agent must:
1. Append a status update to `docs/STATUS-FEED.md` (see format below)
2. Update "Current State" table above
3. Update "Priority Work Queue" — remove completed items, add new ones
4. `git add -A && git commit -m "agent: [agent-name] session [N] close" && git push origin macos-next`
5. If on mini, rsync or push any changes back to MBP

---

## RSYNC (mini → MBP, no SCP — SFTP subsystem missing)

```bash
# From MBP — pull from mini
rsync -avz -e "ssh -p 2222" akmacks@localhost:~/OpenCore-Legacy-Patcher/ \
  ~/Documents/Github/OpenCore-Legacy-Patcher/

# From MBP — push to mini  
rsync -avz ~/Documents/Github/OpenCore-Legacy-Patcher/ \
  -e "ssh -p 2222" akmacks@localhost:~/OpenCore-Legacy-Patcher/
```

---

## CURRENT STATE — Session 33 close (2026-05-03 16:35 AEST)

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | 🟡 Boot pending | KC replaced — awaiting Session 34 boot confirm |
| OpenCore EFI | ✅ Active | boot-args: `keepsyms=1 debug=0x100 -lilubetaall ipc_control_port_options=0 -nokcmismatchpanic -igfxvesa -v` |
| Preboot KC | 🟡 Replaced | Stock March 20 KC copied from System volume; old KC backed up |
| USB (via hub) | ✅ Working | USB-Map-Tahoe format (as of Session 19) |
| Sandy Bridge GPU | ⛔ Not applied | Fatal on Tahoe — Macmini5,3 headless, not needed |
| USB 1.1 patchset | ⛔ Not applied | ABI-incompatible with Tahoe — do not apply |
| Ethernet BCM57765 | 🔴 Pending patch | OCLP root patch not yet run — Session 34 target |
| Audio ALC892 | 🔴 Pending patch | OCLP root patch not yet run — Session 34 target |
| Wi-Fi BCM4331 | ⚠️ Unknown | Root patch applied (Session 19), not re-verified |
| SSH access | ❌ Down | Mini rebooting — tunnel not yet running |
| AMFI in boot-args | ❌ Not present | Removed Session 32 (conservative); add only during patch run |
| TDM disk | ✅ Ejected | Mini released from TDM, rebooting normally |

**Critical environment fact:** MBP=Tahoe 26.5 (25F5068a), Mini=Tahoe 26.4 (25E246).  
`kmutil` from MBP CANNOT build KC for mini — build mismatch. Use stock System volume KC.

## PRIORITY WORK QUEUE — Session 34

### 🔴 P0 — Confirm mini boots (Session 34 first step)
Verbose boot active (`-v`). Check for KC load lines in boot output. If boot succeeds:
1. Remove `-v` from OC boot-args
2. Verify USB hub, desktop accessible, tunnel up
3. Proceed to P1

### 🔴 P1 — Run OCLP root patch (Ethernet + Audio)
Prerequisites: mini booted, SSH accessible, amfi added back for patch run only.
```bash
# On MBP — SSH to mini
ssh akmacks@192.168.2.2   # TB bridge, or
ssh -p 2222 akmacks@localhost  # tunnel

# On mini — run OCLP patch from source
cd ~/OpenCore-Legacy-Patcher
sudo python3.14 OpenCore-Patcher.py --gui  # or headless equivalent
```
**Do NOT apply:** Sandy Bridge GPU patchset, USB 1.1 (IOUSBHostFamily) patchset.

### 🟡 P2 — Verify Wi-Fi BCM4331
```bash
airport -I
kextstat | grep -i "80211\|brcm"
```

### 🟢 P3 — Remove -v from boot-args (after boot confirmed)
```python
# plistlib edit of /Volumes/EFI/EFI/OC/config.plist — remove -v token
```

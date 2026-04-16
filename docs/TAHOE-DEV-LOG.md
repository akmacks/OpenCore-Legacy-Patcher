# OCLP 3.0.0 Tahoe (macOS 26) Development Log
**Date:** 2026-03-22  
**Developer:** akmacks  
**Branch:** `macos-next`  
**Target Machine:** Mac mini Server (Late 2011) — `Macmini5,3` — Intel Core i7 Sandy Bridge  
**Target OS:** macOS Tahoe 26.3.1 (Build `25D2128`)  
**Development Host:** MacBook Pro 16,1 (2019) — macOS Tahoe 26.x  

---

## Objective

Get OCLP 3.0.0 (`macos-next` branch) to successfully boot and apply root patches to a  
`Macmini5,3` running macOS Tahoe 26.3.1 — the first non-T2 Intel Mac to run Tahoe via OCLP.

---

## Environment Setup

### Python & Dependencies (on MBP dev host)
```bash
cd ~/Documents/GitHub/OpenCore-Legacy-Patcher
pip3 install -r requirements.txt
```
- Python 3.14.3 (Homebrew)
- wxPython 4.2.5 — confirmed wheel available for cp314/macosx_14_0_x86_64
- All deps satisfied cleanly

### GUI Smoke Test
```bash
python3 OpenCore-Patcher-GUI.command
```
- OCLP 3.0.0 GUI launched successfully on MBP host
- Custom Model set to `Macmini5,3` via Settings
- Confirmed `Using Custom Model: Macmini5,3` in log output

---

## EFI Build for Macmini5,3

### Build
- Clicked "Build and Install OpenCore" in GUI targeting `Macmini5,3`
- Build succeeded, output at:  
  `Build-Folder/OpenCore-Build/EFI/`
- Key kexts confirmed present:
  - `USB-Map-Tahoe.kext` ✅
  - `USB-Map.kext` ✅
  - `CryptexFixup.kext` ✅
  - `AMFIPass.kext` ✅
  - `AppleIntelCPUPowerManagement.kext` ✅
  - `IOFireWireFamily.kext` ✅
  - `AirportBrcmFixup.kext` ✅

### Issue: Privileged Helper Tool (OCLP_PHT_ERROR_INVALID_TEAM_ID)
Running from source without a valid Apple Developer Team ID means the  
Privileged Helper Tool (`com.dortania.opencore-legacy-patcher.privileged-helper`)  
refuses to mount EFI partitions (Return Code 166).

**Workaround:** Manually mount EFI and copy files:
```bash
sudo diskutil mount disk8s1
sudo cp -r Build-Folder/OpenCore-Build/EFI/OC /Volumes/EFI/EFI/OC
sudo mkdir -p /Volumes/EFI/EFI/BOOT
sudo cp /Volumes/EFI/EFI/OC/OpenCore.efi /Volumes/EFI/EFI/BOOT/BOOTx64.efi
sudo cp -r /Volumes/EFI/EFI/OC /Volumes/EFI/EFI/BOOT/OC
```

**Root cause to fix:** The BOOT/OC folder structure must match what OpenCore expects.  
OpenCore launched from `\EFI\BOOT\BOOTx64.efi` looks for config at `\EFI\BOOT\OC\config.plist`.

---

## Code Changes Made

### 1. `constants.py` — New flag for external volume patching
```python
self.is_patching_external_volume: bool = False
```
Allows bypassing host security checks when patching a volume in Target Disk Mode.

### 2. `sys_patch/patchsets/detect.py` — Extend OS support ceiling to Tahoe
**`_validation_check_unsupported_host_os()`:**
```python
# Before:
_max_os = os_data.sequoia.value
# After:
_max_os = os_data.tahoe.value
```
Also added `is_patching_external_volume` bypass for FileVault, SIP, SecureBootModel, and AMFI checks.

### 3. `wx_gui/gui_main_menu.py` — External volume detection
Added detection of external disks (Target Disk Mode) in `on_post_install_root_patch()`.  
Sets `constants.is_patching_external_volume = True` when external disks are found,  
allowing root patching from a host machine against a TDM-mounted target volume.

### 4. `sys_patch/patchsets/hardware/misc/modern_audio.py` — Tahoe audio source folder
**Issue:** Patcher looked for `AppleHDA.kext` in `PatcherSupportPkg/26.0 Beta 1/`  
which doesn't exist in PatcherSupportPkg 1.9.5.

**Temporary fix:** Point to Sequoia's `15.2` folder as a fallback:
```python
"AppleHDA.kext": "15.2",  # TODO: update when Tahoe PSP assets available
```
**TODO:** Once PatcherSupportPkg receives Tahoe-specific assets, update this back to  
the appropriate `26.x` folder name.

### 5. `support/subprocess_wrapper.py` — Bypass Privileged Helper for sudo operations
When running from source without code signing, replace Privileged Helper with direct sudo:
```python
# Before:
return subprocess.run([OCLP_PRIVILEGED_HELPER] + [args[0][0]] + args[0][1:], **kwargs)
# After:
return subprocess.run(["/usr/bin/sudo"] + [args[0][0]] + args[0][1:], **kwargs)
```
**Note:** This is a development-only workaround. Production builds use the signed helper.

---

## Boot Process

### Mac Mini State
- Previously on Sequoia, upgraded to Tahoe 26.3.1 via OCLP 2.4.1
- OCLP 2.4.1 did not warn about Tahoe incompatibility
- Mac Mini stuck in Internet Recovery / unable to boot Tahoe without patches

### Boot Sequence Established
1. Hold **Option ⌥** on Mac Mini power-on
2. Select OCLP USB EFI Boot (built with OCLP 3.0.0 targeting `Macmini5,3`)
3. OpenCore picker shows: **Server HD**, EFI, Windows
4. Select **Server HD**

### Pre-patch boot behaviour
- Normal boot: hangs at end of progress bar (no Sandy Bridge GPU drivers in Tahoe)
- Safe Mode: reaches login screen but USB HID non-functional (keyboard/mouse dead)

---

## Root Patching via SSH (Target Disk Mode + SSH)

Since GUI patching was blocked by host security (SIP, FileVault, SecureBootModel),  
a combined approach was used:

### Step 1 — Enable SSH on Mac Mini volume while in Target Disk Mode
```bash
sudo touch "/Volumes/Server HD — Data/private/var/db/.RemoteLoginEnabled"
```

### Step 2 — Boot Mac Mini, SSH in from MBP
```bash
ssh akmacks@mac-mini-server-i7.local
```
SSH connected successfully even while screen was frozen on progress bar.

### Step 3 — Transfer OCLP repo + Universal-Binaries.dmg via rsync
```bash
rsync -av --exclude='.git' --exclude='Universal-Binaries.dmg' \
  ~/Documents/GitHub/OpenCore-Legacy-Patcher/ \
  akmacks@mac-mini-server-i7.local:~/OpenCore-Legacy-Patcher/

rsync -av ~/Documents/GitHub/OpenCore-Legacy-Patcher/Universal-Binaries.dmg \
  akmacks@mac-mini-server-i7.local:~/OpenCore-Legacy-Patcher/
```

### Step 4 — Mount Universal-Binaries.dmg on Mac Mini
```bash
hdiutil attach ~/OpenCore-Legacy-Patcher/Universal-Binaries.dmg \
  -mountpoint ~/OpenCore-Legacy-Patcher/payloads/Universal-Binaries \
  -nobrowse -passphrase password
```

### Step 5 — Pre-mount root volume (bypass Privileged Helper)
```bash
sudo mkdir -p /System/Volumes/Update/mnt1
sudo mount -o nobrowse -t apfs /dev/disk2s4 /System/Volumes/Update/mnt1
```

### Step 6 — Stub out GUI dependencies and auto_patcher
The patcher's `auto_patcher/start.py` imports from `wx_gui` which cascades GUI imports.  
Temporary stubs applied:
```bash
echo 'def InstallAutomaticPatchingServices(*a, **k): pass' | \
  sudo tee .../sys_patch/auto_patcher/__init__.py

echo 'class StartAutomaticPatching:
    def __init__(self, *a, **k): pass
    def start_auto_patch(self): pass' | \
  sudo tee .../sys_patch/auto_patcher/start.py
```

### Step 7 — Run patcher natively on Mac Mini
```bash
sudo /usr/local/bin/python3.14 /tmp/patch_mini.py
```

---

## Successful Patch Output

```
OS: 26.3.1 (25D2128) Darwin 25
Model: Macmini5,3
- Starting Patch Process
- Determining Required Patch set for Darwin 25
- Verifying whether Root Patching possible
- Patcher is capable of patching
- Local PatcherSupportPkg resources available, continuing...
- Running sanity checks before patching
- Running patches for Macmini5,3
- Running Preflight Checks before patching
- Found SkylightPlugins folder, removing old plugins
- Cleaning Auxiliary Kernel Collection
  - Relocating Pegasus2R2ICON.kext to /Library/Relocated Extensions
  - Relocating PromiseSTEX.kext to /Library/Relocated Extensions
- Found KDK at: /Library/Developer/KDKs/KDK_26.3.1_25D2128.kdk
- Merging KDK with Root Volume: KDK_26.3.1_25D2128.kdk
- Successfully merged KDK with Root Volume
- Installing Patchset: Intel Sandy Bridge
  - Installing: AppleIntelHD3000Graphics.kext
  - Installing: AppleIntelHD3000GraphicsGA.plugin
  - Installing: AppleIntelHD3000GraphicsGLDriver.bundle
  - Installing: AppleIntelHD3000GraphicsVADriver.bundle
  - Installing: AppleIntelSNBGraphicsFB.kext
  - Installing: AppleIntelSNBVA.bundle
- Writing patchset information to Root Volume
- Rebuilding Boot and System Kernel Collections
- Unmounting root volume
- Patching complete
```

---

## Known Issues / TODO

### Critical
- [ ] **PatcherSupportPkg needs Tahoe assets** — `AppleHDA.kext` for Tahoe 26.x  
  Currently falling back to Sequoia `15.2` build — audio may not work correctly
- [ ] **Privileged Helper signing** — All dev testing done with `sudo` bypass.  
  Production workflow requires proper code signing with Apple Developer certificate
- [ ] **BOOT/OC folder structure** — OCLP GUI should auto-create `EFI/BOOT/OC/`  
  when Privileged Helper is unavailable (currently fails silently)

### Medium
- [ ] **Target Disk Mode patching** — `is_patching_external_volume` flag needs  
  proper integration into the GUI workflow with volume selector
- [ ] **auto_patcher stubs** — `auto_patcher/start.py` should not import `wx_gui`  
  when running in CLI mode. Decouple GUI imports from CLI patching path.
- [ ] **KDK for Tahoe** — `KDK_26.3.1_25D2128.kdk` was already installed on target.  
  Need to verify KDK download logic works for fresh Tahoe installs.

### Low  
- [ ] Add `macOS_26_x` minor version markers to `patchsets/base.py` `BasePatchset`
- [ ] Add `tahoe` to `legacy_accel_support` in `constants.py` for non-metal GPU patchsets
- [ ] Update sucatalog entries for Tahoe

---

## Hardware Confirmed Working

| Component | Status |
|---|---|
| Boot (Sandy Bridge CPU) | ✅ Boots via OpenCore |
| Intel HD 3000 GPU | ✅ Kexts patched |
| USB (keyboard/mouse) | 🔄 Testing post-patch |
| WiFi (Broadcom) | 🔄 Testing post-patch |
| Audio | ⚠️ Using Sequoia fallback |
| FireWire 800 | 🔄 Not yet tested |
| Ethernet | 🔄 Testing post-patch |

---

## Files Modified in This Session

| File | Change |
|---|---|
| `opencore_legacy_patcher/constants.py` | Added `is_patching_external_volume` flag |
| `opencore_legacy_patcher/sys_patch/patchsets/detect.py` | Extended OS ceiling to Tahoe; external volume bypass |
| `opencore_legacy_patcher/wx_gui/gui_main_menu.py` | External volume detection in Post-Install |
| `opencore_legacy_patcher/sys_patch/patchsets/hardware/misc/modern_audio.py` | Tahoe audio source folder fallback |
| `opencore_legacy_patcher/support/subprocess_wrapper.py` | sudo bypass for dev (Privileged Helper workaround) |


---

## Session 13 — 2026-04-08 (Cowork / Claude)

### Focus
KDK forensic analysis, correct identification of the 25-prefix downloaded package,
Bridge-Restore contamination removal, repo cleanup, version tagging.

### What Happened This Session

**Resolved: "25-prefix package" mystery**
After correcting an earlier error (Session 12 incorrectly identified MetallibSupportPkg
15.4-24E248 as the 25-prefix package), a thorough search located the actual package:

- `KDK_26.4_25E246.pkg` — 1.1 GB Kernel Debug Kit for Tahoe 26.4
- Located at `/Library/Developer/KDKs/`
- Downloaded at 11:36 AM by OCLP `gui_cache_os_update.py`
- SHA256: `8c6879cb7e4ccf96039cf08bcdbfc98c5520823dd928cc91f16d480483fbfe9f`
- No standard Dortania log entry — `gui_cache_os_update.py` runs as a
  LaunchAgent GUI dialog, not the standard CLI auto-patcher code path

**KDK deep-dive completed**
Full forensic analysis of `KDK_26.4_25E246.pkg` — see `docs/KDK-FORENSIC.md`:
- Apple-authored, Dortania-mirrored on GitHub (`KdkSupportPkg` project)
- 8,000 files: release + development + KASAN kernels, full Tahoe kext set, dSYMs
- XNU version: `25.4.0 / xnu-12377.101.15~1/RELEASE_X86_64`
- KdkSupportPkg manifest is fully up-to-date: 163 Tahoe (25-prefix) entries ✅
- MetallibSupportPkg manifest has ZERO Tahoe entries — fallback to Sequoia 15.4 ⚠️

**Project plan updated** (`docs/PROJECT-PLAN.md`, commit `3a8ed68`):
- Corrected downloaded packages section (two packages: KDK + MetallibSupportPkg)
- Added MetallibSupportPkg Tahoe manifest gap analysis
- Risk register updated with two new rows

**Bridge-Restore contamination removed**
`app_macOS-Intel_BridgeRestore/` was fully committed inside the OCLP repo —
a mistake from earlier session. Removed from git tracking (`git rm -r --cached`),
added to `.gitignore`. Directory kept on disk (separate project).

**Version tagged:** `3.0.0-alpha (26A02)` on branch `macos-next`

### Bugs Confirmed (Still Pending Fix)

| # | File | Bug | Status |
|---|---|---|---|
| 1 | `constants.py` | `legacy_accel_support` missing `os_data.tahoe` | **Confirmed, fix pending** |
| 2 | `legacy_wireless.py` | `_extended_patch()` requests `12.7.2-25` payloads (don't exist) | **Confirmed, fix pending** |

### Current OCLP State on Macmini5,3

- macOS Tahoe 26.4 (25E246) update **staged / installing** → reboot pending
- OCLP root patches **not yet applied** to 26.4 boot volume
- KDK_26.4_25E246.pkg **downloaded and saved** at `/Library/Developer/KDKs/`
- MetallibSupportPkg 15.4-24E248 (Sequoia fallback) **downloaded** at
  `/Library/Application Support/Dortania/MetallibSupportPkg/`
- EFI: BCM5722 Find/Replace byte patch **in place** (unverified on 26.4)
- Snapshot seal: **broken** from Session 1 GPU patch → auto-patcher will skip

### Next Steps (for next session / OpenClaw)

Priority order (hardware verification sequence post-26.4 reboot):

1. **Ethernet first** — `kextstat | grep 5701`, `ifconfig en0`, ping 8.8.8.8
   - If broken: re-derive BCM5722 Find/Replace bytes from 26.4 kernel in KDK
2. **Apply Bug 1 fix** — add `os_data.tahoe` to `legacy_accel_support` in `constants.py`
3. **Apply Bug 2 fix** — cap Wi-Fi XNU version in `legacy_wireless.py`
4. **Run root patches manually** — `sudo python3 OpenCore-Patcher.app/Contents/MacOS/...`
5. **Reboot and verify** — Wi-Fi, BT, Audio, Desktop colour in sequence

---

## Session 18 — 2026-04-13

### Goal: Restore VNC access and desktop session on Mac mini

### Root Cause Discovery

**VNC black screen / 0x0 desktop size** was caused by missing GPU framebuffer driver.
On Macmini5,3 (Sandy Bridge HD 3000, Device ID `0x0116`), macOS Tahoe has no native
GPU driver. Without a framebuffer:
- WindowServer cannot create a renderable surface
- `screencapture` fails with "could not create image from display"
- `loginwindow` cannot complete the GUI session (auto-login panics)
- VNC protocol reports `0x0` desktop dimensions

Previous sessions (15-17) had WhateverGreen **disabled** because full GPU acceleration
caused kernel panics. The fix: **headless framebuffer mode** — enable WhateverGreen
but use `ig-platform-id 0x10030000` to create a virtual framebuffer without
hardware acceleration.

### Config Changes (EFI)

| Key | Value | Purpose |
|-----|-------|---------|
| `WhateverGreen.kext` | Enabled=True | Framebuffer driver (was disabled) |
| `ig-platform-id` | `00000310` | Sandy Bridge headless framebuffer |
| `framebuffer-patch-enable` | `01000000` | Enable WEG framebuffer patching |
| `framebuffer-stolenmem` | `0000300a` | 640MB stolen VRAM |

### Other Changes

- Created `openclawadmin` user (did not persist through reboot)
- Fixed `autoLoginUserUID` from 503 to 502 (akmacks UID)
- Cleared `lastLoginPanic` from loginwindow preferences
- APFS snapshot: `com.apple.TimeMachine.2026-04-13-161247.local`

### Result

- ✅ WhateverGreen loaded, 1920×1080 virtual display
- ✅ loginwindow completes auto-login
- 🟡 VNC renders desktop but Finder/Dock not running
- 🟡 Desktop session incomplete
- ❌ Ethernet, Wi-Fi, Audio still broken

### Standing Rule

**WhateverGreen must remain in headless framebuffer mode.** Full GPU acceleration
causes kernel panics on Macmini5,3 with Tahoe. `ig-platform-id 0x10030000` only.

## Session 23 — 2026-04-16

### Goal: Fix USB-Map kext to match ACPI renames (EHC1→EH01, EHC2→EH02)

### Root Cause Discovery

**USB-Map.kext IONameMatch targeting wrong device names!** Session 21 renamed ACPI devices
from `EHC1/EHC2` to `EH01/EH02`, but the USB-Map.kext still had `IONameMatch = EHC1` and
`IONameMatch = EHC2`. Since macOS matches IOKit personalities by the ACPI device name
_after rename processing_, these entries **never matched** and were completely inert.

This meant:
- No port type mapping was applied (ports treated as unknown)
- `kUSBCompanion=false` was never set on the active controllers
- All port-count was wrong (1 instead of 3)

### Fix Applied: USB-Map.kext v1.1

| Change | Old | New |
|--------|-----|-----|
| IONameMatch (EH01 personality) | `EHC1` | `EH01` |
| IONameMatch (EH02 personality) | `EHC2` | `EH02` |
| port-count (both) | 1 (`0x01`) | 3 (`0x03`) |
| PRT2 added (both) | — | type 0 (Type-A external) |
| PRT3 added (both) | — | type 0 (Type-A external) |
| PRT1 (both) | type 255 | type 255 (unchanged, internal) |
| kUSBCompanion (both) | false | false (unchanged) |

### ACPI _STA Verification

| Device | _STA | Meaning |
|--------|------|---------|
| UHC1 | 0x0B | Present, no decode |
| UHC2–UHC4 | 0x09 | Disabled |
| UHC5 | 0x0B | Present, no decode |
| UHC6–UHC7 | 0x09 | Disabled |
| EH01 | 0x0F | Fully active |
| EH02 | 0x0F | Fully active |

### Design Decision: No SSDT for UHCI (Yet)

With `kUSBCompanion=false`, the EHCI controllers handle all USB 1.x traffic internally.
The 5 disabled UHCI controllers (UHC2-4, UHC6-7) aren't needed for current functionality.
Recommend holding SSDT-USB-MAP unless a specific device requires direct UHCI access.

### Files Modified
- `/Volumes/EFI/EFI/OC/Kexts/USB-Map.kext/Contents/Info.plist` (v1.1)
- Backup: `USB-Map.kext.session21-backup/`

### Commit
- `0d0703802` on `macos-next`

### Session 23 (continued) — v1.1 Rollback & Failure Analysis

**16:10 AEST:** Rebooted mini with USB-Map v1.1. Result: total USB failure.
- Only 1 `AppleUSBEHCIPort` created (was 6)
- Zero USB devices enumerated
- Controllers stuck in suspended power state (`CurrentPowerState=2`)
- `kControllerStatIOCount=0`

**16:15 AEST:** Rolled back to USB-Map.kext v1.0, APFS snapshot `2026-04-16-161511`.
**16:21 AEST:** Reboot confirmed working — 6 ports, 3 devices, load settling.

**Why v1.1 Failed Despite Careful Planning:**

The plan was sound in isolation: fix IONameMatch to match the renamed devices, add explicit port definitions. What I missed is the *interaction* between `AppleUSBHostMergeProperties` and the EHCI driver on Darwin 25.x.

On macOS Tahoe, when `AppleUSBHostMergeProperties` matches an EHCI controller AND provides explicit port dictionaries, the driver treats those as the *complete* port specification — it does NOT supplement the internal port creation with these properties. Instead, it *replaces* the internal port creation entirely. The `PRT1/PRT2/PRT3` dictionaries with `usb-port-type` values don't trigger the EHCI driver to create `AppleUSBEHCIPort` child nubs. The driver sees the merge properties, configures the controller, but the port creation path is short-circuited.

With v1.0 (IONameMatch=EHC1/EHC2, which doesn't match the renamed EH01/EH02), the merge kext is completely inert. The EHCI driver falls back to ACPI `_UPC`/`_PLD` methods in the DSDT to enumerate ports, which works correctly. The result: 6 ports, 3 devices, everything functional.

**Key insight:** The merge kext was never the right mechanism for setting `kUSBCompanion=false` on Tahoe. It was a workaround that only appeared to work because it was inert (targeting wrong names). The correct approach is an SSDT that adds `_UPC`/`_PLD` methods to the EH01/EH02 devices in the ACPI namespace.

**Current state:** USB-Map.kext v1.0 (inert). All USB working via ACPI fallback.

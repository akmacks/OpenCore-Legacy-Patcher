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

## Session 19 — USB No-Power Root Cause & Fix (2026-04-13)

**Context:** Context window limit hit mid-session; continuing from compacted summary.
Mini was in TDM for most of this session for filesystem-level repairs.

### Achievements

#### 1. LaunchAgent Set Repaired (root cause of 3-day tunnel breakage)

Via TDM on disk10s2 (mini's Data volume):

- Identified `local.nat-persist.plist` on **mini** as root cause
  - Was setting `bridge0 = 192.168.2.1` (MBP's IP), enabling IP forwarding, loading NAT rules referencing `en0` (BCM5722 Ethernet, disabled)
  - Renamed → `local.nat-persist.plist.disabled`
- Identified `local.bridge-ip.plist` on **MBP** (PID 1016 active!)
  - Was setting MBP `bridge0 = 192.168.2.2` every 20 seconds
  - `launchctl unload` → renamed → `.disabled`
- `/etc/pf.anchors/bridge-restore` on mini replaced with `# CLIENT ONLY
pass all`
- `sshd` / RemoteLogin verified enabled on mini's Data volume

#### 2. WhateverGreen Headless Framebuffer Reverted

Removed from `/Volumes/EFI/EFI/OC/config.plist` (edited via TDM):
- `PciRoot(0x0)/Pci(0x2,0x0)` DeviceProperties dict (ig-platform-id `AAADEA==`, framebuffer-patch-enable, framebuffer-stolenmem)
- Was causing WindowServer SIGABRT crash loop on every boot (Session 18 regression)

#### 3. USB No-Power — Diagnosed and Fixed

**Diagnosis steps:**
1. kextstat: `AppleUSBEHCI` + `AppleUSBEHCIPCI` loaded (version 1.2) — no missing kexts
2. ioreg IOUSB plane: EHC1 and EHC2 both `registered, matched, active` — hardware matched
3. `controller-statistics`: `kPowerStateOn: 4ms (0%)`, `kPowerStateSuspended: 99%` — **smoking gun**
4. IOKitDiagnostics: `AppleUSBEHCIPort=0` — zero port objects created despite controllers being active
5. Compared EFI `USB-Map.kext` Info.plist vs Build-Folder `USB-Map-Tahoe.kext` Info.plist:
   - EFI (broken): `UsbConnector` / `port`
   - Build-Folder (correct): `usb-port-type` / `usb-port-number`

**Root cause:** Tahoe's `IOUSBHostFamily` 1.2 changed key names for USB port personality data.
The old keys are silently ignored → zero ports created → controllers suspend immediately →
D3 suspend cuts VBUS (5V) to all physical USB ports.

**Fix applied:**
```bash
sudo diskutil mount disk0s1
cp Build-Folder/OpenCore-Build/EFI/OC/Kexts/USB-Map-Tahoe.kext/Contents/Info.plist \
   /Volumes/EFI/EFI/OC/Kexts/USB-Map.kext/Contents/Info.plist
sudo reboot
```

**Verified post-reboot:**
- `AppleUSBHub` kext now loaded
- EHC1 → IOUSBHostDevice (internal hub) → IR Receiver, Nano Transceiver, KB/Mouse hub
- USB 1.0 direct ✅  USB 2.0 hub ✅  Wireless keyboard/mouse ✅

### Key Technical Notes

- `kUSBCompanion: false` is correct and sufficient — EHCI Transaction Translator handles
  USB 1.0/1.1/2.0 without UHCI companions. UHCI ABI mismatch is a non-issue in this config.
- OCLP build system already generates `USB-Map-Tahoe.kext`; pipeline fix needed to deploy it
  automatically for Tahoe targets (see `docs/USB-MAP-TAHOE-FIX.md`)
- The 3-day breakage had two independent root causes:
  1. nat-persist.plist on mini → IP conflict on bridge0
  2. USB-Map old key format → no USB power (pre-existing since Session 17/18)

### Session 19 Git Activity

- `docs/USB-MAP-TAHOE-FIX.md` — new file, full technical writeup
- `CHANGELOG.md` — 26A03 entry added
- `SESSION-HANDOFF.md` — Session 19 close
- `docs/STATUS-FEED.md` — status appended
- `docs/AGENT-COORDINATION.md` — current state updated
- Tagged: `3.0.0-alpha-26A03`

### Pending

- BCM57765 Ethernet: kext loads, device not coming up — needs live kernel log investigation
- Rsync OCLP repo to mini
- Update tunnel-pro.sh on mini (ioreg + ifconfig fixes)
- Run OCLP 26A03 patcher on mini


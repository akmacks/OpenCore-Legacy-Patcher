# OCLP 3.0.x — Macmini5,3 Hardware Restoration Project Plan
**Machine:** Mac mini (Late 2011) — `Macmini5,3` — Intel Core i7 Sandy Bridge, 16 GB RAM
**OS:** macOS Tahoe 26.3.1 → 26.4 (build 25E246, installed/installing)
**OCLP binary:** 2.4.1 (installed at `/Applications/OpenCore-Patcher.app`)
**OCLP codebase:** 3.0.0 `macos-next` branch at `~/OpenCore-Legacy-Patcher/`
**GitHub:** `akmacks/OpenCore-Legacy-Patcher` — branch `macos-next` — commit `d69b6bf`
**Date:** 2026-04-08

---

## Why Ethernet Failed After the Tahoe Upgrade

The BCM5722 Ethernet chip requires `CatalinaBCM5701Ethernet.kext` (device ID `pci14e4,1682`
is in the kext Info.plist). A **kernel binary patch is also required** for Big Sur+ kernels —
without it, the hardware ID check silently fails and the interface never appears. This patch
was added to `config.plist` in Session 4 but has not been verified after a reboot.
The Thunderbolt bridge is a temporary workaround until Ethernet is confirmed working.

---

## Current Component Status

| Priority | Component | Status | Root Cause |
|---|---|---|---|
| **1** | **Ethernet BCM5722** | ⏳ Patch in EFI, verify after 26.4 reboot | Kernel binary patch added Session 4 |
| **2** | **Wi-Fi BCM4331** | ❌ Not working | Root patches never fully run |
| **3** | **Bluetooth BCM2046** | ❌ Not working | Root patches never run; no device detected |
| **4** | **Audio ALC892** | ❌ Not working | AppleHDA absent in Tahoe; root patches not run |
| **5** | **Desktop colour/wallpaper** | ❌ Not working | `tahoe` missing from `legacy_accel_support` — Sandy Bridge patches blocked on XNU 25 |
| — | Boot (OC EFI) | ✅ Working | disk0s1 |
| — | Intel HD 3000 (login screen) | ✅ Partial | Session 1 kext patch; full OpenGL stack not yet applied |
| — | USB HID | ✅ Working | usb11.py patched |
| — | Internet (TB Bridge NAT) | ✅ Working | bridge-restore — temporary until Ethernet confirmed |

### Why root patches keep being skipped
Every OCLP log since March 30:
```
- Detected Snapshot seal not intact, skipping
```
Auto-patcher sees the broken seal from Session 1 (GPU-only patch) and treats it as done.
Wi-Fi, Audio, BT, and Sandy Bridge OpenGL patches were **never run**. Manual execution required.

---

## Code Bugs to Fix Before Patching

### Bug 1 — Sandy Bridge patches blocked on Tahoe (CRITICAL — fixes desktop/wallpaper)
**File:** `opencore_legacy_patcher/constants.py` (~line 248)

`intel_sandy_bridge.py` guards on `self._xnu_major not in self._constants.legacy_accel_support`.
Tahoe (XNU 25) is not in this list → entire Sandy Bridge patch set (NonMetal, OpenGL shims,
HighSierraGVA, MontereyWebKit) silently skipped.

```python
# FIX: add one line to the list:
self.legacy_accel_support = [
    os_data.os_data.big_sur,
    os_data.os_data.monterey,
    os_data.os_data.ventura,
    os_data.os_data.sonoma,
    os_data.os_data.sequoia,
    os_data.os_data.tahoe,   # ← ADD THIS
]
```

### Bug 2 — Wi-Fi extended-patch payloads likely missing for XNU 25
**File:** `sys_patch/patchsets/hardware/networking/legacy_wireless.py`

`_extended_patch()` requests payloads keyed as `"12.7.2-25"` for Tahoe.
Almost certainly absent from `Universal-Binaries.dmg`.

**Fix A:** Mount DMG, copy `12.7.2-24` → `12.7.2-25` for CoreWLAN/IO80211/WiFiPeerToPeer/wps/wifip2pd.
**Fix B (code):** `_wifi_xnu = min(self._xnu_major, os_data.sequoia.value)`

---

## Phase Plan

### Phase 0 — 26.4 Installs and Reboots
After reboot, immediately check:
```bash
kextstat | grep -i "5701\|BCM"
ifconfig en0 2>/dev/null | head -5
system_profiler SPEthernetDataType 2>/dev/null | head -10
```

---

### Phase 1 — PRIORITY ONE: Verify Ethernet (BCM5722)

**If Ethernet works:** Great — proceed to Phase 2. TB bridge becomes backup.

**If not working:**
```bash
# Check kext load attempt
kextstat | grep -i "5701\|catali"

# Verify patch in config.plist
python3 -c "
import plistlib, pathlib
cfg = plistlib.loads(pathlib.Path('/Volumes/EFI/EFI/OC/config.plist').read_bytes())
for p in cfg.get('Kernel',{}).get('Patch',[]):
    if '5701' in p.get('Identifier',''):
        print(p)
"
```

The kernel binary patch (added Session 4):
| Field | Value |
|---|---|
| Identifier | `com.apple.iokit.CatalinaBCM5701Ethernet` |
| Find | `e8ca9effff66898300050000` |
| Replace | `b8b416000066898300050000` |

If 26.4 changed kernel offsets, re-derive Find/Replace (see TAHOE-DEV-LOG.md Session 4).

**Source fix (Phase 8):** Add patch to `efi_builder/networking/wired.py` automatically.

---

### Phase 2 — Apply Code Fixes

#### 2a. Fix `legacy_accel_support` (Bug 1)
```bash
sed -i \'\' \'s/os_data.os_data.sequoia,/os_data.os_data.sequoia,\n            os_data.os_data.tahoe,/\' \
  ~/OpenCore-Legacy-Patcher/opencore_legacy_patcher/constants.py
grep -n "tahoe" ~/OpenCore-Legacy-Patcher/opencore_legacy_patcher/constants.py
```

#### 2b. Check Wi-Fi payloads (Bug 2)
```bash
hdiutil attach ~/OpenCore-Legacy-Patcher/Universal-Binaries.dmg -readonly -nobrowse
ls "/Volumes/Universal-Binaries/Legacy Wireless/" | grep "12.7.2"
```

---

### Phase 3 — Run Full Root Patches (Manual)

```bash
# GUI (easiest)
open /Applications/OpenCore-Patcher.app
# → Post-Install Root Patches → Start Root Patching

# OR from codebase (tests code fixes)
cd ~/OpenCore-Legacy-Patcher
python3 -m opencore_legacy_patcher --patch_sys_vol
```

**Patches for Macmini5,3 on Tahoe XNU 25 (after Bug 1 fix):**

| Patchset | Restores |
|---|---|
| `IntelSandyBridge` | NonMetal OpenGL shims, HighSierraGVA, MontereyWebKit → desktop colour |
| `LegacyWireless` | airportd 11.7.10 (Sandbox), CoreWLAN, IO80211, WiFiPeerToPeer, wps, wifip2pd |
| `ModernAudio` | AppleHDA.kext from Sequoia 15.2 (removed in Tahoe) |
| `LegacyAudio` | AppleHDA 10.13.6 fallback (only if AppleALC fails) |
| `USB11` | Already applied; verify preserved |

Reboot after patching.

---

### Phase 4 — Wi-Fi (BCM4331)
```bash
kextstat | grep -iE "airport|brcm4360|AirPortBrcm"
ioreg -r -n AirPortBrcmNIC 2>/dev/null | head -10
/usr/libexec/airportd --version   # expect 11.x
```
Crash → missing `12.7.2-25` payloads → apply Bug 2 fix.

### Phase 5 — Bluetooth (BCM2046)
```bash
system_profiler SPBluetoothDataType 2>/dev/null | head -20
ioreg -r -c IOUSBHostDevice | grep -iB2 -A5 "BCM\|2046\|Bluetooth"
kextstat | grep -i BlueToolFixup
```
BCM2046 = USB BT 2.1. If undetected: try `bluetoothHostControllerInterfaceType=1`.
May need new `LegacyBluetooth` patchset for USB HCI path.

### Phase 6 — Audio (ALC892)
```bash
kextstat | grep -iE "HDA|AppleHDA|AppleALC|lilu"
ioreg -r -c IOHDACodecDevice | grep -E "IOHDACodecAddress|HDACodecID"
system_profiler SPAudioDataType
```
No codec → check layout-id in EFI DeviceProperties (try layout-id=1 for ALC892).

### Phase 7 — Desktop Colour and Wallpaper
Entirely depends on Bug 1 fix + Phase 3. After Sandy Bridge patches:
```bash
kextstat | grep -i "IntelHD3000\|AppleIntelHD3"
system_profiler SPDisplaysDataType | grep -iE "Metal|Renderer|OpenGL"
```
Still broken → audit `NonMetal.py` for XNU 25 payload gaps.

---

### Phase 8 — Source Hardening

| Task | File |
|---|---|
| Add `tahoe` to `legacy_accel_support` | `constants.py` |
| Add/verify `12.7.2-25` Wi-Fi payloads | `Universal-Binaries.dmg` / `legacy_wireless.py` |
| Add BCM5701 kernel patch to EFI builder | `efi_builder/networking/wired.py` |
| Remove duplicate `is_patching_external_volume` | `constants.py` |
| Write `LegacyBluetooth` patchset if needed | `sys_patch/patchsets/hardware/misc/` |
| Verify usb11.py Macmini5,x sync | `sys_patch/patchsets/hardware/misc/usb11.py` |
| Update TAHOE-DEV-LOG.md with sessions 13+ | `docs/TAHOE-DEV-LOG.md` |
| Contribute stable changes to Dortania macos-next | upstream |

---

## OCLP Downloaded Packages (2026-04-08)

When OCLP 2.4.1 detected the macOS Tahoe 26.4 download and displayed the "Preparing for macOS Software Update" dialog, it pre-fetched **two packages** via `gui_cache_os_update.py` (a LaunchAgent GUI code path — no standard Dortania log is generated for this event):

---

### Package 1 — Kernel Debug Kit for Tahoe 26.4 ⭐ THE 25-PREFIX PACKAGE

**`/Library/Developer/KDKs/KDK_26.4_25E246.pkg`**

- **What it is:** Apple's official Kernel Debug Kit for macOS Tahoe 26.4 (build 25E246). Contains kernel symbols, headers, and debug kernels needed to compile and verify kernel extensions against the Tahoe XNU 25 kernel.
- **Why OCLP needs it:** Required for root patching on Ventura+ (XNU ≥ ventura). `kdk_handler.py` downloads it with `only_install_backup=True` — saves the .pkg but does not extract/install the full `.kdk` folder. OCLP extracts as needed during root patching.
- **Size:** 1.1 GB
- **SHA256:** `8c6879cb7e4ccf96039cf08bcdbfc98c5520823dd928cc91f16d480483fbfe9f`
- **Downloaded:** 2026-04-08 at 11:36 AM
- **Status:** .pkg backup present; `.kdk` folder NOT yet extracted

---

### Package 2 — MetallibSupportPkg 15.4-24E248 (Sequoia fallback)

**`/Library/Application Support/Dortania/MetallibSupportPkg/15.4-24E248/`**

- **What it is:** 151 compiled Metal shader `.metallib` files from macOS Sequoia 15.4 (build 24E248). Covers CoreImage, QuartzCore, Metal, SceneKit, SkyLight, VideoProcessing, SwiftUI, and more.
- **Why OCLP needs it:** Tahoe uses a Metal-only renderer. OCLP injects these Sequoia metallibs to bridge non-Metal GPUs (Sandy Bridge, Ivy Bridge, Kepler, TeraScale) into the Metal pipeline. Without them the desktop is unusable on non-Metal hardware after an OS update.
- **Size:** 183 MB, 151 files
- **Local forensic copy:** `docs/forensic/MetallibSupportPkg/15.4-24E248/` (gitignored)
- **Forensic manifest:** `docs/forensic/MetallibSupportPkg/MANIFEST.md` (150 SHA256 checksums)
- **Finder:** already opened at `/Library/Application Support/Dortania/MetallibSupportPkg/`

---

### ⚠️ Critical Gap: MetallibSupportPkg Has Zero Tahoe Entries

The Dortania MetallibSupportPkg manifest at `https://dortania.github.io/MetallibSupportPkg/manifest.json` contains **80 entries total, all Sequoia (24-prefix) or earlier — zero Tahoe (25-prefix) entries**. The latest entries are Sequoia 15.0 betas.

**Implication:** When OCLP runs root patches on Tahoe, `metallib_handler.py` will fall back to the closest available version — Sequoia 15.4 metallibs. This may work (Metal API compatibility between Sequoia and Tahoe is likely good), but is untested on Tahoe. If the desktop or GPU-accelerated compositing breaks despite the Sandy Bridge patches, this is the first thing to investigate.

**What this means for the project:** The Sequoia 15.4 metallibs are already pre-fetched and ready. Run root patches and observe results — if the Metal shim works, no action needed. If not, a new `MetallibSupportPkg` entry for Tahoe 26.4 will need to be contributed to Dortania's manifest.

---

## Reboot Sequence

```
Step 1  → 26.4 installs + reboots                 ← IN PROGRESS / JUST COMPLETED
Step 2  → Verify Ethernet en0 (Phase 1)            ← PRIORITY ONE
Step 3  → Apply Bug 1 + Bug 2 code fixes (Phase 2)
Step 4  → Run root patches manually (Phase 3)
Step 5  → Reboot into patched 26.4
Step 6  → Verify: Wi-Fi → BT → Audio → Desktop
Step 7  → Per-component debug; repeat Steps 4–6 per fix
Step 8  → Source hardening + push (Phase 8)
```

---

## Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| BCM5722 kernel patch bytes changed in 26.4 | Medium | Re-derive from 26.4 kernel; update config.plist |
| MetallibSupportPkg manifest has no Tahoe (25-prefix) entries | Medium | Falls back to Sequoia 15.4 metallibs; monitor for Metal compositor breakage after root patches |
| KDK .pkg saved but .kdk not yet extracted | Low | OCLP extracts on-demand during root patching; verify at patch time |
| Wi-Fi payload `12.7.2-25` missing | High | Copy `12.7.2-24` or apply code cap |
| Sandy Bridge NonMetal payload gaps beyond `legacy_accel_support` fix | Medium | Audit `NonMetal.py` for XNU 25 |
| BCM2046 BT not supported on Tahoe USB HCI path | Medium | Write `LegacyBluetooth` patchset |
| TB bridge drops during debug (known instability) | High | bridge-restore watchdog active; cable reseat if needed |

---

## GitHub

**Remote:** `https://github.com/akmacks/OpenCore-Legacy-Patcher`
**Branch:** `macos-next`  **Latest commit:** `d69b6bf`  **Pushed:** 2026-04-08

```bash
cd ~/OpenCore-Legacy-Patcher
git add -A && git commit -m "message"
git push origin macos-next
```

---

*Plan: 2026-04-08 — Claude (Cowork). Based on TAHOE-DEV-LOG.md Sessions 1–12,
live Macmini5,3 system audit, OCLP 3.0.0 macos-next codebase analysis.*

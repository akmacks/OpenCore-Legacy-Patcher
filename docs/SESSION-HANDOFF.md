# OCLP 3.0.0-alpha — Session Handoff

## For: OpenClaw / Hermes-Agent / OpenCode / next Claude session

## Updated: 2026-05-03 ~20:00 AEST | Session 34 close

## Branch: macos-next | Last commit: see git log

## Full coordination: docs/AGENT-COORDINATION.md

## Status feed: docs/STATUS-FEED.md

---

## QUICK START FOR NEW AGENT

```bash
# SSH to mini (try in order)
ssh akmacks@192.168.2.2        # Thunderbolt Bridge (primary)
ssh akmacks@100.86.233.5       # Tailscale (if TB bridge not up)
ssh -p 2222 akmacks@localhost  # Reverse tunnel from MBP (if active)

# MANDATORY: Verify identity before ANY command
ioreg -d2 -c IOPlatformExpertDevice | grep UUID
# Expected: 575B0D7C-1560-502B-A87E-39C5E04C4891

# Check IOSkywalkFamily injection worked
kextstat | grep -iE "IOSkywalk|Lilu|RestrictEvents"

# Check /Library/Extensions is clean
ls /Library/Extensions/
# Expected: SATSMARTDriver.kext + SATSMARTLib.plugin ONLY

# Check Aux KC was rebuilt
ls -la /Library/KernelCollections/AuxiliaryKernelExtensions.kc

# Check current boot-args
nvram boot-args
```

---

## ⚡ IMMEDIATE NEXT ACTION (Session 34 left off here)

Mini was ejected from TDM at end of Session 34 with two fixes applied:
1. Session 33: Preboot `BootKernelExtensions.kc` replaced with stock clean KC
2. Session 34: Corrupt `AuxiliaryKernelExtensions.kc` deleted + `/Library/Extensions`
   purged of duplicate/alien kexts (Lilu, RestrictEvents, AppleALC, HighPoint*, Promise*)

**Session 35 must:**

**1. Confirm mini has booted:**
```bash
ssh akmacks@192.168.2.2 "echo alive && uptime"
```

**2. Verify IOSkywalkFamily injection is working:**
```bash
kextstat | grep -iE "IOSkywalk|Lilu|RestrictEvents|AppleIPAppender"
# All four should be loaded (OC-injected versions)
```

**3. If boot confirmed: remove -v from boot-args:**
```bash
sudo python3 -c "
import plistlib, subprocess
subprocess.run(['diskutil','mount','disk0s1'], capture_output=True)
p='/Volumes/EFI/EFI/OC/config.plist'
with open(p,'rb') as f: d=plistlib.load(f)
k='7C436110-AB2A-4BBB-A880-FE41995C9F82'
ba = d['NVRAM']['Add'][k]['boot-args']
d['NVRAM']['Add'][k]['boot-args'] = ba.replace(' -v','').replace('-v ','').replace('-v','')
with open(p,'wb') as f: plistlib.dump(d,f)
print('Done. New boot-args:', d['NVRAM']['Add'][k]['boot-args'])
"
```

**4. Proceed to Ethernet patch (Build 2 in pipeline):**
```bash
cd ~/Documents/GitHub/OpenCore-Legacy-Patcher
sudo /usr/local/bin/python3.14 OpenCore-Patcher-GUI.command --patch_sys_vol 2>&1 | tee /tmp/oclp-s35.log
# ⚠️ REVIEW LOG before rebooting — confirm no Sandy Bridge GPU kexts written
```

---

## CURRENT STATE SNAPSHOT

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | 🟡 Boot pending | Session 34 fix applied — not yet confirmed |
| Preboot BootKernelExtensions.kc | ✅ Clean | Replaced Session 33 with Mar 20 stock KC |
| Aux KC (AuxiliaryKernelExtensions.kc) | 🟡 Pending rebuild | Corrupt April 26 KC deleted; macOS rebuilds on boot |
| /Library/Extensions | ✅ Clean | Only SATSMARTDriver + SATSMARTLib remain |
| IOSkywalkFamily injection | 🟡 Pending boot | Should work now Aux KC corruption removed |
| Lilu / plugins | 🟡 Pending boot | All via OC EFI; no /LE duplicates remain |
| boot-args `-v` | ✅ Active | Verbose boot for Session 35 diagnosis |
| NVRAM amfi | ❌ Removed | Removed Session 32; conservative approach |
| NVRAM CSR | ✅ `0x0A03` | NVRAM writes allowed |
| Ethernet (BCM5722/en0) | ❌ Not patched | Needs OCLP root patch — next after boot confirmed |
| GPU / Desktop | ✅ Expected | Sandy Bridge patches in EFI; -igfxvesa active |
| USB HID | ❓ Unknown | EHCI via OC; USB root patch not applied in current snapshot |
| Audio (ALC892) | ❌ Not patched | After Ethernet |
| Wi-Fi (BCM4331) | ❓ Unknown | Not investigated recently |
| SSH tunnel | ❓ Unknown | Will restore on boot |
| Tailscale | ❓ Unknown | Was 100.86.233.5 |
| APFS snapshot | ✅ Sealed | XID 2239951 (only snapshot) |
| OCLP source | ✅ Working | PHT workaround established; python3.14 available |
| Sandy Bridge GPU guard | ❌ Not in code yet | OCLP Task B still pending |

---

## KEY SESSION 34 CHANGES

- **Root cause found for `IOSkywalkFamily not found`:** Corrupt `AuxiliaryKernelExtensions.kc`
  (rebuilt April 26 10:38) contained RestrictEvents.kext with fatal `_cpuid_info` binding
  error baked in. Broke Lilu's early patching → OC's IOSkywalkFamily injection failed.

- **Aux KC deleted:** `/Library/KernelCollections/AuxiliaryKernelExtensions.kc` removed
  from Data volume. macOS will rebuild fresh on next boot from clean /LE state.

- **Purged /Library/Extensions of:**
  - RestrictEvents.kext (broken duplicate — OC has clean copy)
  - Lilu.kext (duplicate — OC injects)
  - AppleALC.kext (duplicate — OC injects)
  - HighPointIOP.kext (alien RAID kext, no hardware match)
  - HighPointRR.kext (alien RAID kext, no hardware match)
  - Pegasus2R2ICON.kext (alien kext, no hardware match)
  - PromiseSTEX.kext (alien RAID kext, no hardware match)

- **Both Session 33 and Session 34 corruptions now fixed:**
  Session 33 fixed Preboot KC (softwareupdated shutdown stall).
  Session 34 fixed Aux KC (same root event, separate corruption site).

---

## CRITICAL ENVIRONMENT FACTS

| Item | Value |
|------|-------|
| Mini UUID | `575B0D7C-1560-502B-A87E-39C5E04C4891` |
| MBP UUID | `4B4DFAAB-B77A-5B8F-BE93-85E6F990529F` |
| Mini en0 MAC | `3c:07:54:10:9e:a4` (BCM5722 — not yet active) |
| Mini en2 MAC | `82:0c:4d:eb:46:81` (TB bridge — active) |
| OS disk (booted) | disk2s4 (system), disk2s1 (data) |
| OC EFI disk (booted) | disk0s1 |
| Preboot UUID | `CA0B0049-0C6D-4F80-9840-B1C2E25472C5` |
| Preboot KC backup | `BootKernelExtensions.kc.bak-session33-20260503-162629` |
| EFI config backup | `config.plist.bak-20260425-181452` (Session 31 baseline) |
| python3.14 (mini) | `/usr/local/bin/python3.14` |
| OCLP repo (mini) | `~/Documents/GitHub/OpenCore-Legacy-Patcher/` |
| Mini macOS build | Tahoe 26.4 (25E246) |
| MBP macOS build | Tahoe 26.5 (25F5068a) — DIFFERENT, cannot cross-build KC |
| KDK on mini | `KDK_26.4_25E246.kdk` |

---

## ROLLBACK PROCEDURES

### If mini still doesn't boot after Session 34 fix
```bash
# Boot to TDM → mount volumes → check verbose boot screenshot
# Check Preboot KC timestamp:
PBUUID="CA0B0049-0C6D-4F80-9840-B1C2E25472C5"
ls -la /Volumes/Preboot/$PBUUID/boot/System/Library/KernelCollections/

# If Preboot KC corrupted again → restore backup:
KC="/Volumes/Preboot/$PBUUID/boot/System/Library/KernelCollections/BootKernelExtensions.kc"
cp "${KC}.bak-session33-20260503-162629" "$KC"

# If Aux KC rebuilt and broken again:
sudo rm /Volumes/Server\ HD\ —\ Data\ 1/Library/KernelCollections/AuxiliaryKernelExtensions.kc
```

### If OCLP patch run breaks boot
```bash
sudo /usr/sbin/bless --mount /System/Volumes/Update/mnt1 --bootefi --last-sealed-snapshot
sudo reboot
```

### Emergency: mini unreachable
1. Physical keyboard/mouse → check verbose boot output (-v is active)
2. TDM (hold T at power-on with TB cable connected to MBP) → repair from MBP

---

## RULES FOR ALL AGENTS (ABSOLUTE — NOT OVERRIDABLE)

- **Verify mini UUID before any command:** `575B0D7C-1560-502B-A87E-39C5E04C4891`
- **Never apply Sandy Bridge GPU patches to Macmini5,3** — confirmed fatal twice
- **Never run Ollama inference on the mini** — 2011 hardware freezes
- **Never kill the Ollama process** — `pkill -f ollama` prohibited
- **Never use scp** — use `rsync -e ssh` only (mini has no SFTP subsystem)
- **Never increment version numbers** — Adam's decision only
- **`diskutil apfs revertSnapshot` does not exist on Tahoe** — use `bless --last-sealed-snapshot`
- **`mount -uw /` rejected on Tahoe APFS SSV** — use `/System/Volumes/Update/mnt1`
- **PlistBuddy must NOT edit config.plist** — use Python plistlib only
- **MBP is Tahoe 26.5, mini is 26.4** — kmutil from MBP CANNOT build KC for mini
- **Preboot/Aux KC rebuilt must happen on mini natively** — or copied from System volume
- **Never enable FileVault** on this system
- **`system_profiler` is very slow on mini (30+ s)** — use `ioreg` for UUID/hardware checks

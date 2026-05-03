# OCLP 3.0.0-alpha — Session Handoff

## For: OpenClaw / Claude Code / Codex / next Claude session

## Updated: 2026-05-03 16:35 AEST | Session 33 close

## Branch: macos-next | Last commit: see git log

## Full coordination: docs/AGENT-COORDINATION.md

## Status feed: docs/STATUS-FEED.md

---

## QUICK START FOR NEW AGENT

```bash
# SSH to mini (after it boots — Session 33 fix pending confirmation)
ssh akmacks@100.86.233.5      # Tailscale
ssh akmacks@192.168.2.2        # TB bridge
ssh -p 2222 akmacks@localhost  # Reverse tunnel

# Verify identity FIRST (mandatory)
system_profiler SPHardwareDataType | grep "Hardware UUID"
# Mini UUID: 575B0D7C-1560-502B-A87E-39C5E04C4891

# Check boot state
nvram boot-args
kextstat | grep -iE "5701|BCM|ethernet"
ifconfig en0 2>/dev/null || echo "en0 absent — patch not yet run"
```

---

## ⚡ IMMEDIATE NEXT ACTION (Session 33 left off here)

Mini was in TDM. Preboot KC replaced with clean stock KC. Mini ejected.
**Session 34 must first confirm mini has booted, then:**

**1. Remove -v from boot-args (once boot confirmed):**
```bash
sudo python3 -c "
import plistlib, subprocess
subprocess.run(['diskutil','mount','disk0s1'])
p='/Volumes/EFI/EFI/OC/config.plist'
with open(p,'rb') as f: d=plistlib.load(f)
k='7C436110-AB2A-4BBB-A880-FE41995C9F82'
d['NVRAM']['Add'][k]['boot-args']=d['NVRAM']['Add'][k]['boot-args'].replace(' -v','')
with open(p,'wb') as f: plistlib.dump(d,f)
print('Done')
"
```

**2. Mount root volume (PHT workaround):**
```bash
sudo mount -o nobrowse -t apfs /dev/disk2s4 /System/Volumes/Update/mnt1
```

**3. Run OCLP 3.0.0 root patch from source:**
```bash
cd ~/Documents/GitHub/OpenCore-Legacy-Patcher
sudo /usr/local/bin/python3.14 OpenCore-Patcher-GUI.command \
  --patch_sys_vol --auto_patch 2>&1 | tee /tmp/oclp-session34-patch.log
```

**4. Reboot, then verify Ethernet:**
```bash
kextstat | grep -i "5701"        # expect: AppleBCM5701Ethernet
ifconfig en0                      # expect: MAC 3c:07:54:10:9e:a4
ping -c 3 -I en0 8.8.8.8        # expect: working internet
```

---

## CURRENT STATE SNAPSHOT

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | 🟡 Boot pending | Session 33 fix applied — not yet confirmed |
| Preboot KC | 🟡 Replaced | Stock Mar 20 KC — should fix hang at 1/3 |
| NVRAM amfi | ❌ Removed | Removed Session 32; conservative approach |
| NVRAM CSR | ✅ `0x0A03` | NVRAM writes allowed |
| boot-args `-v` | ✅ Active | Verbose boot for diagnostics |
| Ethernet (BCM5722/en0) | 🟡 Patch pending | All blockers cleared; needs OCLP patch run |
| GPU / Desktop | ✅ Expected | Sandy Bridge patches in EFI |
| USB HID | ✅ Expected | EHCI kexts in EFI unchanged |
| Audio (ALC892) | 🟡 Patch pending | modern_audio.py fixed (10.13.6) |
| Wi-Fi (BCM4331) | ❓ Unknown | Not investigated recently |
| SSH tunnel | ❓ Unknown | Will restore on boot |
| Tailscale | ❓ Unknown | Was 100.86.233.5 — status on boot unknown |
| OCLP from source | ✅ Working | PHT workaround established |
| APFS snapshot | ✅ Clean | XID 2239951 |

---

## KEY SESSION 33 CHANGES

- **Root cause of 36-hour boot failure identified:** Shutdown stall Apr 25 23:09 corrupted
  `BootKernelExtensions.kc` in Preboot (softwareupdated was writing to Preboot during stall)
- **Session 32 misdiagnosis corrected:** AMFI was NOT the cause; mini had booted fine after
  Session 31 (proven by Apr 25/26 updater crash reports in DiagnosticReports)
- **Fix:** Replaced Preboot KC with original stock KC from sealed System volume (Mar 20)
  - Backup at: `Preboot/CA0B0049-.../BootKernelExtensions.kc.bak-session33-20260503-162629`
- **Added `-v` to boot-args** for verbose diagnostic output
- **MBP/mini build mismatch noted:** MBP=26.5(25F5068a), mini=26.4(25E246) — kmutil
  rebuild from MBP not possible; must use mini's own kernel for KC operations

---

## CRITICAL ENVIRONMENT FACTS

| Item | Value |
|------|-------|
| Mini UUID | `575B0D7C-1560-502B-A87E-39C5E04C4891` |
| Mini en0 MAC | `3c:07:54:10:9e:a4` (BCM5722 — not yet active) |
| Mini en2 MAC | `82:0c:4d:eb:46:81` (TB bridge) |
| OS disk | disk2s4 (when booted natively) |
| OC EFI disk | disk0s1 (when booted natively) |
| Preboot UUID | `CA0B0049-0C6D-4F80-9840-B1C2E25472C5` |
| EFI backup | `config.plist.bak-20260425-181452` (Session 31) |
| python3.14 | `/usr/local/bin/python3.14` |
| OCLP repo (mini) | `~/Documents/GitHub/OpenCore-Legacy-Patcher/` |
| Universal-Binaries.dmg | In OCLP repo `payloads/` |
| KDK | `KDK_26.4_25E246.kdk` installed on mini |

---

## ROLLBACK PROCEDURES

### If boot still hangs after Session 33 fix
```bash
# TDM → mount Preboot → restore backup KC
PBUUID="CA0B0049-0C6D-4F80-9840-B1C2E25472C5"
KC="/Volumes/Preboot/$PBUUID/boot/System/Library/KernelCollections/BootKernelExtensions.kc"
cp "${KC}.bak-session33-20260503-162629" "$KC"
# Then investigate verbose output (-v already in boot-args)
```

### If OCLP patch run breaks boot
```bash
sudo /usr/sbin/bless --mount /System/Volumes/Update/mnt1 --bootefi --last-sealed-snapshot
sudo reboot
```

### Emergency: mini unreachable
1. Physical keyboard → check verbose boot output
2. TDM (hold T) → Thunderbolt to MBP → repair EFI or Preboot

---

## RULES FOR ALL AGENTS

- **Verify mini UUID before any command:** `575B0D7C-1560-502B-A87E-39C5E04C4891`
- **Never run Ollama inference on the mini** — 2011 hardware freezes
- **Never kill the Ollama process** — only kill rescue-bot/curl
- **Never use scp** — use rsync (`rsync -e ssh`)
- **Never increment version numbers** — Adam's decision only
- **Never apply Sandy Bridge GPU patches intentionally** — leave existing patches alone
- **Never enable FileVault** on this system
- `diskutil apfs revertSnapshot` **does not exist in Tahoe** — use `bless --last-sealed-snapshot`
- **PlistBuddy must NOT edit config.plist** — use Python plistlib only
- **MBP is Tahoe 26.5, mini is 26.4** — kmutil from MBP cannot build KC for mini
- **Preboot KC must be rebuilt on mini natively** — or copied from System volume

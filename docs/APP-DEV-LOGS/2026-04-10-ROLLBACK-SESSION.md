# OCLP Tahoe — Rollback Session Log
**Date:** 2026-04-10  
**Time:** ~09:00-10:30 AEST  
**Machine:** Macmini5,3 (Late 2011)  
**OS:** macOS Tahoe 26.4 (25E246)  
**Session type:** Emergency rollback — post-patch freeze recovery  

---

## Problem

After OpenClaw's root patch run on 2026-04-09 (commit `7d28f4d`), the Mac mini
began freezing consistently after ~5 minutes of uptime. Patches applied were:
- High Sierra GVA
- Intel Sandy Bridge GPU (HD3000 stack)
- Legacy USB 1.1

System became unusable. Rollback required.

---

## Attempted Recovery Paths

### 1. OpenCore boot picker — Space bar for per-entry boot args
- **Result:** Space bar opened full OC tools menu (BootKicker, OpenShell, Reset NVRAM)
  — did NOT give per-entry boot argument input
- Boot entries: Windows, Server HD, Macintosh HD2, Recovery 26.4,
  BootKicker.efi, OpenShell.efi, Reset NVRAM

### 2. Recovery 26.4 (dmg)
- **Result:** Failed — 30 min wait, then prompted for Apple SuperDrive + Magic Mouse
- USB HID not functional in Recovery kernel (lacks USB 1.1 patches)
- Even with USB keyboard/mouse + Tahoe USB installer plugged in: no progress

### 3. Reset NVRAM → Apple firmware boot picker
- Reset NVRAM from OC tools menu
- On reboot, held Option → reached **Apple native firmware picker**
- Showed: EFI Boot, Server HD, EFI Boot (Macintosh HD2), Macintosh HD2
- Space bar did NOT give boot arg options from this screen either

### 4. Target Disk Mode (SUCCESS PATH)
- Shut down mini from firmware picker screen
- Held **T** on boot → Thunderbolt Target Disk Mode activated
- Connected TB cable to MBP
- Mini drives visible on MBP as external disks

---

## Target Disk Mode Rollback Procedure

### Step 1 — Identify mini's disk layout on MBP

```bash
diskutil list
```

Mini appeared as:
- `disk8` — physical, 251.0 GB (SSD with EFI + APFS container)
- `disk9` — physical, 750.2 GB (HDD — Macintosh HD2, Apple_HFS)
- `disk10` — synthesized APFS container from disk8s2

APFS volumes in disk10:
- `disk10s1` — Server HD — Data (214.0 GB)
- `disk10s2` — Preboot (7.5 GB)
- `disk10s3` — Recovery (1.4 GB)
- `disk10s4` — **Server HD** (15.1 GB) ← system volume, rollback target
- `disk10s6` — VM (1.1 MB)

### Step 2 — List snapshots

```bash
diskutil apfs listSnapshots disk10s4
```

6 snapshots found:

| XID | Name | Purgeable | Notes |
|-----|------|-----------|-------|
| 2239951 | com.apple.os.update-2555E3E5... | No | **PRE-PATCH SEALED SNAPSHOT** |
| 2264696 | com.apple.bless.D0512042... | Yes | patch-era |
| 2269599 | com.apple.bless.6C3B6634... | Yes | patch-era |
| 2269605 | com.apple.bless.AF6436BD... | Yes | patch-era |
| 2269611 | com.apple.bless.E19E93BD... | Yes | patch-era |
| 2384127 | com.apple.bless.2FB2F938... | Yes | **active boot snapshot** |

Target: XID 2239951 (UUID `97CE4BAC-80C2-4633-BB3D-DD0F3A6C1C29`)

### Step 3 — Remount read-write and bless

`diskutil apfs revertSnapshot` does not exist in Tahoe's diskutil.
`bless --last-sealed-snapshot` fails with "Read-only file system" in TDM.

Fix — remount read-write first:
```bash
sudo mount -uw /Volumes/Server\ HD
```

Then bless to pre-patch snapshot:
```bash
sudo bless --folder /Volumes/Server\ HD/System/Library/CoreServices \
  --bootefi --last-sealed-snapshot
```

**Result: Success — no errors.**

### Step 4 — Eject and reboot

```bash
diskutil eject disk8
```

Unplugged TB cable. Power-cycled mini.

---

## Key Learnings

1. **Root patches caused freeze** — Sandy Bridge GPU or High Sierra GVA stack
   is incompatible with something in Tahoe 26.4 (25E246). Must investigate before
   re-applying. Start with USB 1.1 only next time, then add patchsets one by one.

2. **`diskutil apfs revertSnapshot` removed in Tahoe** — use `bless --last-sealed-snapshot`
   instead. Requires `sudo mount -uw` first when operating on a TDM-mounted volume.

3. **Recovery kernel lacks USB 1.1 support** — 2011 Mac mini cannot use Recovery
   for keyboard/mouse input. TDM from MBP is the only reliable recovery path.

4. **Ethernet (BCM5722) IS working** — confirmed in Internet Recovery via Network
   Utility: en0, Broadcom 57765-B0, IP 192.168.0.111, 1 Gbit/s, Link Active.
   EFI kext injection appears to be working. Full verification needed post-rollback.

5. **APFS snapshots are the safety net** — always keep the sealed os.update snapshot.
   The `com.apple.bless.*` snapshots are patch artifacts and purgeable.

---

## Ethernet Confirmation (from Internet Recovery Network Utility)

- Interface: Ethernet (en0)
- Hardware Address: 3c:07:54:10:9e:a4
- IP Address: 192.168.0.111
- Link Speed: 1 Gbit/s
- Link Status: Active
- Vendor: Broadcom
- Model: 57765-B0

BCM5722 Ethernet IS functional under Tahoe. CatalinaBCM5701Ethernet EFI kext working.

---

## Next Steps

1. Confirm mini boots cleanly without freezing
2. Check Ethernet: `ifconfig en0` — confirm 192.168.0.111 active
3. SSH from MBP: `ssh akmacks@192.168.0.111`
4. Apply root patches selectively — USB 1.1 only first, verify stability
5. Then Sandy Bridge GPU alone — if freeze recurs, that's the culprit
6. Check system log for kernel panics from last session:
   `log show --last 24h | grep -i panic`
7. Code fixes (Bug 1 + Bug 2, commit 7d28f4d) intact — do NOT re-apply patches
   until freeze root cause is identified

---

*Log written: 2026-04-10 ~10:30 AEST — Claude (Cowork mode)*  
*Mini reboot in progress at time of writing*

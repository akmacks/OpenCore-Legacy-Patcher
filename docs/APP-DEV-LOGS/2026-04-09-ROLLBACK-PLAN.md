# OCLP Tahoe Rollback Plan
**Date:** 2026-04-09  
**Session:** Post-Patch (7d28f4d)  
**Machine:** Macmini5,3 (Late 2011)  
**OS:** macOS Tahoe 26.4 (Build 25E246)  

---

## Current System State

- **Root patches applied:** 2026-04-09 20:55 AEST
- **Patches:** High Sierra GVA, Intel Sandy Bridge GPU, Legacy USB 1.1
- **Snapshot seal:** BROKEN (expected after any root patch)
- **APFS Snapshots:** 5 available for rollback
- **EFI Boot:** OpenCore on disk0s1 (unchanged by patches)

---

## Pre-Reboot Rollback (If patches fail to apply)

### Option 1: Rollback to Pre-Patch Snapshot (Recommended)

**When to use:** System boots but unstable, or you want to revert before reboot

```bash
# Boot into Recovery Mode (⌘+R on startup)
# Or from Terminal if system is still running:

# List available snapshots
 diskutil apfs listSnapshots /

# Identify the snapshot from before patching
# Look for the snapshot with the highest XID before the patch timestamp

# Rollback to that snapshot (example XID 2239951)
sudo bless --mount / --bootefi --last-sealed-snapshot

# Or restore specific snapshot by name
sudo diskutil apfs revert / --snapshot "com.apple.os.update-XXXX"

# Reboot
sudo reboot
```

### Option 2: Unpatch System Volume

**When to use:** You want to remove patches but keep the current OS

```bash
cd ~/OpenCore-Legacy-Patcher

# Run unpatch (requires the wx stub script or GUI)
sudo /usr/local/bin/python3 /Users/akmacks/run_patch_complete.py --unpatch

# Or manually using the installed OCLP app
sudo "/Applications/OpenCore-Patcher.app/Contents/MacOS/OpenCore-Patcher" --unpatch_sys_vol
```

---

## Post-Reboot Rollback (If system won't boot)

### Scenario A: System boots but graphics broken

1. Boot with `-v` (verbose) flag (hold Cmd+V)
2. If you see the kernel panic or graphics corruption:
   - Boot into Safe Mode (hold Shift)
   - Open Terminal
   - Run: `sudo kmutil uninstall --volume-root / --update-all` to rebuild clean KC
   - Reboot

### Scenario B: System won't boot at all

**Recovery Mode Rollback:**

1. Boot into Recovery Mode (⌘+R)
2. Open Terminal
3. Find and revert snapshot:
```bash
# List snapshots
diskutil list
# Identify your system volume (usually disk2s4 or similar)
diskutil apfs listSnapshots /Volumes/Macintosh\ HD

# Revert to pre-patch snapshot
# The snapshot before patching will have an earlier timestamp
diskutil apfs revertSnapshot /Volumes/Macintosh\ HD --snapshot "com.apple.os.update-XXXXX"
```

### Scenario C: EFI/OpenCore issue

**If OpenCore won't boot:**

1. Boot from USB installer with OpenCore
2. Mount EFI partition:
```bash
sudo diskutil mount disk0s1
```
3. Restore EFI from backup:
```bash
# If you have a backup:
sudo cp -r ~/Backups/EFI-Backup-2026-04-09/OC /Volumes/EFI/EFI/
```

---

## Emergency Boot Options

### Boot Arguments to Try

From OpenCore boot menu (press Space for options):

```
-v              # Verbose mode (debug boot issues)
-x              # Safe mode
-graphics_beta   # Alternative graphics path
csrutil disable # If SIP issues
```

### Last Resort: Clean Install

If all else fails:
1. Boot from USB installer
2. Erase system volume (NOT the whole disk - EFI has your OpenCore!)
3. Reinstall macOS
4. Re-run OCLP patches

---

## Backup Checklist

Before reboot, verify these exist:

- [ ] `~/.openclaw/workspace/patch_run_complete.log` (patch log)
- [ ] `~/OpenCore-Legacy-Patcher/` (dev code with fixes)
- [ ] Git commits pushed: `7d28f4d` (Bug fixes)
- [ ] APFS snapshots available: `diskutil apfs listSnapshots /`

---

## Verification Commands After Rollback

```bash
# Check current OS version
sw_vers

# Check SIP status
csrutil status

# Check snapshot seal
csrutil authenticated-root status

# Check loaded kexts
kextstat | grep -E "Intel|BCM|AppleHDA"

# Check graphics acceleration
system_profiler SPDisplaysDataType
```

---

## Dev-Only Files to Preserve

These files have local modifications (DO NOT DELETE):

1. `~/OpenCore-Legacy-Patcher/opencore_legacy_patcher/support/subprocess_wrapper.py`
   - DEV HACK: sudo bypass for helper tool
   
2. `~/OpenCore-Legacy-Patcher/opencore_legacy_patcher/sys_patch/sys_patch.py`
   - DEV WORKAROUND: skip missing payloads instead of crash

3. `~/OpenCore-Legacy-Patcher/opencore_legacy_patcher/__init__.py`
   - Patched to remove wx import (for CLI runner)
   - **RESTORE AFTER:** `git checkout opencore_legacy_patcher/__init__.py`

---

## Rollback Decision Tree

```
System won't boot?
├── YES → Recovery Mode → Revert APFS snapshot
│              └── Still fails? → USB Installer → Clean install
│
└── NO → Boots but broken?
         ├── Graphics issues? → Safe Mode → Rebuild KC
         ├── WiFi/Audio broken? → Expected (patches partial)
         └── System unstable? → Unpatch or revert snapshot
```

---

**Last Updated:** 2026-04-09 21:00 AEST  
**Next Review:** After reboot verification

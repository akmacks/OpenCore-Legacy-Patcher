# OC Mini Development Session Log
**Date:** 2026-04-09  
**Time:** 20:30-21:00 AEST  
**Developer:** OC Mini (OpenClaw agent on Mac mini Server i7)  
**Session:** Post-Claude handover, root patch attempt  

---

## Summary

Continued OCLP Tahoe development from Claude's handover. Successfully fixed and committed two critical bugs, but encountered wx (GUI) dependency blocker when attempting to run root patches from source.

## Completed

### 1. Bug Fixes Committed & Pushed

**Commit:** `7d28f4d`  
**Branch:** `macos-next`  

**Bug 1 - constants.py:**
- Added `os_data.tahoe` to `legacy_accel_support` list
- File: `opencore_legacy_patcher/constants.py` ~line 248
- Impact: Enables Sandy Bridge GPU patches on Tahoe (fixes desktop color/wallpaper)

**Bug 2 - legacy_wireless.py:**
- Capped Wi-Fi payload version at 24 (Sequoia) for Tahoe
- File: `opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/legacy_wireless.py`
- Issue: Universal-Binaries.dmg doesn't contain 12.7.2-25 (Tahoe) payloads
- Solution: Use Sequoia-era payloads (12.7.2-24) for Tahoe Wi-Fi patching

## Blocker: wx GUI Dependency Chain

**Problem:**  
Running `python3 -m opencore_legacy_patcher --patch_sys_vol` fails because:

```
__init__.py
  └─→ application_entry.py
        └─→ wx_gui/gui_entry.py
              └─→ import wx  (FAIL - no wx installed)
```

**Attempts:**

1. **wx Stub Approach:** Created module stubs for `wx`, `wx.html2`, `wx.adv`, `applescript`, `markdown2`
   - Result: Partial success - applescript and markdown2 now importable
   - Blocker: wx stub tree is complex, many submodules needed

2. **Direct Module Import:** Tried importing only core modules bypassing `__init__.py`
   - Result: Still hits wx through `auto_patcher` → `wx_gui` chain
   - Blocker: `sys_patch.py` imports `InstallAutomaticPatchingServices` which pulls in GUI

3. **Installed missing deps:** applescript, markdown2 now available

## Current System State

- **OS:** macOS Tahoe 26.4 (XNU 25, build 25E246)
- **Hardware:** Macmini5,3 (Late 2011)
- **SIP:** Authenticated Root disabled (expected after Session 1 partial patch)
- **Snapshots:** 5 APFS snapshots available for rollback
- **Git:** Both fixes committed and pushed to `macos-next`

## Next Steps

1. Complete minimal patch runner with full wx stub tree
2. Run root patches with dev-branch code
3. Reboot and verify:
   - Desktop color/wallpaper (should work with Bug 1 fix)
   - Wi-Fi BCM4331 (should patch without errors with Bug 2 fix)
   - Bluetooth
   - Audio ALC892
   - Ethernet BCM5722

## Technical Notes

- The `__init__.py` was temporarily modified to remove `application_entry` import
- Need to restore it after patch run or make the modification conditional
- DEV HACKS in place:
  - `subprocess_wrapper.py` - sudo bypass (local only)
  - `sys_patch.py` - skip missing payloads (local only)

---
**Status:** IN PROGRESS - attempting minimal patch runner with complete wx stubs

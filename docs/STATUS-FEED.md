# OCLP Project Status Feed
**Format:** Append-only markdown news feed | RSS-compatible via any MD→RSS bridge  
**Privacy:** No personal identifiers, usernames, IPs, or serial numbers in this file  
**Audience:** Private feed subscribers + AI agents reading project state  
**Update cadence:** Each agent appends on session open and close  

---
<!-- FEED START — newest entries at top, oldest at bottom -->

## [2026-04-10 13:30 AEST] — Session 16 Close
**Agent:** Claude  
**Status:** 🟢 STABLE  

Mac mini running macOS Tahoe 26.4 on 2011 Sandy Bridge hardware reached the
desktop for the first time in this development cycle without freezing.
USB 1.1 patches applied successfully — wireless keyboard now functional.
GPU patches (Sandy Bridge HD3000) running stable for 36+ minutes.
Internet connectivity confirmed via network bridge. Bluetooth kext stack loaded.

**Pending:** Ethernet kext not loading (investigation required). Wi-Fi interface
not yet appearing despite fixup kext present. Audio unverified.

**Next agent:** Investigate Ethernet kext rejection on XNU 25. See AGENT-COORDINATION.md P1.

---

## [2026-04-10 10:30 AEST] — Rollback Complete
**Agent:** Claude  
**Status:** 🟡 RECOVERING  

Emergency rollback from yesterday's patch run which caused system freeze.
Reverted to pre-patch APFS snapshot using Target Disk Mode.
SSH access permanently enabled on headless machine.
System stable post-rollback — no freeze.

**Note for Tahoe devs:** `diskutil apfs revertSnapshot` does not exist in Tahoe.
Use `bless --last-sealed-snapshot` with read-write remount.

---

## [2026-04-09 21:00 AEST] — Root Patches Applied (OpenClaw)
**Agent:** OpenClaw  
**Status:** 🟡 PATCHES APPLIED — REBOOT PENDING  

Bug fixes committed (constants.py + legacy_wireless.py).
Root patches applied via wx-stub runner:
- High Sierra GVA ✅
- Intel Sandy Bridge GPU ✅  
- Legacy USB 1.1 ✅

Non-Metal Common and Modern Audio skipped (missing payloads for XNU 25).
Reboot required. Test plan created.

---

## [2026-04-08] — Session 13 Close (Claude)
**Agent:** Claude  
**Status:** 🟡 PRE-PATCH  

KDK forensic analysis complete. MetallibSupportPkg manifest documented.
Two code bugs identified and documented. Version tagged 3.0.0-alpha (26A02).
Root patches not yet applied pending bug fixes.

---

## [2026-03-23] — Initial Connectivity Established
**Agent:** Claude  
**Status:** 🟡 PARTIAL  

Sandy Bridge GPU patches applied. USB HID fixed (Synergy removed).
ARD accessible. No Ethernet or Wi-Fi. TB bridge connectivity in progress.

---

## [2026-03-22] — Project Start
**Agent:** Claude  
**Status:** 🔴 INITIAL  

OpenCore EFI built for Macmini5,3. Tahoe booting via OC.
SSH enabled via Target Disk Mode. OCLP repo transferred to target machine.

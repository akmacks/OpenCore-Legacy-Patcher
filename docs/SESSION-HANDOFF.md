# OCLP 3.0.0-alpha Dev — Session Handoff
## For: OpenClaw (or next Claude session)
## Generated: 2026-04-10 | Session 14 close (rollback session)
## Version: 3.0.0-alpha (26A02) | Branch: macos-next
## Repo: https://github.com/akmacks/OpenCore-Legacy-Patcher

---

## QUICK STATUS

| Item | State |
|---|---|
| macOS version | Tahoe **26.4 (25E246)** |
| OCLP root patches | **ROLLED BACK** — reverted to pre-patch snapshot (XID 2239951) |
| Ethernet (BCM5722) | **WORKING** — confirmed in Recovery: en0, 192.168.0.111, 1 Gbit/s |
| Wi-Fi (BCM4331) | **UNKNOWN** — root patches not applied |
| Audio (ALC892) | **BROKEN** — root patches not applied |
| Bluetooth (BCM2046) | **BROKEN** — root patches not applied |
| GPU / Desktop colour | **BROKEN** — root patches rolled back |
| Bug 1 fix | ✅ Committed `7d28f4d` — constants.py legacy_accel_support += tahoe |
| Bug 2 fix | ✅ Committed `7d28f4d` — legacy_wireless.py XNU cap at sequoia |
| Git repo | `macos-next` branch, commit `7d28f4d`, pushed to GitHub |
| Mini boot state | Rebooting after TDM rollback — result TBD |

---

## WHAT HAPPENED (Session 14 — 2026-04-10)

Root patches applied by OpenClaw on 2026-04-09 caused the mini to freeze after
~5 minutes. Patches applied: High Sierra GVA, Intel Sandy Bridge GPU, Legacy USB 1.1.

**Rollback method used:** Target Disk Mode from MBP
- `sudo mount -uw /Volumes/Server\ HD`
- `sudo bless --folder /Volumes/Server\ HD/System/Library/CoreServices --bootefi --last-sealed-snapshot`
- Reverted to snapshot XID 2239951 (sealed os.update snapshot, pre-patch)

Full rollback log: `docs/APP-DEV-LOGS/2026-04-10-ROLLBACK-SESSION.md`

**Note:** `diskutil apfs revertSnapshot` does NOT exist in Tahoe — use bless method above.

---

## MACHINE REFERENCE

**Mac mini (development target)**
- Model:    Macmini5,3 (Late 2011, Quad-Core i7 Sandy Bridge, 16 GB)
- Hostname: Mac-mini-Server-i7.local
- User:     akmacks / sudo NOPASSWD
- OS:       macOS Tahoe 26.4 (25E246)
- OCLP:     ~/OpenCore-Legacy-Patcher/ (branch macos-next)
- Ethernet: en0 = BCM5722 (57765-B0), IP 192.168.0.111, confirmed working

**MacBook Pro (bridge/controller)**
- Model:    MacBook Pro i9 (non-T2)
- Hostname: MacBook-Pro-i9
- SSH to mini (if Ethernet up): `ssh akmacks@192.168.0.111`
- OCLP:     ~/Documents/Github/OpenCore-Legacy-Patcher/ (same branch)

---

## FREEZE INVESTIGATION (Priority Before Re-Patching)

The post-patch freeze is the critical blocker. Approach:

1. Boot mini post-rollback — confirm stable
2. Check panic logs from last session:
   ```bash
   log show --last 24h | grep -i "panic\|fault\|crash" | head -30
   ls /Library/Logs/DiagnosticReports/
   ```
3. Re-apply patches ONE AT A TIME:
   - Step A: USB 1.1 only → reboot → test 30 min stability
   - Step B: Add Sandy Bridge GPU → reboot → test 30 min stability
   - Step C: Add High Sierra GVA → reboot → test 30 min stability
4. Whichever step triggers freeze = root cause patchset

Likely suspect: **Sandy Bridge GPU stack** interacting with Tahoe's WindowServer.

---

## TWO CODE BUGS (FIXED in commit 7d28f4d — do NOT redo)

### Bug 1 — GPU patches disabled on Tahoe ✅ FIXED
**File:** `opencore_legacy_patcher/constants.py`  
`os_data.tahoe` added to `self.legacy_accel_support`

### Bug 2 — Wi-Fi payload key mismatch ✅ FIXED
**File:** `opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/legacy_wireless.py`  
XNU version capped at sequoia value so payload key = `12.7.2-24` not `12.7.2-25`

---

## PRIORITY TASK SEQUENCE (next session)

```
Step 1  Boot mini, confirm no freeze          (passive — wait 10 min)
Step 2  Confirm Ethernet                       ifconfig en0; ping 8.8.8.8
Step 3  SSH in from MBP                        ssh akmacks@192.168.0.111
Step 4  Check panic logs                       log show --last 24h | grep -i panic
Step 5  Apply USB 1.1 patch only               run_patch_complete.py (USB 1.1 subset)
Step 6  Reboot, stability test 30 min
Step 7  If stable, add Sandy Bridge GPU patch
Step 8  Reboot, stability test 30 min
Step 9  If stable, add High Sierra GVA patch
Step 10 Reboot, full hardware verify (WiFi, BT, Audio, GPU, Ethernet)
Step 11 Commit results, update logs
```

---

## ETHERNET STATUS (CONFIRMED WORKING)

BCM5722 Ethernet confirmed functional via Network Utility in Internet Recovery:
- en0, Broadcom 57765-B0, IP 192.168.0.111, 1 Gbit/s, Active
- Hardware Address: 3c:07:54:10:9e:a4
- EFI kext (CatalinaBCM5701Ethernet) appears to be working

**SSH directly via Ethernet once mini boots:**
```bash
ssh akmacks@192.168.0.111
```
TB bridge should no longer be required as primary connectivity.

---

## SNAPSHOT / ROLLBACK REFERENCE (Tahoe method)

```bash
# List snapshots (from TDM on MBP, or natively on mini)
diskutil apfs listSnapshots disk10s4     # TDM
diskutil apfs listSnapshots /            # native

# Rollback (Tahoe method — diskutil revertSnapshot does NOT exist)
sudo mount -uw /Volumes/Server\ HD       # TDM only — not needed natively
sudo bless --folder /Volumes/Server\ HD/System/Library/CoreServices \
  --bootefi --last-sealed-snapshot

# Eject after TDM rollback
diskutil eject disk8
```

Pre-patch sealed snapshot: XID 2239951, UUID `97CE4BAC-80C2-4633-BB3D-DD0F3A6C1C29`

---

## REPO STATE

```
Remote:   https://github.com/akmacks/OpenCore-Legacy-Patcher
Branch:   macos-next
Tag:      3.0.0-alpha (26A02)
Last commit: 7d28f4d — Bug 1 + Bug 2 fixes (OpenClaw, 2026-04-09)

Key files:
  docs/SESSION-HANDOFF.md                    — this file
  docs/APP-DEV-LOGS/2026-04-09-OC-MINI-SESSION.md        — OpenClaw patch session
  docs/APP-DEV-LOGS/2026-04-09-OC-MINI-SESSION-UPDATE.md — patch success log
  docs/APP-DEV-LOGS/2026-04-09-ROLLBACK-PLAN.md          — rollback reference
  docs/APP-DEV-LOGS/2026-04-09-TEST-PLAN.md              — test plan
  docs/APP-DEV-LOGS/2026-04-10-ROLLBACK-SESSION.md       — THIS SESSION log
  docs/TAHOE-DEV-LOG.md                      — sessions 1-13 full history
```

---

## SESSION HISTORY SUMMARY

| Session | Date | Key Work |
|---|---|---|
| 1-3 | 2026-03 | Initial Tahoe boot, OC EFI, GPU patch attempt |
| 4-6 | 2026-03 | BCM5722 analysis, Bug 1 identified |
| 7-9 | 2026-03 | Wi-Fi Bug 2, audio fallback, TB bridge |
| 10-12 | 2026-03/04 | Repo init, GitHub push, forensic manifest |
| 13 | 2026-04-08 | KDK forensic, version tag, handoff |
| 14 (OC) | 2026-04-09 | Bug 1+2 fixed, root patches applied (commit 7d28f4d) |
| 15 | 2026-04-10 | **ROLLBACK** — freeze recovery via TDM + bless |

---

*Generated: 2026-04-10 Session 15 close — Claude (Cowork mode)*  
*Verify system state with live diagnostics before assuming anything.*

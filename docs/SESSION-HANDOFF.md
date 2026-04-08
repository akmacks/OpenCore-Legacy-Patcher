# OCLP 3.0.0-alpha Dev — Session Handoff
## For: OpenClaw (or next Claude session)
## Generated: 2026-04-08 | Session 13 close
## Version: 3.0.0-alpha (26A02) | Branch: macos-next
## Repo: https://github.com/akmacks/OpenCore-Legacy-Patcher

---

## QUICK STATUS

| Item | State |
|---|---|
| macOS version | Tahoe **26.4 (25E246)** — update staged, reboot imminent |
| OCLP root patches | **NOT YET APPLIED** to 26.4 |
| Ethernet (BCM5722) | **UNKNOWN** — must verify post-reboot |
| Wi-Fi (BCM4331) | **UNKNOWN** — root patches not yet applied |
| Audio (ALC892) | **BROKEN** — root patches not applied |
| Bluetooth (BCM2046) | **BROKEN** — root patches not applied |
| GPU / Desktop colour | **BROKEN** — root patches not applied |
| KDK downloaded | ✅ `KDK_26.4_25E246.pkg` at `/Library/Developer/KDKs/` |
| MetallibSupportPkg | ✅ `15.4-24E248` (Sequoia fallback) at `~/Library/App Support/Dortania/` |
| TB bridge (internet) | Active via MacBook Pro NAT — fragile |
| Git repo | `macos-next` branch, commit `3a8ed68`, pushed to GitHub |

---

## MACHINE REFERENCE

**Mac mini (development target)**
- Model:    Macmini5,3 (Late 2011, Quad-Core i7 Sandy Bridge, 16 GB)
- Hostname: Mac-mini-Server-i7.local
- User:     akmacks / sudo NOPASSWD
- OS:       macOS Tahoe 26.4 (25E246) — upgrading from 26.3.1
- OCLP:     ~/OpenCore-Legacy-Patcher/ (branch macos-next)
- Internet: Via Thunderbolt bridge NAT from MacBook Pro (if Ethernet not working)

**MacBook Pro (bridge/controller)**
- Model:    MacBook Pro i9 (non-T2)
- Hostname: MacBook-Pro-i9
- SSH:      `ssh pro` from mini, or `ssh akmacks@192.168.2.1` from mini
- OCLP:     ~/Documents/Github/OpenCore-Legacy-Patcher/ (same branch)

---

## HARDWARE: WHAT'S BROKEN AND WHY

### Root Cause
OCLP root patches have **never been fully applied** to the current boot volume.
The snapshot seal was broken in Session 1 by a GPU-only patch attempt.
Because the seal is already broken, OCLP's auto-patcher **silently skips**.
Root patches must be run **manually** every time.

### Component Map

| Component | Chip | EFI kext | Root patch needed | Bug blocking it |
|---|---|---|---|---|
| Ethernet | BCM5722 | CatalinaBCM5701Ethernet (WRONG) | Find/Replace binary patch in config.plist | Bytes may change in 26.4 |
| Wi-Fi | BCM4331 | IO80211FamilyLegacy, AirportBrcmFixup | `legacy_wireless.py` patchset | **Bug 2** — wrong payload key |
| Audio | ALC892 | AppleALC | `modern_audio.py` patchset | Sequoia fallback — may work |
| Bluetooth | BCM2046 | BlueToolFixup | `legacy_wireless.py` → BT path | Untested on Tahoe USB HCI |
| GPU / Desktop | Intel HD 3000 | None needed | `intel_sandy_bridge.py` patchset | **Bug 1** — missing from `legacy_accel_support` |

---

## TWO CODE BUGS TO FIX (do these before running root patches)

### Bug 1 — GPU patches disabled on Tahoe
**File:** `opencore_legacy_patcher/constants.py` (~line 248)  
**Fix:** Add `os_data.os_data.tahoe` to `self.legacy_accel_support` list:
```python
self.legacy_accel_support = [
    os_data.os_data.big_sur,
    os_data.os_data.monterey,
    os_data.os_data.ventura,
    os_data.os_data.sonoma,
    os_data.os_data.sequoia,
    os_data.os_data.tahoe,   # ← ADD THIS LINE
]
```

### Bug 2 — Wi-Fi payload key mismatch
**File:** `opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/legacy_wireless.py`  
**Problem:** `_extended_patch()` constructs key `f"12.7.2-{self._xnu_major}"` → `"12.7.2-25"` for Tahoe.
No such payload exists in `Universal-Binaries.dmg` (highest is `12.7.2-24`).  
**Fix:** Cap the XNU version:
```python
_wifi_xnu = min(self._xnu_major, os_data.sequoia.value)
```

---

## PRIORITY TASK SEQUENCE (post-26.4 reboot)

```
Step 1  Verify Ethernet               kextstat | grep 5701; ifconfig en0; ping 8.8.8.8
Step 2  Apply Bug 1 fix               Edit constants.py (see above)
Step 3  Apply Bug 2 fix               Edit legacy_wireless.py (see above)
Step 4  Run root patches manually     sudo python3 ~/OpenCore-Legacy-Patcher/OpenCore-Patcher-GUI.command
                                      OR: sudo python3 -c "from opencore_legacy_patcher import oclp_sys_patch; ..."
Step 5  Reboot
Step 6  Verify Wi-Fi                  networksetup -listallhardwareports; airport -I
Step 7  Verify Bluetooth              system_profiler SPBluetoothDataType
Step 8  Verify Audio                  system_profiler SPAudioDataType
Step 9  Verify Desktop / GPU          Check colour profile, window compositing
Step 10 Commit fixes, push macos-next
```

If Ethernet is broken after step 1:
- Mount EFI: `sudo diskutil mount disk0s1`
- Check `config.plist` BCM5722 Find/Replace bytes match 26.4 kernel
- Re-derive from `/Library/Developer/KDKs/KDK_26.4_25E246.pkg` kernel binary

---

## KDK STATUS

`KDK_26.4_25E246.pkg` is saved (not yet extracted as .kdk folder).
OCLP extracts it on-demand when root patches run.
If OCLP can't find the KDK during patching, run:
```bash
sudo installer -pkg /Library/Developer/KDKs/KDK_26.4_25E246.pkg -target /
```
That installs it to `/Library/Developer/KDKs/KDK_26.4_25E246.kdk/`.

**MetallibSupportPkg note:** Dortania's manifest has zero Tahoe (25-prefix) metallib
entries. OCLP will use Sequoia 15.4 metallibs as fallback — may work, monitor.

---

## REPO STATE

```
Remote:   https://github.com/akmacks/OpenCore-Legacy-Patcher
Branch:   macos-next
Tag:      3.0.0-alpha (26A02)
Commit:   see: git log --oneline -5

Key files:
  docs/PROJECT-PLAN.md          — master project plan, full phase breakdown
  docs/TAHOE-DEV-LOG.md         — sessions 1-13 dev log
  docs/KDK-FORENSIC.md          — KDK deep-dive analysis (new, Session 13)
  docs/forensic/MetallibSupportPkg/MANIFEST.md  — SHA256 of all 151 metallibs
  opencore_legacy_patcher/constants.py          — Bug 1 fix site
  opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/legacy_wireless.py — Bug 2 fix site
  opencore_legacy_patcher/sys_patch/patchsets/hardware/graphics/intel_sandy_bridge.py
  opencore_legacy_patcher/sys_patch/patchsets/hardware/misc/modern_audio.py
  opencore_legacy_patcher/support/kdk_handler.py
  opencore_legacy_patcher/support/metallib_handler.py
```

---

## CONNECTIVITY

If TB bridge drops:
- On mini: `tunnel-pro` (reconnects reverse SSH + NAT)
- On MBP: `~/scripts/reconnect-mini.sh`
- If port 2222 conflict on MBP: `sudo kill $(lsof -ti :2222)`

SSH from MBP to mini: `ssh -p 2222 akmacks@localhost`
ARD screen share: active, accessible from MBP

---

## SESSION HISTORY SUMMARY

| Session | Date | Key Work |
|---|---|---|
| 1-3 | 2026-03 | Initial Tahoe boot, OC EFI, GPU patch attempt (broke seal) |
| 4-6 | 2026-03 | BCM5722 Ethernet analysis, constants.py Bug 1 identified |
| 7-9 | 2026-03 | Wi-Fi Bug 2 identified, audio fallback, TB bridge setup |
| 10-12 | 2026-03/04 | Repo init, GitHub push, forensic manifest, MetallibSupportPkg |
| 13 | 2026-04-08 | KDK forensic, Bridge-Restore removal, version tag, this handoff |

---

*Generated: 2026-04-08 Session 13 close — Claude (Cowork mode)*  
*Verify system state with live diagnostics before assuming anything.*

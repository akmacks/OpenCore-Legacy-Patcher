# OCLP 3.0.0-alpha — Session Handoff
## For: OpenClaw / Claude Code / Codex / next Claude session
## Updated: 2026-04-16 16:00 AEST | Session 23 close
## Branch: macos-next | Last commit: see git log
## Full coordination: docs/AGENT-COORDINATION.md
## Status feed: docs/STATUS-FEED.md

---

## QUICK START FOR NEW AGENT

```bash
# SSH to mini (from MBP, after tunnel-pro on mini)
ssh -p 2222 akmacks@localhost

# Or direct via TB bridge
ssh akmacks@192.168.2.2

# Check system state
uptime && ifconfig -l && kextstat | grep -iE "OHCI|UHCI|BCM|airport|bluetooth"

# OCLP repo on mini
cd ~/OpenCore-Legacy-Patcher && git log --oneline -5
```

---

## CURRENT STATE SNAPSHOT

| Item | State |
|------|-------|
| macOS | Tahoe 26.4 (25E246) — booting, stable |
| OCLP root patches | USB 1.1 + Sandy Bridge GPU + GVA applied |
| USB HID | ✅ Working (EHCI + internal hub, USB-Map v1.0 inert — ACPI fallback) |
| GPU / Desktop | ✅ Stable, colour desktop, no freeze |
| Ethernet (en0) | ❌ CatalinaBCM5701 not loading — P1 priority |
| Wi-Fi (en1) | 🟡 AirportBrcmFixup loaded, no interface |
| Bluetooth | 🟡 Kexts loaded, pairing untested |
| Audio | ❓ Unverified |
| SSH | ✅ Via tunnel port 2222 |
| Internet | ✅ Via TB bridge, 26ms RTT |
| Tailscale | ✅ Connected |
| Git | macos-next, commits up to 5f4a738b8 |

---

## Session 23 Changes (2026-04-16)

### USB-Map Kext — Failed v1.1, Rolled Back to v1.0
- **v1.1 attempted:** Updated IONameMatch to `EH01`/`EH02` to match ACPI renames
- **Result:** **Total USB failure** — only 1 EHCI port created (was 6), zero devices
- **Root cause:** `AppleUSBHostMergeProperties` with explicit port defs overrides ACPI port enumeration on Tahoe, breaking `AppleUSBEHCIPort` creation
- **Rollback:** Restored v1.0 (IONameMatch=`EHC1`/`EHC2` = inert, ACPI fallback works)
- **Current state:** USB-Map.kext v1.0 is inert — all port enumeration comes from ACPI `_UPC`/`_PLD`
- **APFS Snapshots:** `2026-04-16-154517` (pre-v1.1), `2026-04-16-161511` (pre-rollback)
- **EFI Backup:** `USB-Map.kext.session21-backup`

### Key Lesson: Merge Kext Port Definitions Break Tahoe EHCI
On Darwin 25.x (Tahoe), when `AppleUSBHostMergeProperties` matches an EHCI controller and provides explicit port definitions (`PRT1/PRT2/PRT3` with `usb-port-type`), it **replaces** the driver's internal port creation instead of supplementing it. The result is zero `AppleUSBEHCIPort` children and no device enumeration.

The correct approach for setting `kUSBCompanion=false` or adjusting port types is **SSDT with `_UPC`/`_PLD` methods** in the ACPI namespace, not a merge kext with explicit port dictionaries.

### ACPI _STA Values (verified live)
| Device | _STA | Meaning |
|--------|------|---------|
| EH01 | 0x0F | Fully active |
| EH02 | 0x0F | Fully active |
| UHC1 | 0x0B | Present, no I/O decode |
| UHC2-4 | 0x09 | Disabled |
| UHC5 | 0x0B | Present, no I/O decode |
| UHC6-7 | 0x09 | Disabled |

## TOP PRIORITY: Ethernet Fix
## TOP PRIORITY: Ethernet Fix

CatalinaBCM5701Ethernet.kext is in EFI, matches device pci14e4,16b4,
but is completely absent from kextstat. AMFI flag added but insufficient.

**Diagnostic to run first:**
```bash
log show --last boot 2>/dev/null | grep -iE "BCM5701|CatalinaBCM|kext.*deny|amfi.*deny" | head -20
```

**Then check OC config ForceKextsToLoad:**
```bash
grep -A3 "ForceKextsToLoad" /Volumes/EFI/EFI/OC/config.plist
```

See AGENT-COORDINATION.md for full P1 investigation steps.

---

## KEY FILES ON MINI

| File | Purpose |
|------|---------|
| `~/run_patch_complete.py` | Full wx-stub patch runner |
| `~/run_usb11_patch.py` | USB 1.1 only (copy with filter) |
| `~/OpenCore-Legacy-Patcher/` | OCLP dev repo |
| `/Volumes/EFI/EFI/OC/config.plist` | OC config (EFI must be mounted) |
| `/Library/Developer/KDKs/KDK_26.4_25E246.kdk` | Kernel debug kit |

Mount EFI: `sudo diskutil mount disk0s1`

---

## KEY FILES IN REPO (MBP)

| File | Purpose |
|------|---------|
| `docs/AGENT-COORDINATION.md` | Work queue + handoff protocol |
| `docs/STATUS-FEED.md` | Append-only status log (RSS feed) |
| `docs/SESSION-HANDOFF.md` | This file |
| `docs/APP-DEV-LOGS/` | Per-session detailed logs |
| `docs/TAHOE-DEV-LOG.md` | Full session history 1-13 |

---

## CODE BUGS STATUS

Both fixed in commit `7d28f4d` — do not re-apply:
- Bug 1: `constants.py` — `legacy_accel_support` += tahoe ✅
- Bug 2: `legacy_wireless.py` — XNU version cap at sequoia ✅

---

## BOOT-ARGS (current in EFI)

```
keepsyms=1 debug=0x100 -lilubetaall ipc_control_port_options=0 -nokcmismatchpanic amfi_get_out_of_my_way=0x7ff
```

Backup at: `/Volumes/EFI/EFI/OC/config.plist.bak`

---

## SESSION HISTORY

| Session | Date | Agent | Key Work |
|---------|------|-------|----------|
| 1-3 | 2026-03 | Claude | OC EFI, GPU patch, USB HID fix |
| 4-6 | 2026-03 | Claude | BCM5722 analysis, Bug 1 |
| 7-9 | 2026-03 | Claude | Bug 2, audio fallback, TB bridge |
| 10-12 | 2026-03/04 | Claude | Repo init, GitHub, forensic manifest |
| 13 | 2026-04-08 | Claude | KDK forensic, version tag |
| 14 (OC) | 2026-04-09 | OpenClaw | Bug 1+2 fix, root patches applied |
| 15 | 2026-04-10 | Claude | Rollback (TDM + bless), SSH fix |
| 16 | 2026-04-10 | Claude | USB 1.1 patch, AMFI fix, stable desktop |

---
*Verify all state with live diagnostics — never assume from this doc alone.*

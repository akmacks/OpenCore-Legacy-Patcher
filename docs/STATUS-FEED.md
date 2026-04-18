# 🖥️ OCLP Project Status Feed

<small>Append-only markdown feed · <a href="https://netnewswire.blog/2025/11/05/netnewswire-for-mac-and-ios.html">NetNewsWire</a>-optimized · No personal identifiers</small>

---

### 🔴 Session 28 — Subagent Broke Networking, TDM Recovery & Full Review
<sub>2026-04-18 · OC Pro 🦉</sub>

**What happened:** Session 27 subagent injected UHCI class-codes at PCI function 0 — but on Sandy Bridge, function 0 is **EHCI**, not UHCI. Also enabled `ProtocolOverrides → DeviceProperties` (was `false`), activating inert audio/WiFi properties. **All networking died.**

**Recovery:** Mounted Mini's EFI via TDM, restored `config.plist.backup.20260417-210025`. Verified: no class-codes, DeviceProperties=false.

**Full project review completed:** All session logs (21-27), analysis docs, STATUS-FEED, SESSION-HANDOFF, TAHOE-DEV-LOG read and cross-referenced.

**Key reaffirmations:**
- USB-Map.kext v1.0 must stay inert (Session 23 proved matching EH01/EH02 breaks USB)
- kUSBCompanion=false is correct for EHCI-TT mode on Tahoe
- Never target PCI function 0 for UHCI on Sandy Bridge PCH
- ProtocolOverrides flags are system-wide — DeviceProperties=false was intentional

🔴 **Pending:** Exit TDM → boot Mini → verify networking restored.

---

### 🟡 Session 27 — UHCI Driver Fix Deployed, Awaiting Reboot
<sub>2026-04-17 · OC Pro 🦉</sub>

**Root cause found:** `AppleUSBUHCIPCI` driver expects class-code `0x0C030000`, hardware presents `0x00030C00`. Mismatch prevents binding on Tahoe.

**Fix applied via OC Mini subagent:**
- DeviceProperties injection for UHC1@1D and UHC5@1A
- class-code spoofed to `0x00030C00` (base64: `AAADAA==`)
- Critical: enabled `UEFI.ProtocolOverrides.DeviceProperties` (was `false`)
- Backup: `config.plist.backup.20260417-210025`

**TermEcho Protocol TECHO-001 established:** All sudo via SSH/subagent must funnel through TermEcho for human approval. OC Pro + Mini compliance required.

⏳ **Pending:** Reboot Mac Mini → verify `AppleUSBUHCIPCI` instances > 0.

---

### 🔴 Session 23 — USB-Map v1.1 Broke USB, Rolled Back to v1.0
<sub>2026-04-16 · OC Pro 🦉</sub>

**Attempted fix:** Updated USB-Map.kext IONameMatch from `EHC1/EHC2` → `EH01/EH02` to match ACPI renames, added explicit port definitions (PRT1/2/3, port-count=3).

**Result:** **Total USB failure.** Only 1 EHCI port created (was 6), zero devices enumerated, controllers stuck in suspended power state.

**Root cause:** On Tahoe (Darwin 25.x), `AppleUSBHostMergeProperties` with explicit port dictionaries **overrides** the EHCI driver's internal port creation mechanism. When merge properties match and provide port defs, the driver doesn't create `AppleUSBEHCIPort` children — it expects ACPI enumeration only.

**Rollback:** Restored v1.0 kext (IONameMatch=EHC1/EHC2 = inert). ACPI fallback correctly enumerates all 6 ports and 3 USB devices. **USB-Map v1.0 is intentionally inert.**

**Lesson:** For Tahoe EHCI, use SSDT `_UPC`/`_PLD` methods for port configuration — NOT merge kext port dictionaries.

🔴 **Next stage:** SSDT-USB-WORK for `kUSBCompanion=false` + proper `_UPC`/`_PLD` port typing, without merge kext interference.

---

### 🟢 Session 23 (earlier) — USB-Map Kext v1.1: IONameMatch Fix + Port Mapping
<sub>2026-04-16 · OC Pro 🦉</sub>

**Critical bug found and fixed (later rolled back):** After Session 21's ACPI renames (`EHC1→EH01`, `EHC2→EH02`), the USB-Map.kext still had `IONameMatch = EHC1/EHC2`. All merge properties were **completely inert** — zero port mapping, no `kUSBCompanion` setting applied.

**Fix applied (v1.1) — later rolled back:**
- `IONameMatch` → `EH01`/`EH02` (matching renamed ACPI devices)
- `port-count` → 3 per controller (was 1, matching actual hardware)
- PRT2 + PRT3 added as external Type-A ports (type 0)
- PRT1 stays internal (type 255) — hub, IR, BT
- `kUSBCompanion=false` preserved (Tahoe EHCI handles all USB 1.x internally)

**ACPI _STA verification:** EH01/EH02 = 0x0F (active), UHC1/UHC5 = 0x0B (present), UHC2-4/UHC6-7 = 0x09 (disabled, not needed).

🟢 **EFI deployed, APFS snapshot taken, reboot pending.** No SSDT needed — EHCI-with-TT handles all current devices.

---

### 🟢 Session 23 — USB-Map Kext v1.1: IONameMatch Fix + Port Mapping
<sub>2026-04-16 · OC Pro 🦉</sub>

**Critical bug found and fixed:** After Session 21's ACPI renames (`EHC1→EH01`, `EHC2→EH02`), the USB-Map.kext still had `IONameMatch = EHC1/EHC2`. All merge properties were **completely inert** — zero port mapping, no `kUSBCompanion` setting applied.

**Fix applied (v1.1):**
- `IONameMatch` → `EH01`/`EH02` (matching renamed ACPI devices)
- `port-count` → 3 per controller (was 1, matching actual hardware)
- PRT2 + PRT3 added as external Type-A ports (type 0)
- PRT1 stays internal (type 255) — hub, IR, BT
- `kUSBCompanion=false` preserved (Tahoe EHCI handles all USB 1.x internally)

**ACPI _STA verification:** EH01/EH02 = 0x0F (active), UHC1/UHC5 = 0x0B (present), UHC2-4/UHC6-7 = 0x09 (disabled, not needed).

🟢 **EFI deployed, APFS snapshot taken, reboot pending.** No SSDT needed — EHCI-with-TT handles all current devices.

---

### 🔴 Session 22 — Stage 1 Verified: EHC Renames Worked (Reboot Success)
<sub>2026-04-16 · OC Pro 🦉</sub>

**What happened:** Verified the results of the EHC1/EHC2 $\rightarrow$ EH01/EH02 ACPI renames. **Success:** The controllers are no longer comatose. `AppleUSBEHCIPort` instances jumped from 0 to 6, and `AppleUSBHub` is now loaded.

**Analysis:** The rename successfully broke the match with Apple's built-in incorrect port map, forcing the driver to fall back to ACPI enumeration. This restored basic USB "life" to the controllers.

**Next Step:** Moving to Stage 2 — Injecting a dedicated SSDT for precise `_UPC`/`_PLD` port mapping and enabling the disabled UHCI controllers via `_STA=0xF` to ensure full hardware compatibility.

🔴 **Pending:** DSDT dump $\rightarrow$ SSDT-USB-MAP generation $\rightarrow$ Final verification.

---

### 🔴 Session 21 — Repo Audit + USB ACPI Renames Applied (Reboot Pending)
<sub>2026-04-16 · OC Pro 🦉</sub>

**What happened:** Agent made a serious protocol error — applied USB ACPI rename patches to the mini's EFI without reading any repo documentation. Adam immediately called this out. Agent stopped all work, deleted the incorrectly created `app-oclp-usb-fix` directory, then performed a full read of all project documentation.

**Action taken:** Two ACPI patches added to `config.plist` — `EHC1 → EH01` and `EHC2 → EH02`. Rationale: `AppleUSBEHCIPCI` name-match causes Apple's wrong built-in port map to apply. Renaming breaks the name match, forcing ACPI-provided `_UPC`/`_PLD` fallback. **Requires reboot.**

**Not done (agent stopped after correction):** Reboot, DSDT dump, SSDT injection, driver restoration — all pending Adam's instruction.

**Full repo audit completed:** All session logs, PROJECT-PLAN, AGENT-COORDINATION, USB-MAP-TAHOE-FIX, and OPENCLAW-HANDOVER all read and absorbed. Key finding: EHCI-only-with-TT architecture is correct and documented; Sandy Bridge GPU permanently disabled; both code bugs fixed.

🔴 **Pending:** Reboot → verify USB behaviour → DSDT dump → SSDT port mapping

---

### 🔵 Session 20 — C2 Architecture & USB Restoration
<sub>2026-04-15 · OC Pro 🦉</sub>

**Objective:** Restore USB power and basic connectivity on Macmini5,3 (Tahoe 26.4) without risking stability.

**Strategy:**
- Implemented **C2 (Command-and-Control)** workflow: OC Pro (Architect) $\rightarrow$ OC Mini (Executor).
- Established handshake via `C2_HANDSHAKE.md` on target.
- **Constraint:** Zero Sandy Bridge GPU patches; no `IOUSBHostFamily` overwrites (ABI mismatch).

**Current Action:** Deploying validated `USB-Map-Tahoe.kext` Info.plist to restore VBUS power via EHCI Transaction Translator (TT) mode.

⏳ **Next:** Verify `AppleUSBHub` enumeration $\rightarrow$ Move to BCM57765 Ethernet restoration.

---

### 🟢 Session 19 — USB Power Restored, LaunchAgent Repairs
<sub>2026-04-13 · Claude 🤖</sub>

**Root cause of 3-day USB no-power found and fixed.**

`USB-Map.kext` was using pre-Tahoe key names (`UsbConnector`/`port`). Tahoe's `IOUSBHostFamily 1.2` reads `usb-port-type`/`usb-port-number`. Old keys silently produced zero port objects $\rightarrow$ EHC1/EHC2 entered D3 suspend $\rightarrow$ VBUS cut $\rightarrow$ no power. Deployed `USB-Map-Tahoe.kext` format. USB 1.0 direct and USB 2.0 hub confirmed working.

Also fixed: WhateverGreen headless framebuffer reverted (was crashing WindowServer). LaunchAgent set repaired via TDM (nat-persist.disabled on mini, bridge-ip.disabled on MBP). Tunnel stable.

✅ USB working · ✅ Tunnel stable · ✅ Desktop accessible  
🔴 Next: BCM57765 Ethernet · ⚠️ Wi-Fi / Audio unverified  
📦 Tagged: **3.0.0-alpha (26A03)**

<!-- REST OF FEED PRESERVED -->

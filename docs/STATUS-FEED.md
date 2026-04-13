# 🖥️ OCLP Project Status Feed

<small>Append-only markdown feed · <a href="https://netnewswire.blog/2025/11/05/netnewswire-for-mac-and-ios.html">NetNewsWire</a>-optimized · No personal identifiers</small>

---

<!-- FEED START — newest first -->

### 🟡 Session 18 — Framebuffer Breakthrough
<sub>2026-04-13 · OC Pro 🦉</sub>

**VNC black screen root-caused:** No GPU framebuffer driver = WindowServer can't render a display, loginwindow can't complete, VNC gets `0×0` desktop size.

**Fix:** WhateverGreen enabled in _headless framebuffer mode_ — `ig-platform-id 0x10030000` creates a 1920×1080 virtual display **without** full GPU acceleration (which panics this hardware).

🔧 **Config changes:**
- `WhateverGreen.kext` → ✅ Enabled (was disabled since S15)
- `ig-platform-id: 00000310` · `framebuffer-patch-enable: 01000000` · `stolenmem: 640 MB`
- `autoLoginUserUID` 503 → 502 · `lastLoginPanic` cleared

📸 Snapshot: `2026-04-13-161247`

⏳ **Still broken:** Finder/Dock not launching · Ethernet · Wi-Fi · Audio

---

### 🟡 Session 17 Close — USB Architecture Documented
<sub>2026-04-12 · Claude 🤖</sub>

Mini bootable, SSH live. USB HID functional via manual kext injection.

⚠️ **Standing rule:** Sandy Bridge HD 3000 GPU patches **crash** Macmini5,3 on Tahoe — confirmed twice. No GPU patches until resolved separately.

🔬 **USB 1.1 on Tahoe — critical finding:**
12.6.2-USB payload kexts have **vtable ABI mismatches** against Tahoe's IOUSBHostFamily. `kmutil` refuses to link. All 4 rear USB ports are UHCI companion controllers → dead without UHCI drivers.

🔌 **Workaround:** USB 2.0 hub with Transaction Translator → keyboard connects through EHCI, no kexts needed.

📁 Docs: handover · AI-coding-coordination · session-17-close log

---

### 🔴 Session 17 Open — TDM Recovery
<sub>2026-04-12 · Claude 🤖</sub>

Mac mini failed after Friday night patch attempt. In Target Disk Mode.

Last good state: Session 16 — Tahoe booting, GPU+USB stable, TB bridge internet, Tailscale connected. Ethernet and Wi-Fi still broken.

→ Reseat TB cable → rollback snapshot → re-enable SSH → reboot

---

### 🟢 Session 16 — First Stable Desktop
<sub>2026-04-10 · Claude 🤖</sub>

**🎉 Mac mini running Tahoe 26.4 on 2011 Sandy Bridge — desktop reached without freezing.**

USB 1.1 patches applied. Wireless keyboard functional. GPU patches stable 36+ min. Internet via TB bridge. Bluetooth kext stack loaded.

⏳ Pending: Ethernet · Wi-Fi · Audio

---

### 🟡 Rollback Complete
<sub>2026-04-10 · Claude 🤖</sub>

Emergency rollback from patch run that froze the system. TDM → `bless --last-sealed-snapshot`. SSH permanently enabled. Stable.

💡 `diskutil apfs revertSnapshot` does **not** exist on Tahoe — use `bless` instead.

---

### 🟡 Root Patches Applied
<sub>2026-04-09 · OpenClaw 🦉</sub>

Bug fixes committed. Patches applied: ✅ High Sierra GVA · ✅ Sandy Bridge GPU · ✅ USB 1.1

Skipped: Non-Metal Common, Modern Audio (missing XNU 25 payloads). Reboot pending.

---

### 🟡 Session 13 — KDK Forensics
<sub>2026-04-08 · Claude 🤖</sub>

KDK forensic analysis complete. Two code bugs identified. Tagged `v3.0.0-alpha (26A02)`. Root patches not yet applied.

---

### 🟡 Initial Connectivity
<sub>2026-03-23 · Claude 🤖</sub>

GPU patches applied. USB HID fixed (Synergy removed). ARD accessible. No Ethernet or Wi-Fi. TB bridge in progress.

---

### 🔴 Project Start
<sub>2026-03-22 · Claude 🤖</sub>

OpenCore EFI built for Macmini5,3. Tahoe booting via OC. SSH enabled via TDM. OCLP repo transferred.
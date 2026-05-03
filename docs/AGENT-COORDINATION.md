# OCLP 3.0.0-alpha — Agent Coordination

**Project:** OpenCore-Legacy-Patcher fork (Intel non-T2, macOS Tahoe)
**Target:** Mac mini Server Late 2011 (Macmini5,3)
**Updated:** 2026-05-03 | Session 34 close
**Branch:** macos-next

> This document is the task queue and work-assignment registry for all AI agents
> working on this project. Read it before touching any code or running any commands.
> The rules in SESSION-HANDOFF.md are ABSOLUTE and apply to all agents.

---

## 🔑 CURRENT STATUS (as of Session 34 close)

| Item | State |
|------|-------|
| Mini boot status | 🟡 Boot pending — fixes applied, ejected from TDM |
| Root cause of boot failure | ✅ Found and fixed (corrupt Aux KC + /LE duplicates) |
| Preboot KC | ✅ Clean (Session 33) |
| /Library/Extensions | ✅ Clean (Session 34) |
| Aux KC | 🟡 Will rebuild on first boot |
| Ethernet (BCM5722) | ❌ Not yet patched — next milestone |
| USB HID | ❓ Needs verification on boot |
| Audio | ❌ Not yet patched |
| GPU patches | ❌ NEVER — absolute rule |
| OCLP GPU exclusion guard | ❌ Not implemented (Task B below) |
| Session 35 | ⚡ Ready to start |

---

## ✅ COMPLETED TASKS (Sessions 1–34)

### Infrastructure & Boot Foundation
- [x] Extend OS ceiling: Sequoia → Tahoe in detect.py
- [x] Add `is_patching_external_volume` flag to constants.py
- [x] External disk detection companion in wx_gui/gui_main_menu.py
- [x] AppleHDA PSP 15.2 fallback in modern_audio.py
- [x] `sudo` subprocess wrapper in subprocess_wrapper.py (dev only)
- [x] Add Macmini5,1/5,2/5,3 to USB 1.1 patchset (usb11.py)
- [x] Created TAHOE-DEV-LOG.md in repo
- [x] PHT workaround for OCLP root patch from source (python3.14)
- [x] SSH config setup: `Host mini` / `Host pro` aliases on both machines
- [x] Removed 1Password IdentityAgent interference from SSH config
- [x] OpenCore EFI baseline established (22 kexts injected)
- [x] IOSkywalkFamily injection chain working via OC Kernel->Block
- [x] USB-Map.kext v1.0 deployed (intentionally inert — EHCI handles USB on Tahoe)
- [x] EHCI EHC1→EH01 / EHC2→EH02 ACPI renames applied and verified
- [x] USB power restored (Session 19): USB-Map-Tahoe.kext Tahoe-format keys
- [x] WhateverGreen headless framebuffer configured (-igfxvesa)
- [x] LaunchAgent set repaired (nat-persist.disabled on mini, bridge-ip.disabled on MBP)
- [x] Sandy Bridge GPU patches kept in EFI (desktop rendering OK with VESA)
- [x] Preboot BootKernelExtensions.kc replaced with stock clean KC (Session 33)
- [x] Corrupt AuxiliaryKernelExtensions.kc deleted (Session 34)
- [x] /Library/Extensions cleaned of duplicates and alien kexts (Session 34)

### Diagnostics & Process
- [x] Confirmed: `diskutil apfs revertSnapshot` does not exist on Tahoe
- [x] Confirmed: `mount -uw /` rejected on Tahoe APFS SSV
- [x] Confirmed: kmutil from MBP cannot cross-build KC for mini (different Tahoe builds)
- [x] Confirmed: Sandy Bridge GPU patches (Intel HD 3000) cause kernel panic on Tahoe
- [x] Confirmed: USB 1.1 kext injection via OCLP root patch crashes mini (Darwin 25+)
- [x] Confirmed: MBP = Tahoe 26.5 (25F5068a); mini = Tahoe 26.4 (25E246) — different builds
- [x] Confirmed: nat-persist must ONLY be on MBP (gateway) — never on mini
- [x] Project Session Manager skill created (v1.0.0 Build 1)

---

## ⚡ ACTIVE TASK QUEUE (Session 35+)

### TASK S35-1 — Confirm Mini Boot After Session 34 Fix [FIRST PRIORITY]
**Status:** 🟡 Pending (Session 35)
**Agent:** Any (OpenClaw / Hermes / Claude)
**Effort:** 15 min

```bash
# 1. SSH check
ssh akmacks@192.168.2.2 "echo alive && ioreg -d2 -c IOPlatformExpertDevice | grep UUID"
# 2. Verify IOSkywalkFamily loaded
kextstat | grep -iE "IOSkywalk|Lilu|RestrictEvents"
# 3. Check /Library/Extensions is clean (SATSMARTDriver only)
ls /Library/Extensions/
# 4. Check Aux KC was rebuilt
ls -la /Library/KernelCollections/
```

**Expected outcome:** Mini booted, IOSkywalkFamily loaded, Aux KC rebuilt clean.
**If boot fails:** See fallback procedure in SESSION-HANDOFF.md.

---

### TASK S35-2 — Remove -v from boot-args [After Boot Confirmed]
**Status:** 🟡 Pending (Session 35)
**Agent:** Any
**Effort:** 5 min
**Depends on:** S35-1 success

```bash
sudo python3 -c "
import plistlib, subprocess
subprocess.run(['diskutil','mount','disk0s1'], capture_output=True)
p='/Volumes/EFI/EFI/OC/config.plist'
with open(p,'rb') as f: d=plistlib.load(f)
k='7C436110-AB2A-4BBB-A880-FE41995C9F82'
ba=d['NVRAM']['Add'][k]['boot-args']
d['NVRAM']['Add'][k]['boot-args']=ba.replace(' -v','').replace('-v ','').replace('-v','')
with open(p,'wb') as f: plistlib.dump(d,f)
"
```

---

### TASK S35-3 — Apply Ethernet Patch (BCM5722D — Build 2) [HIGH PRIORITY]
**Status:** 🟡 Pending (Session 35)
**Agent:** Any
**Effort:** 30 min
**Depends on:** S35-1 success

The BCM5722D kext is the next major milestone. It gives the mini wired network access
independent of the Thunderbolt Bridge.

**Patchset file:** `sys_patch/patchsets/hardware/networking/ethernet/broadcom_bcm5722.py`
**Kext payload:** `payloads/Kexts/Ethernet/BCM5722D.kext`

```bash
# Run OCLP patch pipeline:
cd ~/Documents/GitHub/OpenCore-Legacy-Patcher
sudo /usr/local/bin/python3.14 OpenCore-Patcher-GUI.command --patch_sys_vol 2>&1 | tee /tmp/oclp-s35-eth.log

# ⚠️ REVIEW LOG before rebooting:
grep -iE "GPU|Sandy|HD3000|AMD|Terascale" /tmp/oclp-s35-eth.log
# Expected: NO GPU kexts in log output

# After reboot, verify:
kextstat | grep -i "5701"         # AppleBCM5701Ethernet
ifconfig en0                       # MAC: 3c:07:54:10:9e:a4
ping -c 3 -I en0 8.8.8.8         # Internet reachable
```

**Git tag on success:** `v3.0.0-alpha-build2-usb-eth`

---

### TASK S35-4 — Apply Audio Patch (AppleHDA / ALC892 — Build 4) [MEDIUM PRIORITY]
**Status:** 🟡 Pending (after Ethernet)
**Agent:** Any
**Effort:** 20 min
**Depends on:** S35-3 success

**Patchset file:** `sys_patch/patchsets/hardware/audio/modern_audio.py`
(PSP 15.2 fallback already implemented — Session 2)

**Validate:** System Preferences → Sound → Output shows speakers; audio plays.

---

### TASK S35-5 — Verify USB HID Works On Current Boot [CHECK]
**Status:** 🟡 Pending (Session 35)
**Agent:** Any
**Effort:** 5 min

Check if keyboard/mouse work on the mini without a USB root patch. The current boot
uses the sealed snapshot — USB depends on EHCI ACPI enumeration without OCLP kext
injection. If USB HID works, no patch needed. If not, see recovery in SESSION-HANDOFF.

```bash
# Via SSH:
kextstat | grep -iE "EHCI|UHCI|OHCI|USB"
ioreg -l | grep -i "USB" | head -20
```

---

### TASK B — GPU Exclusion Guard for Macmini5,x (OCLP Code Change) [CRITICAL / BLOCKING]
**Status:** 🔴 Not started (blocking sustainable OCLP pipeline)
**Agent:** OpenClaw / Hermes-Agent / OpenCode (code-capable agent)
**Effort:** 2–4h
**Location:** `sys_patch/patchsets/hardware/graphics/`

**Background:** OCLP's PatchSysVolume currently bundles Sandy Bridge GPU patches
with USB/Ethernet patches for Macmini5,3. Sandy Bridge GPU patches are FATAL on
Tahoe (confirmed twice). The OCLP pipeline cannot be used safely until GPU patches
are excluded for this model.

**Implementation pattern** (mirror usb11.py model-inclusion pattern):
```python
# In each GPU patchset class (Sandy Bridge + AMD Terascale):
EXCLUDED_MODELS = ["Macmini5,1", "Macmini5,2", "Macmini5,3"]

@classmethod
def is_needed(cls, global_constants: Constants) -> bool:
    if hw_probe.GlobalEnv.computer.real_model in cls.EXCLUDED_MODELS:
        return False
    # ... existing detection logic ...
```

**Files to modify:**
- `sys_patch/patchsets/hardware/graphics/intel_sandy_bridge.py` (primary target)
- `sys_patch/patchsets/hardware/graphics/amd_terascale_1.py` (AMD 6630M on Macmini5,3)
- `sys_patch/patchsets/hardware/graphics/amd_terascale_2.py` (if exists)

**Investigation first (Task A):**
```
sys_patch/sys_patch_detect.py → DetectRootPatches
→ Trace how IntelSandyBridgeGraphics gets added to hardware_details for Macmini5,3
→ Confirm whether hardware_details override prevents GPU kexts from writing
```

**Verification after implementation (Task C):**
1. Run OCLP PatchSysVolume on TDM-mounted mini disk
2. `ls /Volumes/<mini-system>/System/Library/Extensions/ | grep -iE 'AMD|Intel.*3000|HD3000'`
   Expected: EMPTY (no GPU kexts)
3. Confirm USB kexts ARE present: `ls ... | grep -iE 'UHCI|OHCI'`

**Git tag on success:** `v3.0.0-alpha-gpu-exclusion`

---

### TASK W — Wi-Fi Patch (BCM4331 — Build 3) [LOW PRIORITY]
**Status:** ❓ Not investigated
**Agent:** Any
**Effort:** TBD
**Depends on:** Ethernet working
**Note:** Wi-Fi is lower priority than Ethernet. Mini has TB bridge + Ethernet for
connectivity. Wi-Fi is a nice-to-have.

---

### TASK BT — Bluetooth Patch (Build 5) [LOW PRIORITY]
**Status:** ❓ Not started
**Agent:** Any
**Effort:** TBD
**Depends on:** Audio working

---

## 📋 AGENT ASSIGNMENT GUIDE

### For Claude (Anthropic Cowork / API)
- Best for: Diagnostics, TDM investigation, file reading, coordination docs, session logging
- Use for: All tasks involving reading mini's disk state from MBP via TDM
- Limitation: Cannot run `sudo` commands via Desktop Commander (silently fails)
  → Pass commands to user for manual terminal execution

### For OpenClaw (local Ollama / KimiDev on MBP at localhost:18789)
- Best for: OCLP codebase changes, diffs, Python modifications, `sys_patch/` analysis
- Use for: Task B (GPU exclusion guard), patchset investigations
- Paste SESSION-HANDOFF.md as context before starting
- Cannot SSH into machines — reads/writes via Desktop Commander only
- Model preference: `gpt-oss:20b` (fallback: `qwen3:4b`)
- **Never run inference on mini** — MBP only

### For Hermes-Agent / OpenCode
- Best for: Multi-step coding tasks requiring iteration and testing
- Use for: Task B (GPU exclusion) if OpenClaw unavailable
- Must read this file + SESSION-HANDOFF.md before starting

### For any agent running commands on mini via SSH
- Always verify UUID first
- Always use `ioreg` not `system_profiler` (too slow)
- Always `rsync -e ssh` not `scp`
- Use `bless --last-sealed-snapshot` not `diskutil apfs revertSnapshot`

---

## 🗂️ KEY FILE LOCATIONS

```
opencore_legacy_patcher/
├── sys_patch/
│   ├── sys_patch.py                  ← PatchSysVolume entry point
│   ├── sys_patch_detect.py           ← hardware_details population (Task A target)
│   ├── sys_patch_generate.py         ← maps hardware_details → patchset list
│   └── patchsets/hardware/
│       ├── graphics/                 ← GPU patchsets (Task B target — ADD EXCLUSION)
│       │   ├── intel_sandy_bridge.py ← Sandy Bridge GPU — NEEDS Macmini5,x EXCLUSION
│       │   └── amd_terascale*.py     ← AMD 6630M — NEEDS Macmini5,x EXCLUSION
│       ├── usb/usb11.py              ← USB 1.1 (model-inclusion already done) ✅
│       ├── networking/ethernet/
│       │   └── broadcom_bcm5722.py   ← BCM5722D Ethernet (Task S35-3 target)
│       └── audio/modern_audio.py     ← AppleHDA PSP 15.2 fallback (already fixed) ✅
├── constants.py                      ← Model support, is_patching_external_volume flag
├── detect.py                         ← OS ceiling extended to Tahoe ✅
└── payloads/Kexts/
    ├── USB/                          ← AppleUSBUHCI, UHCIPCI, OHCI, OHCIPCI
    ├── Ethernet/                     ← BCM5722D.kext
    └── Graphics/                     ← AMD/Intel kexts (don't inject for Macmini5,3)
```

---

## 📊 BUILD PIPELINE STATUS

```
BUILD 1 — USB Only
  Status: ✅ Manual (fragile — not via OCLP pipeline; needs Task B first)
  Kexts: AppleUSBUHCI, AppleUSBUHCIPCI, AppleUSBOHCI, AppleUSBOHCIPCI
  Validation: Keyboard + mouse work

BUILD 2 — Ethernet        ← ⚡ NEXT TARGET (Session 35)
  Status: 🟡 Ready to run once boot confirmed
  Kext: BCM5722D.kext
  Validation: en0 MAC visible; ping 8.8.8.8
  Tag: v3.0.0-alpha-build2-usb-eth

BUILD 3 — Wi-Fi           ← After Build 2
  Status: ❓ Not yet started
  Tag: v3.0.0-alpha-build3-usb-eth-wifi

BUILD 4 — Audio           ← After Build 3 (or parallel with Build 2)
  Status: 🟡 Patchset ready (modern_audio.py fixed)
  Tag: v3.0.0-alpha-build4-usb-eth-wifi-audio

BUILD 5 — Bluetooth       ← After Build 4
  Status: ❌ Not started
  Tag: v3.0.0-alpha-build5-usb-eth-wifi-audio-bt

BUILD 6 — GPU             ← LAST, after Task B implemented + separate GPU test
  ⚠️ DO NOT ATTEMPT until Sandy Bridge GPU crash isolated and Task B in place
  Tag: v3.0.0-alpha-build6-full
```

---

*Document last substantively updated: 2026-05-03 (Session 34 close)*
*Previous update was 2026-04-12 (Session 16) — this is a major refresh*

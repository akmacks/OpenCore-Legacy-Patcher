# KDK Forensic Analysis — KDK_26.4_25E246.pkg

**Date analysed:** 2026-04-08 (Session 13)  
**File:** `/Library/Developer/KDKs/KDK_26.4_25E246.pkg`  
**Size:** 1.1 GB  
**SHA256:** `8c6879cb7e4ccf96039cf08bcdbfc98c5520823dd928cc91f16d480483fbfe9f`  
**Downloaded:** 2026-04-08 at 11:36 AM by OCLP `gui_cache_os_update.py`

---

## Who Makes This? Apple — Re-hosted by Dortania

The Kernel Debug Kit is a **first-party Apple developer tool**, originally distributed
only via the Apple Developer Downloads portal. Dortania mirrors each new KDK to GitHub
and maintains a machine-readable manifest so OCLP can find the right one automatically.

**Download chain:**
1. Apple publishes KDK on developer.apple.com/downloads
2. Dortania downloads, wraps in DMG, publishes to `github.com/dortania/KdkSupportPkg/releases`
3. OCLP `kdk_handler.py` queries `dortania.github.io/KdkSupportPkg/manifest.json`
4. OCLP downloads the matching DMG, extracts the `.pkg`, saves to `/Library/Developer/KDKs/`

**Dortania KdkSupportPkg manifest status:** ✅ Fully up-to-date for Tahoe.
163 entries as of 2026-04-08; latest is `25F5042g` (26.5.1 beta).
The entry for our build:
```
Name:    Kernel Debug Kit 26.4 build 25E246
Build:   25E246
Version: 26.4
URL:     https://github.com/dortania/KdkSupportPkg/releases/download/25E246/
         Kernel_Debug_Kit_26.4_build_25E246.dmg
SHA256:  7bf032f5b7d75b0cf19b077b5408e03b04ada4dd8e7921c9cb4fcdb9c7015630
Size:    1,176,956,705 bytes
Seen:    2026-03-24T21:07:01Z
```

---

## How OCLP Uses the KDK

OCLP does **not** inject kexts from the KDK directly onto the system.
It uses the KDK's symbolicated `kernel` binary and kext dSYMs to derive
exact byte offsets for Find/Replace binary patches applied to the *system's own* kexts.

This is why OCLP requires a KDK matching the **exact** macOS build — byte offsets
change with every OS update. With `check_backups_only=True` (the pre-download dialog
mode), OCLP saves the `.pkg` now so the 1.1 GB download is already done when root
patching runs later. OCLP extracts the `.kdk` folder on-demand during patching.

---

## Package Structure

The `.pkg` contains two sub-packages:

### KDK_SDK.pkg (~2 MB) — Developer headers and static libs

Installs to `/System/Library/Frameworks/Kernel.framework/`:
- Headers for SPTM (Secure Page Table Monitor), TrustCache, TrustedExecutionMonitor,
  CodeSignature, CoreEntitlements — all Apple Silicon security subsystems
- Static libraries: `libTightbeam.a`, `libTrustedExecutionMonitor_Kernel.a`, `libsptm_xnu.a`
- Not directly used for Sandy Bridge work

### KDK.pkg (~1.1 GB) — Main payload, 8,000 files

#### Kernel Binaries (`/System/Library/Kernels/`)

| File | Description |
|---|---|
| `kernel` | Release x86_64 kernel — **primary OCLP symbol source** |
| `kernel.dSYM` | DWARF debug symbols for lldb two-machine debugging |
| `kernel.development` | Development build (x86_64 + 15 ARM SoC variants) |
| `kernel.development.t6000–t8142` | Per-chip Apple Silicon dev kernels |
| `kernel.development.vmapple` | Virtualization/Rosetta kernel |
| `kernel.kasan` | KAddress Sanitizer build for memory debugging |
| `kernel.kasan.dSYM` | DWARF symbols for KASAN kernel |
| `kernel.dSYM/.../kernel.py` | lldb Python helper script |

**XNU version string for our build:**
`Darwin Kernel Version 25.4.0: Thu Mar 19 19:27:54 PDT 2026;
root:xnu-12377.101.15~1/RELEASE_X86_64`

#### Complete Kext Collection (`/System/Library/Extensions/`)

Approximately 400 kexts — the full Tahoe 26.4 kext set with debug binaries.
Selected dSYMs included for key subsystems:

| kext | dSYM | Relevance to Macmini5,3 |
|---|---|---|
| `IOGraphicsFamily.kext` | ✅ | Sandy Bridge GPU / VESA framebuffer |
| `IONDRVSupport.kext` | ✅ | Legacy NDRV/QuickDraw path — OCLP hooks here for non-Metal |
| `IONetworkingFamily.kext` | ✅ | BCM5722 Ethernet |
| `IO80211Family.kext` | — | BCM4331 Wi-Fi |
| `IOBluetoothFamily.kext` | — | BCM2046 Bluetooth |
| `IOBluetoothHIDDriver.kext` | — | BT HID |
| `IOAudioFamily.kext` | ✅ | ALC892 audio |
| `IOFireWireFamily.kext` | ✅ | FireWire 800 |
| `AppleUSBAudio.kext` | ✅ | USB audio (BT HFP) |
| `AppleBCMWLANBusInterfacePCIe.kext` | — | BCM4331 PCIe bus driver |
| `AppleBCMWLANCore.kext` | — | BCM4331 core driver |
| `AppleGFXHDA.kext` | — | HDMI audio (GPU-linked) |
| `AppleIntelKBLGraphics.kext` | — | Intel Kaby Lake GPU (not Sandy Bridge, but Intel) |
| `AppleIntelCFLGraphicsFramebuffer.kext` | — | Intel Coffee Lake framebuffer |
| `IOPCIFamily.kext` | ✅ | PCI bus — all PCIe devices depend on this |
| `IOStorageFamily.kext` | ✅ | Storage stack |
| `IOSCSIArchitectureModelFamily.kext` | ✅ | SCSI/SATA |
| `IOATAFamily.kext` | — | ATA (optical drive) |
| `IOHIDFamily.kext` | ✅ | USB HID (keyboard/mouse) |
| `IOUSBHostFamily.kext` | — | USB host controller |
| `IOThunderboltFamily.kext` | — | Thunderbolt (TB bridge) |

**Notable absence:** `AppleHDA.kext` — renamed/merged in modern macOS.
OCLP restores audio via `Universal-Binaries.dmg` payloads, not the KDK.

---

## OCLP Source Reference

`opencore_legacy_patcher/support/kdk_handler.py`
- `KDK_INSTALL_PATH = "/Library/Developer/KDKs"`
- `KDK_API_LINK = "https://dortania.github.io/KdkSupportPkg/manifest.json"`
- `check_backups_only=True` → saves .pkg, does not extract .kdk
- Fallback logic: exact build match → closest version match → installed KDK → error

---

*Analysed: 2026-04-08 Session 13 — Claude (Cowork mode)*

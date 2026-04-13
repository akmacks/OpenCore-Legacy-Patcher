# Ethernet + Initial Keyboard/USB Recovery (macOS_next fork)

This guide is intended for **fork maintainers and testers** validating OCLP 3.0.0+ behavior on `macOS_next`.

It focuses on two common bring-up failures:

1. Wired Ethernet does not appear or does not pass traffic
2. Keyboard/mouse/trackpad fail early (installer / first boot / post-update)

---

## 1) What OCLP currently does for wired networking

Wired networking patch selection happens in `opencore_legacy_patcher/efi_builder/networking/wired.py`.

High-level behavior:

- If Ethernet controllers are detected on the host, OCLP uses on-model probing (`_on_model`).
- Otherwise it falls back to SMBIOS assumptions (`_prebuilt_assumption`).
- It always enables:
  - `ECM-Override.kext` on models whose max native OS is older than Sonoma (for USB ECM dongle compatibility with downgraded networking stack)
  - `CatalinaIntelI210Ethernet.kext` in the same condition (with `MinKernel` tuning for Ivy Bridge+)

Implication for fork maintainers:

- Your fork is optimized for Apple-supported wired chipsets and known legacy replacements.
- If your target system uses a **non-Apple NIC** (for example common PCIe Realtek/Intel desktop cards), detection may work as generic Ethernet class but no matching legacy kext is injected by this path.

### Quick checks

Run on the target Mac:

```bash
system_profiler SPEthernetDataType
networksetup -listallhardwareports
ifconfig -a
```

Then verify what OpenCore actually injected:

```bash
kextstat | egrep -i "BCM5701|I210|8254X|82574|Yukon|nForce|ECM"
```

If the NIC is absent in `SPEthernetDataType`, collect PCI identity:

```bash
ioreg -l | grep -i -E "vendor-id|device-id|ethernet" -n
```

Use that vendor/device ID to decide whether to:

- Add mapping to an existing OCLP-supported Apple driver path, or
- Introduce a new optional third-party kext flow in your fork (for example IntelMausi/RealtekRTL8111), with explicit model guards and version pinning.

---

## 2) Why initial keyboard/USB failures happen

For Ventura and newer, USB 1.1 (UHCI/OHCI) is removed from base OS.

For affected legacy Macs, keyboard/trackpad/Bluetooth can disappear during installer or immediately after updates until root patches are re-applied.

Known workaround path:

- Insert a USB 2.0/3.0 hub between Mac and input devices (forces EHCI/XHCI path)
- Complete install/boot
- Run root patching
- Reboot

Reference model families are listed in `docs/TROUBLESHOOT-HARDWARE.md` under keyboard/mouse/trackpad failures.

---

## 3) Fast triage flow for your macOS_next branch

1. **Confirm OpenCore source**
   - Ensure system is booting from the same OCLP build you just produced.

2. **Differentiate detection vs driver failure**
   - Detection failure: NIC missing from `system_profiler` and I/O Registry class tree
   - Driver failure: NIC appears, but no link/IP/traffic

3. **Check currently loaded Ethernet stack**
   - `kextstat` output for OCLP legacy ethernet kexts
   - `log show --last boot --predicate 'process == "kernel"' | grep -i -E "ethernet|ioskywalk|i210|bcm|yukon|nforce"`

4. **For keyboard/USB failure**
   - Boot with external USB hub + wired USB keyboard/mouse
   - Re-run OCLP post-install root patches
   - Reboot and retest internal keyboard/trackpad

5. **Capture a minimal bug bundle for regression tracking**

```bash
mkdir -p ~/Desktop/oclp-net-usb-debug
system_profiler SPEthernetDataType SPUSBDataType SPHardwareDataType > ~/Desktop/oclp-net-usb-debug/system_profiler.txt
nvram -p > ~/Desktop/oclp-net-usb-debug/nvram.txt
kextstat > ~/Desktop/oclp-net-usb-debug/kextstat.txt
ifconfig -a > ~/Desktop/oclp-net-usb-debug/ifconfig.txt
log show --last boot --style syslog > ~/Desktop/oclp-net-usb-debug/log-last-boot.txt
```

Archive and attach this set to your fork issue tracker.

---

## 4) Fork-level hardening ideas

If you plan to support more Ethernet hardware in this fork:

- Add a clear allowlist policy:
  - Apple-native legacy replacements (default)
  - Optional third-party NIC kexts behind explicit toggle
- Keep kext versions pinned in constants and payloads
- Add per-kext `MinKernel` / `MaxKernel` bounds to reduce breakage on `macOS_next` seeds
- Add CI sanity checks that parse generated `config.plist` and verify expected enabled NIC kexts for fixture SMBIOS models

For USB/input reliability on early boot:

- Keep user-facing installer/update messaging explicit whenever legacy USB 1.1 dependency is detected
- Offer a one-click “post-update input recovery” action that runs root patching CLI path and schedules reboot


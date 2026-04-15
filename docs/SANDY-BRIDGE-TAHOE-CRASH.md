# Sandy Bridge GPU Patchset — Fatal on Tahoe 26.x

**Status:** DO NOT APPLY on Darwin 25+ (Tahoe / macOS 26.x)
**Affected hardware:** Any Mac with Intel HD 3000 GPU (Sandy Bridge) — including Macmini5,x
**Discovered:** 2026-04-15 on Macmini5,3 running Tahoe 26.4 (25E246)

---

## Crash Signature

```
panic(cpu 0): Kernel trap at 0xffffff8028416de8, type=14=page fault
Fault CR2: 0x0000000000560088  (near-null pointer dereference)
Panicked task: mediaanalysisd

Backtrace:
  OSMetaClassD2Ev + 0x18
  com.apple.driver.AppleIntelHD3000Graphics :: IOGen575Shared::new_iosurface_texture + 0x3a
  com.apple.driver.AppleIntelHD3000Graphics :: IOGen575DVDContext::new_texture + 0xf0
  shim_io_connect_method_structureI_structureO + 0x16c
  IOUserClient::externalMethod + 0x356
```

## Root Cause

`AppleIntelHD3000Graphics.kext` (OCLP Sandy Bridge patchset) was compiled/patched
against the 26.3.1 KDK. In Tahoe 26.4 the IOSurface/Metal ABI changed, causing the
OSMetaClass vtable layout to be incompatible with the updated Darwin 25 kernel.

`mediaanalysisd` (Apple's media analysis daemon) calls into the GPU driver to create
an IOSurface texture within ~2 minutes of every boot. The OSMetaClass dispatch
dereferences a NULL or freed pointer at offset 0x560088, causing the kernel panic.

## Affected Kexts (OCLP Sandy Bridge patchset)

- `AppleIntelHD3000Graphics.kext`
- `AppleIntelHD3000GraphicsGA.plugin`
- `AppleIntelHD3000GraphicsGLDriver.bundle`
- `AppleIntelHD3000GraphicsVADriver.bundle`
- `AppleIntelSNBGraphicsFB.kext`
- `AppleIntelSNBVA.bundle`

## Code Fix

`intel_sandy_bridge.py` — `patches()` now returns `{}` on Darwin 25+:

```python
if self._xnu_major >= os_data.tahoe.value:
    # Sandy Bridge GPU kexts crash on Tahoe 26.x — run headless
    return {}
```

## Manual Recovery (TDM)

If the patchset was already applied:

1. Boot into TDM, mount the mini's disk on MBP
2. `sudo diskutil mount disk10s4` (System volume)
3. `sudo mount -uw "/Volumes/Server HD"`
4. `sudo mv "/Volumes/Server HD/System/Library/Extensions/AppleIntelHD3000Graphics.kext" /path/to/backup/`
5. Repeat for all 6 kexts listed above
6. `sudo kmutil install --volume-root "/Volumes/Server HD" --update-all --variant-suffix release --allow-missing-kdk`
7. `sudo diskutil apfs updatePreboot disk10s4`
8. Unmount + reboot

## Notes for Future Tahoe Compatibility

- The Macmini5,3 operates as a headless server — GPU acceleration not required
- `-igfxvesa` EFI boot arg added as belt-and-suspenders disable
- A Tahoe-native Sandy Bridge patchset would require new kexts compiled against the Darwin 25 ABI — out of scope for this project
- `mediaanalysisd` cannot be easily disabled as it is a system-protected daemon on Tahoe

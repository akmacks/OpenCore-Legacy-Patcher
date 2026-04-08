# Bridge Restore — Changelog

All notable changes to `app_macOS-Intel_BridgeRestore` are documented here.  
Format: [version] — date — build

---

## [1.0.6] — 2026-04-07 — Build 26A06

### Added
- **`tool_macOS-Universal_tb-reset`** — new standalone IOKit tool (separate project at
  `~/dev/projects/tools/tool_macOS-Universal_tb-reset`). Universal binary (x86_64 + arm64).
  Uses `IOServiceRequestProbe()` on the `IOPCIDevice NHI0` (PCIe parent of the TB controller)
  to trigger a true physical L1 Thunderbolt reset from user space — the only method that works
  around the `kext is in use or retained (-603946984)` error blocking `kextunload`.
- **`scripts/tb-reset-trigger.sh`** — Bridge Restore module wrapper for the compiled tool.
  Auto-detects binary location, falls back to `ifconfig` port bounce if not compiled.
- **`tools/tb-reset/`** — compiled binary deployment directory inside Bridge Restore project.
  Contains the pre-built universal binary and `README.md`.
- **Method 6** in `_sever_tb_gateway()` — calls `tb-reset-trigger.sh` as the final and most
  powerful severance method after Methods 1–5 are exhausted.
- **`tb-reset.xcodeproj`** — Xcode project generated via `xcodegen` (project.yml spec).
  Ready to open, build, and archive from Xcode directly.

### Changed
- `bridge-restore-app.sh`: version bumped to `1.0.6`, build `26A06`.
- `bridge-restore-panel.swift`, `bridge-restore-panel.js`, `bridge-restore-gui.sh`:
  all version strings updated to `v1.0.6 (Build 26A06)`.
- `package.json`: version updated to `1.0.6`.
- `_sever_tb_gateway()` now has 6 methods (was 4; Method 5 NHI kextunload added in this
  session, Method 6 tb-reset IOKit probe added).

### Research findings (documented)
- `kextunload -b com.apple.driver.AppleThunderboltNHI` fails with error `-603946984`
  (`kOSKextReturnInUse`) because the NHI has active `IOService` instances bound to hardware.
  The `0` reference count in `kextstat` only counts kext-to-kext deps, not driver instances.
- On MacBookPro16,1 the actual IOKit class is `AppleThunderboltNHIType3` (not `AppleThunderboltNHI`).
  Tree: `IOPCIDevice NHI0@0` → `AppleThunderboltHAL` → `AppleThunderboltNHIType3`.
- The TB4 adapter is an active retimer maintaining two independent L1 segments. MBP-side
  software resets do not propagate cleanly through the adapter to the mini's Light Ridge TB1.
- No `thunderboltd` user-space daemon on Intel Tahoe (unlike Apple Silicon).
- No `/dev/pci` interface for config-space writes on macOS.

### Fixed
- Build number regression: initial bump used stale `BUILD="26A03"` from script instead of
  actual last-released `26A05`. Corrected to `26A06`.

---

## [1.0.4-alpha] — 2026-04-03 — Build 26A05

### Added
- `status-check.sh` (Phase 1a): 7-check JSON data layer, role-aware via hardware UUID.
- `bridge-restore-panel.swift` (Phase 1b): persistent Swift `NSPanel` dashboard compiled
  to binary at `~/Library/Application Support/BridgeRestore/bridge-restore-panel`.
- `bridge-restore-gui.sh`: launcher accepting `--restart` flag to bring existing panel to front.
- `health-monitor.sh`: LaunchAgent on both machines (30s interval). Logs CPU spikes,
  memory pressure, WindowServer freeze heuristics, console errors to
  `~/Library/Logs/BridgeRestore/health.log`.
- Console and Health buttons in dashboard.
- `rescue-bot.sh`: priority model list (`gpt-oss:20b` on MBP, `qwen3:4b` on mini).
  Uses `ioreg` for UUID detection (avoids 30s `system_profiler` delay on 2011 hardware).
  macOS-specific system prompt; prohibits Linux commands.
- `tunnel-watchdog-mbp.sh`: MBP-side watchdog LaunchAgent.
- `bridge-drop-monitor.sh` v2: auto-restarts tunnel-pro; deployed to mini.

### Fixed
- Dashboard hanging on "checking..." due to hardcoded MBP scripts path — fixed via
  `BR_SCRIPTS` environment variable in launcher.
- `contentTintColor` unreliable on `isBordered=false` buttons — replaced with
  `attributedTitle` using explicit `NSColor.white`.
- "All systems green" false positive when IS shows grey/N/A on CLIENT — fixed by adding
  `grey_count` to status JSON summary.
- `postinstall` script corrupting mini's `bridge0` IP by loading all LaunchAgents
  regardless of role — fixed with hardware UUID check.
- All `osascript do shell script "..." with administrator privileges` removed.
- L3 diagnostic: ping-only replaced with TCP fallback.
- L5: role-aware HOST/CLIENT session check.

---

## [1.0.2-alpha] — 2026-03-31 — Build 26A03

### Added
- `install-on-mini.sh`: deploys launchd agents (`local.bridge-ip`, `local.tunnel-pro`) to mini.
- `install-on-mbp.sh`: MBP-side persistent launchd setup.
- `machine-identity.sh`: hardware UUID detection module.
- `local.bridge-ip.plist`: keeps bridge0 at 192.168.2.2 on mini.
- `local.tunnel-pro.plist`: auto-restarts tunnel-pro on mini.
- AI fallback: Ollama model picker, structured prompt, numbered fix output.
- Watchdog daemon: TCP-based peer check, smart notification throttle, action menu.
- `BridgeRestore-1.0.2-alpha.pkg` release artifact.

### Fixed
- APIPA configd probe loop: mini's `en0` (BCM5722) self-assigned 169.254.x.x causing
  `configd` to probe every ~30s and disturb `bridge0`. Fix: disable Ethernet service.
- `sshd` startup: `launchctl load` fails with I/O error 5 on Tahoe — replaced with
  `sudo /usr/sbin/sshd` direct invocation.
- `scp` failure through reverse SSH tunnel (no SFTP subsystem) — replaced with
  `cat`-over-SSH pipe.

---

## [1.0.0] — 2026-03-28 — Build 26A00

### Initial release
- Role-aware Thunderbolt Bridge connectivity suite for Intel non-T2 Macs on macOS Tahoe.
- Supports MacBookPro16,1 (gateway, 192.168.2.1) and Macmini5,3 (client, 192.168.2.2).
- `tunnel-mini.sh`: MBP-side setup — bridge0 IP, NAT, ControlMaster.
- `tunnel-pro.sh`: mini-side reverse SSH tunnel `ssh -R 2222:localhost:22`.
- `bridge-restore-app.sh`: OSI L1–L7 diagnostics, 4-method TB severance, restore engine,
  Setup Wizard, Preferences tabs (osascript GUI).
- Hardware UUID identity guard on all scripts.
- NOPASSWD sudo configured on both machines.

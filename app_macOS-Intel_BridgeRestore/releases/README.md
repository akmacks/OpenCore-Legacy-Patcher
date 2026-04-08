# Bridge Restore — Releases

## Latest: v1.1.0 (2026-03-29)

### Download
[BridgeRestore-1.1.0.pkg](BridgeRestore-1.1.0.pkg) — macOS Intel (x86_64), ~44 KB

### Requirements
- **Intel Mac only** (x86_64 — not compatible with Apple Silicon)
- macOS 14.0 Sonoma or later (tested on macOS 26.x Tahoe)
- Thunderbolt 2/3 cable for bridge connection
- Passwordless sudo recommended

### What the installer does

1. **Detects existing installation** — if Bridge Restore is already installed, you are shown the installed version and offered three choices:
   - **Archive & Install** — zips the existing app + scripts into `~/Library/Application Support/BridgeRestore/archives/BridgeRestore-<version>-<timestamp>.zip`, then installs the new version
   - **Install Over Existing** — replaces without archiving
   - **Cancel** — exits with no changes

2. **Installs payload**
   - `/Applications/BridgeRestore.app` — GUI + CLI launcher
   - `/usr/local/bin/bridge-restore` — main CLI command
   - `/usr/local/bin/bridge-restore-gui` — GUI launcher
   - `/usr/local/bin/tunnel-mini` — gateway restore command
   - `/usr/local/bin/tunnel-mini-status` — quick status
   - `/usr/local/share/bridge-restore/scripts/` — all scripts
   - `/usr/local/share/bridge-restore/launchd/` — LaunchAgent plists
   - `/usr/local/share/bridge-restore/man/` — man page + XML reference

3. **Deploys LaunchAgents** to `~/Library/LaunchAgents/`:
   - `local.nat-persist` — restores NAT + bridge0 IP on every login
   - `local.mbp-watchdog` — auto-connects when mini tunnel opens
   - `local.tunnel-pro` — keeps client tunnel alive (mini side)
   - `local.bridge-ip` — keeps bridge0 IP correct (mini side)

4. **Installs man page**: `man bridge-restore`

5. **Offers to add to Dock** — macOS dialog after install completes

### Post-install quick start

```bash
# Launch the GUI
open /Applications/BridgeRestore.app

# Or use the CLI directly
bridge-restore --gui       # GUI dashboard
bridge-restore --status    # quick connection status
bridge-restore --diag      # OSI L1–L7 diagnostics
bridge-restore --help      # full command reference
man bridge-restore         # read the manual
```

### First run
On first launch the **Setup Wizard** runs automatically. It will ask you to confirm:
- Your machine's role (Gateway or Client)
- Bridge IPs for gateway and client
- Watchdog and auto-retry settings

Config is written to `~/.config/bridge-restore/config.json`.

### Rebuilding the package

```bash
cd ~/dev/projects/apps/app_macOS-Intel_BridgeRestore
bash pkg-build/build-pkg.sh
# Output: releases/BridgeRestore-<version>.pkg
```

### Archive location
Previous versions archived by the installer:
```
~/Library/Application Support/BridgeRestore/archives/
```

---

## Release History

| Version | Date       | Notes |
|---------|-----------|-------|
| 1.1.0   | 2026-03-29 | First packaged release. GUI dashboard, mbp-watchdog, nat-persist, full man page, pkg installer with archive/overwrite/Dock prompt. |
| 1.0.0-alpha | 2026-03-28 | Initial bash engine — restore, diagnostics, TB severance, AI fallback, --bughunt |

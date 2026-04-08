# tb-reset — Thunderbolt L1 Physical Reset Tool

**Module of:** `app_macOS-Intel_BridgeRestore`  
**Source project:** `~/dev/projects/tools/tool_macOS-Universal_tb-reset`  
**Binary:** Universal (x86_64 + arm64)  
**Version:** 1.0.0 (Build 26A06)

## What it does

Triggers a true physical Thunderbolt L1 reset via `IOServiceRequestProbe()` on
the `IOPCIDevice` (NHI0) that hosts the Thunderbolt NHI controller chip. This
is the only user-space method that achieves genuine L1 reset — working around
the `kext is in use or retained` error that blocks `kextunload`.

## Usage

```bash
sudo tb-reset                # auto-detect active bridge0 TB port
sudo tb-reset --port en4     # target specific interface
tb-reset --list              # list all detected TB interfaces
tb-reset --dry-run           # show target without resetting
```

## How to rebuild from source

```bash
cd ~/dev/projects/tools/tool_macOS-Universal_tb-reset
make                         # builds universal binary in build/
make install                 # copies to /usr/local/bin/tb-reset
# or open tb-reset.xcodeproj in Xcode and build (⌘B)
```

## Integration

Called from `bridge-restore-app.sh` via `scripts/tb-reset-trigger.sh`
as Method 6 in the `_sever_tb_gateway()` TB severance sequence.
Falls back to `ifconfig` port bounce if binary is not present.

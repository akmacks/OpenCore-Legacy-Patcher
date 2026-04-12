# OpenClaw Handover — OCLP Tahoe Dev
### Session: 2026-04-09 | Build 26C01 | Handing off from Claude Sonnet 4.6 (Cowork)

---

## YOUR ROLE

You are the **Worker**. Claude (Anthropic, via Cowork) is the **Director**.

Your job: read, edit, build, and test code; run diagnostics; manage git; operate IDE tools; report structured results.

**Available models on this machine:**
- Online: `kimi-k2.5:cloud`, `minimax-m2.7:cloud`, `glm-5.1:cloud` via OpenClaw cloud proxy (localhost:18789)
- Offline: `qwen3:4b`, `llama3.2:3b` via Ollama (localhost:11434)
- Claude Code: `claude` CLI available — use for complex reasoning and multi-file edits
- OpenAI Codex: available for code generation tasks
- Xcode 26.4: installed, use for Swift/ObjC/C builds and IOKit tool compilation
- VS Code: installed, use for Python/shell editing and repo navigation
- GitHub Desktop: installed, use for visual diff/commit/push when CLI is inconvenient

---

## MACHINES

| Role    | Model        | Bridge IP   | Hostname               | Username |
|---------|-------------|-------------|------------------------|----------|
| Gateway | MBP 16,1    | 192.168.2.1 | MacBook-Pro-i9         | akmacks  |
| Client  | Macmini5,3  | 192.168.2.2 | Mac-mini-Server-i7     | akmacks  |

You are running **on the Mac mini** (Mac-mini-Server-i7).
Internet via Thunderbolt bridge NAT from MBP (temporary — Ethernet BCM5722 not yet confirmed working on Tahoe 26.4).
Both machines: NOPASSWD sudo via `/etc/sudoers.d/akmacks-nopasswd`.

---

## THE PROJECT

### What it is

**akmacks/OpenCore-Legacy-Patcher** — a fork of Dortania's OCLP adding macOS Tahoe (26.x / XNU 25) support for Sandy Bridge Intel Macs. The primary target is this machine: **Macmini5,3** (Late 2011, Quad-Core i7, 16 GB RAM, Intel HD 3000 GPU).

OCLP works in two stages:
1. **EFI stage**: builds a modified OpenCore bootloader that injects kexts and patches so macOS installs and boots on unsupported hardware.
2. **Root patch stage**: post-boot, overwrites system volume files (kexts, Metal libraries, IOKit drivers) with versions compatible with the old hardware.

This fork extends the upstream to support Tahoe by removing OS version ceilings, adding `os_data.tahoe` throughout, and building/testing the individual hardware patchsets.

### GitHub repos

| Repo | Branch | Purpose |
|------|--------|---------|
| `akmacks/OpenCore-Legacy-Patcher` | `macos-next` | OCLP fork — Tahoe Sandy Bridge support |
| `akmacks/app_macOS-Intel_BridgeRestore` | `main` | Bridge internet-sharing restore app (v1.0.7-beta) |
| `akmacks/tool_macOS-Universal_tb-reset` | `main` | IOKit Thunderbolt bus reset tool |
| `dortania/OpenCore-Legacy-Patcher` | `main` | Upstream (read-only reference) |

---

## LOCAL REPO LOCATIONS (canonical — do not use other copies)

```
~/OpenCore-Legacy-Patcher/                           ← OCLP fork (git → akmacks/OCLP, macos-next)
~/dev/projects/apps/app_macOS-Intel_BridgeRestore/   ← BridgeRestore (git → akmacks/BridgeRestore)
~/dev/projects/tools/tool_macOS-Universal_tb-reset/  ← tb-reset C tool (git → akmacks/tb-reset)
```

**Do not touch:**
- `~/projects/apps/app_macOS-Intel_BridgeRestore/` — stale untracked copy, earmarked for deletion
- `~/dev/projects/apps/app_macOS-Intel_BridgeRestore.bak/` — old backup, earmarked for deletion
- `~/scripts/` — loose untracked script duplicates, earmarked for deletion

---

## COMPONENT STATUS (as of 2026-04-09)

| Priority | Component        | Status | Notes |
|----------|-----------------|--------|-------|
| 1 | Ethernet BCM5722  | ⏳ Verify | Kernel patch in EFI config.plist since Session 4. Verify after 26.4 reboot. |
| 2 | Wi-Fi BCM4331     | ❌ Not patched | Root patches never ran. Bug 2 (missing payloads) blocks this. |
| 3 | Bluetooth BCM2046 | ❌ Not patched | Root patches never ran. |
| 4 | Audio ALC892      | ❌ Not patched | Root patches never ran. AppleHDA absent in Tahoe. |
| 5 | Desktop colour/wallpaper | ❌ Broken | `os_data.tahoe` missing from `legacy_accel_support` (Bug 1). |
| — | GPU (login screen) | ✅ Partial | Session 1 patch applied but broke snapshot seal. |
| — | USB 1.1           | ✅ Fixed | Committed 2026-04-09, pushed to macos-next. |
| — | Boot              | ✅ OK | OC EFI on disk0s1. |
| — | Internet          | ✅ TB bridge | Temporary via MBP NAT. |

---

## CRITICAL CODE BUGS (fix these before running root patches)

### Bug 1 — CRITICAL: `legacy_accel_support` missing `tahoe`
**File:** `opencore_legacy_patcher/constants.py` ~line 248
**Problem:** `os_data.os_data.tahoe` is absent from the `legacy_accel_support` list.
This blocks ALL Sandy Bridge GPU patches on Tahoe (XNU 25). The patcher detects the hardware correctly but skips the patchset entirely.
**Fix:** Add `os_data.os_data.tahoe` to that list — one line change.
**Verify:** After fix, re-run `python3 -m opencore_legacy_patcher` and confirm Sandy Bridge patchset appears in the detected patches list.

### Bug 2 — Wi-Fi payload version mismatch
**File:** `opencore_legacy_patcher/sys_patch/patchsets/hardware/networking/legacy_wireless.py`
**Problem:** `_extended_patch()` requests `"12.7.2-25"` payload paths that do not exist in `Universal-Binaries.dmg`. The file contains `"12.7.2-24"` (Sequoia-era) entries.
**Fix:** Change `"12.7.2-25"` references to `"12.7.2-24"` or add a Tahoe-specific condition that caps the Wi-Fi patch at the highest available payload version.
**Verify:** Dry-run root patch — confirm Wi-Fi patch no longer raises a missing-file error.

### Root Patch Skip Issue (consequence of Session 1)
Every boot: `"Detected Snapshot seal not intact, skipping"`.
The Session 1 partial GPU patch broke the snapshot seal. Auto-patcher always skips.
**Fix:** Run patches manually:
```bash
cd ~/OpenCore-Legacy-Patcher
sudo python3 -m opencore_legacy_patcher --patch_sys_vol
```
Or use the OCLP GUI (`/Applications/OpenCore-Patcher.app` → Post-Install Root Patches).
Note: the installed app is v2.4.1 (upstream). To use dev-branch code, run from source as above.

---

## UNCOMMITTED LOCAL CHANGES (do not commit without review)

These two diffs are in `~/OpenCore-Legacy-Patcher/` but intentionally NOT committed to GitHub:

**1. `opencore_legacy_patcher/support/subprocess_wrapper.py`**
DEV HACK — replaces privileged helper with `/usr/bin/sudo` directly.
Needed to run the patcher on this dev machine without building the helper tool.
DO NOT commit to `macos-next` — it would break the app for all users.
Keep as a local working change.

**2. `opencore_legacy_patcher/sys_patch/sys_patch.py`**
DEV WORKAROUND — converts hard crash on missing payload files to a logged warning + skip.
Allows the patcher to continue even when `payloads/` is incomplete.
Useful here. DO NOT commit without wrapping in a `DEBUG` flag or similar guard.
Keep as a local working change.

---

## DEVELOPMENT TOOLS — HOW TO USE THEM ON THIS PROJECT

### VS Code
Open the OCLP repo:
```bash
code ~/OpenCore-Legacy-Patcher
```
Recommended extensions already installed: Python, GitLens, Shell Script.
Use for: editing `constants.py`, `legacy_wireless.py`, patchset Python files, shell scripts.

### Xcode 26.4
Use for: building `tool_macOS-Universal_tb-reset` (C/IOKit), any Swift tooling.
Project file:
```
~/dev/projects/tools/tool_macOS-Universal_tb-reset/tb-reset.xcodeproj
```
Build target: `tb-reset` (Universal binary, macOS 12+).
After build: copy binary to `~/dev/projects/apps/app_macOS-Intel_BridgeRestore/tools/tb-reset/tb-reset`.

### Claude Code (`claude` CLI)
Use for: complex multi-file refactors, understanding patchset logic, writing commit messages.
Run from the repo root for best context:
```bash
cd ~/OpenCore-Legacy-Patcher && claude
```
Context it already knows: Tahoe support work, the two dev-only uncommitted diffs, component status above.

### OpenAI Codex
Use for: targeted code generation — e.g. "write a Tahoe-aware payload version resolver for legacy_wireless.py".

### GitHub Desktop
Use for: visual diff review before committing; cherry-picking; resolving merge conflicts with upstream Dortania.
Repos registered: OpenCore-Legacy-Patcher (macos-next), app_macOS-Intel_BridgeRestore (main), tool_macOS-Universal_tb-reset (main).

### Git workflow
```bash
cd ~/OpenCore-Legacy-Patcher
git add <specific files>       # never git add -A (risk of committing payloads/, binaries)
git commit -m "fix(component): description"
git push origin macos-next
```

---

## RECOMMENDED NEXT ACTIONS (in priority order)

1. **Fix Bug 1** (`constants.py` — add `os_data.tahoe` to `legacy_accel_support`). One line. Commit and push.

2. **Fix Bug 2** (`legacy_wireless.py` — fix `"12.7.2-25"` → `"12.7.2-24"` payload paths). Commit and push.

3. **Run manual root patches** with dev-branch code:
   ```bash
   cd ~/OpenCore-Legacy-Patcher && sudo python3 -m opencore_legacy_patcher --patch_sys_vol
   ```
   Expected: Wi-Fi, BT, Audio, Sandy Bridge GL all applied. Reboot. Verify each component.

4. **Verify Ethernet** — after reboot, check if `ifconfig en0` has a valid IP. If BCM5722 kernel patch worked, the TB bridge NAT can be decommissioned.

5. **Clean up stale copies** (when convenient):
   - `rm -rf ~/projects/apps/app_macOS-Intel_BridgeRestore/`
   - `rm -rf ~/dev/projects/apps/app_macOS-Intel_BridgeRestore.bak/`
   - `rm -rf ~/scripts/` (check for anything unique first, especially `bridge-restore.sh`)

---

## KEY FILES REFERENCE

```
~/OpenCore-Legacy-Patcher/
├── opencore_legacy_patcher/
│   ├── constants.py                              ← Bug 1 fix here (legacy_accel_support)
│   ├── support/subprocess_wrapper.py             ← DEV HACK (local only, do not commit)
│   └── sys_patch/
│       ├── sys_patch.py                          ← DEV WORKAROUND (local only, do not commit)
│       └── patchsets/
│           ├── detect.py                         ← OS ceiling (max_os = tahoe ✅)
│           └── hardware/
│               ├── networking/
│               │   └── legacy_wireless.py        ← Bug 2 fix here (payload version)
│               ├── graphics/
│               │   └── intel_sandy_bridge.py     ← Sandy Bridge GPU patchset
│               └── misc/
│                   ├── usb11.py                  ← FIXED 2026-04-09 (Macmini5,x added)
│                   └── modern_audio.py           ← Tahoe audio (needs testing)
├── docs/
│   ├── TAHOE-DEV-LOG.md                          ← Full session history
│   ├── KDK-FORENSIC.md                           ← KDK/MetallibSupportPkg forensic notes
│   └── forensic/MetallibSupportPkg/MANIFEST.md  ← 150-entry SHA256 manifest
├── PROJECT-PLAN.md                               ← Phase plan and priorities
└── SESSION-HANDOFF.md                            ← Last session handoff state

/Library/Application Support/Dortania/
├── MetallibSupportPkg/15.4-24E248/               ← Pre-fetched metallibs (183 MB)
└── OpenCore-Patcher.app/                         ← OCLP v2.4.1 support app

/Volumes/EFI/EFI/OC/config.plist                  ← EFI config (BCM5722 kernel patch active)
                                                    Mount: diskutil mount disk0s1
~/Library/Logs/Dortania/                           ← OCLP session logs (10 recent)
```

---

## TAHOE-SPECIFIC FACTS (hard-won, do not forget)

1. **XNU version for Tahoe is 25**, not 26. Apple's versioning is confusing — macOS 26 runs XNU 25. Code that checks kernel version must use `25`, not `26`.

2. **Snapshot seal**: Once broken by any root patch, `csrutil authenticated-root status` will show "disabled" and the auto-patcher always skips. Always use `--patch_sys_vol` flag for manual runs.

3. **MetallibSupportPkg 15.4-24E248** was pre-fetched for Sequoia 15.4. It contains Sequoia metallibs (build tag `24E248`), not Tahoe ones. The manifest gap analysis (committed Session 13) shows what's missing for full Tahoe GL support. Do not assume these metallibs are complete for Tahoe.

4. **`payloads/` is gitignored** and not present in the local clone. The patcher fetches them at runtime from `Universal-Binaries.dmg` (local: `~/OpenCore-Legacy-Patcher/Universal-Binaries-1.9.6.dmg`). If you see "file not found" errors during a root patch run, the local DEV WORKAROUND in `sys_patch.py` will log and skip instead of crashing.

5. **Ethernet connection**: This machine currently has no direct internet access. All git push/pull, pip install, and web access routes through the Thunderbolt bridge (192.168.2.1). If the bridge drops, use `tunnel-pro` to restore:
   ```bash
   /usr/local/bin/tunnel-pro
   ```

---

## OPENCLAW SYSTEM PROMPT ADDENDUM

When managing this project via IDE tools, apply these rules:

- **Xcode builds**: always target Universal (arm64 + x86_64) for tools, but test on x86_64 here.
- **Python**: use system Python 3 (`/usr/bin/python3`). Do not create venvs inside the OCLP repo.
- **git**: never `git add -A` in the OCLP repo — `payloads/`, `Build-Folder/`, `Universal-Binaries*.dmg`, and `wheels/` are gitignored for good reason but `git add -A` risks staging large binaries if .gitignore has a gap.
- **Commits**: follow `type(scope): description` format matching existing repo history.
- **Never commit** `subprocess_wrapper.py` or `sys_patch.py` changes to macos-next without explicit instruction.
- **Claude Code context**: when invoking `claude` in the OCLP repo, the CLAUDE.md (if present) and PROJECT-PLAN.md give it enough context. Feed it this handover doc for full state.
- **MBP access**: SSH via `ssh akmacks@192.168.2.1`. `gh` CLI is at `/usr/local/bin/gh` (not in default SSH PATH — use full path). MBP has the BridgeRestore canonical repo and tb-reset Xcode project.

# OCLP 3.0.0-alpha — Session Handoff

For: OpenClaw / Claude Code / Codex / next Claude session

Updated: 2026-05-03 15:55 AEST | Session 32 close

Branch: macos-next | Last commit: see git log

Full coordination: docs/AGENT-COORDINATION.md

Status feed: docs/STATUS-FEED.md

---

## QUICK START FOR NEW AGENT

```bash
# Boot mini normally (if not already booted)
# Expected: Should complete boot with conservative AMFI settings

# Once booted, connect via ONE of:
ssh akmacks@100.86.233.5              # Tailscale
ssh akmacks@192.168.2.2                # TB bridge
ssh -p 2222 akmacks@localhost          # Reverse tunnel

# Verify identity FIRST (mandatory)
system_profiler SPHardwareDataType | grep "Hardware UUID"
# Mini UUID: 575B0D7C-1560-502B-A87E-39C5E04C4891

# Check system state
nvram boot-args                        # should NOT show amfi_get_out_of_my_way
kextstat | grep -iE "5701|BCM|ethernet"
ifconfig en0 2>/dev/null || echo "en0 absent — expected before patching"
```

---

## ⚡ IMMEDIATE NEXT ACTION (Session 32 left off here)

Mac mini was ejected from TDM with conservative boot-args applied (AMFI bypass removed). Next boot should complete successfully.

**1. Boot the Mac mini normally**

Expected outcomes:
- ✅ Boot completes without hanging
- ✅ Color desktop with GPU acceleration (Sandy Bridge patches intact from snapshot)
- ✅ USB keyboard/mouse working
- ❌ No Ethernet (BCM5722 kext not loaded — this is expected)

**2. Establish SSH connection** (try methods in order listed above)

**3. Mount root volume for patching:**

```bash
sudo mount -o nobrowse -t apfs /dev/disk2s4 /System/Volumes/Update/mnt1
```

**4. Run OCLP 3.0.0 patches from source:**

```bash
cd /Users/akmacks/Documents/GitHub/OpenCore-Legacy-Patcher
sudo /usr/local/bin/python3.14 OpenCore-Patcher-GUI.command --patch_sys_vol --auto_patch 2>&1 | tee /tmp/oclp-session33-patch.log
```

**5. After successful patch → reboot and verify:**

```bash
kextstat | grep -i "5701"                # expect: AppleBCM5701Ethernet
ifconfig en0                              # expect: MAC 3c:07:54:10:9e:a4
networksetup -getinfo "Ethernet"         # expect: DHCP from router
ping -c 3 -I en0 8.8.8.8                # expect: <50ms, 0% loss
```

---

## CURRENT STATE SNAPSHOT

| Component | Status | Notes |
|-----------|--------|-------|
| macOS Tahoe 26.4 (25E246) | ✅ Should boot | Conservative AMFI settings applied |
| NVRAM boot-args | ✅ Fixed | REMOVED `amfi_get_out_of_my_way=0x7ff` (was causing panic) |
| NVRAM CSR | ✅ Fixed | `csr-active-config=0x0A03` from Session 31 |
| Ethernet (BCM5722/en0) | 🟡 Pending patch | Will load after OCLP root patches run |
| GPU / Desktop | ✅ Working | Sandy Bridge patches in snapshot |
| USB HID | ✅ Working | USB 1.1 patches applied |
| SSH tunnel | ❓ Unknown | Depends on successful boot |
| Tailscale | ❓ Unknown | Was 100.86.233.5 in Session 31 |
| Audio (ALC892) | 🟡 Pending patch | modern_audio.py fix applied (10.13.6 path) |
| Wi-Fi | ❓ Unknown | Not investigated |
| OCLP 3.0.0 from source | ✅ Ready | PHT bypass established, wx available |
| APFS snapshot | ✅ Clean | Booting from system update snapshot |

---

## KEY SESSION 32 CHANGES

### OC config.plist (on EFI disk0s1)

**CRITICAL CHANGE:**
- **Removed** `amfi_get_out_of_my_way=0x7ff` from boot-args entirely
- **Reason:** Was causing kernel panic/hang during boot on XNU 25
- **New boot-args:** `keepsyms=1 debug=0x100 -lilubetaall ipc_control_port_options=0 -nokcmismatchpanic -igfxvesa`
- **Backup:** `/Volumes/EFI/EFI/OC/config.plist.bak-before-conservative-boot`

### New OCLP Patching Strategy (Two-Step Approach)

**OLD (Failed):** Add AMFI bypass to boot-args → boot fails with panic

**NEW (Correct):**
1. Boot with NO AMFI bypass → system boots cleanly
2. Add AMFI bypass ONLY during OCLP patch execution
3. Result: Reliable boot + patches can be applied when needed

### Project Session Manager Skill Created

- **Version:** 1.0.0 Build 1
- **Location (Claude):** `/mnt/skills/user/project-session-manager/SKILL.md`
- **Location (Mac):** `~/dev/projects/skills/project-session-manager-SKILL.md`
- **Purpose:** Automated session logging and AI agent coordination
- **Status:** ✅ Active and operational

---

## CRITICAL ENVIRONMENT FACTS

| Item | Value |
|------|-------|
| Mini UUID | `575B0D7C-1560-502B-A87E-39C5E04C4891` |
| Mini en0 MAC | `3c:07:54:10:9e:a4` (BCM5722 — not yet active) |
| Mini en2 MAC | `82:0c:4d:eb:46:81` (TB bridge) |
| OS disk | disk2s4 |
| OC EFI disk | disk0s1 |
| EFI backup (Session 32) | `/Volumes/EFI/EFI/OC/config.plist.bak-before-conservative-boot` |
| EFI backup (Session 31) | `/Volumes/EFI/EFI/OC/config.plist.bak-20260425-181452` |
| python3.14 | `/usr/local/bin/python3.14` (wx present) |
| KDK | `KDK_26.4_25E246.kdk` installed |
| OCLP repo | `/Users/akmacks/Documents/GitHub/OpenCore-Legacy-Patcher/` |
| Universal-Binaries.dmg | in OCLP repo `payloads/` |

---

## ROLLBACK PROCEDURES

### If boot still fails after Session 32 fix

```bash
# Boot mini in TDM (hold T)
# From MBP, mount EFI and restore Session 31 config:
diskutil mount disk8s1
cp /Volumes/EFI/EFI/OC/config.plist.bak-20260425-181452 /Volumes/EFI/EFI/OC/config.plist
diskutil unmount /Volumes/EFI
# Eject mini, boot normally
```

### If patch run breaks boot

```bash
# From Recovery Terminal or working SSH session:
sudo mount -o nobrowse -t apfs /dev/disk2s4 /System/Volumes/Update/mnt1
sudo /usr/sbin/bless --mount /System/Volumes/Update/mnt1 --bootefi --last-sealed-snapshot
sudo reboot
```

### If need to restore fully to Session 31 state

```bash
# From TDM, restore Session 31 EFI config (the one WITH amfi=0x7ff):
cp /Volumes/EFI/EFI/OC/config.plist.bak-20260425-181452 /Volumes/EFI/EFI/OC/config.plist
```

### Emergency: mini unreachable

1. Physical keyboard → check desktop
2. Frozen: hold power 10s, cold boot
3. Boot loop: hold Option → select macOS volume directly (bypasses OC)
4. TDM: hold T → Thunderbolt to MBP → repair EFI

---

## RULES FOR ALL AGENTS

- **Verify mini UUID before any command:** `575B0D7C-1560-502B-A87E-39C5E04C4891`
- **Never run Ollama inference on the mini** — 2011 hardware freezes
- **Never kill the Ollama process** — only kill rescue-bot/curl
- **Never use scp** — use rsync (`rsync -e ssh`)
- **Never increment version numbers** — Adam's decision only
- **Never apply Sandy Bridge GPU patches intentionally** — came through incidentally, leave alone
- **Never enable FileVault** on this system
- `diskutil apfs revertSnapshot` **does not exist in Tahoe** — use `bless --last-sealed-snapshot`
- `launchctl load/bootstrap` **broken for system daemons in Tahoe** — use `sudo /usr/sbin/sshd`
- **PlistBuddy must NOT edit config.plist** — use Python plistlib only
- **AMFI bypass should NOT be permanent in boot-args** — apply only during OCLP patching (Session 32 finding)

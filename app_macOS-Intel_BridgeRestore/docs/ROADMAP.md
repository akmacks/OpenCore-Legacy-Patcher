# Bridge Restore App — Roadmap
## app_macOS-Intel_BridgeRestore
## Last updated: 2026-03-29

---

## Phase 1 — bash engine ✅ COMPLETE (v1.0.0-alpha)

- [x] Hardware UUID identity guards on all scripts
- [x] First-launch Setup Wizard (AppleScript GUI)
- [x] Preferences window (Hosts / Diagnostic Layers / Watchdog)
- [x] OSI L1-L7 diagnostic engine, individually toggleable
- [x] IS toggle: defaults write + background dialog auto-clicker
- [x] TB severance: 4 software methods (no cable reseat needed)
- [x] Embedded watchdog: smart notifications, action menu after 10 failures
- [x] pro-watchdog: mini-side connectivity monitor
- [x] Ollama AI fallback: local-first model selection
- [x] launchd plists: bridge-ip keeper, tunnel-pro auto-restart (mini side)
- [x] sudoers NOPASSWD: no osascript password prompts
- [x] Git init + first commit (d284eb7)
- [x] --bughunt mode: mini-side high-frequency monitor + LLM analysis
- [x] TCP bidirectional connectivity check (not ICMP)
- [x] APIPA detection + auto-remediation (en0 probe loop fix)

---

## Phase 2 — MBP-side persistence ✅ COMPLETE (2026-03-29, commit 8dc441e)

- [x] install-on-mbp.sh: MBP-side installer (mirrors install-on-mini.sh)
  - /usr/local/bin wrappers: tunnel-mini, bridge-restore, tunnel-mini-status
  - /etc/pf.anchors/bridge-restore: persistent NAT rules
  - pf.conf anchor hook: survives reboot
- [x] mbp-watchdog.sh: 20s loop daemon
  - port 2222 open check (mini tunnel active)
  - ControlMaster liveness check (ssh -O check macmini)
  - Auto-fires tunnel-mini.sh on CM drop
  - macOS notifications: connect / disconnect / persistent fail (threshold 5)
- [x] local.mbp-watchdog.plist: KeepAlive launchd agent
- [x] local.nat-persist.plist: RunAtLoad agent (ip_forwarding + bridge0 + pf)
- [x] bridge-restore.skill: Claude developer skill for the app

---

## Phase 3 — Reliability fixes 🔴 NEXT

- [ ] TCP-only watchdog check: replace all ping uses with nc -z
- [ ] IS toggle reliability: audit launchctl vs defaults+kickstart path consistently
- [ ] Exponential backoff in mbp-watchdog (cap at 5 min after persistent fail)
- [ ] Watchdog state persistence: survive launchd restart without spurious notifications
- [ ] install-on-mbp.sh: run it! Verify nat-persist and mbp-watchdog load cleanly
- [ ] Confirm BCM5722 Ethernet kernel patch: reboot mini, check kextstat

---

## Phase 4 — Pending OCLP work 🟡

- [ ] Apply OCLP root patches on mini (never applied under Tahoe)
  - This fixes: GPU colour, audio, Wi-Fi, Bluetooth, Ethernet
  - Run on mini: sudo /path/to/OCLP --sys-patch
- [ ] Authenticate Tailscale on mini (needs network first)
- [ ] Verify BCM5722 Ethernet after OCLP root patches
- [ ] Wi-Fi (BCM43xx): IO80211Legacy.kext + AirPortBrcm4360.kext status

---

## Phase 5 — SwiftUI Native App Wrapper

- [ ] BridgeRestoreApp.swift — @main entry, AppDelegate
- [ ] MenuBarController.swift — NSStatusItem, green/yellow/red dot
- [ ] MainView.swift — connection status dashboard
- [ ] DiagnosticsView.swift — L1-L7 live results
- [ ] PreferencesView.swift — Cmd-, native window (3 tabs)
- [ ] WizardView.swift — onboarding flow
- [ ] ShellService.swift — calls bash engine via Process()
- [ ] WatchdogService.swift — background polling actor
- [ ] OllamaService.swift — AI fallback + bug hunt queries
- [ ] Assets.xcassets — status icons

---

## Phase 6 — Distribution

- [ ] Code signing (Developer ID Application)
- [ ] Notarization via notarytool
- [ ] Sparkle auto-update framework
- [ ] DMG installer

---

## Open Issues

| # | Issue | Priority | Status |
|---|---|---|---|
| 1 | install-on-mbp.sh not yet run | 🔴 High | Needs manual run |
| 2 | OCLP root patches never applied on mini | 🔴 High | Pending reboot |
| 3 | BCM5722 Ethernet: kernel patch applied, not verified | 🟡 Med | Pending reboot |
| 4 | IS toggle flakiness on Tahoe (launchctl path) | 🟡 Med | Workaround active |
| 5 | Tailscale on mini not authenticated | 🟢 Low | Needs network |
| 6 | Wi-Fi (BCM43xx) status unknown | 🟢 Low | After OCLP patches |

---
*Roadmap v2.0 | 2026-03-29 | Next: run install-on-mbp.sh, reboot mini, OCLP root patches*

---

## Phase 2b — Bless Integration (privilege escalation)

Bridge Restore currently relies on `sudo` + `/etc/sudoers.d/akmacks-nopasswd` for
privileged operations (ifconfig, pfctl, networksetup, launchctl).

**Bless** (`tool_macOS-Intel_Bless` — `~/dev/projects/apps/tool_macOS-Intel_Bless/`)
is a companion app providing SMJobBless-based privilege escalation — the proper
macOS-sanctioned approach, without sudo dependency.

### Integration plan
- [ ] BridgeRestoreHelper — SMJobBless privileged helper Xcode target
- [ ] BlessSession protocol — wraps ifconfig, pfctl, networksetup calls
- [ ] Remove sudo dependency from all shell scripts
- [ ] Keychain-backed authorisation persistence
- [ ] Works without sudoers NOPASSWD — correct for any user account

Bless entitlements: `com.apple.security.app-sandbox: false` (required for network ops)
Bundle ID target: `com.akmacks.bridge-restore.helper`


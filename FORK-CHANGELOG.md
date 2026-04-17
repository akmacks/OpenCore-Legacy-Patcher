# OpenCore Legacy Patcher — macos-next Fork Changelog

> **Development fork** by @akmacks  
> **Branch:** `macos-next`  
> **Target Hardware:** Macmini5,3 (Sandy Bridge, BCM4331/BCM57765/BCM2046/ALC892)  
> **Target OS:** macOS Tahoe 26.x (Darwin 25+)  
> **Status:** ⚠️ **Not for general use — development only**

---

## Quick Links

| Resource | Location |
|----------|----------|
| **Session Logs** | `docs/APP-DEV-LOGS/` — Detailed per-session notes (Session 17–27+) |
| **Status Feed** | `docs/STATUS-FEED.md` — Condensed status updates |
| **Upstream Changelog** | `CHANGELOG.md` — Official OCLP releases (2.x) |
| **Fork Changelog** | `CHANGELOG-FORK.md` — Your complete fork changelog backup |

---

## Versioning

- **Fork Version:** `3.0.0-alpha` (defined in `opencore_legacy_patcher/constants.py`)
- **Upstream Sync:** Merged from `dortania/OpenCore-Legacy-Patcher:main`

## Key Development Areas

1. **Sandy Bridge GPU** — Disabled on Tahoe (crashes), headless mode stable
2. **USB** — EHCI Transaction Translator working; UHCI native fix pending (Session 27)
3. **Ethernet** — BCM57765 kext loads, device enumeration pending
4. **TermEcho** — Human-in-the-loop sudo verification system

---

*See docs/APP-DEV-LOGS/ for detailed session logs.*

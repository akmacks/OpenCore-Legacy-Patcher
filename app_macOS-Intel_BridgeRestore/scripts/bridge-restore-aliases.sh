#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  bridge-restore-aliases.sh                                              ║
# ║  Source this file from ~/.zshrc or ~/.bashrc:                           ║
# ║    source ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/scripts/bridge-restore-aliases.sh
# ╚══════════════════════════════════════════════════════════════════════════╝

# ── Primary alias ─────────────────────────────────────────────────────────────
alias br='bridge-restore'

# ── Status & diagnostics ──────────────────────────────────────────────────────
alias br-status='bridge-restore --status'
alias br-diag='bridge-restore --diag'
alias br-debug='bridge-restore --debug'

# ── Restore actions ───────────────────────────────────────────────────────────
alias br-restore='bridge-restore'
alias br-sever='bridge-restore --sever'
alias br-ai='bridge-restore --ai'
alias br-bughunt='bridge-restore --bughunt'

# ── Setup & config ────────────────────────────────────────────────────────────
alias br-wizard='bridge-restore --wizard'
alias br-prefs='bridge-restore --prefs'

# ── GUI ───────────────────────────────────────────────────────────────────────
alias br-gui='bridge-restore --gui'
alias br-app='open /Applications/BridgeRestore.app'

# ── Watchdog ──────────────────────────────────────────────────────────────────
alias br-watchdog='bridge-restore --watchdog'
alias br-watchdog-start='launchctl load ~/Library/LaunchAgents/local.mbp-watchdog.plist 2>/dev/null && echo "watchdog started"'
alias br-watchdog-stop='launchctl unload ~/Library/LaunchAgents/local.mbp-watchdog.plist 2>/dev/null && echo "watchdog stopped"'

# ── Tunnel helpers ────────────────────────────────────────────────────────────
alias tm='tunnel-mini'
alias tms='tunnel-mini-status'

# ── SSH shortcut (works once ControlMaster is open via tunnel-mini) ───────────
alias ssh-mini='ssh -p 2222 akmacks@localhost'
alias ssh-mini-cmd='ssh -p 2222 -o BatchMode=yes akmacks@localhost'

# ── Log tailing ───────────────────────────────────────────────────────────────
alias br-logs='tail -f ~/Library/Logs/BridgeRestore/tunnel-mini.log ~/Library/Logs/BridgeRestore/bridge-restore-app.log 2>/dev/null'
alias br-logs-all='tail -f ~/Library/Logs/BridgeRestore/tunnel-mini.log ~/Library/Logs/BridgeRestore/bridge-restore-app.log ~/Library/Logs/BridgeRestore/mbp-watchdog.log ~/Library/Logs/BridgeRestore/nat-persist.log 2>/dev/null'
alias br-logs-mini='ssh-mini-cmd "tail -f ~/Library/Logs/BridgeRestore/tunnel-pro.log ~/Library/Logs/BridgeRestore/bridge-ip.log"'

# ── Quick helpers ─────────────────────────────────────────────────────────────
alias br-help='bridge-restore --help'
alias br-version='bridge-restore --version'
alias br-man='man bridge-restore 2>/dev/null || bridge-restore --help'

# Show all br-* aliases
alias br-aliases='alias | grep -E "^br|^tm|^ssh-mini" | sort'

# ── Build pkg ─────────────────────────────────────────────────────────────────
alias br-build='cd ~/dev/projects/apps/app_macOS-Intel_BridgeRestore && bash pkg-build/build-pkg.sh'
alias br-install-pkg='open ~/dev/projects/apps/app_macOS-Intel_BridgeRestore/releases/BridgeRestore-1.0.2-alpha.pkg'

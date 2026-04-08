#!/bin/bash
# bridge-restore-gui.sh — Phase 1b launcher (HOST: MBP)
# VERSION: v1.0.6 (Build 26A06)
# Usage: bridge-restore-gui [--restart]
BINARY="$HOME/Library/Application Support/BridgeRestore/bridge-restore-panel"
SWIFT_SRC="$(dirname "$0")/bridge-restore-panel.swift"

export BR_SCRIPTS="$(dirname "$0")"

# --restart: kill existing panel then relaunch
if [[ "$1" == "--restart" ]]; then
  pkill -f "bridge-restore-panel" 2>/dev/null
  sleep 0.5
fi

# If already running (no --restart), just bring to front
if pgrep -f "bridge-restore-panel" &>/dev/null && [[ "$1" != "--restart" ]]; then
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name contains "bridge-restore-panel") to true' 2>/dev/null
  echo "Panel already running — brought to front"
  exit 0
fi

# Recompile if binary is older than source
if [[ ! -f "$BINARY" ]] || [[ "$SWIFT_SRC" -nt "$BINARY" ]]; then
  echo "Compiling bridge-restore-panel…"
  swiftc "$SWIFT_SRC" -o "$BINARY" 2>&1
fi

exec "$BINARY"

#!/bin/bash
# machine-identity.sh — Shared hardware identity functions
# Source this from other scripts: source ~/scripts/machine-identity.sh
#
# KNOWN MACHINES:
#   MBP  : MacBookPro16,1  | UUID: 4B4DFAAB-B77A-5B8F-BE93-85E6F990529F
#   MINI : Macmini5,3      | UUID: (detected at runtime from mini)

MBP_MODEL="MacBookPro16,1"
MBP_UUID="4B4DFAAB-B77A-5B8F-BE93-85E6F990529F"
MINI_MODEL="Macmini5,3"

# Returns "MBP", "MINI", or "UNKNOWN"
get_machine_role() {
  local model uuid
  model=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Model Identifier/{print $3}')
  uuid=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Hardware UUID/{print $3}')

  if [[ "$model" == "$MBP_MODEL" ]] || [[ "$uuid" == "$MBP_UUID" ]]; then
    echo "MBP"
  elif [[ "$model" == "$MINI_MODEL" ]]; then
    echo "MINI"
  else
    echo "UNKNOWN ($model / $uuid)"
  fi
}

# Call at top of any script that must run on a specific machine.
# Usage: require_machine "MBP" "tunnel-mini"
require_machine() {
  local required="$1"
  local suggestion="$2"
  local actual
  actual=$(get_machine_role)
  if [[ "$actual" != "$required" ]]; then
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  ❌  WRONG MACHINE — REFUSING TO RUN                 ║"
    echo "║                                                      ║"
    printf "║  This script requires: %-29s║\n" "$required"
    printf "║  Currently running on: %-29s║\n" "$actual"
    [[ -n "$suggestion" ]] && printf "║  On this machine use:  %-29s║\n" "$suggestion"
    echo "╚══════════════════════════════════════════════════════╝"
    exit 1
  fi
}

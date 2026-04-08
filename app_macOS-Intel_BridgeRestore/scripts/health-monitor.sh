#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  health-monitor.sh — system health sampler                      ║
# ║  Runs every 30s as a LaunchAgent on both HOST and CLIENT        ║
# ║  Logs runaway processes, memory pressure, and freeze events     ║
# ║  VERSION: v1.0.4-alpha (Build 26A05)                            ║
# ╚══════════════════════════════════════════════════════════════════╝

LOG_DIR="$HOME/Library/Logs/BridgeRestore"
LOG="$LOG_DIR/health.log"
STATE_FILE="/tmp/br-health-state"
CPU_THRESHOLD=80      # % — single process threshold
MEM_THRESHOLD=90      # % memory pressure threshold
SPIKE_COUNT_FILE="/tmp/br-cpu-spike-counts"

mkdir -p "$LOG_DIR"
TS() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(TS)] $*" >> "$LOG"; }

# ── Rotate log if > 2MB ───────────────────────────────────────────
if [[ -f "$LOG" ]] && [[ $(stat -f%z "$LOG" 2>/dev/null) -gt 2097152 ]]; then
  mv "$LOG" "${LOG%.log}-$(date +%Y%m%d).log"
  log "LOG rotated"
fi

# ── CPU check — top 3 processes ───────────────────────────────────
check_cpu() {
  # ps with %cpu, pid, command — skip header
  local top3; top3=$(ps -axro %cpu,pid,comm 2>/dev/null | grep -v '%CPU' | head -3)
  local high_cpu=0

  while IFS= read -r line; do
    local cpu pid cmd
    cpu=$(echo "$line" | awk '{print $1}' | cut -d. -f1)
    pid=$(echo "$line" | awk '{print $2}')
    cmd=$(echo "$line" | awk '{print $3}')
    [[ -z "$cpu" || "$cpu" == "0" ]] && continue

    if [[ "$cpu" -ge "$CPU_THRESHOLD" ]]; then
      high_cpu=1
      # Track consecutive spikes per PID
      local count; count=$(grep "^$pid " "$SPIKE_COUNT_FILE" 2>/dev/null | awk '{print $2}')
      count=$(( ${count:-0} + 1 ))
      # Update spike count file
      grep -v "^$pid " "$SPIKE_COUNT_FILE" 2>/dev/null > /tmp/br-spike-tmp 2>/dev/null
      echo "$pid $count" >> /tmp/br-spike-tmp
      mv /tmp/br-spike-tmp "$SPIKE_COUNT_FILE" 2>/dev/null

      if [[ "$count" -ge 2 ]]; then
        log "HIGH_CPU SPIKE: $cmd (PID $pid) at ${cpu}% — ${count} consecutive samples"
        if [[ "$count" -eq 2 ]]; then
          log "SNAPSHOT: $(ps aux | head -1)"
          ps -axro %cpu,%mem,pid,user,comm 2>/dev/null | grep -v '%CPU' | head -15 >> "$LOG"
        fi
      fi
    fi
  done <<< "$top3"

  # Clear spike counts for PIDs no longer high
  if [[ "$high_cpu" -eq 0 ]] && [[ -f "$SPIKE_COUNT_FILE" ]]; then
    : > "$SPIKE_COUNT_FILE"
  fi
}

# ── Memory pressure ───────────────────────────────────────────────
check_memory() {
  local pressure; pressure=$(memory_pressure 2>/dev/null | grep "System-wide memory free percentage" | awk '{print $NF}' | tr -d '%')
  local vm_stat_free; vm_stat_free=$(vm_stat 2>/dev/null | awk '/Pages free/{gsub(/\./,"",$3); print int($3)*4096/1048576}')
  local level; level=$(memory_pressure 2>/dev/null | grep "The system" | head -1)

  if echo "$level" | grep -qi "critical\|warning"; then
    log "MEM_PRESSURE: $level — free approx ${vm_stat_free}MB"
    log "SNAPSHOT_MEM: $(ps -axro rss,pid,comm 2>/dev/null | sort -rn | head -10)"
  fi
}

# ── Freeze heuristic — detect unresponsive windowserver ──────────
check_freeze() {
  local ws_cpu; ws_cpu=$(ps -axro %cpu,comm 2>/dev/null | grep WindowServer | head -1 | awk '{print $1}' | cut -d. -f1)
  if [[ -n "$ws_cpu" ]] && [[ "$ws_cpu" -ge 90 ]]; then
    log "FREEZE_LIKELY: WindowServer at ${ws_cpu}% CPU — UI may be unresponsive"
    ps -axro %cpu,%mem,pid,comm 2>/dev/null | grep -v '%CPU' | head -20 >> "$LOG"
  fi
}

# ── Console log capture — grab recent errors ──────────────────────
check_console() {
  # Only run every 5 minutes (every 10th sample at 30s interval)
  local sample_count; sample_count=$(cat /tmp/br-health-sample 2>/dev/null || echo 0)
  sample_count=$(( sample_count + 1 ))
  echo "$sample_count" > /tmp/br-health-sample

  if (( sample_count % 10 == 0 )); then
    local errors; errors=$(log show --last 5m \
      --predicate 'messageType == fault OR messageType == error' \
      --style compact 2>/dev/null | grep -v "^Timestamp" | tail -20)
    if [[ -n "$errors" ]]; then
      log "CONSOLE_ERRORS (last 5m):"
      echo "$errors" >> "$LOG"
    fi
  fi
}

# ── Run all checks ────────────────────────────────────────────────
check_cpu
check_memory
check_freeze
check_console

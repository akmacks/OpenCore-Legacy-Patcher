# Troubleshooting Guide
## bridge-restore-project

---

## Known Failure Modes

### 1. ARP Incomplete (most common)
**Symptom:** `arp -n 192.168.2.2` shows `(incomplete)`
**Cause:** TB link has dropped at L2 even though bridge0 shows `status: active`
**Auto-fix in tunnel-mini.sh:** IS toggle → port bounce
**Manual fix:** Toggle Internet Sharing OFF then ON in System Settings → Sharing

### 2. Internet Sharing Fails to Restart
**Symptom:** `pgrep InternetSharing` returns nothing; IS toggle logs "FAILED TO START"
**Cause:** On Tahoe, `launchctl unload/load` doesn't work for IS daemon
**Fix:** Must use System Settings UI — Settings → General → Sharing → Internet Sharing toggle

### 3. Wrong IP on MBP bridge0 (192.168.2.2 instead of 192.168.2.1)
**Cause:** A script ran on wrong machine (tunnel-pro ran on MBP)
**Symptom:** MBP shows bridge0 = 192.168.2.2 in IP Broadcaster menu bar app
**Fix:** `sudo ifconfig bridge0 192.168.2.1 netmask 255.255.255.0` (run on MBP)
**Prevention:** All scripts now have hardware UUID guard at line 1

### 4. NAT Only on en0, Not en43
**Symptom:** Mini has bridge IP but no internet; curl works on MBP but not mini
**Cause:** Default route is en43 (Belkin USB-C LAN) but NAT rule only on en0
**Fix:** NAT must be applied to BOTH en0 and en43 (now fixed in all scripts)

### 5. Tunnel Port 2222 Closed
**Symptom:** `nc -z -G 2 localhost 2222` fails on MBP
**Cause:** Mini has not run tunnel-pro
**Fix:** Run `tunnel-pro` on mini; local.tunnel-pro launchd agent should do this automatically

### 6. Ping Fails But Internet Works
**Symptom:** `ping 8.8.8.8` = 100% loss; Safari works fine
**Cause:** macOS NAT blocks ICMP pass-through — this is NORMAL
**Action:** None needed. Use `curl https://api.ipify.org` to test internet.

### 7. Desktop Commander Confusion
**Symptom:** Commands intended for mini run on MBP (or vice versa)
**Cause:** DC is connected to whichever machine opened the Claude session
**Rule:** When user says "I'm on the mini now", DC is still on MBP unless re-confirmed
**Fix:** Always run hardware UUID check before any network-modifying command

---

## L2/L3 Severance Methods (bridge-restore.sh --sever)

When MBP unreachable, bridge-restore tries 4 escalating methods:

| Method | Command | Effect |
|---|---|---|
| 1 | `ifconfig bridge0 deletem en2; addm en2` | Removes/re-adds bridge member → L2 renegotiation |
| 2 | `networksetup -setnetworkserviceenabled "Thunderbolt Bridge" off/on` | OS-level clean service toggle |
| 3 | `ifconfig en2 down; sleep 10; up` | Physical port bounce |
| 4 | `ifconfig bridge0 down; sleep 3; up` | Full bridge teardown and rebuild |

---

## Internet Sharing Restart (MBP side — must use UI on Tahoe)

```
System Settings → General → Sharing → Internet Sharing → toggle OFF → wait 3s → toggle ON
```

The launchctl approach is unreliable on Tahoe 26.x.
Added to TODO: automate via UI scripting.

---

## osascript Password Prompts — Root Cause and Permanent Fix

### Why it keeps prompting
`do shell script "..." with administrator privileges` uses macOS **Authorization Services**
which ALWAYS shows a password dialog regardless of sudoers configuration.
It is completely separate from sudo and cannot be suppressed via /etc/sudoers.d/.

### Permanent fix — NEVER use "with administrator privileges"

**Pattern 1 — Direct sudo via DC (respects sudoers NOPASSWD):**
```bash
sudo ln -sf /path/to/target /usr/local/bin/command
```

**Pattern 2 — Write temp script, run via Terminal do script:**
```bash
cat > /tmp/fix.sh << 'SCRIPT'
#!/bin/bash
sudo some-privileged-command
SCRIPT
chmod +x /tmp/fix.sh
osascript -e 'tell application "Terminal" to do script "bash /tmp/fix.sh"'
```

### BANNED pattern — always prompts, never use:
```applescript
do shell script "sudo command" with administrator privileges  -- NEVER USE THIS
```

### sudoers file
`/etc/sudoers.d/akmacks-nopasswd` — `akmacks ALL=(ALL) NOPASSWD: ALL`
Recreate if missing:
`sudo sh -c 'echo "akmacks ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/akmacks-nopasswd && chmod 440 /etc/sudoers.d/akmacks-nopasswd'`

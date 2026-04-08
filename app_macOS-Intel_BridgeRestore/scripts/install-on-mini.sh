#!/bin/bash
# install-on-mini.sh — Run on MBP after tunnel is up to deploy to mini
# ~/scripts/install-on-mini.sh
# Deploys ~/scripts/ bridge tools to mini, installs launchd agents, shows popup

MINI_PORT=2222
MINI_USER="akmacks"
MINI_HOME="/Users/akmacks"
SSH="ssh -p $MINI_PORT -o StrictHostKeyChecking=accept-new -o BatchMode=yes $MINI_USER@localhost"
SCP="scp -P $MINI_PORT -o StrictHostKeyChecking=accept-new"
MBP_SCRIPTS="$HOME/scripts"
LOG="$HOME/Library/Logs/BridgeRestore/install-on-mini.log"
mkdir -p "$HOME/logs"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }
ok()  { echo "  ✅ $*"; }
fail(){ echo "  ❌ $*"; }

echo "=== install-on-mini.sh ==="
echo ""

# Check tunnel
if ! nc -z -G 3 localhost $MINI_PORT 2>/dev/null; then
  echo "❌ Tunnel not up. Run 'tunnel-pro' on mini then 'tunnel-mini' here first."
  exit 1
fi
ok "Tunnel up — deploying to mini"

# 1. Create dirs on mini
log "Creating directories on mini..."
$SSH "mkdir -p $MINI_HOME/scripts $MINI_HOME/logs $MINI_HOME/bridge-restore/logs $MINI_HOME/.ssh/cm" \
  && ok "Directories created" || fail "mkdir failed"


# 2. Copy scripts
log "Copying scripts to mini ~/scripts/..."
for f in tunnel-pro.sh bridge-restore.sh reconnect-mini.sh; do
  if [[ -f "$MBP_SCRIPTS/$f" ]]; then
    $SCP "$MBP_SCRIPTS/$f" "$MINI_USER@localhost:$MINI_HOME/scripts/$f" 2>/dev/null \
      && ok "Copied $f" || fail "Failed $f"
  fi
done

# 3. Install tunnel-pro as system command
log "Installing /usr/local/bin/tunnel-pro on mini..."
$SSH "sudo cp $MINI_HOME/scripts/tunnel-pro.sh /usr/local/bin/tunnel-pro && sudo chmod +x /usr/local/bin/tunnel-pro" \
  && ok "/usr/local/bin/tunnel-pro installed" || fail "tunnel-pro install failed"

# 4. Make scripts executable
$SSH "chmod +x $MINI_HOME/scripts/*.sh" && ok "Scripts executable"

# 5. Install bridge-ip keeper launchd
log "Installing local.bridge-ip LaunchAgent on mini..."
$SSH "cat > $MINI_HOME/Library/LaunchAgents/local.bridge-ip.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.bridge-ip</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string><string>-c</string>
    <string>while true; do IP=$(ipconfig getifaddr bridge0 2>/dev/null); if [[ "$IP" != "192.168.2.2" ]]; then /sbin/ifconfig bridge0 192.168.2.2 netmask 255.255.255.0 2>/dev/null &amp;&amp; echo "[$(date +%H:%M:%S)] bridge0 restored" >> /Users/akmacks/Library/Logs/BridgeRestore/bridge-ip.log; fi; sleep 20; done</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/bridge-ip.log</string>
  <key>StandardErrorPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/bridge-ip.log</string>
</dict></plist>
PLIST
$SSH "launchctl unload $MINI_HOME/Library/LaunchAgents/local.bridge-ip.plist 2>/dev/null; launchctl load $MINI_HOME/Library/LaunchAgents/local.bridge-ip.plist" \
  && ok "bridge-ip keeper loaded" || fail "bridge-ip keeper failed"


# 6. Install tunnel-pro keeper launchd
log "Installing local.tunnel-pro LaunchAgent on mini..."
$SSH "cat > $MINI_HOME/Library/LaunchAgents/local.tunnel-pro.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>local.tunnel-pro</string>
  <key>ProgramArguments</key><array>
    <string>/bin/bash</string>
    <string>/usr/local/bin/tunnel-pro</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ThrottleInterval</key><integer>20</integer>
  <key>StandardOutPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/tunnel-pro.log</string>
  <key>StandardErrorPath</key><string>/Users/akmacks/Library/Logs/BridgeRestore/tunnel-pro.log</string>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>/Users/akmacks</string>
  </dict>
</dict></plist>
PLIST
$SSH "launchctl unload $MINI_HOME/Library/LaunchAgents/local.tunnel-pro.plist 2>/dev/null; launchctl load $MINI_HOME/Library/LaunchAgents/local.tunnel-pro.plist" \
  && ok "tunnel-pro keeper loaded" || fail "tunnel-pro keeper failed"

# 7. Add aliases to mini ~/.zshrc
log "Adding shell aliases to mini ~/.zshrc..."
$SSH "grep -q 'bridge-restore aliases' ~/.zshrc 2>/dev/null || cat >> ~/.zshrc << 'ALIASES'

# Bridge-restore / tunnel aliases (installed $(date '+%Y-%m-%d'))
alias tunnel-pro='bash ~/scripts/tunnel-pro.sh'
alias bridge-restore='bash ~/scripts/bridge-restore.sh'
alias bridge-status='bash ~/scripts/bridge-restore.sh --status'
alias bridge-diag='bash ~/scripts/bridge-restore.sh --diag'
alias bridge-ai='bash ~/scripts/bridge-restore.sh --ai'
alias ssh-pro='ssh akmacks@192.168.2.1'
ALIASES
echo 'aliases done'" && ok "Mini aliases added" || fail "Mini aliases failed"

# 8. Pull local LLM if needed
log "Checking Ollama model on mini..."
MODELS=$($SSH "ollama list 2>/dev/null | grep -v NAME" 2>/dev/null)
if echo "$MODELS" | grep -qE "llama3.2:3b|qwen2.5:3b"; then
  ok "Local LLM already present"
else
  warn "No local LLM — pulling llama3.2:3b on mini (background, ~2GB)..."
  $SSH "nohup ollama pull llama3.2:3b >> $MINI_HOME/logs/ollama-pull.log 2>&1 &" 2>/dev/null \
    && ok "llama3.2:3b pull started" || warn "Pull failed — run: ollama pull llama3.2:3b on mini"
fi


echo ""
echo "=== DEPLOYMENT COMPLETE ==="
ok "All scripts deployed to mini ~/scripts/"
ok "LaunchAgents installed and running"
ok "Aliases added to mini ~/.zshrc"
log "=== DEPLOYMENT COMPLETE ==="

# 9. Show COMPLETION POPUP on mini with Finder link
$SSH "osascript << 'APPLESCRIPT'
set scriptsPath to POSIX file \"/Users/akmacks/scripts/\" as alias
display dialog \"✅ BRIDGE-RESTORE DEPLOYED\\n\\nAll tunnel and restore scripts are installed in:\\n~/scripts/\\n\\nCommands available:\\n• tunnel-pro — mini→MBP tunnel\\n• bridge-restore — AI-powered restore\\n• bridge-status — diagnose\\n• bridge-ai — OpenClaw fallback\\n\\nLaunchAgents running:\\n• local.bridge-ip (keeps 192.168.2.2)\\n• local.tunnel-pro (auto-restarts tunnel)\\n\\nClick 'Show in Finder' to open the scripts folder.\" ¬
  buttons {\"OK\", \"Show in Finder\"} default button \"Show in Finder\" ¬
  with title \"Bridge Restore — Deployment Complete\" ¬
  with icon note
set btn to button returned of result
if btn is \"Show in Finder\" then
  tell application \"Finder\"
    activate
    reveal scriptsPath
    open scriptsPath
  end tell
end if
APPLESCRIPT" 2>/dev/null &

echo ""
echo "Popup sent to mini. Deployment done."

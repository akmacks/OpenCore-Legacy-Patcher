#!/bin/bash
# One-shot setup: copies OCLP to Mac Mini and runs root patches
set -e

MINI="akmacks@mac-mini-server-i7.local"
REPO="$HOME/Documents/GitHub/OpenCore-Legacy-Patcher"
DMG="$REPO/Universal-Binaries.dmg"

echo "=== Step 1: Copying OCLP source to Mac Mini ==="
rsync -av --progress \
  --exclude='.git' \
  --exclude='Build-Folder' \
  --exclude='Universal-Binaries.dmg' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  "$REPO/" \
  "$MINI:~/OpenCore-Legacy-Patcher/"

echo ""
echo "=== Step 2: Copying Universal-Binaries.dmg (this will take a few minutes) ==="
rsync -av --progress \
  "$DMG" \
  "$MINI:~/OpenCore-Legacy-Patcher/Universal-Binaries.dmg"

echo ""
echo "=== Step 3: Installing dependencies and running root patcher on Mac Mini ==="
ssh "$MINI" 'cd ~/OpenCore-Legacy-Patcher && pip3 install -r requirements.txt --quiet && echo "Dependencies installed" && sudo python3 OpenCore-Patcher-GUI.command --patch_sys_vol'

echo ""
echo "=== Done ==="

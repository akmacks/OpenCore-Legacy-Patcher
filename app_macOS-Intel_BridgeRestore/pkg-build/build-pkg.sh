#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════════════╗
# ║  build-pkg.sh — Builds BridgeRestore-1.0.4-alpha.pkg                   ║
# ║  Run from repo root: bash pkg-build/build-pkg.sh                        ║
# ║  Output: releases/BridgeRestore-1.0.4-alpha.pkg                         ║
# ╚══════════════════════════════════════════════════════════════════════════╝
set -e

VERSION="1.0.4-alpha"
BUILD="26A05"
IDENTIFIER="com.openclaw.bridge-restore"
APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PKG_BUILD="$APP_DIR/pkg-build"
PAYLOAD="$PKG_BUILD/payload"
SCRIPTS="$PKG_BUILD/scripts"
RESOURCES="$PKG_BUILD/Resources"
RELEASES="$APP_DIR/releases"
WORK="$PKG_BUILD/work"
COMPONENT_PKG="$WORK/BridgeRestore-component.pkg"
FINAL_PKG="$RELEASES/BridgeRestore-$VERSION.pkg"

mkdir -p "$WORK" "$RELEASES"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  Bridge Restore — Package Builder  v$VERSION                         ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# ── Sync payload from latest scripts ─────────────────────────────────────────
echo "[1/5] Syncing payload from scripts/ and launchd/..."
SHARE="$PAYLOAD/usr/local/share/bridge-restore"

rsync -a --delete "$APP_DIR/scripts/" "$SHARE/scripts/"
chmod +x "$SHARE/scripts/"*.sh 2>/dev/null || true

rsync -a --delete "$APP_DIR/launchd/"  "$SHARE/launchd/"
rsync -a "$APP_DIR/man/" "$SHARE/man/"

# Refresh app bundle in payload
# NOTE: skipped if existing bundle is write-protected from prior build
# Run: chmod -R u+w pkg-build/payload/ first if re-bundling needed
if [ -w "$PAYLOAD/Applications/BridgeRestore.app" ]; then
  rm -rf "$PAYLOAD/Applications/BridgeRestore.app"
  cp -R "$APP_DIR/BridgeRestore.app" "$PAYLOAD/Applications/"
  chmod +x "$PAYLOAD/Applications/BridgeRestore.app/Contents/MacOS/BridgeRestore"
  echo "  App bundle refreshed ✓"
else
  echo "  App bundle: using existing (scripts updated via rsync above) ✓"
fi

# Regenerate /usr/local/bin stubs
STUB_SHARE="/usr/local/share/bridge-restore/scripts"
for CMD in bridge-restore bridge-restore-gui tunnel-mini tunnel-mini-status tunnel-watchdog-mbp rescue-bot; do
  case "$CMD" in
    bridge-restore)       TARG="$STUB_SHARE/bridge-restore-app.sh" ;;
    bridge-restore-gui)   TARG="$STUB_SHARE/bridge-restore-gui.sh" ;;
    tunnel-mini)          TARG="$STUB_SHARE/tunnel-mini.sh" ;;
    tunnel-mini-status)   TARG="$STUB_SHARE/bridge-restore-app.sh --status" ;;
    tunnel-watchdog-mbp)  TARG="$STUB_SHARE/tunnel-watchdog-mbp.sh" ;;
    rescue-bot)           TARG="$STUB_SHARE/rescue-bot.sh" ;;
  esac
  printf '#!/bin/bash\nexec bash "%s" "$@"\n' "$TARG" \
    > "$PAYLOAD/usr/local/bin/$CMD"
  chmod +x "$PAYLOAD/usr/local/bin/$CMD"
done
echo "  Payload synced ✓"

# ── Step 2: Build component package ──────────────────────────────────────────
echo "[2/5] Building component package..."
pkgbuild \
  --root       "$PAYLOAD" \
  --scripts    "$SCRIPTS" \
  --identifier "$IDENTIFIER" \
  --version    "$VERSION" \
  --install-location "/" \
  "$COMPONENT_PKG"
echo "  Component pkg: $COMPONENT_PKG ✓"

# ── Step 3: Build product archive (final installer) ──────────────────────────
echo "[3/5] Building product archive..."
productbuild \
  --distribution "$PKG_BUILD/Distribution.xml" \
  --resources    "$RESOURCES" \
  --package-path "$WORK" \
  "$FINAL_PKG"
echo "  Final pkg: $FINAL_PKG ✓"

# ── Step 4: Verify ────────────────────────────────────────────────────────────
echo "[4/5] Verifying..."
PKG_SIZE=$(du -sh "$FINAL_PKG" | cut -f1)
PAYLOAD_COUNT=$(find "$PAYLOAD" -type f | wc -l | tr -d ' ')
echo "  Size:          $PKG_SIZE"
echo "  Payload files: $PAYLOAD_COUNT"
pkgutil --check-signature "$FINAL_PKG" 2>/dev/null || echo "  (unsigned — expected for dev build)"
echo "  Verification done ✓"

# ── Step 5: Write release manifest ───────────────────────────────────────────
echo "[5/5] Writing release manifest..."
MANIFEST="$RELEASES/BridgeRestore-$VERSION.manifest.txt"
cat > "$MANIFEST" << MANIFEST
Bridge Restore v$VERSION — Release Manifest
Built: $(date '+%Y-%m-%d %H:%M:%S')
Package: BridgeRestore-$VERSION.pkg ($PKG_SIZE)
Identifier: $IDENTIFIER

PAYLOAD FILES ($PAYLOAD_COUNT total):
$(find "$PAYLOAD" -type f | sed "s|$PAYLOAD||" | sort)

INSTALLER SCRIPTS:
  preinstall  — version detection, archive/overwrite dialog
  postinstall — script deployment, LaunchAgents, Dock prompt
  preremove   — agent unload, wrapper removal

INSTALL LOCATIONS:
  /Applications/BridgeRestore.app
  /usr/local/bin/bridge-restore
  /usr/local/bin/bridge-restore-gui
  /usr/local/bin/tunnel-mini
  /usr/local/bin/tunnel-mini-status
  /usr/local/share/bridge-restore/scripts/
  /usr/local/share/bridge-restore/launchd/
  /usr/local/share/bridge-restore/man/
  ~/Library/Application Support/BridgeRestore/
  ~/Library/LaunchAgents/local.{nat-persist,mbp-watchdog,tunnel-pro,bridge-ip}.plist
  /etc/pf.anchors/bridge-restore
MANIFEST
echo "  Manifest: $MANIFEST ✓"

echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  ✅  BUILD COMPLETE                                                  ║"
printf "║  Package: %-60s║\n" "releases/BridgeRestore-$VERSION.pkg  ($PKG_SIZE)"
echo "║                                                                      ║"
echo "║  To install:  open releases/BridgeRestore-$VERSION.pkg              ║"
echo "║  To inspect:  pkgutil --expand-full releases/BridgeRestore-$VERSION.pkg /tmp/br-expand ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"

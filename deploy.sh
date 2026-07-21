#!/usr/bin/env bash
# deploy.sh — build Sheen (Godot iOS) and push it to the connected iPhone. No Xcode.
# Usage:  bash ~/Desktop/sheen-godot/deploy.sh    (iPhone plugged in + unlocked)

GODOT="/opt/homebrew/bin/godot"
P="$HOME/Desktop/sheen-godot"
BUNDLE="com.captainnate.sheen"
APP="$P/build/ios/Sheen.xcarchive/Products/Applications/Sheen.app"

echo "▸ Building signed app (Godot export + xcodebuild)…"
"$GODOT" --headless --path "$P" --export-debug "iOS" "$P/build/ios/Sheen.xcodeproj" 2>&1 \
  | grep -iE "ARCHIVE (SUCCEEDED|FAILED)|error:" | tail -4

[ -d "$APP" ] || { echo "✗ Build failed — no .app produced."; exit 1; }

# Auto-detect the connected iPhone (works even if it reconnects with a new session).
DEV=$(xcrun devicectl list devices 2>/dev/null | grep -i iphone | grep -iE "connected|available" \
  | grep -oE "[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}" | head -1)
[ -n "$DEV" ] || { echo "✗ No connected iPhone found — plug it in and unlock it."; exit 1; }

echo "▸ Installing to iPhone…"
xcrun devicectl device install app --device "$DEV" "$APP" >/dev/null 2>&1 \
  || { echo "✗ Install failed — make sure the phone is unlocked."; exit 1; }

echo "▸ Launching…"
xcrun devicectl device process launch --device "$DEV" "$BUNDLE" >/dev/null 2>&1

echo "✓ Sheen updated + running on your iPhone."

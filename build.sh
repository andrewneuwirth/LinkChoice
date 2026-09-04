#!/usr/bin/env bash
# Builds LinkChoice and assembles it into a real .app bundle in /Applications,
# signed and registered with Launch Services.
#
# Signing: uses a "Developer ID Application" identity from your keychain if
# one exists, otherwise falls back to ad-hoc. Ad-hoc is enough to run the app
# locally, but macOS will NOT let an ad-hoc-signed app become the actual
# default browser (Launch Services silently rejects the assignment even via
# CLI tools) — see the README's "Setting it as your default browser" section
# for what a real identity buys you (and notarization on top of that).
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building (release)…"
swift build -c release

APP="/Applications/LinkChoice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp .build/release/LinkChoice "$APP/Contents/MacOS/LinkChoice"
cp Info.plist "$APP/Contents/Info.plist"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | sed -E 's/.*"(.*)"/\1/')
if [ -n "$IDENTITY" ]; then
  echo "==> Signing with Developer ID: $IDENTITY"
  codesign --force --deep --options runtime --sign "$IDENTITY" "$APP"
  echo "    (Not notarized/stapled by this script — see README to do that"
  echo "     once, so macOS actually accepts it as your default browser.)"
else
  echo "==> No Developer ID found — ad-hoc signing (app will run, but"
  echo "    macOS won't let it become your actual default browser)"
  codesign --force --deep --sign - "$APP"
fi

echo "==> Registering with Launch Services…"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP"

# If LinkChoice is already running, `open` just re-activates that old
# process instead of launching the freshly built binary — kill it first so
# every rebuild actually takes effect.
pkill -f "LinkChoice.app/Contents/MacOS/LinkChoice" 2>/dev/null || true
sleep 0.3

echo "==> Launching…"
open "$APP"

cat <<'EOF'

Installed: /Applications/LinkChoice.app

Last step (Apple requires this be done by hand, no app can flip it for you):
  System Settings -> Desktop & Dock -> Default web browser -> LinkChoice

After that, every link you click anywhere shows a browser picker.
EOF

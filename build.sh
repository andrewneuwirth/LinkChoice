#!/usr/bin/env bash
# Builds LinkChoice and assembles it into a real .app bundle in /Applications,
# ad-hoc signed, and registered with Launch Services so it shows up as a
# default-browser candidate immediately (no need to launch it by hand first).
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building (release)…"
swift build -c release

APP="/Applications/LinkChoice.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/LinkChoice "$APP/Contents/MacOS/LinkChoice"
cp Info.plist "$APP/Contents/Info.plist"
echo -n "APPL????" > "$APP/Contents/PkgInfo"

echo "==> Ad-hoc signing…"
codesign --force --deep --sign - "$APP"

echo "==> Registering with Launch Services…"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP"

echo "==> Launching…"
open "$APP"

cat <<'EOF'

Installed: /Applications/LinkChoice.app

Last step (Apple requires this be done by hand, no app can flip it for you):
  System Settings -> Desktop & Dock -> Default web browser -> LinkChoice

After that, every link you click anywhere shows a Chrome/Safari picker.
EOF

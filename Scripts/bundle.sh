#!/bin/bash
# bundle.sh — wrap the SwiftPM release binary into AgentStatus.app and copy
# bundled fonts into Contents/Resources.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$(pwd)

BIN="$ROOT/.build/release/AgentStatus"
if [[ ! -x "$BIN" ]]; then
    echo "binary missing, building..." >&2
    ./Scripts/build.sh
fi

APP_DIR="$ROOT/dist/AgentStatus.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN" "$APP_DIR/Contents/MacOS/AgentStatus"
chmod +x "$APP_DIR/Contents/MacOS/AgentStatus"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Copy any bundled fonts into Resources/ at the root (so Bundle.main.url()
# can find them by filename without a subpath).
if [[ -d "$ROOT/Resources/Fonts" ]]; then
    cp "$ROOT/Resources/Fonts/"*.ttf "$APP_DIR/Contents/Resources/" 2>/dev/null || true
    # Keep the license alongside the font inside the bundle.
    cp "$ROOT/Resources/Fonts/OFL.txt" "$APP_DIR/Contents/Resources/OFL.txt" 2>/dev/null || true
fi

# Clear quarantine so local run doesn't get flagged.
xattr -cr "$APP_DIR" 2>/dev/null || true

# Ad-hoc sign so macOS treats it as a valid executable bundle even without
# a developer certificate.
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "bundled: $APP_DIR"
echo "run with:  open '$APP_DIR'"

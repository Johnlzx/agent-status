#!/bin/bash
# bundle.sh — wrap the SwiftPM release binary into AgentStatus.app.
# Requires build.sh to have run first (or will run it).
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

# Clear quarantine so local run doesn't get flagged.
xattr -cr "$APP_DIR" 2>/dev/null || true

# Ad-hoc sign so macOS treats it as a valid executable bundle even without a dev cert.
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true

echo "bundled: $APP_DIR"
echo "run with:  open '$APP_DIR'"

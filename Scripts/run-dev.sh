#!/bin/bash
# run-dev.sh — iterate fast. Runs the SwiftPM binary directly, no bundle.
# Note: without an .app bundle + LSUIElement, the app will still show a dock
# icon. For a clean menu-bar-only experience use bundle.sh then open the .app.
set -euo pipefail
cd "$(dirname "$0")/.."
exec swift run AgentStatus

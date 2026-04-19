#!/bin/bash
# build.sh — release build of the SwiftPM executable.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
echo "built: $(pwd)/.build/release/AgentStatus"

#!/bin/bash
# install.sh — wire Claude Code hooks to the AgentStatus menu bar app.
#
# Safe: takes a timestamped backup of ~/.claude/settings.json before touching
# it, and appends our hook entries to the existing `hooks` arrays rather than
# overwriting them. Any other hooks you already have (e.g. a `Stop → touch`
# helper) are preserved.
#
# Install target for the notify script: ~/.local/bin/agent-status-notify.sh
# Claude Code events wired: SessionStart, SessionEnd, UserPromptSubmit,
# PreToolUse, PostToolUse, PermissionRequest, Stop.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required. Install with:  brew install jq" >&2
    exit 1
fi

REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
SRC="$REPO_DIR/Hooks/agent-status-notify.sh"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/agent-status-notify.sh"
SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$SRC" ]]; then
    echo "error: notify script not found at $SRC" >&2
    exit 1
fi

mkdir -p "$BIN_DIR"
cp "$SRC" "$BIN"
chmod +x "$BIN"
echo "installed  $BIN"

mkdir -p "$(dirname "$SETTINGS")"
if [[ ! -f "$SETTINGS" ]]; then
    echo '{}' > "$SETTINGS"
fi

TS=$(date +%Y%m%d-%H%M%S)
BACKUP="$SETTINGS.bak-$TS"
cp "$SETTINGS" "$BACKUP"
echo "backed up   $BACKUP"

# List of events and the label (=event name) we want to pass through argv[1].
EVENTS=(SessionStart SessionEnd UserPromptSubmit PreToolUse PostToolUse PermissionRequest Stop)

# Build the jq expression: for each event, append {"hooks":[{type,command,timeout}]}
# but only if an identical command entry isn't already present (idempotent).
TMP=$(mktemp)
cp "$SETTINGS" "$TMP"

for EVENT in "${EVENTS[@]}"; do
    CMD="$BIN $EVENT"
    jq --arg event "$EVENT" --arg cmd "$CMD" '
        .hooks = (.hooks // {}) |
        .hooks[$event] = (.hooks[$event] // []) |
        if any(.hooks[$event][]?; (.hooks // []) | any(.type == "command" and .command == $cmd))
        then .
        else .hooks[$event] += [ { hooks: [ { type: "command", command: $cmd, timeout: 2 } ] } ]
        end
    ' "$TMP" > "$TMP.new"
    mv "$TMP.new" "$TMP"
done

mv "$TMP" "$SETTINGS"
echo "patched     $SETTINGS"

cat <<EOF

Done. Next steps:
  1. Start the menu bar app (e.g.  open ./AgentStatus.app ).
  2. Start any Claude Code session.  A row should appear in the menu.

To uninstall:
  - Restore $BACKUP over $SETTINGS
  - Remove $BIN
EOF

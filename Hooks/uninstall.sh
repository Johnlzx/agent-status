#!/bin/bash
# uninstall.sh — remove AgentStatus hook entries from ~/.claude/settings.json
# and delete the notify script from ~/.local/bin. The most recent .bak file
# is NOT automatically restored; it is shown for manual rollback if desired.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required. Install with:  brew install jq" >&2
    exit 1
fi

BIN="$HOME/.local/bin/agent-status-notify.sh"
SETTINGS="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS" ]]; then
    TS=$(date +%Y%m%d-%H%M%S)
    cp "$SETTINGS" "$SETTINGS.bak-$TS"
    echo "backed up   $SETTINGS.bak-$TS"

    TMP=$(mktemp)
    jq '
        if .hooks == null then .
        else
            .hooks = (
                .hooks
                | to_entries
                | map({
                    key,
                    value: (
                        .value
                        | map(
                            .hooks = ((.hooks // []) | map(select(
                                (.type != "command") or
                                ((.command // "") | test("agent-status-notify\\.sh") | not)
                            )))
                            | select((.hooks | length) > 0)
                        )
                    )
                })
                | map(select((.value | length) > 0))
                | from_entries
            )
        end
    ' "$SETTINGS" > "$TMP"
    mv "$TMP" "$SETTINGS"
    echo "cleaned     $SETTINGS"
fi

if [[ -f "$BIN" ]]; then
    rm -f "$BIN"
    echo "removed     $BIN"
fi

echo "done."

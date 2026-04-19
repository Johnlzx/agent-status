#!/bin/bash
# agent-status-notify.sh
# Called by Claude Code hooks. Reads hook JSON on stdin and forwards to the
# AgentStatus menu bar app via a Unix domain socket. Never blocks Claude:
# exits 0 on every path; fails silently if the socket is absent or the app
# is not running.
#
# Usage:
#   agent-status-notify.sh <event-name>

set +e

SOCK="$HOME/Library/Application Support/AgentStatus/ipc.sock"
EVENT="${1:-unknown}"

# Fast path: app not running → exit 0 without doing anything.
[[ -S "$SOCK" ]] || exit 0

INPUT=$(cat)
[[ -z "$INPUT" ]] && INPUT='{}'

TS=$(date -u +%s)

# Add our event_name + client_ts to the hook JSON. Fall back to a minimal
# hand-built payload if jq is missing or input is malformed.
PAYLOAD=""
if command -v jq >/dev/null 2>&1; then
    PAYLOAD=$(printf '%s' "$INPUT" | jq -c --arg e "$EVENT" --arg ts "$TS" \
        '. + {event_name: $e, client_ts: ($ts|tonumber)}' 2>/dev/null)
fi
if [[ -z "$PAYLOAD" ]]; then
    PAYLOAD=$(printf '{"event_name":"%s","client_ts":%s,"session_id":"%s","cwd":"%s"}' \
        "$EVENT" "$TS" "${CLAUDE_SESSION_ID:-unknown}" "${CLAUDE_PROJECT_DIR:-$PWD}")
fi

# Write one line to the Unix socket via python3 (preinstalled on macOS with
# Command Line Tools). Bounded at 0.5s connect + 0.5s send; always exits 0
# from the caller's perspective.
printf '%s\n' "$PAYLOAD" | SOCK="$SOCK" python3 -c '
import os, socket, sys
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(0.5)
    s.connect(os.environ["SOCK"])
    s.sendall(sys.stdin.buffer.read())
    s.close()
except Exception:
    pass
' 2>/dev/null

exit 0

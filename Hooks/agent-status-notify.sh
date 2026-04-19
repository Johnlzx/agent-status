#!/bin/bash
# agent-status-notify.sh
# Called by Claude Code hooks. Reads hook JSON on stdin and forwards it to the
# AgentStatus menu bar app via a Unix domain socket. Never blocks Claude:
# exits 0 on every path and fails silently if the socket/app are absent.
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

# Find the terminal tty by walking up the process tree. The hook child itself
# usually has no ctty (it's spawned by Claude via a pipe), but an ancestor
# (typically the `claude` process) does. We cache one full `ps` snapshot and
# walk in-process so we don't fork many times per hook.
HOST_TTY=""
HOST_PID=""
PS_SNAP=$(/bin/ps -A -o pid=,ppid=,tty= 2>/dev/null)
if [[ -n "$PS_SNAP" ]]; then
    HOST_TTY=$(echo "$PS_SNAP" | awk -v start="$$" '
        BEGIN { pid = start }
        {
            ppid = ""; tty = ""
            pids[$1] = $2
            ttys[$1] = $3
        }
        END {
            for (i = 0; i < 8; i++) {
                t = ttys[pid]
                if (t != "" && t != "??") { print pid " " t; exit }
                p = pids[pid]
                if (p == "" || p == "0" || p == "1") exit
                pid = p
            }
        }
    ')
    HOST_PID=$(echo "$HOST_TTY" | awk '{print $1}')
    HOST_TTY=$(echo "$HOST_TTY" | awk '{print $2}')
fi

# Add event_name, timestamps, and host info to the hook JSON. Fall back to a
# minimal hand-built payload if jq is missing or input is malformed.
PAYLOAD=""
if command -v jq >/dev/null 2>&1; then
    PAYLOAD=$(printf '%s' "$INPUT" | jq -c \
        --arg e "$EVENT" \
        --arg ts "$TS" \
        --arg tty "$HOST_TTY" \
        --arg pid "$HOST_PID" \
        '. + {event_name: $e, client_ts: ($ts|tonumber),
              host_tty: $tty,
              host_pid: (if ($pid|length) > 0 then ($pid|tonumber) else null end)}' 2>/dev/null)
fi
if [[ -z "$PAYLOAD" ]]; then
    # Hand-built fallback (only event_name is guaranteed populated)
    PAYLOAD=$(printf '{"event_name":"%s","client_ts":%s,"session_id":"%s","cwd":"%s","host_tty":"%s","host_pid":%s}' \
        "$EVENT" "$TS" "${CLAUDE_SESSION_ID:-unknown}" "${CLAUDE_PROJECT_DIR:-$PWD}" \
        "$HOST_TTY" "${HOST_PID:-null}")
fi

# Write one line to the Unix socket via python3 (preinstalled on macOS with
# Command Line Tools). Bounded at 0.5s. Failure is silent by design.
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

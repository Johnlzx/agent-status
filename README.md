# agent-status

A tiny macOS menu bar app that shows the live state of every running **Claude Code** and **Codex** CLI session across your terminals.

Three states per session:

| State | Meaning |
|---|---|
| `IDLE` | Session alive, no turn in progress |
| `RUN`  | Tool call or inference happening |
| `WAIT` | Paused on a permission prompt — **you** need to go look at the terminal |

The menu bar icon aggregates across all sessions:
- **orange** — at least one session is waiting for you
- **green**  — something is running
- **grey**   — everything idle
- **moon**   — no sessions at all

## How it works

```
Claude Code hooks ──JSON──▶  Unix socket  ──▶  SwiftUI MenuBarExtra
                              (SessionStart, PreToolUse, PermissionRequest,
                               PostToolUse, Stop, SessionEnd, UserPromptSubmit)

Codex CLI processes ──ps + lsof (2s poll)──▶  same store
```

Claude Code emits hook events into `~/.claude/settings.json`; the install script wires in a shell script that forwards each event as one line of JSON to `~/Library/Application Support/AgentStatus/ipc.sock`. The menu bar app listens there and maintains an in-memory `session_id → state` map.

Codex has no hooks, so it gets a coarse process-presence signal (labelled `coarse` in the UI). Shows `RUN` while the process exists and disappears when it exits.

## Requirements

- macOS 14 (Sonoma) or newer — uses `MenuBarExtra` and the `@Observable` macro
- Swift 6.0+ toolchain (Command Line Tools is enough; Xcode not required)
- `jq` for the hook installer (`brew install jq`)

## Install

```bash
# 1. Build and bundle
./Scripts/build.sh
./Scripts/bundle.sh

# 2. Launch the menu bar app
open ./dist/AgentStatus.app

# 3. Wire up Claude Code hooks (safely merges into ~/.claude/settings.json; takes a backup first)
./Hooks/install.sh
```

Start a Claude Code or Codex session in any terminal; it should show up in the menu within a second.

## Uninstall

```bash
./Hooks/uninstall.sh        # removes hooks and ~/.local/bin/agent-status-notify.sh
rm -rf ./dist/AgentStatus.app
```

Your previous `~/.claude/settings.json` backups are kept as `~/.claude/settings.json.bak-<timestamp>`.

## Design notes

- **Why hooks?** They're the only documented, reliable signal for "waiting for user confirmation". Accessibility scraping of the terminal is fragile and requires permissions. Process CPU heuristics can't distinguish `WAIT` from `IDLE`.
- **Why Unix socket, not a file?** Events are immediate; no polling; no stale-file edge cases. One connection per hook invocation (open, write one JSON line, close). If the app isn't running, `nc` silently fails — the hook never blocks Claude Code.
- **Session identity**: `session_id` for Claude Code (from the hook JSON), `codex:<pid>` for Codex.
- **Staleness**: a Claude Code session with no event for 30 min is marked `?` (unknown) rather than removed, so it stays visible but visibly stale.

## Hook wiring details

`install.sh` appends — never overwrites — these entries to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart":      [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh SessionStart",      "timeout": 2 }] }],
    "SessionEnd":        [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh SessionEnd",        "timeout": 2 }] }],
    "UserPromptSubmit":  [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh UserPromptSubmit",  "timeout": 2 }] }],
    "PreToolUse":        [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh PreToolUse",        "timeout": 2 }] }],
    "PostToolUse":       [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh PostToolUse",       "timeout": 2 }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh PermissionRequest", "timeout": 2 }] }],
    "Stop":              [{ "hooks": [{ "type": "command", "command": "~/.local/bin/agent-status-notify.sh Stop",              "timeout": 2 }] }]
  }
}
```

Each hook invocation fires a 1-second `nc -U -N`; if the socket is missing the script exits 0 without writing, so your Claude session is never slowed.

## Roadmap

- [ ] Launch at login (`ServiceManagement`)
- [ ] Click session → focus its terminal (needs Accessibility perm)
- [ ] Codex activity heuristic via `~/.codex/history.jsonl` mtime
- [ ] Optional notification sound on `WAIT`
- [ ] Optional icon assets (currently SF Symbols only)

## License

MIT © 2026 Johnlzx

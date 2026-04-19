import Foundation
import AppKit

/// Bring the terminal window/tab that's running a given `Session` to the front.
///
/// Strategy:
///   1. Starting from `session.hostPID`, walk up the process tree looking for
///      an ancestor that is an `NSRunningApplication` with `activationPolicy
///      == .regular`. That process is the terminal emulator (Terminal.app,
///      iTerm2, Ghostty, Warp, Alacritty, Kitty, WezTerm, ...).
///   2. Activate it.
///   3. For terminals with documented AppleScript (Terminal.app, iTerm2),
///      additionally run a script that selects the specific tab whose tty
///      matches `session.hostTTY`. Other terminals: activation only.
enum TerminalFocus {

    static func focus(_ session: Session) {
        guard let pid = session.hostPID, pid > 0 else {
            NSSound.beep()
            return
        }
        let tty = session.hostTTY ?? ""
        Task.detached(priority: .userInitiated) {
            focusSync(hostPID: pid, hostTTY: tty)
        }
    }

    private static func focusSync(hostPID: Int32, hostTTY: String) {
        // Walk the process tree looking for the first ancestor that's a
        // user-facing application. NSRunningApplication(processIdentifier:)
        // returns nil for command-line processes (shells, node, etc.).
        var current = hostPID
        var app: NSRunningApplication?
        for _ in 0..<10 {
            if let candidate = NSRunningApplication(processIdentifier: current),
               candidate.activationPolicy == .regular,
               candidate.bundleIdentifier != nil {
                app = candidate
                break
            }
            guard let parent = Self.parentPID(of: current), parent > 1 else {
                break
            }
            current = parent
        }

        guard let terminalApp = app else {
            // Couldn't identify a GUI terminal app; fall back to a beep so
            // the click isn't completely silent.
            DispatchQueue.main.async { NSSound.beep() }
            return
        }

        terminalApp.activate(options: [.activateAllWindows])

        // Best-effort tab targeting for the two terminals with stable
        // AppleScript dictionaries. Ghostty, Warp, Alacritty, Kitty, WezTerm:
        // activation only (no per-tab addressing available without OS-level
        // accessibility work).
        guard !hostTTY.isEmpty, let bundleID = terminalApp.bundleIdentifier else {
            return
        }
        let normalized = hostTTY.hasPrefix("/dev/") ? hostTTY : "/dev/\(hostTTY)"

        switch bundleID {
        case "com.apple.Terminal":
            runAppleScript(Self.terminalAppScript(tty: normalized))
        case "com.googlecode.iterm2":
            runAppleScript(Self.iterm2Script(tty: normalized))
        default:
            break
        }
    }

    // MARK: - Process tree walk

    private static func parentPID(of pid: Int32) -> Int32? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "ppid=", "-p", "\(pid)"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let out = String(data: data, encoding: .utf8) else { return nil }
        return Int32(out.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - AppleScript helpers

    private static func runAppleScript(_ source: String) {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return }
        _ = script.executeAndReturnError(&error)
        if let error {
            fputs("[focus] AppleScript error: \(error)\n", stderr)
        }
    }

    private static func terminalAppScript(tty: String) -> String {
        // Iterate every window/tab in Terminal.app and select the one whose
        // tty matches. We use `contains` for safety because `tty of tab` can
        // return slightly different formats across macOS versions.
        """
        tell application "Terminal"
            set targetTTY to "\(tty)"
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        try
                            if (tty of t) is targetTTY then
                                set selected of t to true
                                set frontmost of w to true
                                return
                            end if
                        end try
                    end repeat
                end try
            end repeat
        end tell
        """
    }

    private static func iterm2Script(tty: String) -> String {
        """
        tell application "iTerm2"
            set targetTTY to "\(tty)"
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        try
                            repeat with s in sessions of t
                                try
                                    if (tty of s) is targetTTY then
                                        select s
                                        tell w to select t
                                        select w
                                        return
                                    end if
                                end try
                            end repeat
                        end try
                    end repeat
                end try
            end repeat
        end tell
        """
    }
}

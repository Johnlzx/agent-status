import Foundation

enum AgentKind: String, Codable, Sendable, CaseIterable {
    case claudeCode
    case codex

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    var symbolName: String {
        switch self {
        case .claudeCode: return "sparkles.rectangle.stack"
        case .codex: return "terminal"
        }
    }
}

enum AgentState: String, Codable, Sendable {
    case idle
    case running
    case waiting
    case unknown

    var label: String {
        switch self {
        case .idle: return "IDLE"
        case .running: return "RUN"
        case .waiting: return "WAIT"
        case .unknown: return "?"
        }
    }
}

struct Session: Identifiable, Hashable, Sendable {
    let id: String
    let kind: AgentKind
    var cwd: String
    var pid: Int32?
    var state: AgentState
    var lastEventAt: Date
    var lastEventName: String?
    var note: String?

    /// tty name of the first ancestor that has a controlling terminal
    /// (e.g. "ttys003"). Populated for both Claude Code (via hook) and Codex
    /// (via scanner). Nil/empty if we couldn't resolve one.
    var hostTTY: String?
    /// PID of the ancestor process that owns that tty. Used as the starting
    /// point for walking up to find the terminal app (NSRunningApplication).
    var hostPID: Int32?
}

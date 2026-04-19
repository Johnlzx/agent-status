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
}

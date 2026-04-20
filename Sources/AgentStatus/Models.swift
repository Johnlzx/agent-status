import Foundation

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
        case .unknown: return "STALE"
        }
    }
}

struct Session: Identifiable, Hashable, Sendable {
    let id: String
    var cwd: String
    var state: AgentState
    var lastEventAt: Date
    var lastEventName: String?
    var note: String?

    var hostTTY: String?
    var hostPID: Int32?
}

import Foundation

struct HookEvent: Decodable, Sendable {
    let sessionId: String
    let cwd: String?
    let eventName: String
    let hookEventName: String?
    let permissionMode: String?
    let transcriptPath: String?
    let toolName: String?
    let clientTs: Int64?
    let hostTty: String?
    let hostPid: Int32?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case eventName = "event_name"
        case hookEventName = "hook_event_name"
        case permissionMode = "permission_mode"
        case transcriptPath = "transcript_path"
        case toolName = "tool_name"
        case clientTs = "client_ts"
        case hostTty = "host_tty"
        case hostPid = "host_pid"
    }

    var effectiveEventName: String {
        eventName.isEmpty ? (hookEventName ?? "") : eventName
    }
}

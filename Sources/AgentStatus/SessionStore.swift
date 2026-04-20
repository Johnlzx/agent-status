import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [String: Session] = [:]

    var ordered: [Session] {
        sessions.values.sorted { a, b in a.lastEventAt > b.lastEventAt }
    }

    var aggregateState: AgentState {
        let values = sessions.values
        if values.isEmpty { return .unknown }
        if values.contains(where: { $0.state == .waiting }) { return .waiting }
        if values.contains(where: { $0.state == .running }) { return .running }
        if values.allSatisfy({ $0.state == .idle }) { return .idle }
        return .unknown
    }

    func applyClaudeEvent(_ event: HookEvent) {
        let now = Date()
        let id = event.sessionId
        let eventName = event.effectiveEventName

        if eventName == "SessionEnd" {
            sessions.removeValue(forKey: id)
            return
        }

        var session = sessions[id] ?? Session(
            id: id,
            cwd: event.cwd ?? "",
            state: .idle,
            lastEventAt: now,
            lastEventName: nil,
            note: nil,
            hostTTY: event.hostTty,
            hostPID: event.hostPid
        )
        if let cwd = event.cwd, !cwd.isEmpty { session.cwd = cwd }
        if let tty = event.hostTty, !tty.isEmpty { session.hostTTY = tty }
        if let pid = event.hostPid, pid > 0 { session.hostPID = pid }
        session.lastEventAt = now
        session.lastEventName = eventName

        switch eventName {
        case "SessionStart":
            session.state = .idle
            session.note = nil
        case "UserPromptSubmit", "PreToolUse":
            session.state = .running
            if eventName == "PreToolUse", let tool = event.toolName {
                session.note = tool
            }
        case "PermissionRequest":
            session.state = .waiting
            session.note = event.toolName.map { "permission: \($0)" } ?? "permission requested"
        case "PostToolUse":
            if session.state != .waiting {
                session.state = .running
            }
        case "Stop":
            session.state = .idle
            session.note = nil
        case "PermissionDenied":
            session.state = .running
            session.note = "permission denied"
        default:
            break
        }

        sessions[id] = session
    }

    func sweepStale(thresholdSeconds: TimeInterval = 30 * 60) {
        let now = Date()
        for (id, s) in sessions {
            if now.timeIntervalSince(s.lastEventAt) > thresholdSeconds && s.state != .unknown {
                var next = s
                next.state = .unknown
                sessions[id] = next
            }
        }
    }
}

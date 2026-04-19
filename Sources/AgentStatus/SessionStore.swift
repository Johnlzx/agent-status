import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [String: Session] = [:]

    var ordered: [Session] {
        sessions.values.sorted { a, b in
            if a.kind != b.kind { return a.kind.rawValue < b.kind.rawValue }
            return a.lastEventAt > b.lastEventAt
        }
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
        let event_name = event.effectiveEventName

        if event_name == "SessionEnd" {
            sessions.removeValue(forKey: id)
            return
        }

        var session = sessions[id] ?? Session(
            id: id,
            kind: .claudeCode,
            cwd: event.cwd ?? "",
            pid: nil,
            state: .idle,
            lastEventAt: now,
            lastEventName: nil,
            note: nil
        )
        if let cwd = event.cwd, !cwd.isEmpty { session.cwd = cwd }
        session.lastEventAt = now
        session.lastEventName = event_name

        switch event_name {
        case "SessionStart":
            session.state = .idle
            session.note = nil
        case "UserPromptSubmit", "PreToolUse":
            session.state = .running
            if event_name == "PreToolUse", let tool = event.toolName {
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

    func upsertCodex(pid: Int32, cwd: String) {
        let id = "codex:\(pid)"
        let now = Date()
        var s = sessions[id] ?? Session(
            id: id,
            kind: .codex,
            cwd: cwd,
            pid: pid,
            state: .running,
            lastEventAt: now,
            lastEventName: nil,
            note: "coarse"
        )
        if !cwd.isEmpty { s.cwd = cwd }
        s.lastEventAt = now
        s.state = .running
        s.note = "coarse"
        sessions[id] = s
    }

    func reconcileCodex(alivePids: Set<Int32>) {
        for (id, s) in sessions where s.kind == .codex {
            if let pid = s.pid, !alivePids.contains(pid) {
                sessions.removeValue(forKey: id)
            }
        }
    }

    func sweepStale(thresholdSeconds: TimeInterval = 30 * 60) {
        let now = Date()
        for (id, s) in sessions where s.kind == .claudeCode {
            if now.timeIntervalSince(s.lastEventAt) > thresholdSeconds && s.state != .unknown {
                var next = s
                next.state = .unknown
                sessions[id] = next
            }
        }
    }
}

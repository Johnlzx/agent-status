import SwiftUI

struct SessionRow: View {
    let session: Session
    let now: Date

    @State private var hover = false

    var body: some View {
        Button(action: {
            TerminalFocus.focus(session)
        }) {
            content
        }
        .buttonStyle(.plain)
        .disabled(!isFocusable)
        .help(helpText)
        .onHover { hover = $0 }
    }

    private var isFocusable: Bool {
        (session.hostPID ?? 0) > 0
    }

    private var helpText: String {
        if !isFocusable {
            return "No terminal location captured for this session."
        }
        if let tty = session.hostTTY, !tty.isEmpty {
            return "Click to focus \(tty)"
        }
        return "Click to focus the terminal"
    }

    private var rowBackground: Color {
        if !isFocusable { return .clear }
        return hover ? Color.primary.opacity(0.08) : .clear
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 10) {
            Image(systemName: session.kind.symbolName)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(session.kind.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    if session.kind == .codex {
                        Text("coarse")
                            .font(.system(size: 9, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.16))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                    if isFocusable, let tty = session.hostTTY, !tty.isEmpty {
                        Text(tty)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                Text(shortCwd)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let note = session.note, !note.isEmpty, session.state == .waiting {
                    Text(note)
                        .font(.system(size: 10))
                        .foregroundStyle(stateColor(.waiting))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                statePill
                Text(ageString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(rowBackground)
    }

    private var shortCwd: String {
        if session.cwd.isEmpty { return "(unknown)" }
        let home = NSHomeDirectory()
        if session.cwd.hasPrefix(home) {
            return "~" + session.cwd.dropFirst(home.count)
        }
        return session.cwd
    }

    @ViewBuilder
    private var statePill: some View {
        let c = stateColor(session.state)
        HStack(spacing: 4) {
            Circle()
                .fill(c)
                .frame(width: 6, height: 6)
            Text(session.state.label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(c.opacity(0.15))
        .foregroundStyle(c)
        .clipShape(Capsule())
    }

    private var ageString: String {
        let s = max(0, Int(now.timeIntervalSince(session.lastEventAt)))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }

    private func stateColor(_ state: AgentState) -> Color {
        switch state {
        case .idle: return Color(nsColor: .systemGray)
        case .running: return Color(nsColor: .systemGreen)
        case .waiting: return Color(nsColor: .systemOrange)
        case .unknown: return Color(nsColor: .tertiaryLabelColor)
        }
    }
}

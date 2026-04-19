import SwiftUI
import AppKit

struct MenuContentView: View {
    @Bindable var store: SessionStore
    @State private var now: Date = .init()

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
                .padding(.bottom, 4)
            if store.sessions.isEmpty {
                emptyState
            } else {
                sessionList
            }
            Divider()
                .padding(.top, 4)
            footer
        }
        .frame(width: 360)
        .padding(.vertical, 10)
        .onReceive(timer) { now = $0 }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(.tint)
            Text("Agent Status")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            let count = store.sessions.count
            Text("\(count) " + (count == 1 ? "session" : "sessions"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No active sessions")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text("Start `claude` or `codex` in a terminal")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }

    @ViewBuilder
    private var sessionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(store.ordered) { s in
                    SessionRow(session: s, now: now)
                    if s.id != store.ordered.last?.id {
                        Divider().padding(.leading, 40)
                    }
                }
            }
        }
        .frame(maxHeight: 420)
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 8) {
            Text("Listening on ~/Library/.../ipc.sock")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}

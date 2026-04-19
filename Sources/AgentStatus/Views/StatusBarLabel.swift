import SwiftUI

struct StatusBarLabel: View {
    @Bindable var store: SessionStore

    var body: some View {
        let p = presentation
        HStack(spacing: 3) {
            Image(systemName: p.symbol)
            if store.sessions.count > 1 {
                Text("\(store.sessions.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
        }
    }

    private var presentation: (symbol: String, tone: String) {
        if store.sessions.isEmpty {
            return ("moon.zzz", "dim")
        }
        switch store.aggregateState {
        case .waiting:
            return ("exclamationmark.circle.fill", "warn")
        case .running:
            return ("circle.fill", "active")
        case .idle:
            return ("circle", "idle")
        case .unknown:
            return ("questionmark.circle", "idle")
        }
    }
}

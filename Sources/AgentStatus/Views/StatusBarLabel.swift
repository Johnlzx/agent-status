import SwiftUI

struct StatusBarLabel: View {
    @Bindable var store: SessionStore

    var body: some View {
        HStack(spacing: 3) {
            PixelGear(
                palette: GearPalette.forState(aggregate),
                pixels: 14,
                rotates: aggregate == .running,
                rpm: 0.35,
                pulses: aggregate == .waiting
            )
            .frame(width: 18, height: 18)

            if store.sessions.count > 1 {
                Text("\(store.sessions.count)")
                    .font(SteampunkFonts.pixel(9))
                    .foregroundStyle(Steam.amberHot)
            }
        }
    }

    private var aggregate: AgentState {
        store.sessions.isEmpty ? .unknown : store.aggregateState
    }
}

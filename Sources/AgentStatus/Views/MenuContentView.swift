import SwiftUI
import AppKit

struct MenuContentView: View {
    @Bindable var store: SessionStore
    @State private var now: Date = .init()

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            contentBody
            footer
        }
        .frame(width: 360)
        .background(Steam.paneBG)
        .onReceive(timer) { now = $0 }
    }

    // MARK: - Title bar (brass plate with rivets)

    @ViewBuilder
    private var titleBar: some View {
        ZStack {
            LinearGradient(
                colors: [Steam.brass, Steam.brassDim],
                startPoint: .top, endPoint: .bottom
            )
            HStack {
                RivetStrip(count: 3, spacing: 4)
                Spacer()
                VStack(alignment: .center, spacing: 1) {
                    Text("AGENT  STATUS")
                        .font(SteampunkFonts.pixel(10))
                        .foregroundStyle(Steam.ink)
                        .kerning(1)
                    Text("CLAUDE  CODE  WATCHTOWER")
                        .font(SteampunkFonts.pixel(6))
                        .foregroundStyle(Steam.ink.opacity(0.55))
                        .kerning(1)
                }
                Spacer()
                RivetStrip(count: 3, spacing: 4)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 38)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Steam.ink).frame(height: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Steam.brassLight.opacity(0.8)).frame(height: 1)
        }
    }

    // MARK: - Body

    @ViewBuilder
    private var contentBody: some View {
        if store.sessions.isEmpty {
            emptyState
        } else {
            sessionList
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            PixelMoon()
                .frame(width: 28, height: 28)
            Text("NO  SIGNAL")
                .font(SteampunkFonts.pixel(9))
                .foregroundStyle(Steam.steamDim)
                .kerning(1)
            Text("start  `claude`  in  a  terminal".uppercased())
                .font(SteampunkFonts.pixel(6))
                .foregroundStyle(Steam.steamFaint)
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            Steam.innerBG
                .overlay(alignment: .topLeading) {
                    Path { p in
                        // diagonal hatch lines for an "empty panel" feel
                        for i in stride(from: -40, through: 400, by: 10) {
                            p.move(to: CGPoint(x: i, y: 0))
                            p.addLine(to: CGPoint(x: i + 200, y: 200))
                        }
                    }
                    .stroke(Steam.brassDim.opacity(0.07), lineWidth: 1)
                }
                .clipped()
        )
    }

    @ViewBuilder
    private var sessionList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(store.ordered) { session in
                    SessionRow(session: session, now: now)
                }
            }
        }
        .frame(maxHeight: 420)
        .background(Steam.paneBG)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        ZStack {
            LinearGradient(
                colors: [Steam.plateBG, Steam.innerBG],
                startPoint: .top, endPoint: .bottom
            )
            HStack(spacing: 8) {
                Rivet()
                Text(countLabel)
                    .font(SteampunkFonts.pixel(6))
                    .foregroundStyle(Steam.steamDim)
                    .kerning(1)
                Spacer()
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("[  QUIT  ]")
                        .font(SteampunkFonts.pixel(7))
                        .foregroundStyle(Steam.brassLight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                Rivet()
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 26)
        .overlay(alignment: .top) {
            Rectangle().fill(Steam.brassDim.opacity(0.6)).frame(height: 1)
        }
    }

    private var countLabel: String {
        let n = store.sessions.count
        if n == 0 { return "0  SESSIONS" }
        if n == 1 { return "1  SESSION" }
        return "\(n)  SESSIONS"
    }
}

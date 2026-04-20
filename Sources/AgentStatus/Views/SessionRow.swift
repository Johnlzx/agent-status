import SwiftUI

struct SessionRow: View {
    let session: Session
    let now: Date

    @State private var hover = false

    var body: some View {
        Button(action: { TerminalFocus.focus(session) }) {
            content
        }
        .buttonStyle(.plain)
        .disabled(!isFocusable)
        .help(helpText)
        .onHover { hover = $0 }
    }

    private var isFocusable: Bool { (session.hostPID ?? 0) > 0 }

    private var helpText: String {
        if !isFocusable { return "No terminal location captured for this session." }
        if let tty = session.hostTTY, !tty.isEmpty { return "Click to focus \(tty)" }
        return "Click to focus the terminal"
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 10) {
            // state gear — 22x22 chunk with 14-pixel grid
            PixelGear(
                palette: GearPalette.forState(session.state),
                pixels: 14,
                rotates: session.state == .running,
                rpm: 0.35,
                pulses: session.state == .waiting
            )
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    statePill
                    if isFocusable, let tty = session.hostTTY, !tty.isEmpty {
                        Text(tty.uppercased())
                            .font(SteampunkFonts.pixel(7))
                            .foregroundStyle(Steam.steamDim)
                    }
                }
                Text(shortCwd)
                    .font(SteampunkFonts.pixel(8))
                    .foregroundStyle(Steam.steam)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let note = session.note, !note.isEmpty, session.state == .waiting {
                    Text(note.uppercased())
                        .font(SteampunkFonts.pixel(7))
                        .foregroundStyle(Steam.rustBright)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            Text(ageString)
                .font(SteampunkFonts.pixel(7))
                .foregroundStyle(Steam.steamDim)
                .monospacedDigit()
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Steam.innerBG)
                .brassBevel(highlight: Steam.brassDim, shadow: Steam.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(rowBackground)
    }

    private var rowBackground: some View {
        ZStack {
            hover && isFocusable ? Steam.plateBGHi : Steam.plateBG
            // bottom hairline divider in brass dim
            GeometryReader { geo in
                Path(CGRect(x: 10, y: geo.size.height - 1, width: geo.size.width - 20, height: 1))
                    .fill(Steam.brassDim.opacity(0.5))
            }
        }
    }

    private var statePill: some View {
        let colors = pillColors(session.state)
        return Text(session.state.label)
            .font(SteampunkFonts.pixel(8))
            .foregroundStyle(colors.fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(colors.bg)
            .brassBevel(highlight: colors.fg.opacity(0.5), shadow: Steam.ink)
    }

    private func pillColors(_ state: AgentState) -> (bg: Color, fg: Color) {
        switch state {
        case .idle:    return (Steam.brassDim.opacity(0.35),   Steam.brassLight)
        case .running: return (Steam.amber.opacity(0.25),      Steam.amberHot)
        case .waiting: return (Steam.rust.opacity(0.45),       Steam.rustBright)
        case .unknown: return (Steam.steamFaint.opacity(0.25), Steam.steamDim)
        }
    }

    private var shortCwd: String {
        if session.cwd.isEmpty { return "(UNKNOWN)" }
        let home = NSHomeDirectory()
        if session.cwd.hasPrefix(home) { return "~" + session.cwd.dropFirst(home.count) }
        return session.cwd
    }

    private var ageString: String {
        let s = max(0, Int(now.timeIntervalSince(session.lastEventAt)))
        if s < 60 { return "\(s)S" }
        if s < 3600 { return "\(s / 60)M" }
        return "\(s / 3600)H"
    }
}

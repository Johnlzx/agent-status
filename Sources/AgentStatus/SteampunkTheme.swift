import SwiftUI

/// Color palette for the steampunk pixel aesthetic.
///
/// Colors are chosen in pairs (light + dark) so pixel art has readable edges
/// against the plate background. Keep this file narrow: every view imports
/// these constants so a small palette shift propagates everywhere.
enum Steam {
    // Backgrounds
    static let paneBG      = Color(red: 0.11,  green: 0.08,  blue: 0.06)     // deep oily brown
    static let plateBG     = Color(red: 0.165, green: 0.115, blue: 0.075)    // metal plate
    static let plateBGHi   = Color(red: 0.215, green: 0.155, blue: 0.100)    // plate highlight
    static let innerBG     = Color(red: 0.085, green: 0.060, blue: 0.045)    // inset panel

    // Brass / copper metal tones
    static let brass       = Color(red: 0.70, green: 0.545, blue: 0.365)     // #B38B5E
    static let brassDim    = Color(red: 0.44, green: 0.355, blue: 0.240)     // #705A3D
    static let brassLight  = Color(red: 0.83, green: 0.690, blue: 0.490)     // #D4B07D
    static let copper      = Color(red: 0.66, green: 0.355, blue: 0.195)     // #A85A31

    // State colors
    static let amber       = Color(red: 0.910, green: 0.610, blue: 0.235)    // #E89B3C
    static let amberHot    = Color(red: 1.000, green: 0.720, blue: 0.280)    // #FFB847
    static let rust        = Color(red: 0.545, green: 0.230, blue: 0.120)    // #8B3A1F
    static let rustBright  = Color(red: 0.830, green: 0.335, blue: 0.165)    // #D4552A

    // Text
    static let steam       = Color(red: 0.900, green: 0.835, blue: 0.690)    // #E6D5B0
    static let steamDim    = Color(red: 0.605, green: 0.545, blue: 0.430)    // #9A8B6E
    static let steamFaint  = Color(red: 0.42,  green: 0.37,  blue: 0.285)

    // Accents
    static let oxide       = Color(red: 0.228, green: 0.352, blue: 0.305)    // oxidized green
    static let ink         = Color(red: 0.045, green: 0.025, blue: 0.015)    // ≈ pure black but warm
}

/// Palette for a single pixel gear, keyed by state.
struct GearPalette {
    let body: Color
    let bodyShade: Color
    let hole: Color
    let glow: Color?

    static let idle = GearPalette(
        body: Steam.brassDim, bodyShade: Steam.ink,
        hole: Steam.ink, glow: nil
    )
    static let running = GearPalette(
        body: Steam.amber, bodyShade: Steam.copper,
        hole: Steam.ink, glow: Steam.amberHot
    )
    static let waiting = GearPalette(
        body: Steam.rustBright, bodyShade: Steam.rust,
        hole: Steam.ink, glow: Steam.rustBright
    )
    static let stale = GearPalette(
        body: Steam.steamFaint, bodyShade: Steam.ink,
        hole: Steam.ink, glow: nil
    )

    static func forState(_ state: AgentState) -> GearPalette {
        switch state {
        case .idle:    return .idle
        case .running: return .running
        case .waiting: return .waiting
        case .unknown: return .stale
        }
    }
}

/// A thin 2-px brass bevel around content: light on top-left, dark on
/// bottom-right. No rounded corners — this is deliberately flat-angled.
struct BrassBevel: ViewModifier {
    var thickness: CGFloat = 1
    var highlight: Color = Steam.brass
    var shadow: Color = Steam.ink

    func body(content: Content) -> some View {
        content.overlay(
            ZStack {
                // top + left highlight
                Path { p in
                    p.addRect(CGRect(x: 0, y: 0, width: 9999, height: thickness))
                    p.addRect(CGRect(x: 0, y: 0, width: thickness, height: 9999))
                }
                .fill(highlight)
                // bottom + right shadow
                GeometryReader { geo in
                    Path { p in
                        p.addRect(CGRect(x: 0, y: geo.size.height - thickness, width: geo.size.width, height: thickness))
                        p.addRect(CGRect(x: geo.size.width - thickness, y: 0, width: thickness, height: geo.size.height))
                    }
                    .fill(shadow)
                }
            }
        )
    }
}

extension View {
    func brassBevel(thickness: CGFloat = 1, highlight: Color = Steam.brass, shadow: Color = Steam.ink) -> some View {
        modifier(BrassBevel(thickness: thickness, highlight: highlight, shadow: shadow))
    }
}

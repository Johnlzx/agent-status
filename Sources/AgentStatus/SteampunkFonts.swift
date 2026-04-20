import Foundation
import CoreText
import SwiftUI

/// Registers bundled pixel fonts and exposes named accessors.
///
/// Fonts are loaded from the main bundle's Resources at launch. If a bundled
/// font is missing (e.g. running the binary directly without the .app
/// wrapper), we fall back to SF Mono, which still looks reasonable with the
/// rest of the steampunk styling.
enum SteampunkFonts {
    /// PostScript name used after registration. Verify via `Font Book`.
    static let pixelPostScript = "PressStart2P-Regular"

    static private(set) var pixelRegistered = false

    static func registerBundledFonts() {
        let names = ["PressStart2P-Regular"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                fputs("[fonts] bundled \(name).ttf not found; will fall back to SF Mono.\n", stderr)
                continue
            }
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if ok {
                pixelRegistered = true
            } else if let e = error?.takeRetainedValue() {
                fputs("[fonts] register failed for \(name): \(e)\n", stderr)
            }
        }
    }

    /// Primary pixel font — use for most text. Falls back to SF Mono.
    static func pixel(_ size: CGFloat) -> Font {
        if pixelRegistered {
            return .custom(pixelPostScript, fixedSize: size)
        }
        return .system(size: size, weight: .bold, design: .monospaced)
    }
}

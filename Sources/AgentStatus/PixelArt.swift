import SwiftUI

/// A pixel-art gear rendered procedurally on a fixed grid. No anti-aliasing;
/// every drawn pixel is an integer-aligned rectangle. The gear rotates at a
/// fixed rate when `rotates == true`.
///
/// Keep `pixels` at 14 for a 2x scale in the menu bar (28×28 logical pts).
/// Smaller grids look mushy; larger grids lose the pixel-art character.
struct PixelGear: View {
    var palette: GearPalette
    var pixels: Int = 14
    var rotates: Bool = false
    /// Full rotations per second.
    var rpm: Double = 0.4
    /// Opacity pulse (for the WAIT state).
    var pulses: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
            Canvas { graphics, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let rotation = rotates ? (t * rpm * 2.0 * .pi) : 0.0
                let pulseAlpha: Double = pulses
                    ? 0.55 + 0.45 * (0.5 + 0.5 * sin(t * 4.0))
                    : 1.0
                var g = graphics
                g.opacity = pulseAlpha
                Self.drawGear(
                    into: &g, size: size, pixels: pixels,
                    rotation: rotation, palette: palette
                )
            }
        }
    }

    /// Draw the gear by grouping pixels by color and issuing one `fill` per
    /// color. `graphics.translateBy`/`scaleBy` are intentionally not used —
    /// we want every pixel aligned to integer positions.
    static func drawGear(
        into ctx: inout GraphicsContext,
        size: CGSize,
        pixels: Int,
        rotation: Double,
        palette: GearPalette
    ) {
        let side = min(size.width, size.height)
        let pxSize = floor(side / CGFloat(pixels))
        guard pxSize >= 1 else { return }
        let originX = floor((size.width  - pxSize * CGFloat(pixels)) / 2)
        let originY = floor((size.height - pxSize * CGFloat(pixels)) / 2)

        let cx = CGFloat(pixels) / 2.0
        let cy = CGFloat(pixels) / 2.0
        let outerTooth: CGFloat = CGFloat(pixels) * 0.47   // 6.5 on 14 grid
        let outerBody: CGFloat  = CGFloat(pixels) * 0.39   // 5.5 on 14 grid
        let innerRing: CGFloat  = CGFloat(pixels) * 0.18   // 2.5 on 14 grid
        let hole: CGFloat       = CGFloat(pixels) * 0.11   // 1.5 on 14 grid

        let teeth = 8
        let halfSector = Double.pi / Double(teeth)

        var bodyPath = Path()
        var shadePath = Path()

        for py in 0..<pixels {
            for px in 0..<pixels {
                let dx = CGFloat(px) + 0.5 - cx
                let dy = CGFloat(py) + 0.5 - cy
                let r = sqrt(dx * dx + dy * dy)

                if r < hole { continue } // transparent center

                var angle = Double(atan2(dy, dx)) + rotation
                angle = angle.truncatingRemainder(dividingBy: 2 * .pi)
                if angle < 0 { angle += 2 * .pi }
                let sectorIdx = Int(floor(angle / halfSector))
                let isTooth = sectorIdx.isMultiple(of: 2)

                var hit: Bool = false
                var shaded: Bool = false

                if r < innerRing {
                    hit = true
                    shaded = true // inner hub — darker
                } else if isTooth {
                    if r <= outerTooth { hit = true }
                } else {
                    if r <= outerBody { hit = true }
                }
                if !hit { continue }

                // Give the upper-left of the gear a lighter edge to suggest
                // directional light. Bottom-right gets the shade color.
                if !shaded {
                    let edge = r > (outerBody - 0.5)
                    if edge && (dx + dy) > 0.5 { shaded = true }
                }

                let rect = CGRect(
                    x: originX + CGFloat(px) * pxSize,
                    y: originY + CGFloat(py) * pxSize,
                    width: pxSize, height: pxSize
                )
                if shaded {
                    shadePath.addRect(rect)
                } else {
                    bodyPath.addRect(rect)
                }
            }
        }

        ctx.fill(bodyPath, with: .color(palette.body))
        ctx.fill(shadePath, with: .color(palette.bodyShade))

        // Optional glow: a 1-pixel-outer ring of palette.glow at low opacity.
        if let glow = palette.glow {
            var ring = Path()
            for py in 0..<pixels {
                for px in 0..<pixels {
                    let dx = CGFloat(px) + 0.5 - cx
                    let dy = CGFloat(py) + 0.5 - cy
                    let r = sqrt(dx * dx + dy * dy)
                    if r > outerTooth && r < outerTooth + 1.2 {
                        let rect = CGRect(
                            x: originX + CGFloat(px) * pxSize,
                            y: originY + CGFloat(py) * pxSize,
                            width: pxSize, height: pxSize
                        )
                        ring.addRect(rect)
                    }
                }
            }
            ctx.opacity = 0.35
            ctx.fill(ring, with: .color(glow))
        }
    }
}

/// Small brass rivet. Use in frame corners. 3×3 pixel grid.
struct Rivet: View {
    var pixel: CGFloat = 2
    var body: some View {
        Canvas { ctx, size in
            let px = pixel
            let highlight = Steam.brassLight
            let shadow = Steam.brassDim
            let body = Steam.brass

            // body (full 3x3 minus corners)
            var p = Path()
            p.addRect(CGRect(x: px,     y: 0,      width: px, height: px))
            p.addRect(CGRect(x: 0,      y: px,     width: px, height: px))
            p.addRect(CGRect(x: px,     y: px,     width: px, height: px))
            p.addRect(CGRect(x: px * 2, y: px,     width: px, height: px))
            p.addRect(CGRect(x: px,     y: px * 2, width: px, height: px))
            ctx.fill(p, with: .color(body))

            // top-left highlight pixel
            ctx.fill(
                Path(CGRect(x: px, y: px, width: px, height: px)),
                with: .color(highlight)
            )
            // bottom-right shadow — overlay the body's bottom-right edge
            ctx.fill(
                Path(CGRect(x: px * 2, y: px * 2, width: px, height: px)),
                with: .color(shadow)
            )
        }
        .frame(width: pixel * 3, height: pixel * 3)
    }
}

/// A row of screws/rivets across the top or bottom of a plate.
struct RivetStrip: View {
    var count: Int
    var spacing: CGFloat = 0
    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in Rivet() }
        }
    }
}

/// Small pixel moon icon (used when there are no sessions).
struct PixelMoon: View {
    var pixels: Int = 14
    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let pxSize = floor(side / CGFloat(pixels))
            let ox = floor((size.width - pxSize * CGFloat(pixels)) / 2)
            let oy = floor((size.height - pxSize * CGFloat(pixels)) / 2)
            let cx = CGFloat(pixels) / 2.0
            let cy = CGFloat(pixels) / 2.0
            let outer: CGFloat = CGFloat(pixels) * 0.48
            let bite:  CGFloat = CGFloat(pixels) * 0.40
            let biteCX = cx + 1.6
            let biteCY = cy - 1.6

            var moon = Path()
            for py in 0..<pixels {
                for px in 0..<pixels {
                    let dx = CGFloat(px) + 0.5 - cx
                    let dy = CGFloat(py) + 0.5 - cy
                    if sqrt(dx*dx + dy*dy) > outer { continue }
                    let bx = CGFloat(px) + 0.5 - biteCX
                    let by = CGFloat(py) + 0.5 - biteCY
                    if sqrt(bx*bx + by*by) < bite { continue }
                    moon.addRect(CGRect(
                        x: ox + CGFloat(px) * pxSize,
                        y: oy + CGFloat(py) * pxSize,
                        width: pxSize, height: pxSize
                    ))
                }
            }
            ctx.fill(moon, with: .color(Steam.brassDim))
        }
    }
}

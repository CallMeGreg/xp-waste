import SwiftUI
import UIKit

/// Vector artwork for a skill emblem or training method.
///
/// Every icon is a tintable, resolution-independent vector so it renders crisply at any
/// size on iPhone and iPad. Most concepts map to an SF Symbol; the handful of RuneScape
/// objects SF Symbols lacks (sword, axe, pickaxe, bow, arrow, quiver, ore, ingot, bone, skull,
/// warhammer, flexed arm) are drawn as custom `VectorIcon` paths below.
enum SkillArt {
    /// An SF Symbol, referenced by name.
    case symbol(String)
    /// A custom-drawn vector icon.
    case vector(VectorIcon)
}

/// Custom vector icons for objects with no good SF Symbol equivalent.
///
/// `bolt`, `flame`, and `lock` duplicate common SF Symbols on purpose: on iPad an
/// `Image(systemName:)` placed in the bottom control bar phantom-renders a faint copy up
/// near the navigation bar. Drawn vector paths don't trigger that bug, so the control-bar
/// glyphs use these instead.
enum VectorIcon {
    case sword, axe, pickaxe, bow, arrow, quiver, ore, ingot, bone, skull, warhammer, flexArm, bolt, flame, lock, battery
}

// MARK: - Rendering

/// Renders a `SkillArt` value as a tinted, square, scalable icon.
struct ArtworkView: View {
    let art: SkillArt
    var size: CGFloat
    var color: Color
    /// When true (the big training object), the icon is brightened and shadowed so it reads
    /// clearly on top of the skill-tinted disc regardless of hue.
    var emphasized: Bool = false

    var body: some View {
        let fill = emphasized ? color.lightened(0.5) : color
        Group {
            switch art {
            case .symbol(let name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(fill)
                    .padding(size * 0.06)
            case .vector(let icon):
                icon.view(color: fill)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: emphasized ? .black.opacity(0.35) : .clear,
                radius: emphasized ? size * 0.03 : 0, y: emphasized ? 1 : 0)
    }
}

// MARK: - Custom vector icons

extension VectorIcon {
    @ViewBuilder
    func view(color: Color) -> some View {
        switch self {
        case .sword, .axe, .pickaxe, .bone, .warhammer, .bolt, .flame:
            SolidIconShape(icon: self).fill(color)
        case .skull:
            SolidIconShape(icon: self).fill(color, style: FillStyle(eoFill: true))
        case .ingot:
            IngotIcon(color: color)
        case .ore:
            OreIcon(color: color)
        case .bow:
            BowIcon(color: color)
        case .arrow:
            ArrowIcon(color: color)
        case .quiver:
            QuiverIcon(color: color)
        case .lock:
            LockIcon(color: color)
        case .battery:
            BatteryIcon(color: color)
        case .flexArm:
            FlexArmIcon(color: color)
        }
    }
}

/// Draws the single-path icons in a normalized 0…1 design space scaled to `rect`.
private struct SolidIconShape: Shape {
    let icon: VectorIcon

    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        func poly(_ pts: [(Double, Double)], into path: inout Path) {
            guard let first = pts.first else { return }
            path.move(to: p(first.0, first.1))
            for pt in pts.dropFirst() { path.addLine(to: p(pt.0, pt.1)) }
            path.closeSubpath()
        }
        func rectSub(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, into path: inout Path) {
            path.addRect(CGRect(x: rect.minX + x0 * rect.width, y: rect.minY + y0 * rect.height,
                                width: (x1 - x0) * rect.width, height: (y1 - y0) * rect.height))
        }
        func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, into path: inout Path) {
            path.addEllipse(in: CGRect(x: rect.minX + (cx - rx) * rect.width,
                                       y: rect.minY + (cy - ry) * rect.height,
                                       width: 2 * rx * rect.width, height: 2 * ry * rect.height))
        }

        var path = Path()
        switch icon {
        case .sword:
            poly([(0.50, 0.06), (0.565, 0.20), (0.565, 0.55), (0.435, 0.55), (0.435, 0.20)], into: &path)
            rectSub(0.27, 0.55, 0.73, 0.63, into: &path)   // crossguard
            rectSub(0.45, 0.63, 0.55, 0.84, into: &path)   // grip
            ellipse(0.50, 0.87, 0.075, 0.065, into: &path) // pommel
        case .axe:
            rectSub(0.455, 0.30, 0.545, 0.92, into: &path)  // vertical handle
            // Single-bit axe head: squat poll on the left, broad blade sweeping down-right to a
            // point, with a concave cutting edge so it reads clearly as an axe (not a hammer).
            path.move(to: p(0.30, 0.18))                                   // poll top-left
            path.addLine(to: p(0.55, 0.15))                                // top, over the handle
            path.addQuadCurve(to: p(0.88, 0.46), control: p(0.86, 0.16))   // outer edge → blade tip
            path.addQuadCurve(to: p(0.55, 0.40), control: p(0.68, 0.52))   // concave cutting edge
            path.addLine(to: p(0.30, 0.38))                                // poll bottom-left
            path.closeSubpath()
        case .pickaxe:
            rectSub(0.46, 0.24, 0.54, 0.92, into: &path)   // handle
            rectSub(0.42, 0.20, 0.58, 0.34, into: &path)   // center boss
            poly([(0.50, 0.19), (0.10, 0.40), (0.15, 0.46), (0.50, 0.31)], into: &path) // left spike
            poly([(0.50, 0.19), (0.90, 0.40), (0.85, 0.46), (0.50, 0.31)], into: &path) // right spike
        case .warhammer:
            // A heavy two-faced maul: a long vertical handle capped by a bold hexagonal head, so
            // it reads as a crush weapon (not the pickaxe's spikes or the axe's single blade).
            rectSub(0.455, 0.32, 0.545, 0.93, into: &path)  // handle
            rectSub(0.44, 0.28, 0.56, 0.36, into: &path)    // collar under the head
            poly([(0.24, 0.15), (0.76, 0.15), (0.82, 0.24), (0.76, 0.33),
                  (0.24, 0.33), (0.18, 0.24)], into: &path) // barrel head
        case .bone:
            rectSub(0.44, 0.27, 0.56, 0.73, into: &path)
            ellipse(0.40, 0.28, 0.11, 0.10, into: &path)
            ellipse(0.60, 0.28, 0.11, 0.10, into: &path)
            ellipse(0.40, 0.72, 0.11, 0.10, into: &path)
            ellipse(0.60, 0.72, 0.11, 0.10, into: &path)
        case .skull:
            // Outer solid (cranium + jaw)…
            ellipse(0.50, 0.42, 0.25, 0.25, into: &path)
            path.addRoundedRect(in: CGRect(x: rect.minX + 0.34 * rect.width, y: rect.minY + 0.55 * rect.height,
                                           width: 0.32 * rect.width, height: 0.24 * rect.height),
                                cornerSize: CGSize(width: 0.06 * rect.width, height: 0.06 * rect.height))
            // …minus eyes, nose, and tooth gaps (even-odd holes).
            ellipse(0.40, 0.44, 0.085, 0.09, into: &path)
            ellipse(0.60, 0.44, 0.085, 0.09, into: &path)
            poly([(0.50, 0.50), (0.455, 0.61), (0.545, 0.61)], into: &path) // nose
            rectSub(0.475, 0.63, 0.492, 0.78, into: &path) // tooth gap
            rectSub(0.508, 0.63, 0.525, 0.78, into: &path) // tooth gap
        case .bolt:
            // A lightning bolt: an upper stroke slanting down-left, then the lower stroke
            // sweeping to a bottom-left point — the classic energy glyph.
            poly([(0.62, 0.05), (0.22, 0.55), (0.45, 0.55), (0.38, 0.95),
                  (0.80, 0.44), (0.55, 0.44)], into: &path)
        case .flame:
            // A rounded flame teardrop: pointed tip up, bulging base.
            path.move(to: p(0.50, 0.05))
            path.addQuadCurve(to: p(0.22, 0.56), control: p(0.30, 0.24))
            path.addQuadCurve(to: p(0.50, 0.95), control: p(0.11, 0.86))
            path.addQuadCurve(to: p(0.78, 0.56), control: p(0.89, 0.86))
            path.addQuadCurve(to: p(0.50, 0.05), control: p(0.70, 0.24))
            path.closeSubpath()
        default:
            break
        }
        return path
    }
}

/// A battery cell with a lightning bolt — the Energy Cell "instant charge" glyph. Drawn (not an
/// SF Symbol) so it doesn't phantom-render in the iPad control bar.
private struct BatteryIcon: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Terminal cap
                RoundedRectangle(cornerRadius: 0.03 * s)
                    .fill(color)
                    .frame(width: 0.22 * s, height: 0.09 * s)
                    .position(x: 0.50 * s, y: 0.14 * s)
                // Cell body
                RoundedRectangle(cornerRadius: 0.11 * s)
                    .fill(color)
                    .frame(width: 0.48 * s, height: 0.70 * s)
                    .position(x: 0.50 * s, y: 0.56 * s)
                // Bolt cut into the cell so it reads as stored charge
                SolidIconShape(icon: .bolt)
                    .fill(color.lightened(0.78))
                    .frame(width: 0.34 * s, height: 0.34 * s)
                    .position(x: 0.50 * s, y: 0.56 * s)
            }
        }
    }
}

/// A flexed arm (biceps) — the Strength emblem. Composed from a horizontal upper arm and a
/// vertical forearm meeting at the elbow, a round fist capping the forearm, and a bold biceps
/// bulge in the crook, echoing OSRS's flexed-arm skill icon in the app's clean vector style.
private struct FlexArmIcon: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Upper arm (shoulder → elbow), lying along the bottom.
                RoundedRectangle(cornerRadius: 0.115 * s)
                    .fill(color)
                    .frame(width: 0.64 * s, height: 0.23 * s)
                    .position(x: 0.47 * s, y: 0.715 * s)
                // Forearm rising from the elbow.
                RoundedRectangle(cornerRadius: 0.115 * s)
                    .fill(color)
                    .frame(width: 0.23 * s, height: 0.56 * s)
                    .position(x: 0.665 * s, y: 0.45 * s)
                // Biceps bulge in the crook, just left of the forearm.
                Circle()
                    .fill(color)
                    .frame(width: 0.37 * s, height: 0.37 * s)
                    .position(x: 0.39 * s, y: 0.485 * s)
                // Fist capping the forearm.
                Circle()
                    .fill(color)
                    .frame(width: 0.32 * s, height: 0.32 * s)
                    .position(x: 0.665 * s, y: 0.19 * s)
            }
        }
    }
}

/// A padlock: a stroked arched shackle sitting above a solid rounded body. Drawn (not an SF
/// Symbol) so it doesn't phantom-render in the iPad control bar.
private struct LockIcon: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Shackle: a narrow arch clearly above the body (quad curve avoids addArc's
                // flipped-coordinate clockwise ambiguity).
                Path { p in
                    p.move(to: CGPoint(x: 0.36 * s, y: 0.56 * s))
                    p.addLine(to: CGPoint(x: 0.36 * s, y: 0.44 * s))
                    p.addQuadCurve(to: CGPoint(x: 0.64 * s, y: 0.44 * s),
                                   control: CGPoint(x: 0.50 * s, y: 0.14 * s))
                    p.addLine(to: CGPoint(x: 0.64 * s, y: 0.56 * s))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 0.10 * s, lineCap: .round, lineJoin: .round))
                // Body
                RoundedRectangle(cornerRadius: 0.08 * s)
                    .fill(color)
                    .frame(width: 0.56 * s, height: 0.38 * s)
                    .position(x: 0.50 * s, y: 0.72 * s)
            }
        }
    }
}

/// A recurve bow with a nocked arrow.
private struct BowIcon: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            // Bow opens toward the arrowhead: the limb's convex (front) side faces
            // right so the nocked arrow is loosed forward, not out the string side.
            let c = CGPoint(x: 0.18 * s, y: 0.50 * s)
            let r = 0.40 * s
            let a0 = Angle.degrees(-62), a1 = Angle.degrees(62)
            let tip0 = CGPoint(x: c.x + r * cos(a0.radians), y: c.y + r * sin(a0.radians))
            let tip1 = CGPoint(x: c.x + r * cos(a1.radians), y: c.y + r * sin(a1.radians))
            ZStack {
                // Bow limb
                Path { p in p.addArc(center: c, radius: r, startAngle: a0, endAngle: a1, clockwise: false) }
                    .stroke(color, style: StrokeStyle(lineWidth: 0.10 * s, lineCap: .round))
                // String
                Path { p in p.move(to: tip0); p.addLine(to: tip1) }
                    .stroke(color, style: StrokeStyle(lineWidth: 0.028 * s, lineCap: .round))
                // Arrow shaft
                Path { p in p.move(to: CGPoint(x: 0.16 * s, y: 0.50 * s)); p.addLine(to: CGPoint(x: 0.80 * s, y: 0.50 * s)) }
                    .stroke(color, style: StrokeStyle(lineWidth: 0.05 * s, lineCap: .round))
                // Arrowhead
                Path { p in
                    p.move(to: CGPoint(x: 0.92 * s, y: 0.50 * s))
                    p.addLine(to: CGPoint(x: 0.80 * s, y: 0.43 * s))
                    p.addLine(to: CGPoint(x: 0.80 * s, y: 0.57 * s))
                    p.closeSubpath()
                }.fill(color)
            }
        }
    }
}

/// A fletched arrow pointing up — the Fletching skill emblem.
private struct ArrowIcon: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Shaft
                Path { p in p.move(to: CGPoint(x: 0.50 * s, y: 0.86 * s)); p.addLine(to: CGPoint(x: 0.50 * s, y: 0.24 * s)) }
                    .stroke(color, style: StrokeStyle(lineWidth: 0.07 * s, lineCap: .round))
                // Head
                Path { p in
                    p.move(to: CGPoint(x: 0.50 * s, y: 0.08 * s))
                    p.addLine(to: CGPoint(x: 0.37 * s, y: 0.30 * s))
                    p.addLine(to: CGPoint(x: 0.63 * s, y: 0.30 * s))
                    p.closeSubpath()
                }.fill(color)
                // Fletching
                Path { p in
                    p.move(to: CGPoint(x: 0.50 * s, y: 0.66 * s))
                    p.addLine(to: CGPoint(x: 0.36 * s, y: 0.86 * s))
                    p.addLine(to: CGPoint(x: 0.50 * s, y: 0.80 * s))
                    p.addLine(to: CGPoint(x: 0.64 * s, y: 0.86 * s))
                    p.closeSubpath()
                }.fill(color)
            }
        }
    }
}

/// A quiver holding three fletched arrows — the Fletching training object. Deliberately distinct
/// from Ranged's `BowIcon` so the two skills read differently at a glance. Arrowheads point up
/// (matching the single-arrow emblem) and the tapered tube reads as a quiver at any size.
private struct QuiverIcon: View {
    let color: Color

    /// Precomputed geometry for one arrow in normalized 0…1 space scaled to `s`.
    private struct Arrow {
        let shaftA, shaftB, headTip, headL, headR, fletchApex, fletchL, fletchR: CGPoint
    }

    /// Three arrows fanning out of the quiver mouth: base sits under the rim, tip above it.
    private func arrows(_ s: CGFloat) -> [Arrow] {
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * Double(s), y: y * Double(s)) }
        let specs: [(bx: Double, by: Double, tx: Double, ty: Double)] = [
            (0.44, 0.50, 0.29, 0.15),   // left, leaning out
            (0.50, 0.50, 0.50, 0.07),   // centre, tallest
            (0.56, 0.50, 0.71, 0.15)    // right, leaning out
        ]
        return specs.map { sp in
            let dx = sp.tx - sp.bx, dy = sp.ty - sp.by
            let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
            let ux = dx / len, uy = dy / len          // unit along the shaft (base → tip)
            let px = -uy, py = ux                      // unit perpendicular to the shaft
            let hbx = sp.tx - ux * 0.12, hby = sp.ty - uy * 0.12   // arrowhead back edge
            return Arrow(
                shaftA: pt(sp.bx, sp.by),
                shaftB: pt(sp.tx, sp.ty),
                headTip: pt(sp.tx, sp.ty),
                headL: pt(hbx + px * 0.055, hby + py * 0.055),
                headR: pt(hbx - px * 0.055, hby - py * 0.055),
                fletchApex: pt(sp.bx + ux * 0.22, sp.by + uy * 0.22),
                fletchL: pt(sp.bx + ux * 0.10 + px * 0.06, sp.by + uy * 0.10 + py * 0.06),
                fletchR: pt(sp.bx + ux * 0.10 - px * 0.06, sp.by + uy * 0.10 - py * 0.06)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let list = arrows(s)
            ZStack {
                // Arrows first so the quiver body overlaps their bases (they emerge from inside).
                ForEach(0..<list.count, id: \.self) { i in
                    let a = list[i]
                    Path { p in p.move(to: a.shaftA); p.addLine(to: a.shaftB) }
                        .stroke(color, style: StrokeStyle(lineWidth: 0.045 * s, lineCap: .round))
                    Path { p in
                        p.move(to: a.headTip); p.addLine(to: a.headL); p.addLine(to: a.headR); p.closeSubpath()
                    }.fill(color)
                    Path { p in p.move(to: a.fletchL); p.addLine(to: a.fletchApex); p.addLine(to: a.fletchR) }
                        .stroke(color, style: StrokeStyle(lineWidth: 0.03 * s, lineCap: .round, lineJoin: .round))
                }
                // Quiver body: a tapered tube with a rounded base, covering the arrow bases.
                Path { p in
                    p.move(to: CGPoint(x: 0.32 * s, y: 0.47 * s))
                    p.addLine(to: CGPoint(x: 0.68 * s, y: 0.47 * s))
                    p.addLine(to: CGPoint(x: 0.62 * s, y: 0.87 * s))
                    p.addQuadCurve(to: CGPoint(x: 0.38 * s, y: 0.87 * s), control: CGPoint(x: 0.50 * s, y: 0.99 * s))
                    p.closeSubpath()
                }.fill(color)
            }
        }
    }
}

/// A metal ingot / bar drawn isometrically: a base-tone front face plus a lighter top face so
/// it reads as a solid 3D bar of metal rather than a flat trapezoid.
private struct IngotIcon: View {
    let color: Color

    private func face(_ points: [(Double, Double)], _ w: CGFloat, _ h: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: points[0].0 * w, y: points[0].1 * h))
        for v in points.dropFirst() { p.addLine(to: CGPoint(x: v.0 * w, y: v.1 * h)) }
        p.closeSubpath()
        return p
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                face([(0.24, 0.50), (0.76, 0.50), (0.86, 0.70), (0.14, 0.70)], w, h)
                    .fill(color)                        // front face
                face([(0.24, 0.50), (0.34, 0.38), (0.86, 0.38), (0.76, 0.50)], w, h)
                    .fill(color.lightened(0.3))         // top face (lighter → 3D)
            }
        }
    }
}

/// A rough ore chunk: an irregular rocky nugget studded with bright mineral flecks so it reads
/// as ore/rock rather than a plain polygon. Flecks derive from the fill so any tint works.
private struct OreIcon: View {
    let color: Color

    private let rockPoints: [(Double, Double)] = [
        (0.22, 0.50), (0.34, 0.30), (0.50, 0.24), (0.67, 0.28),
        (0.82, 0.44), (0.80, 0.62), (0.64, 0.78), (0.42, 0.77), (0.26, 0.66)
    ]
    // x, y, radius (all normalized) for the bright mineral flecks.
    private let flecks: [(Double, Double, Double)] = [
        (0.44, 0.44, 0.075), (0.60, 0.56, 0.055), (0.40, 0.62, 0.045)
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: rockPoints[0].0 * w, y: rockPoints[0].1 * h))
                    for v in rockPoints.dropFirst() {
                        p.addLine(to: CGPoint(x: v.0 * w, y: v.1 * h))
                    }
                    p.closeSubpath()
                }
                .fill(color)
                ForEach(0..<flecks.count, id: \.self) { i in
                    Circle()
                        .fill(color.lightened(0.5))
                        .frame(width: flecks[i].2 * 2 * w, height: flecks[i].2 * 2 * h)
                        .position(x: flecks[i].0 * w, y: flecks[i].1 * h)
                }
            }
        }
    }
}

// MARK: - Colour helpers & material palette

extension Color {
    /// Blends toward white by `amount` (0…1), preserving opacity. Used to keep icons legible
    /// on same-hue backgrounds (e.g. a red heart on the Hitpoints disc).
    func lightened(_ amount: Double = 0.4) -> Color {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let f = CGFloat(min(max(amount, 0), 1))
        return Color(red: Double(r + (1 - r) * f),
                     green: Double(g + (1 - g) * f),
                     blue: Double(b + (1 - b) * f),
                     opacity: Double(a))
    }
}

/// Material / element tints used to show a training object visibly upgrading across its six
/// tiers (e.g. copper → runite ore). Kept here so re-theming never touches gameplay code.
enum Palette {
    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }

    // Metal progression (bronze → runite) for weapons, armour, bars, ores.
    static let metal: [Color] = [
        rgb(0.80, 0.53, 0.32), // bronze
        rgb(0.60, 0.62, 0.66), // iron
        rgb(0.80, 0.82, 0.86), // steel
        rgb(0.42, 0.55, 0.92), // mithril
        rgb(0.26, 0.70, 0.50), // adamant
        rgb(0.28, 0.74, 0.80)  // runite
    ]

    // Dragon-tier equipment (deep crimson) — end-game weapons/armour for Attack, Strength, Defence.
    static let dragon = rgb(0.72, 0.22, 0.20)

    // Log / bow woods (normal → magic).
    static let wood: [Color] = [
        rgb(0.62, 0.45, 0.26), // normal
        rgb(0.70, 0.52, 0.28), // oak
        rgb(0.63, 0.66, 0.34), // willow
        rgb(0.84, 0.46, 0.24), // maple
        rgb(0.36, 0.52, 0.34), // yew
        rgb(0.52, 0.74, 0.95)  // magic
    ]

    // Fish / cooked food (shrimp → shark, with wine at the end for cooking).
    static let fish: [Color] = [
        rgb(0.93, 0.58, 0.53), // shrimp
        rgb(0.74, 0.76, 0.80), // sardine
        rgb(0.58, 0.68, 0.82), // trout
        rgb(0.52, 0.57, 0.64), // tuna
        rgb(0.85, 0.34, 0.30), // lobster
        rgb(0.58, 0.63, 0.70)  // shark
    ]

    // Potion colours by potion type.
    static let potion: [Color] = [
        rgb(0.85, 0.30, 0.30), // attack (red)
        rgb(0.92, 0.60, 0.22), // strength (orange)
        rgb(0.55, 0.82, 0.88), // prayer (cyan)
        rgb(0.60, 0.44, 0.86), // super (purple)
        rgb(0.40, 0.68, 0.38), // ranging (green)
        rgb(0.74, 0.20, 0.32)  // super combat (deep red)
    ]

    // Runecraft rune colours by element.
    static let rune: [Color] = [
        rgb(0.74, 0.85, 0.90), // air
        rgb(0.60, 0.45, 0.30), // earth
        rgb(0.90, 0.47, 0.22), // fire
        rgb(0.40, 0.68, 0.40), // nature
        rgb(0.42, 0.50, 0.85), // law
        rgb(0.76, 0.18, 0.22)  // blood
    ]

    // Hitpoints hearts — warm vitality progression (all clearly a heart).
    static let vitality: [Color] = [
        rgb(0.88, 0.40, 0.44),
        rgb(0.90, 0.32, 0.38),
        rgb(0.94, 0.28, 0.34),
        rgb(0.96, 0.38, 0.46),
        rgb(0.98, 0.52, 0.40),
        rgb(1.00, 0.66, 0.34)
    ]

    // Cut gems for Crafting's top tiers.
    static let sapphire = rgb(0.36, 0.56, 0.92)
    static let emerald  = rgb(0.28, 0.72, 0.46)
    static let diamond  = rgb(0.86, 0.90, 0.96)
}

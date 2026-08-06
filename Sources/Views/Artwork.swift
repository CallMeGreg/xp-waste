import SwiftUI
import UIKit

/// Vector artwork for a skill emblem or training method.
///
/// Every icon is a tintable, resolution-independent vector so it renders crisply at any
/// size on iPhone and iPad. Most concepts map to an SF Symbol; the handful of RuneScape
/// objects SF Symbols lacks (sword, axe, pickaxe, bow, arrow, ore, ingot, bone, skull) are
/// drawn as custom `VectorIcon` paths below.
enum SkillArt {
    /// An SF Symbol, referenced by name.
    case symbol(String)
    /// A custom-drawn vector icon.
    case vector(VectorIcon)
}

/// Custom vector icons for objects with no good SF Symbol equivalent.
enum VectorIcon {
    case sword, axe, pickaxe, bow, arrow, ore, ingot, bone, skull
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
        case .sword, .axe, .pickaxe, .bone:
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
        default:
            break
        }
        return path
    }
}

/// A recurve bow with a nocked arrow.
private struct BowIcon: View {
    let color: Color
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: 0.82 * s, y: 0.50 * s)
            let r = 0.40 * s
            let a0 = Angle.degrees(118), a1 = Angle.degrees(242)
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

/// A fletched arrow pointing up — used for arrow/bow fletching.
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

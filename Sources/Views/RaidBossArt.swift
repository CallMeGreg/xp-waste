import SwiftUI

/// Palette for a boss silhouette: a body gradient (`base` → `deep`) plus a `glow` used for eyes,
/// molten cracks, and the enrage rim.
private struct BossPalette {
    let base: Color
    let deep: Color
    let glow: Color
}

private extension RaidBoss {
    var palette: BossPalette {
        func c(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        switch self {
        case .beast:    return BossPalette(base: c(0.74, 0.56, 0.33), deep: c(0.40, 0.28, 0.15), glow: c(1.00, 0.74, 0.30))
        case .champion: return BossPalette(base: c(0.62, 0.30, 0.30), deep: c(0.26, 0.10, 0.12), glow: c(1.00, 0.52, 0.34))
        case .golem:    return BossPalette(base: c(0.46, 0.48, 0.54), deep: c(0.18, 0.19, 0.24), glow: c(1.00, 0.56, 0.18))
        case .foreman:  return BossPalette(base: c(0.44, 0.37, 0.36), deep: c(0.18, 0.13, 0.13), glow: c(1.00, 0.62, 0.22))
        case .hound:    return BossPalette(base: c(0.34, 0.32, 0.42), deep: c(0.12, 0.11, 0.18), glow: c(0.72, 0.60, 1.00))
        case .warden:   return BossPalette(base: c(0.52, 0.44, 0.76), deep: c(0.20, 0.16, 0.34), glow: c(1.00, 0.86, 0.42))
        case .serpent:  return BossPalette(base: c(0.32, 0.56, 0.40), deep: c(0.11, 0.24, 0.17), glow: c(0.96, 0.90, 0.40))
        case .colossus: return BossPalette(base: c(0.46, 0.52, 0.44), deep: c(0.17, 0.22, 0.18), glow: c(0.56, 1.00, 0.58))
        }
    }
}

/// A parametrised boss creature drawn entirely with vector shapes on a `Canvas`, so it renders
/// crisply at any size on iPhone and iPad. It **breathes** (idle bob), its eyes pulse, it **flinches
/// and flashes** when struck (`hitToken`), and it takes on an angry rim + faster pulse when
/// `enraged`. There is one silhouette per `RaidBoss`, sharing this chrome — a varied roster with no
/// per-creature asset.
struct RaidBossView: View {
    let boss: RaidBoss
    /// 1 → full health, 0 → defeated. Drives a slight "wounded" darkening and slump.
    var hpFraction: Double = 1
    /// Final-phase rage: hotter eyes, a glowing rim, quicker breathing.
    var enraged: Bool = false
    /// Bump this to make the boss flinch + flash white (a landed hit).
    var hitToken: Int = 0
    var size: CGFloat = 200

    @State private var shake: CGFloat = 0
    @State private var flash: Double = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, sz in draw(ctx, size: sz, time: t) }
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .offset(x: shake)
        .onChange(of: hitToken) { _, _ in reactToHit() }
        .accessibilityLabel(Text(boss.name))
    }

    private func reactToHit() {
        flash = 0.85
        withAnimation(.easeOut(duration: 0.28)) { flash = 0 }
        shake = 7
        withAnimation(.interpolatingSpring(stiffness: 900, damping: 8)) { shake = 0 }
    }

    private func draw(_ ctx: GraphicsContext, size sz: CGSize, time t: TimeInterval) {
        let pal = boss.palette
        let wounded = max(0, min(1, hpFraction))
        // Idle breathing: a small vertical bob; faster + deeper when enraged.
        let breatheRate = enraged ? 3.4 : 1.7
        let bob = CGFloat(sin(t * breatheRate)) * sz.height * (enraged ? 0.018 : 0.012)
        // Eye pulse 0…1.
        let pulse = 0.5 + 0.5 * sin(t * (enraged ? 6.0 : 2.6))

        var rect = CGRect(origin: .zero, size: sz).insetBy(dx: sz.width * 0.06, dy: sz.height * 0.06)
        rect.origin.y += bob
        // A wounded boss slumps a touch.
        rect.origin.y += (1 - wounded) * sz.height * 0.02

        let art = BossArt.build(boss, in: rect)

        // Soft ground shadow.
        let shadow = Path(ellipseIn: CGRect(x: rect.midX - rect.width * 0.34,
                                            y: rect.maxY - rect.height * 0.02,
                                            width: rect.width * 0.68, height: rect.height * 0.09))
        ctx.fill(shadow, with: .color(.black.opacity(0.32)))

        // Enrage rim: a blurred glow behind the body.
        if enraged {
            var glowCtx = ctx
            glowCtx.addFilter(.blur(radius: sz.width * 0.05))
            glowCtx.fill(art.body, with: .color(pal.glow.opacity(0.5)))
        }

        // Body gradient (base → deep), darkened as HP falls.
        let baseCol = pal.base.mixed(with: pal.deep, amount: (1 - wounded) * 0.4)
        let flashed = baseCol.mixed(with: .white, amount: flash)
        ctx.fill(
            art.body,
            with: .linearGradient(
                Gradient(colors: [flashed.lightened(0.16), flashed, pal.deep]),
                startPoint: CGPoint(x: rect.midX, y: rect.minY),
                endPoint: CGPoint(x: rect.midX, y: rect.maxY)
            )
        )
        // Rim light along the top edge.
        ctx.stroke(art.body, with: .color(.white.opacity(0.12)), lineWidth: max(1, sz.width * 0.006))

        // Molten cracks / detail strokes.
        if !art.cracks.isEmpty {
            var crackCtx = ctx
            crackCtx.addFilter(.blur(radius: sz.width * 0.012))
            crackCtx.stroke(art.cracks, with: .color(pal.glow.opacity(0.9)),
                            style: StrokeStyle(lineWidth: sz.width * 0.02, lineCap: .round))
            ctx.stroke(art.cracks, with: .color(pal.glow.mixed(with: .white, amount: 0.3)),
                       style: StrokeStyle(lineWidth: sz.width * 0.008, lineCap: .round))
        }

        // Glowing eyes: a blurred halo then a crisp core.
        let eyeGlow = pal.glow.mixed(with: enraged ? .red : .clear, amount: enraged ? 0.5 : 0)
        var haloCtx = ctx
        haloCtx.addFilter(.blur(radius: sz.width * 0.03))
        for e in art.eyes {
            let r = e.height * (0.9 + 0.5 * pulse)
            haloCtx.fill(Path(ellipseIn: e.insetBy(dx: -r, dy: -r)), with: .color(eyeGlow.opacity(0.8)))
        }
        for e in art.eyes {
            ctx.fill(Path(ellipseIn: e), with: .color(.white.opacity(0.95)))
            ctx.fill(Path(ellipseIn: e.insetBy(dx: e.width * 0.28, dy: e.height * 0.28)),
                     with: .color(eyeGlow))
        }
    }
}

// MARK: - Silhouette geometry

/// The resolved shapes for a boss inside a rect: a body path, eye rects, and optional glowing cracks.
private struct BossArtParts {
    var body: Path
    var eyes: [CGRect]
    var cracks: Path
}

private enum BossArt {
    static func build(_ boss: RaidBoss, in rect: CGRect) -> BossArtParts {
        switch boss {
        case .beast:    return brute(rect, headgear: .horns, eyeY: 0.30, cracks: [])
        case .champion: return brute(rect, headgear: .crown, eyeY: 0.29, cracks: [])
        case .foreman:  return brute(rect, headgear: .none,  eyeY: 0.30,
                                     cracks: [[(0.30, 0.66), (0.44, 0.60)], [(0.70, 0.66), (0.56, 0.60)]])
        case .colossus: return brute(rect, headgear: .craggy, eyeY: 0.33, wide: true,
                                     cracks: [[(0.30, 0.70), (0.40, 0.58), (0.36, 0.46)],
                                              [(0.70, 0.72), (0.60, 0.60)]])
        case .golem:    return construct(rect)
        case .hound:    return hound(rect)
        case .warden:   return warden(rect)
        case .serpent:  return serpent(rect)
        }
    }

    private enum Headgear { case none, horns, crown, craggy }

    /// A hulking humanoid brute — shared by the Sand Beast, Champion, Forge Master and (wide,
    /// craggy) the Grove Colossus. `headgear` swaps horns / a crown / a rocky ridge.
    private static func brute(_ rect: CGRect, headgear: Headgear, eyeY: Double,
                              wide: Bool = false, cracks crackPts: [[(Double, Double)]]) -> BossArtParts {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let shoulderX = wide ? 0.08 : 0.14
        var body = Path()
        body.move(to: p(0.24, 0.97))
        body.addQuadCurve(to: p(shoulderX, 0.54), control: p(shoulderX - 0.02, 0.82))     // left flank
        body.addQuadCurve(to: p(0.34, 0.44), control: p(0.26, 0.44))                       // left neck
        body.addQuadCurve(to: p(0.30, 0.28), control: p(0.28, 0.34))                       // left jaw
        body.addQuadCurve(to: p(0.50, 0.17), control: p(0.36, 0.17))                       // head top-left
        body.addQuadCurve(to: p(0.70, 0.28), control: p(0.64, 0.17))                       // head top-right
        body.addQuadCurve(to: p(0.66, 0.44), control: p(0.72, 0.34))                       // right jaw
        body.addQuadCurve(to: p(1 - shoulderX, 0.54), control: p(0.74, 0.44))              // right neck
        body.addQuadCurve(to: p(0.76, 0.97), control: p(1 - shoulderX + 0.02, 0.82))       // right flank
        body.closeSubpath()

        switch headgear {
        case .horns:
            body.move(to: p(0.34, 0.26)); body.addLine(to: p(0.16, 0.05)); body.addLine(to: p(0.42, 0.21)); body.closeSubpath()
            body.move(to: p(0.66, 0.26)); body.addLine(to: p(0.84, 0.05)); body.addLine(to: p(0.58, 0.21)); body.closeSubpath()
        case .crown:
            let ys = 0.15, base = 0.20
            for (i, cx) in stride(from: 0.34, through: 0.66, by: 0.08).enumerated() {
                let h = i == 2 ? ys - 0.06 : ys
                body.move(to: p(cx - 0.03, base)); body.addLine(to: p(cx, h)); body.addLine(to: p(cx + 0.03, base)); body.closeSubpath()
            }
        case .craggy:
            body.move(to: p(0.30, 0.24)); body.addLine(to: p(0.40, 0.10)); body.addLine(to: p(0.46, 0.22)); body.closeSubpath()
            body.move(to: p(0.70, 0.24)); body.addLine(to: p(0.58, 0.12)); body.addLine(to: p(0.54, 0.22)); body.closeSubpath()
        case .none:
            break
        }

        let eyes = [
            CGRect(x: rect.minX + 0.385 * rect.width, y: rect.minY + (eyeY - 0.035) * rect.height,
                   width: 0.07 * rect.width, height: 0.07 * rect.height),
            CGRect(x: rect.minX + 0.545 * rect.width, y: rect.minY + (eyeY - 0.035) * rect.height,
                   width: 0.07 * rect.width, height: 0.07 * rect.height)
        ]
        return BossArtParts(body: body, eyes: eyes, cracks: polyline(crackPts, rect))
    }

    private static func construct(_ rect: CGRect) -> BossArtParts {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var body = Path()
        let pts: [(Double, Double)] = [(0.50, 0.10), (0.84, 0.28), (0.90, 0.60),
                                       (0.70, 0.72), (0.72, 0.96), (0.56, 0.80),
                                       (0.44, 0.80), (0.28, 0.96), (0.30, 0.72),
                                       (0.10, 0.60), (0.16, 0.28)]
        body.move(to: p(pts[0].0, pts[0].1))
        for pt in pts.dropFirst() { body.addLine(to: p(pt.0, pt.1)) }
        body.closeSubpath()

        let eyes = [0.36, 0.50, 0.64].map { x in
            CGRect(x: rect.minX + (x - 0.035) * rect.width, y: rect.minY + 0.37 * rect.height,
                   width: 0.07 * rect.width, height: 0.05 * rect.height)
        }
        let cracks = polyline([[(0.32, 0.50), (0.44, 0.58), (0.40, 0.70)],
                               [(0.68, 0.48), (0.58, 0.60), (0.64, 0.72)]], rect)
        return BossArtParts(body: body, eyes: eyes, cracks: cracks)
    }

    private static func hound(_ rect: CGRect) -> BossArtParts {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var body = Path()
        body.move(to: p(0.08, 0.60))                                   // tail tip
        body.addQuadCurve(to: p(0.30, 0.46), control: p(0.16, 0.44))   // back haunch up
        body.addQuadCurve(to: p(0.58, 0.44), control: p(0.44, 0.40))   // back
        body.addQuadCurve(to: p(0.70, 0.50), control: p(0.66, 0.44))   // neck to head
        body.addLine(to: p(0.72, 0.40))                                // ear back
        body.addLine(to: p(0.80, 0.52))                                // ear tip → brow
        body.addQuadCurve(to: p(0.97, 0.62), control: p(0.94, 0.52))   // snout top
        body.addLine(to: p(0.86, 0.66))                                // nose underside
        body.addQuadCurve(to: p(0.66, 0.70), control: p(0.76, 0.72))   // jaw / chest
        body.addLine(to: p(0.62, 0.96)); body.addLine(to: p(0.54, 0.96)); body.addLine(to: p(0.56, 0.72)) // front leg
        body.addQuadCurve(to: p(0.36, 0.80), control: p(0.46, 0.80))   // belly
        body.addLine(to: p(0.34, 0.96)); body.addLine(to: p(0.26, 0.96)); body.addLine(to: p(0.26, 0.74)) // hind leg
        body.addQuadCurve(to: p(0.08, 0.60), control: p(0.10, 0.68))   // back to tail
        body.closeSubpath()

        let eyes = [CGRect(x: rect.minX + 0.78 * rect.width, y: rect.minY + 0.565 * rect.height,
                           width: 0.06 * rect.width, height: 0.045 * rect.height)]
        return BossArtParts(body: body, eyes: eyes, cracks: Path())
    }

    private static func warden(_ rect: CGRect) -> BossArtParts {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var body = Path()
        body.move(to: p(0.50, 0.08))
        body.addQuadCurve(to: p(0.80, 0.46), control: p(0.80, 0.20))
        body.addQuadCurve(to: p(0.50, 0.94), control: p(0.72, 0.82))
        body.addQuadCurve(to: p(0.20, 0.46), control: p(0.28, 0.82))
        body.addQuadCurve(to: p(0.50, 0.08), control: p(0.20, 0.20))
        body.closeSubpath()
        // Side fins.
        body.move(to: p(0.20, 0.46)); body.addLine(to: p(0.05, 0.40)); body.addLine(to: p(0.16, 0.56)); body.closeSubpath()
        body.move(to: p(0.80, 0.46)); body.addLine(to: p(0.95, 0.40)); body.addLine(to: p(0.84, 0.56)); body.closeSubpath()

        let eyes = [CGRect(x: rect.minX + 0.40 * rect.width, y: rect.minY + 0.38 * rect.height,
                           width: 0.20 * rect.width, height: 0.16 * rect.height)]
        return BossArtParts(body: body, eyes: eyes, cracks: Path())
    }

    private static func serpent(_ rect: CGRect) -> BossArtParts {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        // A thick coil, built by stroking a spine then closing the head.
        var spine = Path()
        spine.move(to: p(0.72, 0.20))
        spine.addQuadCurve(to: p(0.40, 0.42), control: p(0.44, 0.20))
        spine.addQuadCurve(to: p(0.68, 0.66), control: p(0.86, 0.56))
        spine.addQuadCurve(to: p(0.30, 0.88), control: p(0.40, 0.94))
        let body = spine.strokedPath(StrokeStyle(lineWidth: rect.width * 0.17, lineCap: .round, lineJoin: .round))
        // Head bulge.
        var head = Path(ellipseIn: CGRect(x: rect.minX + 0.62 * rect.width, y: rect.minY + 0.12 * rect.height,
                                          width: 0.22 * rect.width, height: 0.18 * rect.height))
        head.addPath(body)

        let eyes = [
            CGRect(x: rect.minX + 0.66 * rect.width, y: rect.minY + 0.17 * rect.height,
                   width: 0.05 * rect.width, height: 0.05 * rect.height),
            CGRect(x: rect.minX + 0.75 * rect.width, y: rect.minY + 0.17 * rect.height,
                   width: 0.05 * rect.width, height: 0.05 * rect.height)
        ]
        return BossArtParts(body: head, eyes: eyes, cracks: Path())
    }

    private static func polyline(_ groups: [[(Double, Double)]], _ rect: CGRect) -> Path {
        var path = Path()
        for group in groups {
            guard let first = group.first else { continue }
            path.move(to: CGPoint(x: rect.minX + first.0 * rect.width, y: rect.minY + first.1 * rect.height))
            for pt in group.dropFirst() {
                path.addLine(to: CGPoint(x: rect.minX + pt.0 * rect.width, y: rect.minY + pt.1 * rect.height))
            }
        }
        return path
    }
}

// MARK: - Animated room backdrop

/// A living backdrop for a raid room: a themed vertical gradient, a vignette, a floor glow, and a
/// drift of ambient motes (embers in the Forge, dust in the Colosseum, sparks in the Vault, spores
/// in the Grove). The static chrome (gradient, blurred floor pool, vignette) is drawn **once**; only
/// the motes redraw, capped at ~30fps, so the backdrop stays alive without burning frames.
struct RaidRoomBackdrop: View {
    let group: SkillCategory
    var enraged: Bool = false

    var body: some View {
        ZStack {
            staticChrome
            moteLayer
        }
        .ignoresSafeArea()
    }

    /// Non-animated layer: gradient + one blurred floor pool + vignette. Redraws only when `group`
    /// or `enraged` change — not every frame.
    private var staticChrome: some View {
        Canvas { ctx, size in
            let top = group.raidTintDeep.mixed(with: enraged ? .red : .clear, amount: enraged ? 0.28 : 0)
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(
                        Gradient(colors: [top.lightened(0.05),
                                          Color(red: 0.05, green: 0.06, blue: 0.07)]),
                        startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

            let pool = Path(ellipseIn: CGRect(x: size.width * 0.1, y: size.height * 0.72,
                                              width: size.width * 0.8, height: size.height * 0.4))
            var poolCtx = ctx
            poolCtx.addFilter(.blur(radius: size.width * 0.08))
            poolCtx.fill(pool, with: .color(group.raidTint.opacity(0.18)))

            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(
                        Gradient(colors: [.clear, .black.opacity(0.45)]),
                        center: CGPoint(x: size.width / 2, y: size.height * 0.42),
                        startRadius: size.width * 0.2, endRadius: size.width * 0.75))
        }
    }

    /// Only the drifting motes animate, at ~30fps with cheap circle fills (no blur).
    private var moteLayer: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let count = 12
                for i in 0..<count {
                    let seed = Double(i)
                    let speed = 0.03 + (seed.truncatingRemainder(dividingBy: 5) / 5) * 0.05
                    let x = (0.08 + (seed * 0.6180339).truncatingRemainder(dividingBy: 1) * 0.84) * size.width
                    let phase = (t * speed + seed * 0.37).truncatingRemainder(dividingBy: 1)
                    let y = (1 - phase) * size.height
                    let wobble = sin(t * 0.8 + seed) * size.width * 0.02
                    let r = size.width * (0.004 + (seed.truncatingRemainder(dividingBy: 3) / 3) * 0.006)
                    let alpha = 0.10 + 0.35 * sin(phase * .pi)
                    ctx.fill(Path(ellipseIn: CGRect(x: x + wobble - r, y: y - r, width: r * 2, height: r * 2)),
                             with: .color(group.raidTint.opacity(alpha)))
                }
            }
        }
    }
}

// MARK: - Color blending helpers

extension Color {
    /// Linear blend toward `other` in sRGB. `amount` 0 → self, 1 → other.
    func mixed(with other: Color, amount: Double) -> Color {
        let a = max(0, min(1, amount))
        let s = UIColor(self).rgba
        let o = UIColor(other).rgba
        return Color(red: s.r + (o.r - s.r) * a,
                     green: s.g + (o.g - s.g) * a,
                     blue: s.b + (o.b - s.b) * a)
    }
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

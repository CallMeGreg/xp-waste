import SwiftUI

/// A full-screen fireworks celebration for a milestone, thrown at the root so it overlays every tab.
///
/// Three intensities scale with the achievement — a single **level 99** gets fireworks, a **maxed
/// account** gets a denser, rainbow *mega* show, and the **200M XP** ceiling gets the longest, most
/// saturated *ultra-mega* barrage. Everything is drawn on one `Canvas` (rising rockets + exploding
/// spark particles under gravity), so hundreds of sparks stay cheap and crisp on iPhone and iPad.
/// The overlay ignores hits so the player can keep tapping underneath while it plays.
struct MilestoneCelebrationView: View {
    let event: MilestoneEvent

    @State private var start = Date()
    @State private var rockets: [Firework] = []
    @State private var bannerIn = false

    private var config: FireworksConfig {
        FireworksConfig.of(event.kind, accent: event.skill?.tint, skillName: event.skill?.displayName)
    }

    var body: some View {
        ZStack {
            // Darken the game a touch so the sparks pop — heavier for the bigger shows.
            Color.black.opacity(config.dimming)
                .ignoresSafeArea()
                .transition(.opacity)

            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    for rocket in rockets { rocket.draw(ctx, size: size, t: t) }
                }
                .ignoresSafeArea()
            }

            banner
                .scaleEffect(bannerIn ? 1 : 0.6)
                .opacity(bannerIn ? 1 : 0)
                .offset(y: -20)
        }
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            rockets = FireworksFactory.make(config)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.12)) { bannerIn = true }
        }
    }

    // MARK: Banner

    private var banner: some View {
        VStack(spacing: 12) {
            glyph
            Text(config.title)
                .font(.system(size: config.titleSize, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [config.tint.lightened(0.25), config.tint],
                                   startPoint: .top, endPoint: .bottom))
                .shadow(color: config.tint.opacity(0.6), radius: 12)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            Text(config.subtitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(config.tint.opacity(0.7), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
        .padding(.horizontal, 32)
    }

    @ViewBuilder
    private var glyph: some View {
        ZStack {
            Circle()
                .fill(config.tint.opacity(0.22))
                .frame(width: 76, height: 76)
            Circle()
                .strokeBorder(config.tint.opacity(0.6), lineWidth: 2)
                .frame(width: 76, height: 76)
            if let skill = event.skill {
                ArtworkView(art: skill.art, size: 44, color: skill.tint, emphasized: true)
            } else {
                Image(systemName: config.symbol)
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [config.tint.lightened(0.3), config.tint],
                                       startPoint: .top, endPoint: .bottom))
            }
        }
    }
}

// MARK: - Show configuration

/// The tunable shape of one celebration tier: copy, palette, and particle counts.
struct FireworksConfig {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color
    let palette: [Color]
    let rocketCount: Int
    let sparksPerRocket: Int
    let spawnWindow: Double     // seconds over which rockets launch
    let dimming: Double
    let titleSize: CGFloat

    /// How long the whole show runs before the overlay dismisses — the last rocket's launch plus
    /// enough time for its rise and burst to finish playing out.
    var displayDuration: Double { spawnWindow + 2.6 }

    static func of(_ kind: MilestoneKind, accent: Color?, skillName: String?) -> FireworksConfig {
        let gold = Color(red: 1.0, green: 0.82, blue: 0.30)
        let warm: [Color] = [gold, Color(red: 1.0, green: 0.55, blue: 0.24), .white,
                             Color(red: 1.0, green: 0.36, blue: 0.42)]
        let rainbow: [Color] = [
            Color(red: 1.0, green: 0.30, blue: 0.34), Color(red: 1.0, green: 0.60, blue: 0.24),
            gold, Color(red: 0.42, green: 0.90, blue: 0.46), Color(red: 0.30, green: 0.70, blue: 1.0),
            Color(red: 0.66, green: 0.46, blue: 1.0), Color(red: 1.0, green: 0.42, blue: 0.80)
        ]
        let skill = skillName ?? "this skill"
        switch kind {
        case .level99:
            return FireworksConfig(
                title: "Level 99!", subtitle: "Congratulations! You've mastered \(skill).",
                symbol: "star.fill", tint: accent ?? gold,
                palette: ([accent].compactMap { $0 } + warm),
                rocketCount: 8, sparksPerRocket: 20, spawnWindow: 1.7, dimming: 0.3, titleSize: 40)
        case .maxAccount:
            return FireworksConfig(
                title: "Maxed!", subtitle: "Congratulations! You've reached level 99 in every skill.",
                symbol: "crown.fill", tint: gold,
                palette: rainbow,
                rocketCount: 14, sparksPerRocket: 22, spawnWindow: 3.4, dimming: 0.44, titleSize: 48)
        case .maxXP:
            return FireworksConfig(
                title: "200M XP!", subtitle: "Congratulations! You've completed the ultimate \(skill) grind.",
                symbol: "infinity", tint: accent ?? gold,
                palette: ([accent].compactMap { $0 } + [.white, gold] + rainbow),
                rocketCount: 20, sparksPerRocket: 24, spawnWindow: 4.0, dimming: 0.54, titleSize: 46)
        }
    }
}

// MARK: - Particle system

/// One firework: a rocket that rises to a peak, then bursts into gravity-bound sparks that fade.
private struct Firework {
    let launchAt: Double        // seconds after the show starts
    let rise: Double            // seconds spent rising to the peak
    let life: Double            // seconds the burst lingers after exploding
    let originX: Double         // 0…1 horizontal launch column
    let peakY: Double           // 0…1 explosion height (0 = top)
    let color: Color
    let sparks: [Spark]

    struct Spark {
        let angle: Double       // radians
        let speed: Double       // fraction of the min screen dimension per second
        let radius: Double      // spark size as a fraction of the min dimension
        let twinkle: Double     // phase offset for a subtle shimmer
    }

    func draw(_ ctx: GraphicsContext, size: CGSize, t: Double) {
        let local = t - launchAt
        guard local >= 0 else { return }
        let w = size.width, h = size.height
        let dim = min(w, h)
        let peakPX = originX * w
        let peakPY = peakY * h

        if local < rise {
            drawRocket(ctx, w: w, h: h, dim: dim, peakPX: peakPX, peakPY: peakPY, p: local / rise)
        } else {
            let e = local - rise
            guard e <= life else { return }
            drawBurst(ctx, dim: dim, cx: peakPX, cy: peakPY, e: e)
        }
    }

    /// The rising trail: a bright head with a short fading tail, easing to a stop at the peak.
    private func drawRocket(_ ctx: GraphicsContext, w: CGFloat, h: CGFloat, dim: CGFloat,
                            peakPX: CGFloat, peakPY: CGFloat, p: Double) {
        let eased = 1 - pow(1 - p, 2)                    // decelerate toward the peak
        let startY = h + dim * 0.02
        let y = startY + (peakPY - startY) * eased
        let head = CGPoint(x: peakPX, y: y)
        let tail = CGPoint(x: peakPX, y: min(h, y + dim * 0.06 * (1 - p)))

        var trail = Path()
        trail.move(to: head)
        trail.addLine(to: tail)
        ctx.stroke(trail, with: .color(color.opacity(0.5 * (1 - p) + 0.2)),
                   style: StrokeStyle(lineWidth: dim * 0.006, lineCap: .round))
        let r = dim * 0.008
        ctx.fill(Path(ellipseIn: CGRect(x: head.x - r, y: head.y - r, width: r * 2, height: r * 2)),
                 with: .color(.white.opacity(0.9)))
    }

    /// The explosion: sparks fly out radially, decelerate, then arc down under gravity as they fade.
    private func drawBurst(_ ctx: GraphicsContext, dim: CGFloat, cx: CGFloat, cy: CGFloat, e: Double) {
        let prog = e / life
        let fade = pow(1 - prog, 1.4)
        let gravity = dim * 0.9                            // downward acceleration (pts/s²)
        // Radial expansion eases out so sparks shoot fast then settle.
        let expand = (1 - exp(-e * 3.2)) / 3.2

        // Opening flash — a small bright core in the shell's own color the instant it bursts. Kept
        // tight and tinted (not a big white disc) so several simultaneous bursts don't screen-stack
        // into a full-white frame.
        if e < 0.12 {
            let k = 1 - e / 0.12
            let fr = dim * (0.014 + e * 0.16)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - fr, y: cy - fr, width: fr * 2, height: fr * 2)),
                     with: .color(color.lightened(0.4).opacity(k * 0.5)))
        }

        for s in sparks {
            let travel = s.speed * dim * expand
            let x = cx + cos(s.angle) * travel
            let y = cy + sin(s.angle) * travel + 0.5 * gravity * e * e
            let shimmer = 0.75 + 0.25 * sin(e * 22 + s.twinkle)
            let alpha = fade * shimmer
            guard alpha > 0.02 else { continue }
            let r = dim * s.radius * (0.7 + 0.5 * fade)
            // A soft halo behind a brighter core reads as a glowing ember. Normal (source-over)
            // compositing keeps overlaps bounded by the color instead of stacking to white the way
            // additive/screen blending does once hundreds of sparks overlap.
            let halo = r * 1.8
            ctx.fill(Path(ellipseIn: CGRect(x: x - halo, y: y - halo, width: halo * 2, height: halo * 2)),
                     with: .color(color.opacity(alpha * 0.16)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(color.lightened(0.35).opacity(min(1, alpha * 1.1))))
        }
    }
}

private enum FireworksFactory {
    /// Builds a show's rockets: launch times spread across the spawn window, each bursting into a
    /// ring of sparks in one palette color, at a varied height and column across the screen.
    static func make(_ config: FireworksConfig) -> [Firework] {
        var rng = SystemRandomNumberGenerator()
        return (0..<config.rocketCount).map { i in
            let color = config.palette[i % config.palette.count]
            let launchAt = Double(i) / Double(max(1, config.rocketCount)) * config.spawnWindow
                + Double.random(in: -0.08...0.08, using: &rng)
            let sparks = (0..<config.sparksPerRocket).map { j -> Firework.Spark in
                // Even angular spread with a little jitter, so bursts read as rings, not clumps.
                let base = Double(j) / Double(config.sparksPerRocket) * 2 * .pi
                return Firework.Spark(
                    angle: base + Double.random(in: -0.12...0.12, using: &rng),
                    speed: Double.random(in: 0.42...0.72, using: &rng),
                    radius: Double.random(in: 0.006...0.011, using: &rng),
                    twinkle: Double.random(in: 0...6.28, using: &rng))
            }
            return Firework(
                launchAt: max(0, launchAt),
                rise: Double.random(in: 0.55...0.85, using: &rng),
                life: Double.random(in: 1.0...1.3, using: &rng),
                originX: Double.random(in: 0.16...0.84, using: &rng),
                peakY: Double.random(in: 0.16...0.46, using: &rng),
                color: color,
                sparks: sparks)
        }
    }
}

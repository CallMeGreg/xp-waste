import SwiftUI

/// Everything a room mechanic needs from the raid engine. The engine owns the clock, objective
/// progress, raid HP and boss phase; a mechanic just renders its interface and reports **one unit of
/// progress** (`onSuccess`) or a **failed dodge** (`onMistake`, which costs a raid-HP heart). Skilling
/// tempo penalties (a mistimed strike, a wrong pick) are handled inside the mechanic and don't drain
/// HP — raid HP is the *combat* resource, so a flawless run means you dodged everything.
struct RaidRoomContext {
    let params: Balance.RaidTierParams
    let tint: Color
    let group: SkillCategory
    let running: Bool
    let boss: RaidBoss?
    let bossHPFraction: Double
    let bossPhase: Int
    let enraged: Bool
    let hitToken: Int
    let onSuccess: () -> Void
    let onMistake: () -> Void

    var isBoss: Bool { boss != nil }
}

/// Shared bordered "stage" chrome so every room reads as one place.
private extension View {
    func raidPanel(_ tint: Color) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color.black.opacity(0.16)))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(tint.opacity(0.28), lineWidth: 1.5))
    }
}

// MARK: - Barrage — dodge the volley, strike in the gaps

/// Three lanes. Telegraphed hazards fall with one lane left safe; slide your ward into the gap
/// before the volley lands. Surviving a wave lands a counter-strike (progress); getting clipped
/// costs a heart. A pure **dodge-and-punish** loop — the whole verb is reading the safe lane.
struct BarrageRoom: View {
    let ctx: RaidRoomContext

    private struct Wave: Identifiable {
        let id = UUID()
        let blocked: Set<Int>
        let born: Date
        var resolved = false
    }

    @State private var lane = 1
    @State private var waves: [Wave] = []
    @State private var spawnAccumulator: Double = 0
    @State private var lastTick = Date()
    @State private var flashHit = false

    private let lanes = 3
    private let tick = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    private var fallTime: Double { ctx.params.targetLifetime + 0.5 }
    private var spawnEvery: Double { ctx.params.spawnInterval + 0.35 }

    var body: some View {
        GeometryReader { geo in
            let laneW = geo.size.width / CGFloat(lanes)
            let hitLine = geo.size.height * 0.82
            ZStack {
                // Lane columns.
                HStack(spacing: 0) {
                    ForEach(0..<lanes, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i == lane ? 0.06 : 0.02))
                            .overlay(Rectangle().stroke(Color.white.opacity(0.05)))
                    }
                }
                // Hit line.
                Rectangle().fill(ctx.tint.opacity(0.35)).frame(height: 2).position(x: geo.size.width / 2, y: hitLine)

                // Falling hazards.
                ForEach(waves) { wave in
                    let age = Date().timeIntervalSince(wave.born)
                    let progress = min(1, age / fallTime)
                    let y = progress * hitLine
                    ForEach(Array(wave.blocked), id: \.self) { l in
                        HazardBolt(tint: ctx.tint)
                            .frame(width: laneW * 0.5, height: laneW * 0.5)
                            .position(x: (CGFloat(l) + 0.5) * laneW, y: y)
                            .opacity(0.55 + 0.45 * progress)
                    }
                }

                // Player ward.
                WardIcon(tint: ctx.tint, flash: flashHit)
                    .frame(width: laneW * 0.62, height: laneW * 0.62)
                    .position(x: (CGFloat(lane) + 0.5) * laneW, y: hitLine)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: lane)

                // Tap zones to slide the ward.
                HStack(spacing: 0) {
                    ForEach(0..<lanes, id: \.self) { i in
                        Rectangle().fill(Color.white.opacity(0.001)).contentShape(Rectangle())
                            .onTapGesture { if ctx.running { lane = i } }
                    }
                }
            }
        }
        .raidPanel(ctx.tint)
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date(); lane = 1 }
    }

    private func step() {
        let now = Date()
        let dt = min(0.1, now.timeIntervalSince(lastTick))
        lastTick = now
        guard ctx.running else { return }

        // Resolve landed waves.
        for i in waves.indices where !waves[i].resolved {
            if now.timeIntervalSince(waves[i].born) >= fallTime {
                waves[i].resolved = true
                if waves[i].blocked.contains(lane) {
                    flash(); ctx.onMistake()
                } else {
                    ctx.onSuccess()
                }
            }
        }
        waves.removeAll { now.timeIntervalSince($0.born) >= fallTime + 0.15 }

        // Spawn cadence: block 1–2 lanes, always leave a gap.
        spawnAccumulator += dt
        if spawnAccumulator >= spawnEvery {
            spawnAccumulator = 0
            let blockCount = Bool.random() ? 2 : 1
            var blocked = Set<Int>()
            while blocked.count < blockCount { blocked.insert(Int.random(in: 0..<lanes)) }
            if blocked.count == lanes { blocked.remove(Int.random(in: 0..<lanes)) }
            waves.append(Wave(blocked: blocked, born: now))
        }
    }

    private func flash() {
        flashHit = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { flashHit = false }
    }
}

private struct HazardBolt: View {
    let tint: Color
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.white, tint, tint.opacity(0.2)],
                                         center: .center, startRadius: 0, endRadius: 18))
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
        }
        .shadow(color: tint.opacity(0.7), radius: 6)
    }
}

private struct WardIcon: View {
    let tint: Color
    let flash: Bool
    var body: some View {
        ZStack {
            Circle().fill(flash ? Color.red.opacity(0.85) : tint.opacity(0.9))
            Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2)
            Image(systemName: "shield.fill").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
        }
        .shadow(color: (flash ? Color.red : tint).opacity(0.7), radius: 8)
    }
}

// MARK: - Assault — break the boss's weakpoints, dodge its slams

/// The signature boss fight: the boss looms; glowing weakpoints flash across it — tap them fast to
/// deal damage. It telegraphs a slam (a closing red ring); tap **DODGE** before it lands or take a
/// hit. Enrages in its final phase with faster, tighter slams.
struct AssaultRoom: View {
    let ctx: RaidRoomContext

    private struct Weakpoint: Identifiable { let id = UUID(); let x: CGFloat; let y: CGFloat; let born: Date }

    @State private var points: [Weakpoint] = []
    @State private var spawnAccumulator: Double = 0
    @State private var sinceSlam: Double = 0
    @State private var slamStart: Date?
    @State private var lastTick = Date()

    private let tick = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()

    private var slamWindow: Double { ctx.params.targetLifetime }
    private var slamEvery: Double { ctx.params.spawnInterval * (ctx.enraged ? 2.4 : 3.4) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let boss = ctx.boss {
                    RaidBossView(boss: boss, hpFraction: ctx.bossHPFraction, enraged: ctx.enraged,
                                 hitToken: ctx.hitToken, size: min(geo.size.width, geo.size.height) * 0.66)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
                }

                ForEach(points) { pt in
                    let age = Date().timeIntervalSince(pt.born)
                    let remaining = max(0, 1 - age / (slamWindow + 0.3))
                    WeakpointReticle(tint: ctx.tint, remaining: remaining)
                        .frame(width: 54, height: 54)
                        .position(x: pt.x * geo.size.width, y: pt.y * geo.size.height)
                        .onTapGesture {
                            guard ctx.running else { return }
                            points.removeAll { $0.id == pt.id }
                            ctx.onSuccess()
                        }
                        .transition(.scale.combined(with: .opacity))
                }

                if let start = slamStart {
                    let age = Date().timeIntervalSince(start)
                    let close = max(0, 1 - age / slamWindow)
                    SlamPrompt(close: close)
                        .contentShape(Rectangle())
                        .onTapGesture { if ctx.running { slamStart = nil } }
                        .transition(.opacity)
                }
            }
        }
        .raidPanel(ctx.tint)
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date() }
    }

    private func step() {
        let now = Date()
        let dt = min(0.15, now.timeIntervalSince(lastTick))
        lastTick = now
        guard ctx.running else { return }

        points.removeAll { now.timeIntervalSince($0.born) > slamWindow + 0.3 }

        if let start = slamStart, now.timeIntervalSince(start) >= slamWindow {
            slamStart = nil
            ctx.onMistake()
        }

        spawnAccumulator += dt
        sinceSlam += dt
        let spawnEvery = ctx.params.spawnInterval * 0.9
        if spawnAccumulator >= spawnEvery, points.count < 3, slamStart == nil {
            spawnAccumulator = 0
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                points.append(Weakpoint(x: .random(in: 0.2...0.8), y: .random(in: 0.2...0.62), born: now))
            }
        }
        if slamStart == nil, sinceSlam >= slamEvery {
            sinceSlam = 0
            withAnimation { slamStart = now }
        }
    }
}

private struct WeakpointReticle: View {
    let tint: Color
    let remaining: Double
    var body: some View {
        ZStack {
            Circle().fill(tint.opacity(0.28))
            Circle().strokeBorder(.white, lineWidth: 2.5)
            Circle().trim(from: 0, to: remaining)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "burst.fill").font(.system(size: 18, weight: .black)).foregroundStyle(.white)
        }
        .shadow(color: tint.opacity(0.8), radius: 7)
    }
}

private struct SlamPrompt: View {
    let close: Double
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Color.red.opacity(0.22))
            // Closing danger ring.
            Circle().strokeBorder(Color.red.opacity(0.9), lineWidth: 6)
                .scaleEffect(0.5 + close * 0.9)
                .frame(width: 160, height: 160)
            VStack(spacing: 8) {
                Image(systemName: "hand.raised.fill").font(.system(size: 40, weight: .black))
                Text("DODGE!").font(.system(size: 30, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 4)
        }
    }
}

// MARK: - Forge — time the strike, build the combo

/// A marker sweeps a bar with a bright **perfect** core inside a **good** band. Strike inside the
/// band to land a blow; nailing the core builds a combo that reads as escalating heat. Mistimed
/// strikes break the combo and waste tempo (the clock is the pressure) — no HP lost outside slams.
struct ForgeRoom: View {
    let ctx: RaidRoomContext

    @State private var marker: Double = 0.5
    @State private var direction: Double = 1
    @State private var sweetCenter = 0.5
    @State private var lastTick = Date()
    @State private var combo = 0
    @State private var flash: FlashKind?

    private enum FlashKind { case perfect, good, miss }

    private let tick = Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()

    private var perfectHalf: Double { ctx.params.sweetHalfWidth }
    private var goodHalf: Double { ctx.params.sweetHalfWidth * 2.1 }
    private var speed: Double { 1.0 / (ctx.params.spawnInterval * 1.5) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            // Heat / combo readout.
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(combo >= 3 ? .orange : .secondary)
                Text(combo > 1 ? "Combo ×\(combo)" : "Strike the sweet-spot")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(combo > 1 ? .orange : .secondary)
                    .contentTransition(.numericText())
            }

            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule().fill(ctx.tint.opacity(0.30))
                        .frame(width: CGFloat(goodHalf * 2) * w)
                        .position(x: CGFloat(sweetCenter) * w, y: geo.size.height / 2)
                    Capsule().fill(ctx.tint)
                        .frame(width: CGFloat(perfectHalf * 2) * w)
                        .position(x: CGFloat(sweetCenter) * w, y: geo.size.height / 2)
                    // Marker.
                    RoundedRectangle(cornerRadius: 3).fill(Color.white)
                        .frame(width: 6)
                        .shadow(color: .white.opacity(0.8), radius: 4)
                        .position(x: CGFloat(marker) * w, y: geo.size.height / 2)
                }
                .overlay(
                    Capsule().strokeBorder(flashColor, lineWidth: flash == nil ? 0 : 3)
                )
            }
            .frame(height: 52)
            .padding(.horizontal, 6)

            Button { strike() } label: {
                Text("STRIKE")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .frame(maxWidth: .infinity).padding(.vertical, 20)
                    .background(
                        LinearGradient(colors: [ctx.tint.lightened(0.15), ctx.tint],
                                       startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)
                    .shadow(color: ctx.tint.opacity(0.5), radius: 8, y: 3)
            }
            .buttonStyle(PressableStyle(scale: 0.95))
            .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .padding(18)
        .raidPanel(ctx.tint)
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date(); randomize() }
    }

    private var flashColor: Color {
        switch flash {
        case .perfect: return .yellow
        case .good:    return .green
        case .miss:    return .red
        case .none:    return .clear
        }
    }

    private func step() {
        let now = Date()
        let dt = min(0.08, now.timeIntervalSince(lastTick))
        lastTick = now
        guard ctx.running else { return }
        marker += direction * speed * dt
        if marker >= 1 { marker = 1; direction = -1 }
        else if marker <= 0 { marker = 0; direction = 1 }
    }

    private func strike() {
        guard ctx.running else { return }
        let d = abs(marker - sweetCenter)
        if d <= perfectHalf {
            combo += 1; show(.perfect); ctx.onSuccess(); randomize()
        } else if d <= goodHalf {
            combo = max(1, combo); show(.good); ctx.onSuccess(); randomize()
        } else {
            combo = 0; show(.miss)
        }
    }

    private func show(_ k: FlashKind) {
        flash = k
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { if flash == k { flash = nil } }
    }

    private func randomize() {
        sweetCenter = Double.random(in: 0.18...0.82)
    }
}

// MARK: - Recognition — gather the called resource among decoys

/// A field of resource nodes; a banner calls the target ("Gather: Ore"). Tap matching nodes to
/// gather (progress); wrong picks stagger the board briefly (tempo cost). The called resource
/// rotates as you go, and the number of decoy species grows with tier.
struct RecognitionRoom: View {
    let ctx: RaidRoomContext

    private enum Resource: Int, CaseIterable {
        case log, fish, ore, herb, crop, gem, pelt
        var name: String { ["Log", "Fish", "Ore", "Herb", "Crop", "Gem", "Pelt"][rawValue] }
        var symbol: String { ["tree.fill", "fish.fill", "cube.fill", "leaf.fill", "carrot.fill", "diamond.fill", "pawprint.fill"][rawValue] }
        var color: Color {
            [Color(red: 0.55, green: 0.38, blue: 0.22), .cyan, .gray, .green, .orange,
             Color(red: 0.42, green: 0.66, blue: 0.95), Color(red: 0.72, green: 0.52, blue: 0.34)][rawValue]
        }
    }

    private let rows: Int
    private let itemMin: CGFloat = 66
    private let spacing: CGFloat = 10

    @State private var nodes: [Resource] = []
    @State private var target: Resource = .log
    @State private var correctSinceSwitch = 0
    @State private var staggered = false

    init(ctx: RaidRoomContext) {
        self.ctx = ctx
        self.rows = ctx.isBoss ? 2 : 3
    }

    private var palette: [Resource] {
        let count = min(Resource.allCases.count, max(2, ctx.params.decoyCount + 1))
        return Array(Resource.allCases.prefix(count))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("GATHER").font(.caption2.weight(.black)).foregroundStyle(.secondary).tracking(1)
                HStack(spacing: 7) {
                    Image(systemName: target.symbol).foregroundStyle(target.color)
                    Text(target.name).font(.headline.weight(.heavy))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(target.color.opacity(0.20), in: Capsule())
                .overlay(Capsule().strokeBorder(target.color.opacity(0.6), lineWidth: 1.5))
                Spacer()
            }

            GeometryReader { geo in
                let cols = columnCount(geo.size.width)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols), spacing: spacing) {
                    ForEach(Array(nodes.enumerated()), id: \.offset) { index, res in
                        Button { tap(index) } label: { NodeTile(res: res, target: res == target) }
                            .buttonStyle(PressableStyle(scale: 0.9))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .onAppear { sync(cols) }
                .onChange(of: cols) { _, c in sync(c) }
            }
            .opacity(staggered ? 0.4 : 1)
            .overlay(staggered ? RoundedRectangle(cornerRadius: 16).stroke(Color.red.opacity(0.6), lineWidth: 2) : nil)
        }
        .padding(16)
        .raidPanel(ctx.tint)
        .onAppear { setup() }
    }

    private func setup() {
        target = palette.randomElement() ?? .log
        correctSinceSwitch = 0
        ensureSolvable()
    }

    private func columnCount(_ width: CGFloat) -> Int {
        guard width > 0 else { return 3 }
        return min(6, max(3, Int((width + spacing) / (itemMin + spacing))))
    }

    private func sync(_ cols: Int) {
        let desired = max(cols, 1) * rows
        guard nodes.count != desired else { return }
        if nodes.count < desired {
            nodes.append(contentsOf: (0..<(desired - nodes.count)).map { _ in palette.randomElement() ?? .log })
        } else {
            nodes.removeLast(nodes.count - desired)
        }
        ensureSolvable()
    }

    private func tap(_ index: Int) {
        guard ctx.running, !staggered, nodes.indices.contains(index) else { return }
        let hit = nodes[index] == target
        nodes[index] = palette.randomElement() ?? .log
        if hit {
            ctx.onSuccess()
            correctSinceSwitch += 1
            if correctSinceSwitch >= 8 { rotate() }
        } else {
            stagger()
        }
        ensureSolvable()
    }

    private func stagger() {
        staggered = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { staggered = false }
    }

    private func rotate() {
        correctSinceSwitch = 0
        let pool = palette
        var next = pool.randomElement() ?? target
        if pool.count > 1 { while next == target { next = pool.randomElement() ?? target } }
        target = next
        ensureSolvable()
    }

    private func ensureSolvable() {
        if !nodes.contains(target), !nodes.isEmpty {
            nodes[Int.random(in: 0..<nodes.count)] = target
        }
    }

    private struct NodeTile: View {
        let res: Resource
        let target: Bool
        var body: some View {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(res.color.opacity(0.18))
                RoundedRectangle(cornerRadius: 14).strokeBorder(res.color.opacity(0.45), lineWidth: 1.5)
                Image(systemName: res.symbol).font(.system(size: 28, weight: .bold)).foregroundStyle(res.color)
            }
            .frame(height: 66)
        }
    }
}

// MARK: - Stealth — loot while the eye is turned

/// A sentinel's searchlight sweeps an arc. Loot only while it's turned away (the field goes calm);
/// tap while the beam is on you and the alarm costs a heart. Every tap in a safe window counts, so
/// greed is tempting — but the sweep speeds up with tier and (in a boss room) the beam is the boss.
struct StealthRoom: View {
    let ctx: RaidRoomContext

    @State private var beam: Double = 0           // 0…1 sweep position
    @State private var direction: Double = 1
    @State private var lastTick = Date()
    @State private var caught = false
    @State private var lootPulse = false

    private let tick = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    /// The beam covers a band around its centre; you're safe when its centre is far from the vault
    /// (fixed at 0.5). Faster sweep + wider beam at higher tiers.
    private var beamHalf: Double { 0.16 + Double(ctx.params.decoyCount) * 0.012 }
    private var sweepSpeed: Double { 1.0 / (ctx.params.spawnInterval * 2.2) }
    private var watched: Bool { abs(beam - 0.5) <= beamHalf }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // The watcher.
                VStack {
                    if let boss = ctx.boss {
                        RaidBossView(boss: boss, hpFraction: ctx.bossHPFraction, enraged: ctx.enraged,
                                     hitToken: ctx.hitToken, size: min(geo.size.width, geo.size.height) * 0.36)
                    } else {
                        Image(systemName: watched ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(watched ? .red : .green)
                    }
                    Spacer()
                }
                .padding(.top, 8)

                // Searchlight beam sweeping across.
                SearchBeam(position: beam, half: beamHalf, watched: watched)

                // Vault / loot target near the bottom centre.
                VStack {
                    Spacer()
                    Button { attempt() } label: {
                        VStack(spacing: 8) {
                            Image(systemName: caught ? "bell.fill" : "shippingbox.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(caught ? .red : (watched ? .white.opacity(0.5) : .green))
                                .scaleEffect(lootPulse ? 1.15 : 1)
                            Text(caught ? "CAUGHT!" : (watched ? "WATCHED — HOLD" : "CLEAR — LOOT"))
                                .font(.headline.weight(.heavy))
                                .foregroundStyle(caught ? .red : (watched ? .red.opacity(0.8) : .green))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(RoundedRectangle(cornerRadius: 18)
                            .fill((watched ? Color.red : Color.green).opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 18)
                            .strokeBorder((watched ? Color.red : Color.green).opacity(0.6), lineWidth: 2))
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                }
            }
        }
        .raidPanel(ctx.tint)
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date() }
    }

    private func step() {
        let now = Date()
        let dt = min(0.08, now.timeIntervalSince(lastTick))
        lastTick = now
        guard ctx.running else { return }
        beam += direction * sweepSpeed * dt
        if beam >= 1 { beam = 1; direction = -1 }
        else if beam <= 0 { beam = 0; direction = 1 }
    }

    private func attempt() {
        guard ctx.running else { return }
        if watched {
            caught = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { caught = false }
            ctx.onMistake()
        } else {
            lootPulse = true
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { lootPulse = false }
            ctx.onSuccess()
        }
    }
}

private struct SearchBeam: View {
    let position: Double
    let half: Double
    let watched: Bool
    var body: some View {
        GeometryReader { geo in
            let x = CGFloat(position) * geo.size.width
            Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x - CGFloat(half) * geo.size.width, y: geo.size.height))
                p.addLine(to: CGPoint(x: x + CGFloat(half) * geo.size.width, y: geo.size.height))
                p.closeSubpath()
            }
            .fill(LinearGradient(colors: [(watched ? Color.red : Color.yellow).opacity(0.32), .clear],
                                 startPoint: .top, endPoint: .bottom))
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Sequence — memorise then repeat the glyph pattern

/// A row of glyph runes flashes a pattern; repeat it back in order. A correct round is progress; a
/// wrong tap resets the round (tempo cost). The pattern grows with tier. A pure puzzle beat between
/// the action rooms.
struct SequenceRoom: View {
    let ctx: RaidRoomContext

    private enum Phase { case watch, input, right, wrong }

    @State private var pattern: [Int] = []
    @State private var inputIndex = 0
    @State private var highlight: Int?
    @State private var phase: Phase = .watch
    @State private var started = false

    private let padCount = 4

    private var glyphs: [String] { ["circle.hexagongrid.fill", "seal.fill", "sparkle", "hexagon.fill"] }
    private var glyphColors: [Color] {
        [ctx.tint, ctx.tint.lightened(0.3), Color.doubleXP, Color(red: 0.42, green: 0.66, blue: 0.95)]
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Text(prompt)
                .font(.headline.weight(.bold))
                .foregroundStyle(promptColor)
                .contentTransition(.opacity)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                ForEach(0..<padCount, id: \.self) { i in
                    Button { press(i) } label: { pad(i) }
                        .buttonStyle(PressableStyle(scale: 0.94))
                        .disabled(phase != .input)
                }
            }
            .frame(maxWidth: 360)
            Spacer(minLength: 0)
        }
        .padding(18)
        .raidPanel(ctx.tint)
        .onAppear { if !started { started = true; newRound() } }
    }

    private var prompt: String {
        switch phase {
        case .watch: return "Watch the pattern…"
        case .input: return "Repeat it — \(inputIndex)/\(pattern.count)"
        case .right: return "Correct!"
        case .wrong: return "Wrong — watch again"
        }
    }
    private var promptColor: Color {
        switch phase { case .right: return .green; case .wrong: return .red; default: return .secondary }
    }

    private func pad(_ i: Int) -> some View {
        let lit = highlight == i
        return ZStack {
            RoundedRectangle(cornerRadius: 18).fill(glyphColors[i].opacity(lit ? 0.9 : 0.16))
            RoundedRectangle(cornerRadius: 18).strokeBorder(glyphColors[i].opacity(lit ? 1 : 0.4), lineWidth: 2)
            Image(systemName: glyphs[i]).font(.system(size: 34, weight: .bold))
                .foregroundStyle(lit ? .white : glyphColors[i])
        }
        .frame(height: 92)
        .scaleEffect(lit ? 1.05 : 1)
        .shadow(color: lit ? glyphColors[i].opacity(0.8) : .clear, radius: 10)
        .animation(.easeOut(duration: 0.18), value: lit)
    }

    private func newRound() {
        let len = max(2, ctx.params.sequenceLength)
        pattern = (0..<len).map { _ in Int.random(in: 0..<padCount) }
        inputIndex = 0
        phase = .watch
        playback()
    }

    private func playback() {
        var delay = 0.4
        for (i, g) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard ctx.running else { return }
                highlight = g
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { if highlight == g { highlight = nil } }
                if i == pattern.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .input }
                }
            }
            delay += 0.55
        }
    }

    private func press(_ i: Int) {
        guard ctx.running, phase == .input else { return }
        highlight = i
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { if highlight == i { highlight = nil } }
        if pattern[inputIndex] == i {
            inputIndex += 1
            if inputIndex >= pattern.count {
                phase = .right
                ctx.onSuccess()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { if ctx.running { newRound() } }
            }
        } else {
            phase = .wrong
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                inputIndex = 0
                phase = .watch
                playback()
            }
        }
    }
}

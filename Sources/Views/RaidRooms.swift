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

// MARK: - Duel — trade blows with the boss (tap red to strike, tap green to parry)

/// The marquee combat finale. The boss looms in the centre and the fight is fought entirely with
/// **circles**: **red** rings flash open on the boss — tap them to land a blow (damage) — while
/// **green** rings close in from the edges as the boss attacks — tap them to parry before they seal,
/// or take the hit (a heart). Both can crowd the screen at once, so you triage offence against
/// defence. There is **no full-screen dodge**; enrage floods more green, faster.
struct DuelRoom: View {
    let ctx: RaidRoomContext

    private enum Kind { case strike, parry }
    private struct Orb: Identifiable {
        let id = UUID()
        let kind: Kind
        let x: CGFloat
        let y: CGFloat
        let born: Date
        let life: Double
    }

    @State private var orbs: [Orb] = []
    @State private var sinceStrike: Double = 0
    @State private var sinceParry: Double = 0
    @State private var lastTick = Date()
    @State private var hurtFlash = false

    private let tick = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

    private var strikeEvery: Double { ctx.params.spawnInterval * (ctx.enraged ? 0.7 : 0.95) }
    private var parryEvery: Double { ctx.params.spawnInterval * (ctx.enraged ? 1.25 : 1.9) }
    private var strikeLife: Double { ctx.params.targetLifetime * 1.35 }
    private var parryLife: Double { ctx.params.targetLifetime }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if let boss = ctx.boss {
                    RaidBossView(boss: boss, hpFraction: ctx.bossHPFraction, enraged: ctx.enraged,
                                 hitToken: ctx.hitToken, size: side * 0.6)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                }

                ForEach(orbs) { orb in
                    let age = Date().timeIntervalSince(orb.born)
                    let remaining = max(0, 1 - age / orb.life)
                    DuelOrb(strike: orb.kind == .strike, tint: ctx.tint, remaining: remaining)
                        .frame(width: 60, height: 60)
                        .position(x: orb.x * geo.size.width, y: orb.y * geo.size.height)
                        .onTapGesture { hit(orb) }
                        .transition(.scale.combined(with: .opacity))
                }

                if hurtFlash {
                    RoundedRectangle(cornerRadius: 22).stroke(Color.red, lineWidth: 5)
                        .transition(.opacity)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        legendChip(color: Color(red: 0.95, green: 0.32, blue: 0.28),
                                   symbol: "burst.fill", label: "Strike")
                        legendChip(color: Color(red: 0.30, green: 0.95, blue: 0.5),
                                   symbol: "shield.lefthalf.filled", label: "Parry")
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .raidPanel(ctx.tint)
        .onReceive(tick) { _ in step() }
        .onAppear {
            lastTick = Date()
            // Prime the first strike so the fight reads as active from the very first frame.
            sinceStrike = strikeEvery * 0.7
            sinceParry = parryEvery * 0.4
        }
    }

    private func legendChip(color: Color, symbol: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2.weight(.black))
            Text(label).font(.caption2.weight(.bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.4)))
    }

    private func hit(_ orb: Orb) {
        guard ctx.running, orbs.contains(where: { $0.id == orb.id }) else { return }
        orbs.removeAll { $0.id == orb.id }
        if orb.kind == .strike { ctx.onSuccess() }   // parrying is pure defence — no damage dealt
    }

    private func step() {
        let now = Date()
        let dt = min(0.15, now.timeIntervalSince(lastTick))
        lastTick = now
        guard ctx.running else { return }

        // Expire orbs: a lapsed strike is just a missed opening; a lapsed parry lands a blow.
        var missedParry = false
        orbs.removeAll { orb in
            guard now.timeIntervalSince(orb.born) >= orb.life else { return false }
            if orb.kind == .parry { missedParry = true }
            return true
        }
        if missedParry { flashHurt(); ctx.onMistake() }

        sinceStrike += dt; sinceParry += dt
        let strikes = orbs.filter { $0.kind == .strike }.count
        let parries = orbs.filter { $0.kind == .parry }.count
        if sinceStrike >= strikeEvery, strikes < 3 {
            sinceStrike = 0
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                orbs.append(Orb(kind: .strike, x: .random(in: 0.30...0.70), y: .random(in: 0.26...0.60),
                                born: now, life: strikeLife))
            }
        }
        if sinceParry >= parryEvery, parries < (ctx.enraged ? 3 : 2) {
            sinceParry = 0
            // Parry orbs arrive at the edges, reading as incoming blows.
            let edge = [CGPoint(x: .random(in: 0.10...0.24), y: .random(in: 0.24...0.80)),
                        CGPoint(x: .random(in: 0.76...0.90), y: .random(in: 0.24...0.80)),
                        CGPoint(x: .random(in: 0.30...0.70), y: .random(in: 0.74...0.90))].randomElement()!
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                orbs.append(Orb(kind: .parry, x: edge.x, y: edge.y, born: now, life: parryLife))
            }
        }
    }

    private func flashHurt() {
        hurtFlash = true
        withAnimation(.easeOut(duration: 0.35)) { hurtFlash = false }
    }
}

/// One duel circle: a **red** strike orb (tap to hit) or a **green** parry ring — each with a closing
/// arc timer showing how long the opening stays open / before the incoming blow lands.
private struct DuelOrb: View {
    let strike: Bool
    let tint: Color
    let remaining: Double
    var body: some View {
        if strike {
            ZStack {
                Circle().fill(RadialGradient(colors: [.white, Color(red: 0.95, green: 0.32, blue: 0.28),
                                                      Color(red: 0.6, green: 0.12, blue: 0.12)],
                                             center: .center, startRadius: 0, endRadius: 30))
                // Closing timer arc — the opening seals when it completes (mirrors the parry ring).
                Circle().stroke(.white.opacity(0.3), lineWidth: 3)
                Circle().trim(from: 0, to: remaining)
                    .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "burst.fill").font(.system(size: 20, weight: .black)).foregroundStyle(.white)
            }
            .shadow(color: Color.red.opacity(0.7), radius: 8)
        } else {
            ZStack {
                Circle().fill(Color(red: 0.20, green: 0.85, blue: 0.45).opacity(0.18))
                Circle().stroke(Color(red: 0.30, green: 0.95, blue: 0.5).opacity(0.5), lineWidth: 2)
                // Closing timer arc — the blow lands when it completes.
                Circle().trim(from: 0, to: remaining)
                    .stroke(Color(red: 0.30, green: 1.0, blue: 0.55),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "shield.lefthalf.filled").font(.system(size: 18, weight: .black))
                    .foregroundStyle(Color(red: 0.4, green: 1.0, blue: 0.6))
            }
            .shadow(color: Color.green.opacity(0.6), radius: 7)
        }
    }
}

// MARK: - Swipe-dodge — read the beast's lunge, sidestep, counter

/// The Sand Beast mini-boss. It rears and **telegraphs a lunge** with a bright arrow and a closing
/// ring; **swipe the shown way** to sidestep and land an automatic counter (damage). Let the ring
/// close without swiping and it mauls you (a heart). A pure read-and-react gesture duel — no taps.
struct SwipeDodgeRoom: View {
    let ctx: RaidRoomContext

    private enum Dir: CaseIterable { case left, right, up
        var vector: CGSize { switch self { case .left: return .init(width: -1, height: 0)
            case .right: return .init(width: 1, height: 0); case .up: return .init(width: 0, height: -1) } }
        var symbol: String { switch self { case .left: return "arrow.left"; case .right: return "arrow.right"; case .up: return "arrow.up" } }
    }

    @State private var lunge: (dir: Dir, born: Date)?
    @State private var sinceLunge: Double = 0
    @State private var lastTick = Date()
    @State private var counterFlash = false
    @State private var missFlash = false

    private let tick = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()
    private var window: Double { ctx.params.targetLifetime * 1.15 }
    private var cadence: Double { ctx.params.spawnInterval * (ctx.enraged ? 1.1 : 1.7) }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if let boss = ctx.boss {
                    RaidBossView(boss: boss, hpFraction: ctx.bossHPFraction, enraged: ctx.enraged,
                                 hitToken: ctx.hitToken, size: side * 0.6)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                        .scaleEffect(lunge != nil ? 1.06 : 1)
                        .animation(.easeInOut(duration: 0.2), value: lunge != nil)
                }

                if let l = lunge {
                    let remaining = max(0, 1 - Date().timeIntervalSince(l.born) / window)
                    LungeTell(dir: l.dir.symbol, remaining: remaining,
                              offset: CGSize(width: l.dir.vector.width * side * 0.32,
                                             height: l.dir.vector.height * side * 0.32))
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.44)
                }

                if counterFlash {
                    Text("COUNTER!").font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(ctx.tint).shadow(color: .black.opacity(0.5), radius: 3)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.16)
                        .transition(.scale.combined(with: .opacity))
                }
                if missFlash {
                    RoundedRectangle(cornerRadius: 22).stroke(Color.red, lineWidth: 5).transition(.opacity)
                }

                VStack {
                    Spacer()
                    Text(lunge == nil ? "Watch for the lunge…" : "Swipe \(swipeWord)!")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(lunge == nil ? Color.secondary : Color.white)
                        .padding(.bottom, 12)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 24).onEnded { value in resolve(swipe: value.translation) })
        }
        .raidPanel(ctx.tint)
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date() }
    }

    private var swipeWord: String {
        switch lunge?.dir { case .left: return "left"; case .right: return "right"; case .up: return "up"; case nil: return "" }
    }

    private func resolve(swipe: CGSize) {
        guard ctx.running, let l = lunge else { return }
        let horizontal = abs(swipe.width) > abs(swipe.height)
        let matched: Bool
        switch l.dir {
        case .left:  matched = horizontal && swipe.width < 0
        case .right: matched = horizontal && swipe.width > 0
        case .up:    matched = !horizontal && swipe.height < 0
        }
        if matched {
            lunge = nil; sinceLunge = 0
            counterFlash = true
            withAnimation(.easeOut(duration: 0.4)) { counterFlash = false }
            ctx.onSuccess()
        }
    }

    private func step() {
        let now = Date()
        let dt = min(0.15, now.timeIntervalSince(lastTick))
        lastTick = now
        guard ctx.running else { return }
        if let l = lunge {
            if now.timeIntervalSince(l.born) >= window {
                lunge = nil; sinceLunge = 0
                missFlash = true
                withAnimation(.easeOut(duration: 0.35)) { missFlash = false }
                ctx.onMistake()
            }
            return
        }
        sinceLunge += dt
        if sinceLunge >= cadence {
            sinceLunge = 0
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                lunge = (Dir.allCases.randomElement()!, now)
            }
        }
    }
}

private struct LungeTell: View {
    let dir: String
    let remaining: Double
    let offset: CGSize
    var body: some View {
        ZStack {
            Circle().stroke(Color.red.opacity(0.9), lineWidth: 5)
                .scaleEffect(0.6 + remaining * 0.8).frame(width: 130, height: 130)
            Image(systemName: dir).font(.system(size: 44, weight: .black))
                .foregroundStyle(.white).shadow(color: .red, radius: 6)
                .offset(offset)
        }
    }
}

// MARK: - Forge — time the strike, build the combo

/// A marker sweeps a bar with a bright **perfect** core inside a **good** band. Strike inside the
/// band to land a blow; nailing the core builds a combo that reads as escalating heat. Mistimed
/// strikes break the combo and waste tempo (the clock is the pressure) — no HP lost outside slams.
struct ForgeRoom: View {
    let ctx: RaidRoomContext

    @State private var startDate = Date()
    @State private var sweetCenter = 0.5
    @State private var combo = 0
    @State private var flash: FlashKind?

    private enum FlashKind { case perfect, good, miss }

    private var perfectHalf: Double { ctx.params.sweetHalfWidth }
    private var goodHalf: Double { ctx.params.sweetHalfWidth * 2.1 }
    private var speed: Double { 1.0 / (ctx.params.spawnInterval * 1.5) }

    /// The marker is a pure triangle wave of elapsed time, so the sweep is driven by a lightweight
    /// `TimelineView` (only the marker layer redraws), capped to ~30 fps to match the other rooms
    /// rather than free-running at the display refresh rate.
    private func markerValue(_ elapsed: Double) -> Double {
        let phase = (max(0, elapsed) * speed).truncatingRemainder(dividingBy: 2)
        return phase <= 1 ? phase : 2 - phase
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(combo >= 3 ? Color.orange : Color.secondary)
                Text(combo > 1 ? "Combo ×\(combo)" : "Strike the sweet-spot")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(combo > 1 ? Color.orange : Color.secondary)
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
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { tl in
                        let m = markerValue(tl.date.timeIntervalSince(startDate))
                        RoundedRectangle(cornerRadius: 3).fill(Color.white)
                            .frame(width: 6)
                            .shadow(color: .white.opacity(0.8), radius: 4)
                            .position(x: CGFloat(m) * w, y: geo.size.height / 2)
                    }
                }
                .overlay(Capsule().strokeBorder(flashColor, lineWidth: flash == nil ? 0 : 3))
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
        .onAppear { startDate = Date(); randomize() }
    }

    private var flashColor: Color {
        switch flash {
        case .perfect: return .yellow
        case .good:    return .green
        case .miss:    return .red
        case .none:    return .clear
        }
    }

    private func strike() {
        guard ctx.running else { return }
        let marker = markerValue(Date().timeIntervalSince(startDate))
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

    private let tick = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()

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
    @State private var alarm = 0     // boss room: two slips trip the Warden's alarm → a heart

    private let padCount = 4
    private let alarmLimit = 2

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

            if ctx.isBoss {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill").font(.caption2).foregroundStyle(.secondary)
                    ForEach(0..<alarmLimit, id: \.self) { i in
                        Circle().fill(i < alarm ? Color.red : Color.white.opacity(0.22))
                            .frame(width: 7, height: 7)
                    }
                    Text("alarm").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

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
        .onAppear { startIfNeeded() }
        .onChange(of: ctx.running) { _, running in if running { startIfNeeded() } }
    }

    /// Kick off the first pattern only once the room is actually *playing*. The mechanic mounts while
    /// the room-intro card is still up (`running == false`); `playback()` schedules its steps through
    /// `asyncAfter`, and those closures capture the room state *by value*, so starting at mount would
    /// arm a sequence that silently bails on every step and never re-fires — leaving the room frozen on
    /// "Watch the pattern…". Start on appear if we're already live, otherwise when `running` flips true.
    private func startIfNeeded() {
        guard ctx.running, !started else { return }
        started = true
        newRound()
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
            if ctx.isBoss {
                alarm += 1
                if alarm >= alarmLimit { alarm = 0; ctx.onMistake() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                inputIndex = 0
                phase = .watch
                playback()
            }
        }
    }
}

// MARK: - Charge — stoke the Slag Golem's core, release inside the band (press-and-hold)

struct ChargeRoom: View {
    let ctx: RaidRoomContext

    @State private var heat: Double = 0
    @State private var holding = false
    @State private var bandCenter: Double = 0.6
    @State private var lastTick = Date()
    @State private var flash: Flash?
    @State private var started = false

    private enum Flash { case good, over, early }

    private let tick = Timer.publish(every: 0.033, on: .main, in: .common).autoconnect()
    private var bandHalf: Double { max(0.07, ctx.params.sweetHalfWidth * 2.1) }
    private var overheatAt: Double { min(0.99, bandCenter + bandHalf + 0.05) }
    private var fillRate: Double { 1.0 / max(0.7, ctx.params.spawnInterval * 1.5) }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Text(hint).font(.headline.weight(.bold)).foregroundStyle(hintColor)
                .contentTransition(.opacity)

            GeometryReader { geo in
                let h = geo.size.height, w = geo.size.width
                ZStack {
                    Capsule().fill(Color.black.opacity(0.35))
                    // Overheat zone (top)
                    Rectangle().fill(Color.red.opacity(0.22))
                        .frame(height: CGFloat(1 - overheatAt) * h)
                        .position(x: w / 2, y: CGFloat(1 - overheatAt) * h / 2)
                    // Target band
                    Rectangle().fill(ctx.tint.opacity(0.9))
                        .frame(height: CGFloat(bandHalf * 2) * h)
                        .position(x: w / 2, y: CGFloat(1 - bandCenter) * h)
                    Rectangle().fill(.white.opacity(0.9)).frame(height: 2)
                        .position(x: w / 2, y: CGFloat(1 - bandCenter) * h)
                    // Heat fill
                    LinearGradient(colors: [Color.orange, Color.red, Color.yellow],
                                   startPoint: .bottom, endPoint: .top)
                        .frame(height: CGFloat(heat) * h)
                        .position(x: w / 2, y: h - CGFloat(heat) * h / 2)
                        .opacity(0.92)
                    Rectangle().fill(.white).frame(height: 3)
                        .shadow(color: .orange, radius: 6)
                        .position(x: w / 2, y: CGFloat(1 - heat) * h)
                }
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(borderColor, lineWidth: 3))
            }
            .frame(width: 96)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            RoundedRectangle(cornerRadius: 18)
                .fill(holding ? ctx.tint.opacity(0.9) : ctx.tint.opacity(0.5))
                .frame(height: 68)
                .frame(maxWidth: 320)
                .overlay(
                    Label(holding ? "Release in the band" : "Hold to stoke",
                          systemImage: holding ? "flame.fill" : "flame")
                        .font(.headline.weight(.bold)).foregroundStyle(.white)
                )
                .scaleEffect(holding ? 0.97 : 1)
                .animation(.easeOut(duration: 0.12), value: holding)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in if !holding, ctx.running { startHold() } }
                        .onEnded { _ in release() }
                )
            Spacer(minLength: 0)
        }
        .padding(18)
        .raidPanel(ctx.tint)
        .onAppear { if !started { started = true; randomizeBand() } }
        .onReceive(tick) { now in
            let dt = now.timeIntervalSince(lastTick); lastTick = now
            guard ctx.running, holding else { return }
            heat = min(1, heat + fillRate * dt)
            if heat >= overheatAt {
                holding = false
                heat = overheatAt
                flash = .over
                ctx.onMistake()
                resetSoon()
            }
        }
    }

    private var hint: String {
        switch flash {
        case .good: return "Tempered!"
        case .over: return "Overheated!"
        case .early: return "Too cold — hold longer"
        case nil: return "Stoke into the band, then release"
        }
    }
    private var hintColor: Color {
        switch flash { case .good: return .green; case .over, .early: return .red; case nil: return .secondary }
    }
    private var borderColor: Color {
        switch flash { case .good: return .green; case .over: return .red; default: return .white.opacity(0.18) }
    }

    private func startHold() {
        holding = true; heat = 0; flash = nil; lastTick = Date()
    }
    private func release() {
        guard holding else { return }
        holding = false
        if abs(heat - bandCenter) <= bandHalf {
            flash = .good; ctx.onSuccess()
        } else if heat < bandCenter - bandHalf {
            flash = .early; ctx.onMistake()
        } else {
            flash = .over; ctx.onMistake()
        }
        resetSoon()
    }
    private func resetSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            heat = 0; flash = nil; randomizeBand()
        }
    }
    private func randomizeBand() {
        bandCenter = Double.random(in: 0.42...(0.9 - bandHalf))
    }
}

// MARK: - Dial — align the Forge Master's key notch to the top before the press-timer runs out

struct DialRoom: View {
    let ctx: RaidRoomContext

    @State private var keyAngle: Double = .pi
    @State private var dialRotation: Double = 0
    @State private var lastDragWidth: CGFloat = 0
    @State private var pressStart = Date()
    @State private var spark = false
    @State private var started = false
    @State private var lastTick = Date()

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var tolerance: Double { max(0.14, ctx.params.sweetHalfWidth * 2.6) }
    private var pressWindow: Double { max(1.4, ctx.params.targetLifetime * 2.4 * (ctx.enraged ? 0.75 : 1)) }
    private let sensitivity: Double = 0.012
    private var offset: Double { wrap(keyAngle + dialRotation) }
    private var aligned: Bool { abs(offset) <= tolerance }

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Text(aligned ? "Aligned — hold steady!" : "Rotate the key notch to the top")
                .font(.headline.weight(.bold))
                .foregroundStyle(aligned ? Color.green : Color.secondary)
                .contentTransition(.opacity)

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let radius = side * 0.42
                ZStack {
                    // Press timer ring
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { tl in
                        let left = max(0, 1 - tl.date.timeIntervalSince(pressStart) / pressWindow)
                        Circle()
                            .trim(from: 0, to: left)
                            .stroke(left < 0.3 ? Color.red : ctx.tint.opacity(0.8),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: radius * 2 + 30, height: radius * 2 + 30)
                    }
                    // Dial body
                    Circle().fill(Color.black.opacity(0.35))
                        .frame(width: radius * 2, height: radius * 2)
                    Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 2)
                        .frame(width: radius * 2, height: radius * 2)
                    ForEach(0..<12, id: \.self) { t in
                        Capsule().fill(.white.opacity(0.16)).frame(width: 2, height: 10)
                            .offset(y: -radius + 8)
                            .rotationEffect(.degrees(Double(t) / 12 * 360))
                    }
                    // Top target wedge
                    Triangle().fill(aligned ? Color.green : Color.white.opacity(0.55))
                        .frame(width: 20, height: 14)
                        .offset(y: -radius - 14)
                    // Key notch
                    ZStack {
                        Capsule().fill(aligned ? Color.green : ctx.tint)
                            .frame(width: 14, height: 34)
                        Image(systemName: "key.fill").font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white).rotationEffect(.degrees(180))
                    }
                    .offset(y: -radius)
                    .rotationEffect(.radians(keyAngle + dialRotation))
                    .shadow(color: aligned ? .green.opacity(0.8) : .clear, radius: 8)
                    // Hub
                    Circle().fill(ctx.tint.opacity(0.85)).frame(width: 34, height: 34)
                    Image(systemName: "gearshape.fill").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white).opacity(0.9)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(spark ? 1.04 : 1)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard ctx.running else { return }
                            let d = v.translation.width - lastDragWidth
                            lastDragWidth = v.translation.width
                            dialRotation += Double(d) * sensitivity
                            if aligned { lockIn() }
                        }
                        .onEnded { _ in lastDragWidth = 0 }
                )
            }
            .frame(maxWidth: 360, maxHeight: 360)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(18)
        .raidPanel(ctx.tint)
        .onAppear { if !started { started = true; newRound() } }
        .onReceive(tick) { now in
            guard ctx.running else { return }
            if now.timeIntervalSince(pressStart) >= pressWindow {
                ctx.onMistake()
                sparkMiss()
                newRound()
            }
        }
    }

    private func lockIn() {
        ctx.onSuccess()
        newRound()
    }
    private func sparkMiss() {
        withAnimation(.easeOut(duration: 0.12)) { spark = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeIn(duration: 0.12)) { spark = false }
        }
    }
    private func newRound() {
        pressStart = Date()
        let target = Double.random(in: 0.9...(2 * Double.pi - 0.9))
        keyAngle = wrap(target - dialRotation)
    }
    private func wrap(_ a: Double) -> Double {
        var x = a.truncatingRemainder(dividingBy: 2 * .pi)
        if x > .pi { x -= 2 * .pi }
        if x < -.pi { x += 2 * .pi }
        return x
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Path trace — guide the loot past the Warhound without straying from the corridor

struct PathTraceRoom: View {
    let ctx: RaidRoomContext

    @State private var waypoints: [CGPoint] = []
    @State private var current = 1
    @State private var token = CGPoint(x: 0.5, y: 0.9)
    @State private var strayUntil = Date.distantPast
    @State private var strayFlash = false
    @State private var started = false

    private var corridorHalf: CGFloat { max(0.09, CGFloat(ctx.params.sweetHalfWidth) * 2.0) }
    private let reachR: CGFloat = 0.075

    var body: some View {
        VStack(spacing: 12) {
            Text(strayFlash ? "Off the trail!" : "Trace the path — keep inside the corridor")
                .font(.headline.weight(.bold))
                .foregroundStyle(strayFlash ? Color.red : Color.secondary)
                .contentTransition(.opacity)

            GeometryReader { geo in
                let sz = geo.size
                ZStack {
                    // Corridor
                    if waypoints.count > 1 {
                        Path { p in
                            p.move(to: pt(waypoints[0], sz))
                            for w in waypoints.dropFirst() { p.addLine(to: pt(w, sz)) }
                        }
                        .stroke(ctx.tint.opacity(0.18),
                                style: StrokeStyle(lineWidth: corridorHalf * 2 * sz.width, lineCap: .round, lineJoin: .round))
                        Path { p in
                            p.move(to: pt(waypoints[0], sz))
                            for w in waypoints.dropFirst() { p.addLine(to: pt(w, sz)) }
                        }
                        .stroke(ctx.tint.opacity(0.5),
                                style: StrokeStyle(lineWidth: 2, dash: [6, 7]))
                    }
                    // Waypoint gems
                    ForEach(Array(waypoints.enumerated()), id: \.offset) { idx, w in
                        Circle()
                            .fill(idx < current ? Color.green : (idx == current ? ctx.tint : Color.white.opacity(0.25)))
                            .frame(width: idx == current ? 20 : 14, height: idx == current ? 20 : 14)
                            .position(pt(w, sz))
                            .shadow(color: idx == current ? ctx.tint.opacity(0.8) : .clear, radius: 6)
                    }
                    // Token
                    ZStack {
                        Circle().fill(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom))
                            .frame(width: 30, height: 30)
                        Image(systemName: "bag.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.brown)
                    }
                    .position(pt(token, sz))
                    .shadow(color: strayFlash ? .red : .black.opacity(0.4), radius: strayFlash ? 10 : 4)
                }
                .frame(width: sz.width, height: sz.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard ctx.running else { return }
                            let u = CGPoint(x: min(1, max(0, v.location.x / sz.width)),
                                            y: min(1, max(0, v.location.y / sz.height)))
                            token = u
                            evaluate(u)
                        }
                )
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
        .raidPanel(ctx.tint)
        .onAppear { if !started { started = true; regenerate(startNear: token) } }
    }

    private func pt(_ u: CGPoint, _ sz: CGSize) -> CGPoint {
        CGPoint(x: u.x * sz.width, y: u.y * sz.height)
    }

    private func evaluate(_ u: CGPoint) {
        guard current < waypoints.count else { return }
        let target = waypoints[current]
        if hypot(u.x - target.x, u.y - target.y) < reachR {
            ctx.onSuccess()
            current += 1
            if current >= waypoints.count { regenerate(startNear: target) }
            return
        }
        // Stray check against the active segment
        let a = waypoints[current - 1], b = waypoints[current]
        let d = distToSegment(u, a, b)
        if d > corridorHalf, Date() > strayUntil {
            ctx.onMistake()
            strayUntil = Date().addingTimeInterval(0.7)
            token = a
            withAnimation(.easeOut(duration: 0.12)) { strayFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { strayFlash = false }
            }
        }
    }

    private func regenerate(startNear: CGPoint) {
        let n = max(4, min(7, 3 + ctx.params.sequenceLength))
        var pts: [CGPoint] = [CGPoint(x: startNear.x, y: 0.9)]
        let step = 0.78 / CGFloat(n - 1)
        for i in 1..<n {
            let y = 0.9 - step * CGFloat(i)
            let x: CGFloat = i % 2 == 0 ? 0.7 : 0.3
            pts.append(CGPoint(x: x + CGFloat.random(in: -0.05...0.05), y: y))
        }
        waypoints = pts
        current = 1
        token = pts[0]
    }

    private func distToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        if len2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
        var t = ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
        t = min(1, max(0, t))
        let px = a.x + t * dx, py = a.y + t * dy
        return hypot(p.x - px, p.y - py)
    }
}

// MARK: - Mash — haul the River Serpent's net, but freeze when it thrashes

struct MashRoom: View {
    let ctx: RaidRoomContext

    @State private var haul: Double = 0.12
    @State private var thrashing = false
    @State private var sinceThrash: Double = 0
    @State private var thrashAge: Double = 0
    @State private var lastTick = Date()
    @State private var badFlash = false
    @State private var started = false

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let decay: Double = 0.26
    private let perTap: Double = 0.085
    private var thrashEvery: Double { max(1.6, ctx.params.spawnInterval * (ctx.enraged ? 1.7 : 2.6)) }
    private var thrashWindow: Double { max(0.7, ctx.params.targetLifetime * (ctx.enraged ? 1.1 : 0.85)) }

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Text(thrashing ? "It thrashes — STOP!" : "Mash to haul the net")
                .font(.headline.weight(.bold))
                .foregroundStyle(thrashing ? Color.red : Color.secondary)
                .contentTransition(.opacity)

            // Haul bar
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule()
                        .fill(LinearGradient(colors: [ctx.tint, ctx.tint.lightened(0.35)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, CGFloat(haul) * w))
                }
                .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 2))
            }
            .frame(height: 26)
            .frame(maxWidth: 360)

            Button {
                mash()
            } label: {
                ZStack {
                    Circle()
                        .fill(thrashing
                              ? Color.red.opacity(0.85)
                              : ctx.tint.opacity(0.85))
                    Circle().strokeBorder(.white.opacity(0.25), lineWidth: 3)
                    Image(systemName: thrashing ? "hand.raised.fill" : "figure.fishing")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 200, height: 200)
                .scaleEffect(badFlash ? 0.92 : 1)
                .shadow(color: thrashing ? .red.opacity(0.7) : ctx.tint.opacity(0.6), radius: 16)
            }
            .buttonStyle(PressableStyle(scale: 0.9))
            Spacer(minLength: 0)
        }
        .padding(18)
        .raidPanel(ctx.tint)
        .onAppear { started = true; lastTick = Date() }
        .onReceive(tick) { now in
            let dt = now.timeIntervalSince(lastTick); lastTick = now
            guard ctx.running else { return }
            sinceThrash += dt
            if thrashing {
                thrashAge += dt
                if thrashAge >= thrashWindow { thrashing = false; sinceThrash = 0 }
            } else {
                haul = max(0, haul - decay * dt)
                if sinceThrash >= thrashEvery { thrashing = true; thrashAge = 0 }
            }
        }
    }

    private func mash() {
        guard ctx.running else { return }
        if thrashing {
            ctx.onMistake()
            flashBad()
            return
        }
        haul = min(1, haul + perTap)
        if haul >= 1 {
            ctx.onSuccess()
            haul = 0.12
        }
    }
    private func flashBad() {
        withAnimation(.easeOut(duration: 0.08)) { badFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeIn(duration: 0.1)) { badFlash = false }
        }
    }
}

// MARK: - Sort — route the Grove Colossus's harvest: ripe to the altar, rotten to the pit

struct SortRoom: View {
    let ctx: RaidRoomContext

    private struct Item: Identifiable {
        let id = UUID()
        let ripe: Bool
        let icon: String
    }
    private enum Side { case altar, pit }

    @State private var queue: [Item] = []
    @State private var frontStart = Date()
    @State private var alarm = 0
    @State private var lastTick = Date()
    @State private var flash: Side?
    @State private var started = false

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let alarmLimit = 2
    private var deadline: Double { max(1.1, ctx.params.targetLifetime * 1.6 * (ctx.enraged ? 0.75 : 1)) }
    private let ripeIcons = ["leaf.fill", "carrot.fill", "tree.fill"]
    private let rotIcons = ["ant.fill", "flame.fill", "smoke.fill"]

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(0..<alarmLimit, id: \.self) { i in
                    Circle().fill(i < alarm ? Color.red : Color.white.opacity(0.22))
                        .frame(width: 8, height: 8)
                }
                Text("wrath").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }

            // Upcoming queue (flows toward the front)
            HStack(spacing: 10) {
                ForEach(Array(queue.dropFirst().prefix(4))) { item in
                    itemChip(item, size: 40, dim: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 360, alignment: .leading)
            .frame(height: 48)

            // Front item with deadline ring
            ZStack {
                TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { tl in
                    let left = max(0, 1 - tl.date.timeIntervalSince(frontStart) / deadline)
                    Circle()
                        .trim(from: 0, to: left)
                        .stroke(left < 0.3 ? Color.red : ctx.tint,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 132, height: 132)
                }
                if let front = queue.first {
                    itemChip(front, size: 104, dim: false)
                }
            }
            .frame(height: 150)

            // Bins
            HStack(spacing: 18) {
                bin(.altar)
                bin(.pit)
            }
            .frame(maxWidth: 360)
        }
        .padding(16)
        .raidPanel(ctx.tint)
        .onAppear { if !started { started = true; fill(); frontStart = Date() } }
        .onReceive(tick) { _ in
            guard ctx.running, !queue.isEmpty else { return }
            if Date().timeIntervalSince(frontStart) >= deadline {
                registerWrong()
                advance()
            }
        }
    }

    private func itemChip(_ item: Item, size: CGFloat, dim: Bool) -> some View {
        let color: Color = item.ripe ? .green : Color(red: 0.55, green: 0.36, blue: 0.72)
        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(color.opacity(dim ? 0.28 : 0.9))
            RoundedRectangle(cornerRadius: size * 0.24)
                .strokeBorder(color.opacity(dim ? 0.4 : 1), lineWidth: 2)
            Image(systemName: item.icon)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(dim ? color : .white)
        }
        .frame(width: size, height: size)
    }

    private func bin(_ side: Side) -> some View {
        let isAltar = side == .altar
        let color: Color = isAltar ? .green : Color(red: 0.55, green: 0.36, blue: 0.72)
        return Button {
            choose(side)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: isAltar ? "sparkles" : "trash.fill")
                    .font(.system(size: 30, weight: .bold))
                Text(isAltar ? "Altar · ripe" : "Pit · rotten")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(flash == side ? 0.95 : 0.6))
            )
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.2), lineWidth: 2))
            .scaleEffect(flash == side ? 1.04 : 1)
        }
        .buttonStyle(PressableStyle(scale: 0.95))
    }

    private func choose(_ side: Side) {
        guard ctx.running, let front = queue.first else { return }
        let correct = (side == .altar && front.ripe) || (side == .pit && !front.ripe)
        withAnimation(.easeOut(duration: 0.1)) { flash = side }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { flash = nil }
        if correct {
            ctx.onSuccess()
        } else {
            registerWrong()
        }
        advance()
    }

    private func registerWrong() {
        alarm += 1
        if alarm >= alarmLimit { alarm = 0; ctx.onMistake() }
    }

    private func advance() {
        if !queue.isEmpty { queue.removeFirst() }
        fill()
        frontStart = Date()
    }

    private func fill() {
        while queue.count < 6 {
            let ripe = Bool.random()
            queue.append(Item(ripe: ripe, icon: (ripe ? ripeIcons : rotIcons).randomElement()!))
        }
    }
}

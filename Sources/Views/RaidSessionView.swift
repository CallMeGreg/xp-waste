import SwiftUI

/// Immersive full-screen raid minigame. One shared HUD (timer, progress, mistake pips) hosts one of
/// four thematic loops selected by the group. The host owns the clock, score, and mistakes; each loop
/// is a self-contained subview that reports successes/mistakes via closures. Reaching `goal` before
/// the timer wins (early-out); running out of time or exceeding `allowedMistakes` loses.
///
/// Difficulty is read from `Balance.raidParams(forTier:)`, selected by the group's raid tier. A win
/// banks a lamp via `GameState.finishRaid`. The daily attempt is spent on appear (`beginRaid`).
struct RaidSessionView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    let group: SkillCategory

    private enum Phase { case playing, won, lost }

    @State private var phase: Phase = .playing
    @State private var timeLeft: Double = Balance.raidDurationSeconds
    @State private var score = 0
    @State private var mistakes = 0
    @State private var tier = 0
    @State private var earnedLamp: RaidLampRecord?
    @State private var resolved = false
    @State private var didBegin = false
    @State private var hitHaptic = 0
    @State private var missHaptic = 0
    @State private var endHaptic = 0
    @State private var debugVisualOnly = false

    private let clock = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var params: Balance.RaidTierParams { Balance.raidParams(forTier: tier) }

    var body: some View {
        ZStack {
            GameBackground().ignoresSafeArea()
            VStack(spacing: 12) {
                hud
                loopArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if phase != .playing { resultOverlay }
        }
        .onAppear(perform: setup)
        .onReceive(clock) { _ in tickClock() }
        .sensoryFeedback(.impact(weight: .light), trigger: hitHaptic)
        .sensoryFeedback(.warning, trigger: missHaptic)
        .sensoryFeedback(phase == .won ? .success : .error, trigger: endHaptic)
    }

    // MARK: Lifecycle

    private func setup() {
        tier = game.raidTier(group)
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let raw = env["FORCE_RAID_TIER"], let t = Int(raw) { tier = min(max(t, 0), 5) }
        if let result = env["RAID_RESULT"]?.lowercased(), result == "win" || result == "lose" || result == "loss" {
            debugVisualOnly = true
            resolved = true
            let won = (result == "win")
            phase = won ? .won : .lost
            if won { earnedLamp = RaidLampRecord(group: group, tier: tier) }
            return
        }
        #endif
        if !didBegin {
            didBegin = true
            _ = game.beginRaid(group)
        }
    }

    private func tickClock() {
        guard phase == .playing, !debugVisualOnly else { return }
        timeLeft -= 0.1
        if timeLeft <= 0 {
            timeLeft = 0
            end(passed: score >= params.goal)
        }
    }

    private func registerSuccess() {
        guard phase == .playing else { return }
        score += 1
        if game.hapticsEnabled { hitHaptic &+= 1 }
        SoundManager.shared.play(.tap, enabled: game.soundEnabled)
        if score >= params.goal { end(passed: true) }
    }

    private func registerMistake() {
        guard phase == .playing else { return }
        mistakes += 1
        if game.hapticsEnabled { missHaptic &+= 1 }
        SoundManager.shared.play(.ui, enabled: game.soundEnabled)
        // Lives shown to the player are `allowedMistakes - mistakes`; reaching 0 ends the raid.
        if mistakes >= params.allowedMistakes { end(passed: false) }
    }

    private func end(passed: Bool) {
        guard !resolved else { return }
        resolved = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            phase = passed ? .won : .lost
        }
        earnedLamp = game.finishRaid(group, passed: passed)
        endHaptic &+= 1
        SoundManager.shared.play(passed ? .supercharge : .ui, enabled: game.soundEnabled)
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.raidName).font(.subheadline.weight(.bold))
                    Text("\(SkillCategory.raidTierName(tier)) tier").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Label(Format.clock(timeLeft), systemImage: "timer")
                    .font(.callout.weight(.bold)).monospacedDigit()
                    .foregroundStyle(timeLeft < 20 ? .red : .primary)
            }

            // Countdown bar
            XPProgressBar(progress: max(0, timeLeft / Balance.raidDurationSeconds),
                          tint: timeLeft < 20 ? .red : .white.opacity(0.5), height: 4)

            // Objective progress
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(objectiveLabel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(min(score, params.goal))/\(params.goal)")
                            .font(.caption.weight(.bold)).monospacedDigit()
                    }
                    XPProgressBar(progress: Double(score) / Double(params.goal),
                                  tint: group.raidTint, height: 7)
                }
                mistakePips
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(group.raidTint.opacity(0.3)))
    }

    private var mistakePips: some View {
        let allowed = params.allowedMistakes
        let remaining = max(0, allowed - mistakes)
        return VStack(alignment: .trailing, spacing: 3) {
            Text(mistakeLabel).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Image(systemName: "heart.fill").font(.caption2).foregroundStyle(.red.opacity(0.9))
                Text("\(remaining)").font(.caption.weight(.bold)).monospacedDigit()
                    .foregroundStyle(remaining <= 2 ? .red : .primary)
            }
        }
        .frame(minWidth: 62)
    }

    private var objectiveLabel: String {
        switch group {
        case .combat:     return "Boss weakened"
        case .production: return "Order filled"
        case .utility:    return "Rooms looted"
        case .gathering:  return "Resources gathered"
        }
    }

    private var mistakeLabel: String {
        switch group {
        case .combat:     return "Health"
        case .production: return "Scrap left"
        case .utility:    return "Alarm"
        case .gathering:  return "Waste left"
        }
    }

    // MARK: Loop switch

    @ViewBuilder private var loopArea: some View {
        let running = phase == .playing && !debugVisualOnly
        switch group {
        case .combat:
            ColosseumLoop(params: params, tint: group.raidTint, running: running,
                          onSuccess: registerSuccess, onMistake: registerMistake)
        case .production:
            ForgeLoop(params: params, tint: group.raidTint, running: running,
                      onSuccess: registerSuccess, onMistake: registerMistake)
        case .utility:
            HeistLoop(params: params, tint: group.raidTint, running: running,
                      onSuccess: registerSuccess, onMistake: registerMistake)
        case .gathering:
            ExpeditionLoop(params: params, tint: group.raidTint, running: running,
                           onSuccess: registerSuccess, onMistake: registerMistake)
        }
    }

    // MARK: Result

    private var resultOverlay: some View {
        let won = phase == .won
        return ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: won ? "trophy.fill" : "xmark.octagon.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(won ? Color.yellow : Color.red.opacity(0.9))
                    .shadow(color: won ? .yellow.opacity(0.5) : .clear, radius: 12)

                Text(won ? "Raid Cleared!" : "Raid Failed")
                    .font(.title2.weight(.heavy))

                Text(won
                     ? "You conquered \(group.raidName)."
                     : "\(group.raidName) bested you this time.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if won, let lamp = earnedLamp {
                    lampReward(lamp)
                } else if !won {
                    Text("One attempt per day — come back tomorrow.")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.top, 2)
                }

                Button { dismiss() } label: {
                    Text(won ? "Claim Lamp" : "Leave")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(won ? group.raidTint : Color.white.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .padding(.top, 4)
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.12)))
            .padding(28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func lampReward(_ lamp: RaidLampRecord) -> some View {
        let c = SkillCategory.raidTierColor(lamp.tier)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                ArtworkView(art: .vector(.genieLamp), size: 28, color: c)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(SkillCategory.raidTierName(lamp.tier)) \(group.rawValue) Lamp")
                        .font(.subheadline.weight(.bold)).foregroundStyle(c)
                    Text("Spend it on any \(group.rawValue.lowercased()) skill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text("Open Raids → Apply to choose a skill.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(c.opacity(0.35)))
    }
}

// MARK: - Combat: The Colosseum (precise, quick strikes + dodge)

/// Weakpoints flash at random spots for a short lifetime — tap them for damage. Periodically the boss
/// telegraphs a slam: a red overlay you must tap anywhere to dodge before it lands, or take a hit.
private struct ColosseumLoop: View {
    let params: Balance.RaidTierParams
    let tint: Color
    let running: Bool
    var onSuccess: () -> Void
    var onMistake: () -> Void

    private struct Weakpoint: Identifiable { let id = UUID(); let x: CGFloat; let y: CGFloat; let born: Date }

    @State private var points: [Weakpoint] = []
    @State private var spawnAccumulator: Double = 0
    @State private var sinceDodge: Double = 0
    @State private var dodgeDeadline: Date?
    @State private var lastTick = Date()

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.22))
                    .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(tint.opacity(0.25)))

                // Boss avatar (top), purely decorative anchor
                VStack {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(tint)
                        .padding(.top, 14)
                    Spacer()
                }

                ForEach(points) { p in
                    let age = Date().timeIntervalSince(p.born)
                    let remaining = max(0, 1 - age / params.targetLifetime)
                    Button {
                        guard running else { return }
                        points.removeAll { $0.id == p.id }
                        onSuccess()
                    } label: {
                        ZStack {
                            Circle().strokeBorder(tint, lineWidth: 3)
                                .background(Circle().fill(tint.opacity(0.28)))
                            Image(systemName: "target").font(.headline.weight(.bold)).foregroundStyle(.white)
                            Circle().trim(from: 0, to: remaining)
                                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 52, height: 52)
                    }
                    .buttonStyle(PressableStyle(scale: 0.85))
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
                }

                if dodgeDeadline != nil {
                    Button {
                        guard running else { return }
                        dodgeDeadline = nil
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20).fill(Color.red.opacity(0.28))
                            VStack(spacing: 6) {
                                Image(systemName: "burst.fill").font(.system(size: 40, weight: .bold))
                                Text("DODGE!").font(.title.weight(.heavy))
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(PressableStyle(scale: 0.97))
                    .transition(.opacity)
                }
            }
        }
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date() }
    }

    private func step() {
        let now = Date()
        let dt = min(0.2, now.timeIntervalSince(lastTick))
        lastTick = now
        guard running else { return }

        // Expire lapsed weakpoints (missing them is fine — no penalty; keeps combat about aim/speed)
        points.removeAll { now.timeIntervalSince($0.born) > params.targetLifetime }

        // Resolve an unmet dodge into a hit
        if let deadline = dodgeDeadline, now >= deadline {
            dodgeDeadline = nil
            onMistake()
        }

        // Spawn cadence
        spawnAccumulator += dt
        sinceDodge += dt
        if spawnAccumulator >= params.spawnInterval {
            spawnAccumulator = 0
            if points.count < 4 {
                points.append(Weakpoint(x: CGFloat.random(in: 0.14...0.86),
                                        y: CGFloat.random(in: 0.24...0.86),
                                        born: now))
            }
        }
        // Telegraphed slam every ~4 spawn intervals
        if dodgeDeadline == nil, sinceDodge >= params.spawnInterval * 4 {
            sinceDodge = 0
            dodgeDeadline = now.addingTimeInterval(params.targetLifetime)
        }
    }
}

// MARK: - Production: The Grand Forge (rhythm / timing)

/// A marker sweeps across a bar; a highlighted sweet-spot marks the perfect strike window. Hit STRIKE
/// while the marker is inside it to advance the order; mistime it and you waste metal (a mistake).
private struct ForgeLoop: View {
    let params: Balance.RaidTierParams
    let tint: Color
    let running: Bool
    var onSuccess: () -> Void
    var onMistake: () -> Void

    @State private var marker: Double = 0
    @State private var direction: Double = 1
    @State private var sweetCenter: Double = 0.5
    @State private var lastTick = Date()
    @State private var flash: Bool = false
    @State private var flashGood = true

    private let tick = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    private var halfWidth: Double {
        // Reuse targetLifetime as the tolerance source: higher tiers (shorter lifetimes) → tighter.
        max(0.05, (params.targetLifetime - 0.8) * 0.16 + 0.06)
    }
    private var speed: Double {
        // Full sweep in ~1.6× spawnInterval; higher tiers sweep faster.
        1.0 / (params.spawnInterval * 1.6)
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Image(systemName: "hammer.fill").font(.system(size: 40, weight: .bold)).foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.3))
                    // Sweet spot
                    Capsule().fill(tint.opacity(0.55))
                        .frame(width: max(6, CGFloat(halfWidth * 2) * geo.size.width))
                        .position(x: CGFloat(sweetCenter) * geo.size.width, y: geo.size.height / 2)
                    // Marker
                    Capsule().fill(Color.white)
                        .frame(width: 6)
                        .position(x: CGFloat(marker) * geo.size.width, y: geo.size.height / 2)
                }
                .overlay(
                    Capsule().strokeBorder(flash ? (flashGood ? Color.green : Color.red) : Color.clear, lineWidth: 3)
                )
            }
            .frame(height: 46)
            .padding(.horizontal, 8)

            Button {
                strike()
            } label: {
                Text("STRIKE")
                    .font(.title2.weight(.heavy))
                    .frame(maxWidth: .infinity).padding(.vertical, 22)
                    .background(tint.opacity(0.85), in: RoundedRectangle(cornerRadius: 18))
                    .foregroundStyle(.white)
            }
            .buttonStyle(PressableStyle(scale: 0.96))
            .padding(.horizontal, 8)
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(tint.opacity(0.25)))
        .onReceive(tick) { _ in step() }
        .onAppear { lastTick = Date(); randomizeSpot() }
    }

    private func step() {
        let now = Date()
        let dt = min(0.1, now.timeIntervalSince(lastTick))
        lastTick = now
        guard running else { return }
        marker += direction * speed * dt
        if marker >= 1 { marker = 1; direction = -1 }
        else if marker <= 0 { marker = 0; direction = 1 }
    }

    private func strike() {
        guard running else { return }
        let good = abs(marker - sweetCenter) <= halfWidth
        flashGood = good
        withAnimation(.easeOut(duration: 0.12)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { flash = false }
        if good { onSuccess(); randomizeSpot() } else { onMistake() }
    }

    private func randomizeSpot() {
        sweetCenter = Double.random(in: 0.2...0.8)
    }
}

// MARK: - Utility: The Heist (stealth / restraint)

/// A guard alternates between WATCHING and DISTRACTED. Loot freely while distracted — every tap
/// before the guard turns back counts — but a tap while the guard WATCHES trips the alarm (a
/// mistake). It's pure timing: mash for more loot and risk catching the window as it flips back.
/// Windows tighten with tier.
private struct HeistLoop: View {
    let params: Balance.RaidTierParams
    let tint: Color
    let running: Bool
    var onSuccess: () -> Void
    var onMistake: () -> Void

    @State private var watching = true
    @State private var nextToggle = Date().addingTimeInterval(1)
    @State private var lastTick = Date()
    @State private var pulse = false

    private let tick = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var safeWindow: Double { params.targetLifetime }         // distracted (loot) duration
    private var watchWindow: Double { params.spawnInterval * 1.4 }   // watching duration

    var body: some View {
        Button { attempt() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill((watching ? Color.red : Color.green).opacity(0.18))
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder((watching ? Color.red : Color.green).opacity(0.6), lineWidth: 3)
                VStack(spacing: 18) {
                    Image(systemName: watching ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 68, weight: .bold))
                        .foregroundStyle(watching ? .red : .green)
                        .scaleEffect(pulse ? 1.06 : 1)
                    Text(watching ? "WATCHING" : "CLEAR — LOOT!")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(watching ? .red : .green)
                    Text(watching ? "Don't move" : "Tap to loot the room")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .onReceive(tick) { _ in step() }
        .onAppear {
            lastTick = Date()
            watching = true
            nextToggle = Date().addingTimeInterval(watchWindow)
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    private func step() {
        let now = Date()
        lastTick = now
        guard running else { return }
        if now >= nextToggle {
            watching.toggle()
            let dur = (watching ? watchWindow : safeWindow) * Double.random(in: 0.8...1.2)
            nextToggle = now.addingTimeInterval(dur)
        }
    }

    private func attempt() {
        guard running else { return }
        if watching {
            onMistake()
        } else {
            // Timing-based: as many loots as you can land before the guard turns back count.
            // Spamming risks a tap landing the instant the window flips to WATCHING (a mistake).
            onSuccess()
        }
    }
}

// MARK: - Gathering: The Expedition (recognition / speed)

/// A grid of resource nodes with a called target ("Harvest: Ore"). Tap nodes matching the target to
/// gather; tap a decoy and you waste effort (a mistake). Tapped nodes respawn, and the called
/// resource rotates every 10 correct gathers. The grid keeps full rows on any width (iPhone/iPad).
private struct ExpeditionLoop: View {
    let params: Balance.RaidTierParams
    let tint: Color
    let running: Bool
    var onSuccess: () -> Void
    var onMistake: () -> Void

    private enum Resource: Int, CaseIterable {
        case log, fish, ore, herb, crop
        var name: String { ["Log", "Fish", "Ore", "Herb", "Crop"][rawValue] }
        var symbol: String { ["tree.fill", "fish.fill", "cube.fill", "leaf.fill", "carrot.fill"][rawValue] }
        var color: Color {
            [Color(red: 0.55, green: 0.38, blue: 0.22), .cyan,
             .gray, .green, .orange][rawValue]
        }
    }

    /// Rotate the called resource after this many correct gathers.
    private static let gathersPerTargetSwitch = 10
    private let rows = 3
    private let itemMin: CGFloat = 76
    private let spacing: CGFloat = 12

    @State private var nodes: [Resource] = []
    @State private var target: Resource = .log
    @State private var correctSinceSwitch = 0

    private var palette: [Resource] {
        // Number of distinct resource types on the board grows with tier (harder recognition).
        let count = min(Resource.allCases.count, max(2, params.decoyCount + 1))
        return Array(Resource.allCases.prefix(count))
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Text("HARVEST").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: target.symbol).foregroundStyle(target.color)
                    Text(target.name).font(.headline.weight(.bold))
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(target.color.opacity(0.18), in: Capsule())
                .overlay(Capsule().strokeBorder(target.color.opacity(0.5)))
                Spacer()
            }

            GeometryReader { geo in
                let cols = columnCount(forWidth: geo.size.width)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: cols),
                          spacing: spacing) {
                    ForEach(Array(nodes.enumerated()), id: \.offset) { index, res in
                        Button { tap(index) } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14).fill(res.color.opacity(0.16))
                                RoundedRectangle(cornerRadius: 14).strokeBorder(res.color.opacity(0.4))
                                Image(systemName: res.symbol)
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(res.color)
                            }
                            .frame(height: 76)
                        }
                        .buttonStyle(PressableStyle(scale: 0.92))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onAppear { syncNodeCount(columns: cols) }
                .onChange(of: cols) { _, newCols in syncNodeCount(columns: newCols) }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.22)))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(tint.opacity(0.25)))
        .onAppear { setupBoard() }
    }

    private func setupBoard() {
        target = palette.randomElement() ?? .log
        correctSinceSwitch = 0
        ensureSolvable()
    }

    /// Columns that fit the measured width (clamped 3…6); node count is `columns × rows` so the grid
    /// never renders a stray partial row on either iPhone or iPad.
    private func columnCount(forWidth width: CGFloat) -> Int {
        guard width > 0 else { return 3 }
        let raw = Int((width + spacing) / (itemMin + spacing))
        return min(6, max(3, raw))
    }

    private func syncNodeCount(columns: Int) {
        let desired = max(columns, 1) * rows
        guard nodes.count != desired else { return }
        if nodes.count < desired {
            let pool = palette
            nodes.append(contentsOf: (0..<(desired - nodes.count)).map { _ in pool.randomElement() ?? .log })
        } else {
            nodes.removeLast(nodes.count - desired)
        }
        ensureSolvable()
    }

    private func rotateTarget() {
        correctSinceSwitch = 0
        let pool = palette
        var next = pool.randomElement() ?? target
        if pool.count > 1 { while next == target { next = pool.randomElement() ?? target } }
        target = next
        ensureSolvable()
    }

    private func tap(_ index: Int) {
        guard running, nodes.indices.contains(index) else { return }
        let hit = nodes[index] == target
        nodes[index] = palette.randomElement() ?? .log
        if hit {
            onSuccess()
            correctSinceSwitch += 1
            if correctSinceSwitch >= Self.gathersPerTargetSwitch { rotateTarget() }
        } else {
            onMistake()
        }
        ensureSolvable()
    }

    /// Guarantee at least one node matches the current target so the board is always solvable.
    private func ensureSolvable() {
        if !nodes.contains(target), !nodes.isEmpty {
            nodes[Int.random(in: 0..<nodes.count)] = target
        }
    }
}

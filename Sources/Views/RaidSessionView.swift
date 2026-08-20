import SwiftUI

/// Immersive, multi-room raid. A run is an **expedition through several rooms** — a warm-up, a
/// mini-boss, then a tougher **final boss** — sharing one countdown and one pool of **raid HP**.
/// Every room runs a **different** mechanic (`RaidRooms.swift`), and no mechanic repeats across the
/// four raids. The engine owns the clock, objective progress, HP, boss phases, and the room-intro
/// cards; each boss threatens the player natively from inside its own mechanic.
///
/// Clear every room before the timer to win and bank an XP lamp (a **flawless** run — no HP lost —
/// banks a bonus). All numbers come from `Balance`; room identities from `RaidPlan`.
struct RaidSessionView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    let group: SkillCategory

    private enum Phase { case introRoom, playing, won, lost }

    @State private var tier = 0
    @State private var rooms: [RaidRoom] = []
    @State private var roomIndex = 0
    @State private var roomProgress = 0
    @State private var roomGoal = 1

    @State private var playerHP = 5
    @State private var maxHP = 5
    @State private var flawless = true

    @State private var timeLeft: Double = 180
    @State private var totalTime: Double = 180

    @State private var phase: Phase = .introRoom
    @State private var earnedLamps: [RaidLampRecord] = []
    @State private var bonusLamp = false

    // Boss reaction feedback (flinch on each boss-room hit) + hurt shake.
    @State private var hitToken = 0
    @State private var screenShake: CGFloat = 0

    @State private var didBegin = false
    @State private var resolved = false
    @State private var debugVisualOnly = false

    @State private var hitHaptic = 0
    @State private var hurtHaptic = 0
    @State private var endHaptic = 0
    @State private var roomHaptic = 0

    private let clock = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var params: Balance.RaidTierParams { Balance.raidParams(forTier: tier) }
    private var room: RaidRoom {
        rooms.indices.contains(roomIndex) ? rooms[roomIndex]
            : RaidRoom(id: 0, title: "", kind: .duel, boss: .champion, objectiveNoun: "", objective: "")
    }
    private var isFinalRoom: Bool { roomIndex == rooms.count - 1 }
    private var bossPhases: Int { isFinalRoom ? params.bossPhases : 1 }
    private var bossHPFraction: Double { room.isBoss ? max(0, 1 - Double(roomProgress) / Double(max(1, roomGoal))) : 1 }
    private var enraged: Bool { room.isBoss && bossHPFraction <= 0.34 }
    private var currentPhaseIndex: Int {
        guard bossPhases > 1 else { return 0 }
        return min(bossPhases - 1, Int((1 - bossHPFraction) * Double(bossPhases)))
    }

    var body: some View {
        ZStack {
            RaidRoomBackdrop(group: group, enraged: enraged && phase == .playing)

            VStack(spacing: 12) {
                hud
                stage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: Layout.maxWidth(hSize, compact: 760, regular: 1040))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: screenShake)

            if phase == .introRoom { roomIntroOverlay }
            if phase == .won || phase == .lost { resultOverlay }
        }
        .onAppear(perform: setup)
        .onReceive(clock) { _ in tickClock() }
        .sensoryFeedback(.impact(weight: .light), trigger: hitHaptic)
        .sensoryFeedback(.impact(weight: .heavy), trigger: hurtHaptic)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: roomHaptic)
        .sensoryFeedback(phase == .won ? .success : .error, trigger: endHaptic)
    }

    // MARK: Lifecycle

    private func setup() {
        tier = game.raidTier(group)
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let raw = env["FORCE_RAID_TIER"], let t = Int(raw) { tier = min(max(t, 0), 5) }
        #endif
        rooms = group.raidRooms(tier: tier)
        maxHP = params.playerHP
        playerHP = maxHP
        totalTime = Balance.raidDuration(forTier: tier)
        timeLeft = totalTime

        #if DEBUG
        if let result = env["RAID_RESULT"]?.lowercased(), ["win", "lose", "loss"].contains(result) {
            debugVisualOnly = true
            resolved = true
            let won = result == "win"
            flawless = env["RAID_FLAWLESS"] == "1"
            if won {
                earnedLamps = [RaidLampRecord(group: group, tier: tier)]
                if flawless {
                    for _ in 0..<max(0, Balance.raidFlawlessBonusLamps) {
                        earnedLamps.append(RaidLampRecord(group: group, tier: tier))
                    }
                    bonusLamp = Balance.raidFlawlessBonusLamps > 0
                }
            }
            phase = won ? .won : .lost
            return
        }
        if let raw = env["RAID_ROOM"], let n = Int(raw), rooms.indices.contains(n) {
            roomIndex = n
            enterRoom(startPlaying: env["RAID_PLAY"] == "1")
            spendDailyAttempt()
            return
        }
        #endif

        roomIndex = 0
        enterRoom(startPlaying: false)
        spendDailyAttempt()
    }

    private func spendDailyAttempt() {
        guard !didBegin, !debugVisualOnly else { return }
        didBegin = true
        _ = game.beginRaid(group)
    }

    /// Prepare the current room: compute its goal, reset progress + slam state, and show its intro
    /// card (unless jumping straight into play for a screenshot).
    private func enterRoom(startPlaying: Bool) {
        roomProgress = 0
        roomGoal = Balance.raidRoomGoal(kind: room.kind, isBoss: room.isBoss, tier: tier)
        phase = startPlaying ? .playing : .introRoom
    }

    private func beginRoom() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { phase = .playing }
    }

    private func tickClock() {
        guard phase == .playing, !debugVisualOnly else { return }
        timeLeft -= 0.1
        if timeLeft <= 0 { timeLeft = 0; end(passed: false) }
    }

    // MARK: Progress

    private func registerSuccess(_ amount: Int = 1) {
        guard phase == .playing else { return }
        roomProgress += max(1, amount)
        if game.hapticsEnabled { hitHaptic &+= 1 }
        if room.isBoss { withAnimation { hitToken &+= 1 } }
        SoundManager.shared.play(.tap, enabled: game.soundEnabled)
        if roomProgress >= roomGoal { clearRoom() }
    }

    private func registerMistake() {
        guard phase == .playing else { return }
        playerHP -= 1
        flawless = false
        if game.hapticsEnabled { hurtHaptic &+= 1 }
        SoundManager.shared.play(.ui, enabled: game.soundEnabled)
        shake()
        if playerHP <= 0 { end(passed: false) }
    }

    private func clearRoom() {
        if isFinalRoom {
            end(passed: true)
        } else {
            if game.hapticsEnabled { roomHaptic &+= 1 }
            SoundManager.shared.play(.energyCell, enabled: game.soundEnabled)
            roomIndex += 1
            enterRoom(startPlaying: false)
        }
    }

    private func end(passed: Bool) {
        guard !resolved else { return }
        resolved = true
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = passed ? .won : .lost }
        let flawlessWin = passed && flawless
        earnedLamps = game.finishRaid(group, passed: passed, flawless: flawlessWin)
        bonusLamp = earnedLamps.count > 1
        endHaptic &+= 1
        SoundManager.shared.play(passed ? .supercharge : .ui, enabled: game.soundEnabled)
    }

    private func shake() {
        screenShake = 9
        withAnimation(.interpolatingSpring(stiffness: 700, damping: 7)) { screenShake = 0 }
    }

    // MARK: HUD

    private var hud: some View {
        VStack(spacing: 9) {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34).background(Color.white.opacity(0.10), in: Circle())
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.raidName).font(.subheadline.weight(.heavy))
                    Text("\(SkillCategory.raidTierName(tier)) tier").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Label(Format.clock(timeLeft), systemImage: "timer")
                    .font(.callout.weight(.bold)).monospacedDigit()
                    .foregroundStyle(timeLeft < 20 ? .red : .primary)
            }

            XPProgressBar(progress: max(0, timeLeft / totalTime),
                          tint: timeLeft < 20 ? .red : .white.opacity(0.5), height: 4)

            roomMap

            HStack(alignment: .center, spacing: 12) {
                objectiveBar
                heartsView
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(group.raidTint.opacity(0.3)))
    }

    /// The expedition map: one node per room, cleared / current / upcoming, bosses marked.
    private var roomMap: some View {
        HStack(spacing: 6) {
            ForEach(rooms) { r in
                let cleared = r.id < roomIndex
                let current = r.id == roomIndex
                let color = cleared ? group.raidTint : (current ? Color.white : Color.white.opacity(0.28))
                HStack(spacing: 6) {
                    ZStack {
                        if r.isBoss {
                            Image(systemName: r.id == rooms.count - 1 ? "crown.fill" : "flame.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(color)
                        } else {
                            Circle().fill(color).frame(width: 9, height: 9)
                        }
                        if current {
                            Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5).frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 24, height: 22)
                    if r.id != rooms.count - 1 {
                        Rectangle().fill(cleared ? group.raidTint : Color.white.opacity(0.18))
                            .frame(height: 2).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 22)
    }

    private var objectiveBar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if room.isBoss {
                    Text(room.boss?.name.uppercased() ?? "BOSS")
                        .font(.caption2.weight(.black)).foregroundStyle(enraged ? .red : .secondary).tracking(0.5)
                    if bossPhases > 1 {
                        HStack(spacing: 3) {
                            ForEach(0..<bossPhases, id: \.self) { i in
                                Circle().fill(i <= currentPhaseIndex ? Color.red : Color.white.opacity(0.25))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
                } else {
                    Text(room.objectiveNoun.uppercased())
                        .font(.caption2.weight(.black)).foregroundStyle(.secondary).tracking(0.5)
                }
                Spacer()
                // Bosses read as *remaining* HP (drains from max → 0, matching the health bar);
                // skill rooms count progress up toward the goal.
                Text(room.isBoss ? "\(max(0, roomGoal - roomProgress))/\(roomGoal)"
                                 : "\(min(roomProgress, roomGoal))/\(roomGoal)")
                    .font(.caption.weight(.bold)).monospacedDigit()
            }
            let frac = room.isBoss ? bossHPFraction : Double(roomProgress) / Double(max(1, roomGoal))
            XPProgressBar(progress: frac,
                          tint: room.isBoss ? (enraged ? .red : group.raidTint) : group.raidTint, height: 8)
        }
    }

    private var heartsView: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(maxHP, 1), id: \.self) { i in
                Image(systemName: i < playerHP ? "heart.fill" : "heart")
                    .font(.caption)
                    .foregroundStyle(i < playerHP ? (playerHP <= 1 ? .red : Color(red: 0.9, green: 0.3, blue: 0.34)) : .white.opacity(0.25))
            }
        }
        .accessibilityLabel("Raid health \(playerHP) of \(maxHP)")
    }

    // MARK: Stage (current room's mechanic + engine boss banner)

    private var stage: some View {
        // Boss banner sits above the mechanic, except for bosses that draw themselves inside their
        // own stage (the duel and the beast lunge).
        VStack(spacing: 8) {
            if room.isBoss, !room.kind.selfDrawsBoss {
                bossBanner
            }
            mechanic
                .id(roomIndex)
        }
    }

    private var bossBanner: some View {
        HStack(spacing: 12) {
            if let boss = room.boss {
                RaidBossView(boss: boss, hpFraction: bossHPFraction, enraged: enraged, hitToken: hitToken, size: 78)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(room.boss?.name ?? "").font(.subheadline.weight(.heavy))
                Text(room.boss?.threat ?? "").font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder((enraged ? Color.red : group.raidTint).opacity(0.35)))
    }

    @ViewBuilder private var mechanic: some View {
        let ctx = RaidRoomContext(
            params: params, tint: group.raidTint, group: group,
            running: phase == .playing && !debugVisualOnly,
            boss: room.boss, bossHPFraction: bossHPFraction,
            bossPhase: currentPhaseIndex, enraged: enraged, hitToken: hitToken,
            onSuccess: { registerSuccess() }, onProgress: { registerSuccess($0) },
            onMistake: registerMistake
        )
        switch room.kind {
        case .laneDodge:   BarrageRoom(ctx: ctx)
        case .swipeDodge:  SwipeDodgeRoom(ctx: ctx)
        case .duel:        DuelRoom(ctx: ctx)
        case .rhythm:      ForgeRoom(ctx: ctx)
        case .charge:      ChargeRoom(ctx: ctx)
        case .vents:       VentsRoom(ctx: ctx)
        case .stealth:     StealthRoom(ctx: ctx)
        case .pathTrace:   PathTraceRoom(ctx: ctx)
        case .memory:      SequenceRoom(ctx: ctx)
        case .recognition: RecognitionRoom(ctx: ctx)
        case .mash:        MashRoom(ctx: ctx)
        case .sort:        SortRoom(ctx: ctx)
        }
    }

    // MARK: Room intro

    private var roomIntroOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("ROOM \(roomIndex + 1) OF \(rooms.count)")
                    .font(.caption.weight(.black)).tracking(2).foregroundStyle(group.raidTint)

                if let boss = room.boss {
                    RaidBossView(boss: boss, hpFraction: 1, enraged: isFinalRoom, hitToken: 0, size: 150)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    ZStack {
                        Circle().fill(group.raidTint.opacity(0.18)).frame(width: 108, height: 108)
                        Image(systemName: room.kind.symbol).font(.system(size: 46, weight: .bold))
                            .foregroundStyle(group.raidTint)
                    }
                }

                VStack(spacing: 5) {
                    Text(room.title).font(.title.weight(.heavy)).multilineTextAlignment(.center)
                    if let boss = room.boss {
                        Label(boss.threat, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption).foregroundStyle(.red.opacity(0.9))
                    }
                    Text(room.objective).font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 14) {
                    introChip(icon: room.kind.symbol, label: room.kind.verb)
                    if isFinalRoom { introChip(icon: "crown.fill", label: "Final boss", tint: .yellow) }
                    else if room.isBoss { introChip(icon: "flame.fill", label: "Mini-boss", tint: .orange) }
                }

                Button { beginRoom() } label: {
                    Text(roomIndex == 0 ? "Enter the Raid" : (isFinalRoom ? "Face the Boss" : "Advance"))
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(group.raidTint, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 440)
            .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(group.raidTint.opacity(0.3)))
            .padding(26)
        }
        .transition(.opacity)
    }

    private func introChip(icon: String, label: String, tint: Color? = nil) -> some View {
        let c = tint ?? group.raidTint
        return HStack(spacing: 6) {
            Image(systemName: icon).font(.caption.weight(.bold))
            Text(label).font(.caption.weight(.bold))
        }
        .foregroundStyle(c)
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(c.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(c.opacity(0.4)))
    }

    // MARK: Result

    private var resultOverlay: some View {
        let won = phase == .won
        return ZStack {
            Color.black.opacity(0.66).ignoresSafeArea()
            VStack(spacing: 15) {
                Image(systemName: won ? "trophy.fill" : "xmark.octagon.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(won ? .yellow : .red.opacity(0.9))
                    .shadow(color: won ? .yellow.opacity(0.5) : .clear, radius: 12)

                Text(won ? "Raid Cleared!" : "Raid Failed").font(.title2.weight(.heavy))

                Text(won ? "You conquered \(group.raidName)."
                         : "\(group.raidName) bested you — you fell in \(room.title).")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)

                if won {
                    if flawless {
                        Label("Flawless — not a single hit taken", systemImage: "sparkles")
                            .font(.caption.weight(.bold)).foregroundStyle(.yellow)
                    }
                    ForEach(earnedLamps) { lamp in lampReward(lamp) }
                    if bonusLamp {
                        Text("Flawless bonus: an extra lamp!").font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                } else {
                    Text("One attempt per day — come back tomorrow.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button { dismiss() } label: {
                    Text(won ? "Claim Reward" : "Leave")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(won ? group.raidTint : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .buttonStyle(PressableStyle(scale: 0.97))
                .padding(.top, 2)
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.12)))
            .padding(28)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
    }

    private func lampReward(_ lamp: RaidLampRecord) -> some View {
        let c = SkillCategory.raidTierColor(lamp.tier)
        return HStack(spacing: 10) {
            ArtworkView(art: .vector(.genieLamp), size: 26, color: c)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(SkillCategory.raidTierName(lamp.tier)) \(group.rawValue) Lamp")
                    .font(.subheadline.weight(.bold)).foregroundStyle(c)
                Text("Spend it on any \(group.rawValue.lowercased()) skill from the Raids tab.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity)
        .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(c.opacity(0.35)))
    }
}

extension RaidRoomKind {
    /// SF Symbol used on the room-intro card and preview chips.
    var symbol: String {
        switch self {
        case .laneDodge:   return "arrow.down.to.line"
        case .swipeDodge:  return "arrow.left.arrow.right"
        case .duel:        return "shield.lefthalf.filled"
        case .rhythm:      return "hammer.fill"
        case .charge:      return "flame.fill"
        case .vents:       return "gauge.with.dots.needle.bottom.50percent"
        case .stealth:     return "eye.slash.fill"
        case .pathTrace:   return "scribble.variable"
        case .memory:      return "square.grid.2x2.fill"
        case .recognition: return "leaf.fill"
        case .mash:        return "hand.tap.fill"
        case .sort:        return "arrow.triangle.branch"
        }
    }
}

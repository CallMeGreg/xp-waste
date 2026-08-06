import SwiftUI

/// A single floating indicator spawned on tap. `crit`/`special` change its styling.
struct TapPop: Identifiable {
    let id = UUID()
    let text: String
    let x: CGFloat
    var crit: Bool = false
    var special: Bool = false
}

/// Animates a `TapPop` upward and fades it out.
struct PopView: View {
    let pop: TapPop
    let tint: Color
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Text(pop.text)
            .font(.system(size: pop.crit ? 34 : (pop.special ? 20 : 26),
                          weight: .heavy, design: .rounded))
            .foregroundStyle(pop.crit ? Color.yellow : (pop.special ? Color.orange : tint))
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .offset(x: pop.x, y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offsetY = pop.crit ? -160 : -130
                    opacity = 0
                }
            }
    }
}

/// Full-screen training screen: tap the thematic object to earn XP, manage the
/// training slot, and trigger a Supercharge.
struct SkillTrainingView: View {
    @EnvironmentObject private var game: GameState
    let skill: SkillID

    @State private var pops: [TapPop] = []
    @State private var tapScale: CGFloat = 1
    @State private var tapHaptic = 0
    @State private var superchargeHaptic = 0
    @State private var energyCellHaptic = 0
    @State private var showSlotFull = false
    @State private var autoTapAccumulator: Double = 0
    @Environment(\.horizontalSizeClass) private var hSize

    /// Drives Runecraft's auto-tap perk while this screen is open.
    private let autoTapTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        let level = game.level(for: skill)
        let xp = game.xp(for: skill)
        let supercharged = game.isSupercharged(skill)

        return ZStack {
            GameBackground()
            Group {
                if hSize == .regular {
                    regularLayout(level: level, xp: xp, supercharged: supercharged)
                } else {
                    compactLayout(level: level, xp: xp, supercharged: supercharged)
                }
            }
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(skill.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.impact(weight: .light), trigger: tapHaptic)
        .sensoryFeedback(.success, trigger: superchargeHaptic)
        .sensoryFeedback(.impact, trigger: energyCellHaptic)
        .onReceive(autoTapTimer) { _ in stepAutoTap(0.1) }
        .alert("All slots are full", isPresented: $showSlotFull) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Remove a skill from a slot, or raise your total level to unlock another slot.")
        }
    }

    // MARK: Layouts

    /// iPhone / compact-width layout: a single scrollable vertical column (survives short heights).
    private func compactLayout(level: Int, xp: Int, supercharged: Bool) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                header(level: level, xp: xp, supercharged: supercharged)
                methodBanner.padding(.horizontal, 20)
                buffBanner.padding(.horizontal, 20)
                objectArea(supercharged: supercharged, diameter: 240)
                    .padding(.top, 4)
                controlCard
            }
            .padding(.bottom, 12)
        }
    }

    /// iPad / regular-width layout: object on the left, method + perk + controls on the right.
    private func regularLayout(level: Int, xp: Int, supercharged: Bool) -> some View {
        VStack(spacing: 12) {
            header(level: level, xp: xp, supercharged: supercharged)
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 24) {
                objectArea(supercharged: supercharged, diameter: 340)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 16) {
                    methodBanner
                    buffBanner
                    controlCard
                }
                .frame(maxWidth: 400)
            }
            .padding(.horizontal, 8)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    // MARK: Method banner

    /// Shows the current thematic training method, its XP-per-tap, and the next unlock.
    private var methodBanner: some View {
        let method = game.currentMethod(for: skill)
        let base = game.baseXPPerAction(for: skill)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ArtworkView(art: method.art, size: 24 * method.scale, color: method.tint ?? skill.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Method").font(.caption2).foregroundStyle(.secondary)
                    Text(method.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                }
                Spacer()
                Text("+\(base) / tap")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(skill.tint)
                    .monospacedDigit()
            }
            if let next = game.nextMethodUnlock(for: skill) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("Next: \(next.method.name) at Lv \(next.level)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("Top-tier method unlocked")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
    }

    // MARK: Perk banner

    /// Shows this skill's unique, account-wide perk, its current magnitude, and the next-level value.
    private var buffBanner: some View {
        let info = skill.buff
        let values = game.buffValues(for: skill)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: info.icon).font(.title3).foregroundStyle(skill.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Perk · \(info.name)").font(.caption2).foregroundStyle(.secondary)
                    Text(values.current)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(skill.tint)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
            }
            Text(info.blurb)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let next = values.next {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").font(.caption2).foregroundStyle(.secondary)
                    Text("Next level: \(next)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(skill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(skill.tint.opacity(0.20)))
    }

    private func header(level: Int, xp: Int, supercharged: Bool) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Level").font(.subheadline).foregroundStyle(.secondary)
                Text("\(level)")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(skill.tint)
                Text("/ 99").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if game.isDoubleXPActive {
                    Label(multText(game.xpMultiplier), systemImage: "sparkles")
                        .font(.headline.weight(.bold)).foregroundStyle(Color.doubleXP)
                }
                if supercharged {
                    Label("×\(game.effectiveSuperchargeMultiplier) · \(Int(game.superchargeSeconds(for: skill).rounded()))s",
                          systemImage: "flame.fill")
                        .font(.headline).foregroundStyle(.orange)
                }
            }
            XPProgressBar(progress: XPTable.progressToNextLevel(forXP: xp), tint: skill.tint, height: 10)
            HStack {
                Text("\(Format.abbrev(xp)) XP").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if level < XPTable.maxLevel {
                    Text("\(Format.abbrev(XPTable.xpToNextLevel(forXP: xp))) to level \(level + 1)")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Maxed").font(.caption.bold()).foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Tappable object

    private func objectArea(supercharged: Bool, diameter: CGFloat) -> some View {
        let method = game.currentMethod(for: skill)
        return ZStack {
            Circle().fill(skill.tint.opacity(0.18))
                .frame(width: diameter * 1.2, height: diameter * 1.2).blur(radius: 30)

            Button(action: handleTap) {
                ZStack {
                    Circle().fill(RadialGradient(
                        colors: [skill.tint.opacity(0.55), skill.tint.opacity(0.18)],
                        center: .center, startRadius: 8, endRadius: diameter * 0.6))
                    Circle().strokeBorder(
                        supercharged ? Color.orange : skill.tint.opacity(0.7),
                        lineWidth: supercharged ? 6 : 3)
                    ArtworkView(art: method.art, size: diameter * 0.46 * method.scale,
                                color: method.tint ?? skill.tint, emphasized: true)
                }
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .scaleEffect(tapScale)
            .shadow(color: supercharged ? .orange.opacity(0.6) : .black.opacity(0.35),
                    radius: supercharged ? 22 : 12)

            ForEach(pops) { pop in
                PopView(pop: pop, tint: supercharged ? .orange : (game.isDoubleXPActive ? .doubleXP : skill.tint))
            }
        }
        .frame(height: diameter * 1.15)
        .overlay(alignment: .bottom) {
            Text(supercharged ? "SUPERCHARGED — tap fast!" : "Tap to train")
                .font(.callout.weight(.semibold))
                .foregroundStyle(supercharged ? Color.orange : .secondary)
        }
    }

    // MARK: Bottom controls

    private var controlCard: some View {
        VStack(spacing: 14) {
            slotControl
            Divider().overlay(Color.white.opacity(0.12))
            energyControl
        }
        .padding(16)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white.opacity(0.08)))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var slotControl: some View {
        if game.isSlotted(skill), let idx = game.slotIndex(of: skill) {
            Button { game.toggleSlot(skill) } label: {
                HStack {
                    Label("Training in slot \(idx + 1)", systemImage: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text("Remove").foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
            }
        } else if game.isEligibleForSlot(skill) {
            Button {
                if !game.toggleSlot(skill) { showSlotFull = true }
            } label: {
                HStack {
                    Label("Add to training slot", systemImage: "bolt")
                    Spacer()
                    Text("\(game.slots.count)/\(game.maxSlots)").foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
            }
        } else {
            HStack {
                Label("Passive training locked", systemImage: "lock.fill")
                Spacer()
                Text("Reach level \(Balance.slotEligibilityLevel)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var energyControl: some View {
        let banked = game.energy(for: skill)
        let supercharged = game.isSupercharged(skill)

        HStack(spacing: 14) {
            ZStack {
                EnergyRing(fraction: game.energyFraction(for: skill),
                           ready: game.canSupercharge(skill), lineWidth: 5)
                    .frame(width: 44, height: 44)
                Image(systemName: "flame.fill").font(.system(size: 15)).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Energy").font(.subheadline.weight(.semibold))
                Text("\(Int(banked.rounded(.down)))s / \(Int(game.energyCapSeconds))s banked")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if game.energyCells > 0 && game.isSlotted(skill) && banked < game.energyCapSeconds {
                Button {
                    if game.useEnergyCell(), game.hapticsEnabled { energyCellHaptic += 1 }
                } label: {
                    Label("Use Cell", systemImage: "bolt.batteryblock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.orange.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            superchargeButton(supercharged: supercharged)
        }

        if game.energyCells > 0 && game.isSlotted(skill) && banked < game.energyCapSeconds {
            Text("🔋 \(game.energyCells) Energy Cell\(game.energyCells == 1 ? "" : "s") — instantly recharge every slot to full.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        if !game.isSlotted(skill) && banked < Balance.minEnergyToSupercharge {
            Text("Slot this skill to bank Energy — even while the app is closed.")
                .font(.caption2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func superchargeButton(supercharged: Bool) -> some View {
        if supercharged {
            Label("\(Int(game.superchargeSeconds(for: skill).rounded()))s", systemImage: "flame.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.orange)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.orange.opacity(0.15), in: Capsule())
        } else {
            let enabled = game.canSupercharge(skill)
            Button {
                if game.supercharge(skill), game.hapticsEnabled { superchargeHaptic += 1 }
            } label: {
                Text("Supercharge ×\(game.effectiveSuperchargeMultiplier)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(enabled ? .black : .secondary)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(enabled ? Color.orange : Color.white.opacity(0.1), in: Capsule())
            }
            .disabled(!enabled)
        }
    }

    // MARK: Tap handling

    private func handleTap() {
        let result = game.tap(skill)
        spawnPops(for: result)
        tapScale = 0.9
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { tapScale = 1.0 }
        if game.hapticsEnabled { tapHaptic += 1 }
    }

    /// Advances Runecraft's auto-tap perk; fires whole taps accumulated over `dt`.
    private func stepAutoTap(_ dt: Double) {
        let rate = game.autoTapsPerSecond
        guard rate > 0 else { autoTapAccumulator = 0; return }
        autoTapAccumulator += rate * dt
        var fired = 0
        while autoTapAccumulator >= 1, fired < 5 {
            autoTapAccumulator -= 1
            spawnPops(for: game.tap(skill))
            fired += 1
        }
    }

    /// Spawns floating indicators for a tap, calling out crits, extra hits, caches, and Energy procs.
    private func spawnPops(for result: GameState.TapResult) {
        let text = result.didCrit ? "✦ +\(result.xp)!" : "+\(result.xp)"
        addPop(TapPop(text: text, x: .random(in: -34...34), crit: result.didCrit))
        if result.extraHits > 0 {
            addPop(TapPop(text: "＋\(result.extraHits) hit\(result.extraHits == 1 ? "" : "s")",
                          x: .random(in: -48...48), special: true))
        }
        if result.gotCache {
            addPop(TapPop(text: "🪹 cache!", x: .random(in: -48...48), special: true))
        }
        if result.gotEnergy {
            addPop(TapPop(text: "⚡︎ energy", x: .random(in: -48...48), special: true))
        }
    }

    private func addPop(_ pop: TapPop) {
        pops.append(pop)
        if pops.count > 16 { pops.removeFirst(pops.count - 16) }
        let id = pop.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            pops.removeAll { $0.id == id }
        }
    }

    private func multText(_ v: Double) -> String {
        v == v.rounded() ? String(format: "×%.0f", v) : String(format: "×%.1f", v)
    }
}

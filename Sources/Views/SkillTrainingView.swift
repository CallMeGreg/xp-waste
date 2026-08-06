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
    @State private var showDetails = false
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
            VStack(spacing: 16) {
                slimHeader(level: level, xp: xp, supercharged: supercharged)
                methodPerkChip
                Spacer(minLength: 0)
                objectArea(supercharged: supercharged, diameter: hSize == .regular ? 300 : 240)
                Spacer(minLength: 0)
                focusControlBar(supercharged: supercharged)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sheet(isPresented: $showDetails) { detailsSheet }
    }

    // MARK: Header + method/perk chip

    /// Slim level + XP header. Active Double XP is flagged inline; Supercharge status lives in the
    /// control bar and on the object itself, keeping this strip minimal.
    private func slimHeader(level: Int, xp: Int, supercharged: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(level)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(skill.tint)
                Text("/ 99").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                if game.isDoubleXPActive {
                    Label(multText(game.xpMultiplier), systemImage: "sparkles")
                        .font(.subheadline.weight(.bold)).foregroundStyle(Color.doubleXP)
                }
                Text("\(Format.abbrev(xp)) XP").font(.caption).foregroundStyle(.secondary)
            }
            XPProgressBar(progress: XPTable.progressToNextLevel(forXP: xp), tint: skill.tint, height: 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// One combined chip: current method + XP/tap and the skill's perk, with full details a tap away.
    private var methodPerkChip: some View {
        let method = game.currentMethod(for: skill)
        return Button { showDetails = true } label: {
            HStack(spacing: 9) {
                ArtworkView(art: method.art, size: 22 * method.scale, color: method.tint ?? skill.tint)
                Text(method.name).font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Text("+\(game.baseXPPerAction(for: skill))/tap")
                    .font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(skill.tint)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                Divider().frame(height: 14).overlay(Color.white.opacity(0.2))
                Image(systemName: skill.buff.icon).font(.caption).foregroundStyle(skill.tint)
                Text(skill.buff.name)
                    .font(.caption.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(1).layoutPriority(1)
                Image(systemName: "info.circle").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.08)))
        }
        .buttonStyle(PressableStyle(scale: 0.98))
        .padding(.horizontal, 16)
    }

    // MARK: Control bar (slot · energy · supercharge)

    private func focusControlBar(supercharged: Bool) -> some View {
        let slotted = game.isSlotted(skill)
        let ready = game.canSupercharge(skill)
        let banked = game.energy(for: skill)
        let canUseCell = game.energyCells > 0 && slotted && banked < game.energyCapSeconds
        return HStack(spacing: 10) {
            slotControlButton(slotted: slotted)
            energyControlButton(ready: ready, banked: banked, canUseCell: canUseCell)
            superchargeControlButton(supercharged: supercharged, ready: ready)
        }
    }

    @ViewBuilder
    private func slotControlButton(slotted: Bool) -> some View {
        if slotted {
            Button { game.toggleSlot(skill) } label: {
                controlPill {
                    controlGlyph(.bolt, .yellow)
                    Text(slotLabel).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                }
            }
            .buttonStyle(PressableStyle())
        } else if game.isEligibleForSlot(skill) {
            Button {
                if !game.toggleSlot(skill) { showSlotFull = true }
            } label: {
                controlPill {
                    controlGlyph(.bolt, .secondary)
                    Text("Add slot").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PressableStyle())
        } else {
            controlPill {
                controlGlyph(.lock, .secondary)
                Text("Lv \(Balance.slotEligibilityLevel)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
    }

    private var slotLabel: String {
        if let idx = game.slotIndex(of: skill) { return "Slot \(idx + 1)" }
        return "Slotted"
    }

    @ViewBuilder
    private func energyControlButton(ready: Bool, banked: Double, canUseCell: Bool) -> some View {
        let content = HStack(spacing: 8) {
            ZStack {
                EnergyRing(fraction: game.energyFraction(for: skill), ready: ready, lineWidth: 4)
                    .frame(width: 30, height: 30)
                controlGlyph(canUseCell ? .bolt : .flame, .orange, size: 13)
            }
            Text("\(Int(banked.rounded(.down)))/\(Int(game.energyCapSeconds))s")
                .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(canUseCell ? Color.orange.opacity(0.15) : Color.white.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
            canUseCell ? Color.orange.opacity(0.5) : Color.white.opacity(0.08)))

        if canUseCell {
            Button {
                if game.useEnergyCell(), game.hapticsEnabled { energyCellHaptic += 1 }
            } label: { content }
            .buttonStyle(PressableStyle())
        } else {
            content
        }
    }

    @ViewBuilder
    private func superchargeControlButton(supercharged: Bool, ready: Bool) -> some View {
        if supercharged {
            HStack(spacing: 6) {
                controlGlyph(.flame, .orange)
                Text("\(Int(game.superchargeSeconds(for: skill).rounded()))s")
                    .font(.subheadline.weight(.bold)).foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.5)))
        } else {
            Button {
                if game.supercharge(skill), game.hapticsEnabled { superchargeHaptic += 1 }
            } label: {
                Text("Supercharge ×\(game.effectiveSuperchargeMultiplier)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ready ? .black : .secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(ready ? Color.orange : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                        ready ? Color.clear : Color.white.opacity(0.08)))
            }
            .buttonStyle(PressableStyle())
            .disabled(!ready)
        }
    }

    private func controlPill<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 6) { content() }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
    }

    /// A small drawn control-bar glyph. Uses `VectorIcon` paths rather than `Image(systemName:)`
    /// because SF Symbols in the bottom bar phantom-render near the nav bar on iPad.
    private func controlGlyph(_ icon: VectorIcon, _ color: Color, size: CGFloat = 15) -> some View {
        icon.view(color: color).frame(width: size, height: size)
    }

    // MARK: Details sheet (full method + perk info, one tap from the chip)

    private var detailsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    methodBanner
                    buffBanner
                }
                .padding(20)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle(skill.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDetails = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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

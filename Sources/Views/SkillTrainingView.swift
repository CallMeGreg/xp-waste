import SwiftUI

/// A single floating indicator spawned on tap. `crit`/`special`/`idle` change its styling.
struct TapPop: Identifiable {
    let id = UUID()
    let text: String
    let x: CGFloat
    var crit: Bool = false
    var special: Bool = false
    var idle: Bool = false
}

/// Animates a `TapPop` upward and fades it out.
struct PopView: View {
    let pop: TapPop
    let tint: Color
    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 1

    private var fontSize: CGFloat {
        if pop.crit { return 34 }
        if pop.idle { return 16 }
        return pop.special ? 20 : 26
    }

    private var color: Color {
        if pop.crit { return .yellow }
        if pop.idle { return .secondary }
        return pop.special ? .orange : tint
    }

    var body: some View {
        Text(pop.text)
            .font(.system(size: fontSize, weight: pop.idle ? .semibold : .heavy, design: .rounded))
            .foregroundStyle(color)
            .opacity(pop.idle ? 0.9 : 1)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .offset(x: pop.x, y: offsetY)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    offsetY = pop.crit ? -160 : (pop.idle ? -80 : -130)
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
    @State private var showSlotManager = false
    @State private var showDetails = false
    @State private var autoTapAccumulator: Double = 0
    @State private var idleAccumulator: Double = 0
    @Environment(\.horizontalSizeClass) private var hSize

    /// Drives Runecraft's auto-tap perk while this screen is open.
    private let autoTapTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    /// Spawns display-only "+N idle" pops for the passive XP a slotted skill earns each second.
    private let idleTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
        .onReceive(idleTimer) { _ in stepIdlePop() }
        .sheet(isPresented: $showSlotManager) { slotManagerSheet }
        .sheet(isPresented: $showDetails) { detailsSheet }
    }

    // MARK: Header + method/perk chip

    /// Slim level + XP header. Active Daily Boost is flagged inline; Supercharge status lives in the
    /// control bar and on the object itself, keeping this strip minimal.
    private func slimHeader(level: Int, xp: Int, supercharged: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("lv.").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(level)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(skill.tint)
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
                Text(method.tag).font(.caption.weight(.semibold))
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
                if !game.toggleSlot(skill) { showSlotManager = true }
            } label: {
                controlPill {
                    controlGlyph(.bolt, .secondary)
                    Text("Add AFK").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(PressableStyle())
        } else {
            controlPill {
                controlGlyph(.lock, .secondary)
                Text("lv. \(Balance.slotEligibilityLevel)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
        }
    }

    private var slotLabel: String {
        if let idx = game.slotIndex(of: skill) { return "AFK \(idx + 1)" }
        return "AFK'ing"
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
            // A wall-clock TimelineView so the countdown keeps ticking down every second even while
            // the player spams taps (the old per-second decrement froze under a busy main thread).
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = game.superchargeSeconds(for: skill)
                HStack(spacing: 6) {
                    controlGlyph(.flame, .orange)
                    Text("\(Int(remaining.rounded()))s")
                        .font(.subheadline.weight(.bold)).foregroundStyle(.orange)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.orange.opacity(0.5)))
            }
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

    // MARK: Slot manager sheet (item 7 — swap a full AFK slot instead of a dead-end alert)

    /// Shown when every AFK slot is full and the player tries to slot this skill. Lists the
    /// currently-slotted skills and lets the player swap one out for this one in a single tap.
    private var slotManagerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("All \(game.maxSlots) AFK slots are full")
                        .font(.headline)
                    Text("Swap one out to AFK **\(skill.displayName)** instead, or raise your total level to unlock another slot.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(game.slots.enumerated()), id: \.element) { index, slotted in
                        Button {
                            if game.swapSlot(remove: slotted, add: skill), game.hapticsEnabled {
                                superchargeHaptic += 1
                            }
                            showSlotManager = false
                        } label: {
                            HStack(spacing: 12) {
                                ArtworkView(art: slotted.art, size: 26, color: slotted.tint)
                                    .frame(width: 30, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(slotted.displayName).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("AFK \(index + 1) · lv. \(game.level(for: slotted))")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Label("Swap out", systemImage: "arrow.left.arrow.right")
                                    .font(.caption.weight(.semibold)).foregroundStyle(skill.tint)
                                    .labelStyle(.titleAndIcon)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(PressableStyle(scale: 0.98))
                    }
                }
                .padding(20)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("AFK slots")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { showSlotManager = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Details sheet (full method + perk info, one tap from the chip)

    private var detailsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    methodBanner
                    buffBanner
                    accountWideEffectsBanner
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
                    Text("Next: \(next.method.name) at lv. \(next.level)")
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

    /// Shows this skill's unique, account-wide perk, its current magnitude, and the next level at
    /// which that magnitude actually changes (some perks read the same across several levels).
    private var buffBanner: some View {
        let info = skill.buff
        let current = game.buffValues(for: skill).current
        let change = game.nextBuffChange(for: skill)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: info.icon).font(.title3).foregroundStyle(skill.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Perk · \(info.name)").font(.caption2).foregroundStyle(.secondary)
                    Text(current)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(skill.tint)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer()
            }
            Text(info.blurb)
                .font(.caption2).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let change {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill").font(.caption2).foregroundStyle(.secondary)
                    Text("At lv. \(change.level): \(change.value)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(skill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(skill.tint.opacity(0.20)))
    }

    // MARK: Account-wide effects banner (item 1 — makes the "perks apply everywhere" rule visible)

    /// Lists every *other* skill's leveled-up perk that is affecting this training session right
    /// now, so players can see that perks are account-wide (e.g. Strength's max-hit boost applies
    /// while training anything, not just Strength).
    @ViewBuilder
    private var accountWideEffectsBanner: some View {
        let effects = game.activeAccountWideEffects(excluding: skill)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.rays").font(.caption).foregroundStyle(.secondary)
                Text("Active account-wide effects").font(.caption.weight(.semibold)).foregroundStyle(.primary)
            }
            if effects.isEmpty {
                Text("Level up other skills to stack account-wide perks that apply while you train anything.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("These apply while training \(skill.displayName):")
                    .font(.caption2).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(effects) { effect in
                        HStack(spacing: 4) {
                            Image(systemName: effect.icon).font(.caption2)
                            Text(effect.value).font(.caption2.weight(.semibold)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.white.opacity(0.06), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10)))
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.08)))
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

    /// Spawns a display-only "+N idle" pop for the passive XP a slotted skill banks each second,
    /// so AFK progress is visible on the training screen. The XP itself is credited by
    /// `GameState.foregroundTick`; this only surfaces it (no double-credit).
    private func stepIdlePop() {
        guard game.isSlotted(skill) else { idleAccumulator = 0; return }
        idleAccumulator += game.expectedIdleGainPerSecond(for: skill)
        guard idleAccumulator >= 1 else { return }
        let gain = Int(idleAccumulator.rounded(.down))
        idleAccumulator -= Double(gain)
        guard gain > 0 else { return }
        addPop(TapPop(text: "+\(gain) idle", x: .random(in: -52...52), idle: true))
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

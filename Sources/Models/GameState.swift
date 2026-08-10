import SwiftUI

/// Fired when a skill gains a level, so the UI can celebrate it.
struct LevelUpEvent: Identifiable, Equatable {
    let id = UUID()
    let skill: SkillID
    let newLevel: Int
}

/// Summary of the XP each *slotted* skill earned while the app was closed, surfaced as a
/// "welcome back" sheet on return. Transient UI state — never persisted.
struct OfflineProgress: Identifiable, Equatable {
    let id = UUID()
    /// How long the player was actually away.
    let timeAway: TimeInterval
    /// The portion of `timeAway` that earned XP (clamped to `Balance.maxOfflineHours`).
    let creditedTime: TimeInterval
    /// True when `timeAway` exceeded the offline cap, so some idle time wasn't counted.
    let wasCapped: Bool
    let entries: [Entry]
    let totalXP: Int

    /// One slotted skill's offline gain.
    struct Entry: Identifiable, Equatable {
        var id: SkillID { skill }
        let skill: SkillID
        let xpGained: Int
        let fromLevel: Int
        let toLevel: Int
        var leveledUp: Bool { toLevel > fromLevel }
    }
}

/// Codable snapshot persisted to `UserDefaults`.
private struct SaveData: Codable {
    var xp: [String: Double]
    var energy: [String: Double]
    var slots: [String]
    var supercharge: [String: Double]
    var hasSeenOnboarding: Bool
    var soundEnabled: Bool
    var hapticsEnabled: Bool
    var lastActive: Date
    // Added in v1.1 — optional for backward-compatible decoding of older saves.
    var doubleXPCoupons: Int?
    var doubleXPExpiry: Date?
    var lastFreeCouponDay: String?
    // Added in v1.2 — optional for backward-compatible decoding of older saves.
    var energyCells: Int?
    // Added in v1.3 — Supercharge is now stored as an absolute expiry date. Optional so older
    // saves (which only had `supercharge` remaining-seconds) still decode; `supercharge` is kept
    // in sync as remaining seconds for forward/backward compatibility.
    var superchargeExpiry: [String: Date]?
    // Added in v1.4 — the Supercharge multiplier locked in when each active burst was triggered,
    // so a mid-burst level-up can't retroactively change it. Optional so older saves still decode;
    // a burst without a snapshot falls back to the live multiplier.
    var superchargeMultiplier: [String: Int]?
}

/// The single source of truth for all game state and rules.
@MainActor
final class GameState: ObservableObject {

    // MARK: Persisted state
    @Published private(set) var xpBySkill: [SkillID: Double] = [:]
    @Published private(set) var energyBySkill: [SkillID: Double] = [:]
    /// When each skill's Supercharge burst ends (wall-clock). Absent/past = not supercharged.
    /// Wall-clock expiry (rather than a decrementing counter) keeps the burst honest: rapid
    /// tapping can't stall the timer, and the countdown is derived straight from the clock.
    @Published private(set) var superchargeExpiryBySkill: [SkillID: Date] = [:]
    /// The effective Supercharge multiplier locked in when each active burst was triggered.
    /// Snapshotting it here (instead of recomputing from total level on every tap) keeps an
    /// in-progress burst at the value it started with, so leveling up mid-burst — Mining or any
    /// other skill crossing a Supercharge tier, or Prayer's bonus — can't retroactively pump the
    /// boost that's already running. The *next* Supercharge picks up the new, higher value.
    @Published private(set) var superchargeMultiplierBySkill: [SkillID: Int] = [:]
    @Published private(set) var slots: [SkillID] = []
    @Published var hasSeenOnboarding: Bool = false
    @Published var soundEnabled: Bool = true
    @Published var hapticsEnabled: Bool = true

    /// Daily Boost coupons the player owns (free daily + in-app purchases).
    @Published private(set) var doubleXPCoupons: Int = 0
    /// Energy Cells the player owns — each instantly fills one skill's Supercharge charge to its cap.
    @Published private(set) var energyCells: Int = 0
    /// When the current Daily Boost ends, or `nil` if no boost is active.
    @Published private(set) var doubleXPExpiry: Date?
    /// Total duration of the currently-running boost, so the UI can draw an accurate countdown bar.
    @Published private(set) var doubleXPActiveDuration: TimeInterval = Balance.doubleXPDurationSeconds

    /// Most recent level-up, consumed by the UI for a celebratory toast.
    @Published var levelUpEvent: LevelUpEvent?

    /// The most recent offline-earnings summary, presented as a "welcome back" sheet on return.
    @Published var offlineProgress: OfflineProgress?

    /// Transient, user-facing message surfaced as a toast (daily reward, purchase, etc.).
    @Published var notice: String?

    // MARK: Runtime-only state
    private var isForeground: Bool = true
    private var lastTick: Date = Date()
    private var lastActive: Date = Date()
    private var lastFreeCouponDay: String?
    private var autosaveAccumulator: TimeInterval = 0

    /// Agility combo tracking (runtime only — derived from tap timing, never persisted).
    private var comboStreak: Int = 0
    private var lastTapAt: Date = .distantPast

    private static let saveKey = "xpWaste.save.v1"

    init() {
        load()
        lastTick = Date()
        if hasSeenOnboarding { grantDailyCouponIfNeeded() }
        #if DEBUG
        applyDemoSeedIfRequested()
        applyOfflineDemoIfRequested()
        #endif
    }

    // MARK: - Derived values

    func xp(for skill: SkillID) -> Int { Int((xpBySkill[skill] ?? 0).rounded(.down)) }
    func level(for skill: SkillID) -> Int { XPTable.level(forXP: xp(for: skill)) }
    func energy(for skill: SkillID) -> Double { energyBySkill[skill] ?? 0 }

    /// Seconds left on a skill's Supercharge burst (0 when inactive), derived from the clock.
    func superchargeSeconds(for skill: SkillID) -> Double {
        max(0, (superchargeExpiryBySkill[skill] ?? .distantPast).timeIntervalSinceNow)
    }

    func isSupercharged(_ skill: SkillID) -> Bool {
        (superchargeExpiryBySkill[skill] ?? .distantPast) > Date()
    }
    func isSlotted(_ skill: SkillID) -> Bool { slots.contains(skill) }
    func slotIndex(of skill: SkillID) -> Int? { slots.firstIndex(of: skill) }
    func isEligibleForSlot(_ skill: SkillID) -> Bool { level(for: skill) >= Balance.slotEligibilityLevel }
    func isMaxed(_ skill: SkillID) -> Bool { level(for: skill) >= XPTable.maxLevel }

    /// Progress (0...1) of banked Energy toward the (perk-adjusted) cap.
    func energyFraction(for skill: SkillID) -> Double {
        min(energy(for: skill) / energyCapSeconds, 1.0)
    }

    func canSupercharge(_ skill: SkillID) -> Bool {
        !isSupercharged(skill) && energy(for: skill) >= Balance.minEnergyToSupercharge
    }

    /// Seconds the *next* Supercharge burst would last if triggered right now — the banked Energy
    /// stretched by Firemaking's duration perk. Surfaced in the UI so the player can see the payoff
    /// (burst length) before spending their charge.
    func superchargeBurstPreview(for skill: SkillID) -> Double {
        energy(for: skill) * superchargeDurationMultiplier
    }

    var totalLevel: Int { SkillID.allCases.reduce(0) { $0 + level(for: $1) } }
    var totalXP: Int { SkillID.allCases.reduce(0) { $0 + xp(for: $1) } }
    var maxTotalLevel: Int { SkillID.allCases.count * XPTable.maxLevel }
    var maxSlots: Int { Balance.maxSlots(forTotalLevel: totalLevel) }
    var superchargeMultiplier: Int { Balance.superchargeMultiplier }
    /// The Supercharge multiplier actually applied to taps, including Prayer's flat bonus.
    var effectiveSuperchargeMultiplier: Int { superchargeMultiplier + superchargeBonus }

    /// The Supercharge multiplier applied to a skill's *active* burst — the value locked in when it
    /// was triggered, so leveling up mid-burst doesn't change the boost already running. Falls back
    /// to the live value for a burst with no snapshot (e.g. an older save that was mid-Supercharge).
    func activeSuperchargeMultiplier(for skill: SkillID) -> Int {
        superchargeMultiplierBySkill[skill] ?? effectiveSuperchargeMultiplier
    }
    var maxedSkillCount: Int { SkillID.allCases.filter { isMaxed($0) }.count }
    var isFullyMaxed: Bool { maxedSkillCount == SkillID.allCases.count }
    var hasFreeSlot: Bool { slots.count < maxSlots }

    // MARK: Training methods

    /// Index into `Balance.trainingTiers` / `SkillID.trainingMethods` for a skill's current level.
    func currentTierIndex(for skill: SkillID) -> Int {
        Balance.trainingTierIndex(forSkillLevel: level(for: skill))
    }

    /// The active thematic training method for a skill at its current level.
    func currentMethod(for skill: SkillID) -> TrainingMethod {
        let methods = skill.trainingMethods
        return methods[min(currentTierIndex(for: skill), methods.count - 1)]
    }

    /// Base XP per action (tap) at a skill's current tier, before Supercharge / Daily Boost.
    func baseXPPerAction(for skill: SkillID) -> Int {
        Balance.trainingTiers[currentTierIndex(for: skill)].xpPerAction
    }

    /// The next method a skill unlocks as (method, required level), or nil if on the top tier.
    func nextMethodUnlock(for skill: SkillID) -> (method: TrainingMethod, level: Int)? {
        let idx = currentTierIndex(for: skill)
        guard idx + 1 < Balance.trainingTiers.count else { return nil }
        return (skill.trainingMethods[idx + 1], Balance.trainingTiers[idx + 1].unlockLevel)
    }

    // MARK: Daily Boost

    /// Whether a Daily Boost is currently running.
    var isDoubleXPActive: Bool { (doubleXPExpiry ?? .distantPast) > Date() }

    /// Seconds left on the active Daily Boost (0 when inactive).
    var doubleXPRemaining: TimeInterval { max(0, (doubleXPExpiry ?? Date()).timeIntervalSinceNow) }

    /// Progress (0...1) of the active Daily Boost, measured against its *actual* duration
    /// (which Herblore can extend) so the countdown bar stays accurate.
    var doubleXPFraction: Double {
        guard doubleXPActiveDuration > 0 else { return 0 }
        return min(max(doubleXPRemaining / doubleXPActiveDuration, 0), 1)
    }

    /// The current global XP multiplier (Magic-boosted Daily Boost while active, otherwise 1×).
    var xpMultiplier: Double { isDoubleXPActive ? doubleXPPotency : 1 }

    /// True when the player has a coupon to spend and no boost is already running.
    var canActivateDoubleXP: Bool { !isDoubleXPActive && doubleXPCoupons > 0 }

    /// True when the player owns an Energy Cell and the given skill can accept an instant fill: it
    /// isn't already bursting and isn't already full. Available at any level — charge is not gated.
    func canUseEnergyCell(on skill: SkillID) -> Bool {
        energyCells > 0
            && !isSupercharged(skill)
            && energy(for: skill) < energyCapSeconds
    }

    // MARK: - Skill perks (account-wide buffs)

    /// Raw interpolated magnitude of a skill's perk at its current level.
    private func buffRaw(_ skill: SkillID) -> Double {
        guard let scaling = Balance.buffScaling[skill] else { return 0 }
        return Balance.buffValue(level: level(for: skill), scaling: scaling)
    }

    // Combat — tap "hit" shaping
    var accuracyBias: Double { buffRaw(.attack) }          // 0 = uniform roll; higher biases toward max
    var maxHitMultiplier: Double { buffRaw(.strength) }    // × base method XP (the hit ceiling)
    var minHitMultiplier: Double { buffRaw(.defence) }     // × base method XP (the hit floor)
    var energyRateMultiplier: Double { buffRaw(.hitpoints) }  // Energy banked per tap-proc
    var extraHitChance: Double { buffRaw(.ranged) }
    var superchargeBonus: Int { Int(buffRaw(.prayer).rounded()) }
    var doubleXPPotency: Double { buffRaw(.magic) }        // the live Daily Boost multiplier value

    // Gathering — idle engine
    var cacheChance: Double { buffRaw(.woodcutting) }
    var energyProcChance: Double { buffRaw(.fishing) }
    var energyCapSeconds: Double { max(Balance.maxEnergySeconds, buffRaw(.mining)) }
    /// Farming "Patient Growth": multiplies offline passive XP retention (app closed).
    var offlineXPEfficiency: Double { buffRaw(.farming) }
    /// Hunter "Trapper": multiplies OFFLINE passive XP (app closed). Neutral ×1 at level 1.
    var offlineRateMultiplier: Double { buffRaw(.hunter) }

    // Artisan — production & boosts
    var tapXPMultiplier: Double { 1 + buffRaw(.cooking) }
    var superchargeDurationMultiplier: Double { buffRaw(.firemaking) }
    var critMagnitude: Double { buffRaw(.crafting) }
    /// Smithing "Foundry": multiplies FOREGROUND idle XP (app open). Neutral ×1 at level 1.
    var foregroundIdleMultiplier: Double { buffRaw(.smithing) }
    var flatTapBonus: Double { buffRaw(.fletching) }
    var doubleXPBonusDuration: TimeInterval { buffRaw(.herblore) }
    var autoTapsPerSecond: Double { buffRaw(.runecraft) }
    /// Construction "Workshop": raises the OFFLINE accrual cap (hours). Neutral at `Balance.maxOfflineHours` (level 1).
    var offlineCapHours: Double { max(Balance.maxOfflineHours, buffRaw(.construction)) }

    // Support — tempo & meta
    var comboCeiling: Double { buffRaw(.agility) }
    /// Thieving "Pickpocket": chance (0…1) to refund a spent coupon or Supercharge.
    var refundChance: Double { buffRaw(.thieving) }
    var critChance: Double { buffRaw(.slayer) }

    /// Current Agility combo multiplier from the recent tap streak (decays once you stop tapping).
    var comboMultiplier: Double {
        guard comboCeiling > 1, comboStreak > 0,
              Date().timeIntervalSince(lastTapAt) <= Balance.agilityComboWindow else { return 1 }
        let frac = min(Double(comboStreak) / Double(Balance.agilityComboTapsToMax), 1)
        return 1 + (comboCeiling - 1) * frac
    }

    /// One tap's outcome, so the UI can animate crits, extra hits, caches, and Energy procs.
    struct TapResult {
        var xp: Int
        var didCrit: Bool = false
        var extraHits: Int = 0
        var gotCache: Bool = false
        var gotEnergy: Bool = false
    }

    /// Rolls a single "hit": XP within [min, max], biased toward max by Accuracy (Attack).
    private func rollHit(base: Double) -> Double {
        let maxHit = base * maxHitMultiplier
        let minHit = min(base * minHitMultiplier, maxHit)
        guard maxHit > minHit else { return maxHit }
        let u = Double.random(in: 0...1)
        let skewed = pow(u, 1.0 / (1.0 + accuracyBias))
        return minHit + (maxHit - minHit) * skewed
    }

    /// Number of *extra* hits a tap lands (Ranged). Chances > 100% guarantee +1 and roll for more.
    private func rollExtraHits() -> Int {
        var chance = extraHitChance
        var extra = 0
        while chance > 0 {
            if chance >= 1 { extra += 1; chance -= 1 }
            else {
                if Double.random(in: 0..<1) < chance { extra += 1 }
                break
            }
        }
        return extra
    }

    /// Resolves a full tap through the perk pipeline. See `docs/SKILL_BUFFS.md` for the order.
    func rollTap(for skill: SkillID) -> TapResult {
        let base = Double(baseXPPerAction(for: skill))
        let combo = comboMultiplier
        let hitCount = 1 + rollExtraHits()
        var didCrit = false
        var total = 0.0
        for _ in 0..<hitCount {
            var hit = rollHit(base: base) + flatTapBonus     // Fletching flat bonus
            hit *= tapXPMultiplier                            // Cooking
            hit *= combo                                      // Agility
            if critChance > 0, Double.random(in: 0..<1) < critChance {   // Slayer chance
                hit *= critMagnitude                          // Crafting magnitude
                didCrit = true
            }
            total += hit
        }
        var gotCache = false
        if cacheChance > 0, Double.random(in: 0..<1) < cacheChance {     // Woodcutting
            total += base * Balance.woodcuttingCacheMultiple
            gotCache = true
        }
        if isSupercharged(skill) { total *= Double(activeSuperchargeMultiplier(for: skill)) } // locked at activation
        if isDoubleXPActive { total *= doubleXPPotency }                 // Magic-boosted Daily Boost
        var gotEnergy = false
        let chargeChance = Balance.baseEnergyTapChance + energyProcChance       // base + Fishing "Big Catch"
        if chargeChance > 0, Double.random(in: 0..<1) < chargeChance {
            bankEnergySeconds(Balance.energyTapProcSeconds * energyRateMultiplier, to: skill)  // Hitpoints "Vitality"
            gotEnergy = true
        }
        return TapResult(xp: Int(total.rounded()), didCrit: didCrit,
                         extraHits: hitCount - 1, gotCache: gotCache, gotEnergy: gotEnergy)
    }

    /// Deterministic *average* XP per tap with all perks folded in — for display only.
    func expectedTapGain(for skill: SkillID) -> Int {
        let base = Double(baseXPPerAction(for: skill))
        let maxHit = base * maxHitMultiplier
        let minHit = min(base * minHitMultiplier, maxHit)
        let skewMean = (1 + accuracyBias) / (2 + accuracyBias)   // E[u^(1/(1+bias))]
        var hit = (minHit + (maxHit - minHit) * skewMean) + flatTapBonus
        hit *= tapXPMultiplier
        hit *= comboMultiplier
        hit *= 1 + critChance * (critMagnitude - 1)               // expected crit uplift
        var total = hit * (1 + extraHitChance)                    // expected extra hits
        total += cacheChance * base * Balance.woodcuttingCacheMultiple
        if isSupercharged(skill) { total *= Double(activeSuperchargeMultiplier(for: skill)) }
        if isDoubleXPActive { total *= doubleXPPotency }
        return max(1, Int(total.rounded()))
    }

    /// A formatted (current, next-level) description of a skill's perk magnitude, for the UI.
    func buffValues(for skill: SkillID) -> (current: String, next: String?) {
        let lvl = level(for: skill)
        let current = formattedBuff(skill, atLevel: lvl)
        let next = lvl < XPTable.maxLevel ? formattedBuff(skill, atLevel: lvl + 1) : nil
        return (current, next)
    }

    /// The next level at which this skill's *formatted* perk value actually changes, and that new
    /// value. Some perks (e.g. Prayer's integer Supercharge bonus) read the same across several
    /// levels, so the naive "next level" preview looks static — this scans ahead to the first level
    /// whose displayed magnitude differs, so the UI can show a meaningful "At Lv N: …" preview.
    func nextBuffChange(for skill: SkillID) -> (level: Int, value: String)? {
        let lvl = level(for: skill)
        guard lvl < XPTable.maxLevel else { return nil }
        let current = formattedBuff(skill, atLevel: lvl)
        for next in (lvl + 1)...XPTable.maxLevel {
            let candidate = formattedBuff(skill, atLevel: next)
            if candidate != current { return (next, candidate) }
        }
        return nil
    }

    /// Average XP/second a slotted skill earns passively while the app is in the foreground,
    /// mirroring `foregroundTick` (Smithing idle rate + any active Daily Boost). Display-only —
    /// used to animate idle "+N" pops without double-crediting XP.
    func expectedIdleGainPerSecond(for skill: SkillID) -> Double {
        Double(baseXPPerAction(for: skill))
            * Balance.passiveActionsPerSecond
            * foregroundIdleMultiplier
            * xpMultiplier
    }

    private func formattedBuff(_ skill: SkillID, atLevel lvl: Int) -> String {
        guard let scaling = Balance.buffScaling[skill] else { return "—" }
        let v = Balance.buffValue(level: lvl, scaling: scaling)
        switch skill.buff.kind {
        case .accuracy:            return String(format: "avg roll %.0f%% of max", (1 + v) / (2 + v) * 100)
        case .maxHit:              return String(format: "+%.0f%% max hit", (v - 1) * 100)
        case .minHit:              return String(format: "+%.0f%% min hit", (v - 1) * 100)
        case .energyRate:          return String(format: "×%.2f Energy per proc", v)
        case .extraHit:            return String(format: "%.0f%% extra hit", v * 100)
        case .superchargeBonus:    return String(format: "+%.0f Supercharge ×", v)
        case .doubleXPPotency:     return String(format: "%.2f× Daily Boost", v)
        case .cache:               return String(format: "%.0f%% bonus cache", v * 100)
        case .energyProc:          return String(format: "+%.0f%% charge chance", v * 100)
        case .energyCap:           return String(format: "%.0fs Energy cap", max(Balance.maxEnergySeconds, v))
        case .offline:             return String(format: "×%.2f offline XP kept", v)
        case .offlineRate:         return String(format: "×%.2f offline XP rate", v)
        case .tapPercent:          return String(format: "+%.0f%% tap XP", v * 100)
        case .superchargeDuration: return String(format: "×%.2f Supercharge time", v)
        case .critMagnitude:       return String(format: "×%.1f crit damage", v)
        case .foregroundRate:      return String(format: "×%.2f idle XP", v)
        case .flatTap:             return String(format: "+%.1f XP per tap", v)
        case .doubleXPDuration:    return String(format: "+%.0fs Daily Boost", v)
        case .autoTap:             return String(format: "%.1f taps/sec", v)
        case .offlineCap:          return String(format: "%.0fh offline cap", max(Balance.maxOfflineHours, v))
        case .combo:               return String(format: "up to ×%.2f combo", v)
        case .refund:              return String(format: "%.1f%% refund chance", v * 100)
        case .critChance:          return String(format: "%.0f%% crit chance", v * 100)
        }
    }

    /// Records a tap for Agility combo purposes (extends or resets the streak).
    private func registerComboTap() {
        let now = Date()
        if now.timeIntervalSince(lastTapAt) <= Balance.agilityComboWindow {
            comboStreak = min(comboStreak + 1, Balance.agilityComboTapsToMax)
        } else {
            comboStreak = 1
        }
        lastTapAt = now
    }

    /// The next training-slot unlock as (slot number, required total level), or nil if all unlocked.
    var nextSlotUnlock: (slot: Int, totalLevel: Int)? {
        for (i, threshold) in Balance.slotUnlockTotalLevels.enumerated() where totalLevel < threshold {
            return (i + 2, threshold)
        }
        return nil
    }

    // MARK: - Player actions

    /// Register a tap on a skill's trainable object. Returns the roll so the UI can animate it.
    @discardableResult
    func tap(_ skill: SkillID) -> TapResult {
        let result = rollTap(for: skill)
        addXP(Double(result.xp), to: skill)
        registerComboTap()
        return result
    }

    /// Assign or remove a skill from a training slot. Returns true if the state changed.
    @discardableResult
    func toggleSlot(_ skill: SkillID) -> Bool {
        if let index = slots.firstIndex(of: skill) {
            slots.remove(at: index)
            save()
            return true
        }
        guard isEligibleForSlot(skill), hasFreeSlot else { return false }
        slots.append(skill)
        save()
        return true
    }

    /// Swaps an AFK slot: drops `remove` and slots `add` in one step, so a player with every slot
    /// full can free one up and assign the skill they're on without leaving the training screen.
    /// Returns true when the swap succeeded.
    @discardableResult
    func swapSlot(remove: SkillID, add: SkillID) -> Bool {
        guard let index = slots.firstIndex(of: remove), isEligibleForSlot(add),
              !slots.contains(add) else { return false }
        slots[index] = add
        save()
        return true
    }

    /// Spend all banked Energy on a Supercharge. Returns true if one was triggered.
    @discardableResult
    func supercharge(_ skill: SkillID) -> Bool {
        let banked = energy(for: skill)
        guard banked >= Balance.minEnergyToSupercharge else { return false }
        let duration = banked * superchargeDurationMultiplier                // Firemaking extends the burst
        superchargeExpiryBySkill[skill] = Date().addingTimeInterval(duration)
        superchargeMultiplierBySkill[skill] = effectiveSuperchargeMultiplier // lock the boost so mid-burst level-ups don't change it
        if refundChance > 0, Double.random(in: 0..<1) < refundChance {       // Thieving "Pickpocket": keep the banked Energy
            notice = "🥷 Pickpocket! Energy refunded."
        } else {
            energyBySkill[skill] = 0
        }
        save()
        return true
    }

    // MARK: - Daily Boost actions

    /// Spend one coupon to start a Daily Boost across every skill. Duration is the base
    /// 5 minutes plus any Herblore extension; potency (1.5×+) comes from Magic.
    @discardableResult
    func activateDoubleXP() -> Bool {
        guard canActivateDoubleXP else { return false }
        doubleXPCoupons -= 1
        let duration = Balance.doubleXPDurationSeconds + doubleXPBonusDuration
        doubleXPActiveDuration = duration
        doubleXPExpiry = Date().addingTimeInterval(duration)
        if refundChance > 0, Double.random(in: 0..<1) < refundChance {       // Thieving "Pickpocket": nick the coupon back
            doubleXPCoupons += 1
            notice = "🥷 Pickpocket! Coupon refunded."
        }
        save()
        return true
    }

    /// Add coupons to the player's balance (free daily grant or a completed purchase).
    func addCoupons(_ count: Int, announce: Bool = true) {
        guard count > 0 else { return }
        doubleXPCoupons += count
        if announce {
            notice = "🎟️ +\(count) Daily Boost coupon\(count == 1 ? "" : "s")"
        }
        save()
    }

    // MARK: - Energy Cell actions

    /// Add Energy Cells to the player's balance (from a completed purchase).
    func addEnergyCells(_ count: Int, announce: Bool = true) {
        guard count > 0 else { return }
        energyCells += count
        if announce {
            notice = "🔋 +\(count) Energy Cell\(count == 1 ? "" : "s")"
        }
        save()
    }

    /// Spend one Energy Cell to instantly fill a single skill's Supercharge charge to its
    /// (perk-adjusted) cap — the skill the player is currently training. Taps build charge over
    /// time; this is just the on-demand, targeted top-up.
    @discardableResult
    func useEnergyCell(on skill: SkillID) -> Bool {
        guard canUseEnergyCell(on: skill) else { return false }
        energyCells -= 1
        energyBySkill[skill] = energyCapSeconds
        notice = "🔋 Energy Cell used — \(skill.displayName) charged to full."
        save()
        return true
    }

    /// Grants the free daily coupon the first time the app is opened each calendar day.
    @discardableResult
    func grantDailyCouponIfNeeded() -> Bool {
        let today = Self.dayKey()
        guard lastFreeCouponDay != today else { return false }
        lastFreeCouponDay = today
        let granted = Balance.dailyFreeCoupons
        doubleXPCoupons += granted
        if hasSeenOnboarding {
            notice = "🎁 Daily reward: +\(granted) Daily Boost coupon\(granted == 1 ? "" : "s")"
        }
        save()
        return true
    }

    private static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
        grantDailyCouponIfNeeded()
        lastActive = Date()
        lastTick = Date()
        save()
    }

    func resetProgress() {
        xpBySkill = Dictionary(uniqueKeysWithValues: SkillID.allCases.map { ($0, 0.0) })
        energyBySkill = [:]
        superchargeExpiryBySkill = [:]
        superchargeMultiplierBySkill = [:]
        slots = []
        levelUpEvent = nil
        doubleXPExpiry = nil
        lastActive = Date()
        lastTick = Date()
        save()
    }

    /// Explicit persistence hook for settings toggles.
    func persist() { save() }

    // MARK: - Time progression

    func setForeground(_ active: Bool) { isForeground = active }

    /// Called ~1x/second while in the foreground: credits passive XP + Energy and clears any
    /// Supercharge/Daily Boost whose wall-clock window has elapsed.
    func foregroundTick() {
        guard isForeground else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard dt > 0, dt < 3600 else { return } // ignore clock jumps
        for skill in slots {
            let actionsXP = Double(baseXPPerAction(for: skill)) * Balance.passiveActionsPerSecond * foregroundIdleMultiplier
            addXP(actionsXP * dt * xpMultiplier, to: skill)   // Smithing sets the idle rate; Daily Boost still applies
        }
        pruneExpiredSupercharges()
        expireDoubleXPIfNeeded()
        autosaveAccumulator += dt
        if autosaveAccumulator >= 15 {
            autosaveAccumulator = 0
            save()
        }
    }

    /// Called when the app returns to the foreground: credits offline XP to slotted skills
    /// (reduced-rate and capped), then resets the offline window.
    func handleBecameActive() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastActive)
        if elapsed > 0 {
            creditOfflineProgress(timeAway: elapsed)
        }
        pruneExpiredSupercharges()   // Supercharge expiry is wall-clock, so away time already counts
        expireDoubleXPIfNeeded()
        grantDailyCouponIfNeeded()
        // Resetting `lastActive` restarts the offline counter, so the next away period is measured
        // from now (and the capped window can't be "banked" across returns).
        lastActive = now
        lastTick = now
        isForeground = true
        save()
    }

    /// Called when the app leaves the foreground: stamp the time and persist.
    func handleWillResignActive() {
        isForeground = false
        lastActive = Date()
        save()
    }

    /// Credits offline passive XP to each *slotted* skill for the time the app was closed, at the
    /// base offline rate (`Balance.offlineXPMultiplier`) scaled by Hunter's `offlineRateMultiplier`,
    /// and clamped to `offlineCapHours` (raised by Construction). Boosts (Supercharge / Daily Boost)
    /// are consumed in real time, so they don't apply offline. Builds the "welcome back" summary
    /// when the player was away long enough.
    private func creditOfflineProgress(timeAway: TimeInterval) {
        guard !slots.isEmpty, timeAway > 0 else { return }
        let cap = offlineCapHours * 3600                                    // Construction raises the cap
        let credited = min(timeAway, cap)
        guard credited > 0 else { return }

        var entries: [OfflineProgress.Entry] = []
        for skill in slots {
            let ratePerSecond = Double(baseXPPerAction(for: skill))
                * Balance.passiveActionsPerSecond
                * offlineRateMultiplier                                     // Hunter (offline rate)
            let gained = ratePerSecond * credited
                * Balance.offlineXPMultiplier                              // base offline penalty (40%)
                * offlineXPEfficiency                                       // Farming (retention)
            guard gained > 0 else { continue }
            let fromLevel = level(for: skill)
            let before = xpBySkill[skill] ?? 0
            addXP(gained, to: skill, announceLevelUp: false)
            let earned = Int(((xpBySkill[skill] ?? 0) - before).rounded())
            guard earned > 0 else { continue }
            entries.append(.init(skill: skill, xpGained: earned,
                                 fromLevel: fromLevel, toLevel: level(for: skill)))
        }

        let total = entries.reduce(0) { $0 + $1.xpGained }
        guard total > 0, timeAway >= Balance.minOfflineSecondsForSummary else { return }
        offlineProgress = OfflineProgress(
            timeAway: timeAway,
            creditedTime: credited,
            wasCapped: timeAway > cap + 1,
            entries: entries,
            totalXP: total
        )
    }

    // MARK: - Internal mutation

    private func addXP(_ amount: Double, to skill: SkillID, announceLevelUp: Bool = true) {
        guard amount > 0 else { return }
        let current = xpBySkill[skill] ?? 0
        let oldLevel = XPTable.level(forXP: Int(current.rounded(.down)))
        // XP keeps accruing past level 99 (the progress bar simply stays full); the level itself
        // is capped at 99 by `XPTable.level`, so a maxed skill never re-announces a level-up.
        let updated = current + amount
        xpBySkill[skill] = updated
        let newLevel = XPTable.level(forXP: Int(updated.rounded(.down)))
        if announceLevelUp, newLevel > oldLevel {
            levelUpEvent = LevelUpEvent(skill: skill, newLevel: newLevel)
        }
    }

    /// Banks `seconds` of Supercharge Energy directly (used by the per-tap charge proc).
    private func bankEnergySeconds(_ seconds: Double, to skill: SkillID) {
        let current = energyBySkill[skill] ?? 0
        energyBySkill[skill] = min(current + seconds, energyCapSeconds)
    }

    /// Drops any Supercharge whose wall-clock window has elapsed, so the published state (and UI)
    /// reflect the burst ending even if the player never stops tapping.
    private func pruneExpiredSupercharges() {
        let now = Date()
        for (skill, expiry) in superchargeExpiryBySkill where expiry <= now {
            superchargeExpiryBySkill[skill] = nil
            superchargeMultiplierBySkill[skill] = nil   // drop the locked boost when the burst ends
        }
    }

    /// Clears the boost once its window has elapsed so the UI updates and the save stays clean.
    private func expireDoubleXPIfNeeded() {
        if let expiry = doubleXPExpiry, expiry <= Date() {
            doubleXPExpiry = nil
            save()
        }
    }

    // MARK: - Persistence

    private func load() {
        for skill in SkillID.allCases { xpBySkill[skill] = 0 }
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let saved = try? JSONDecoder().decode(SaveData.self, from: data) else {
            lastActive = Date()
            return
        }
        let now = Date()
        for skill in SkillID.allCases {
            xpBySkill[skill] = saved.xp[skill.rawValue] ?? 0
            if let e = saved.energy[skill.rawValue] { energyBySkill[skill] = e }
            if let expiry = saved.superchargeExpiry?[skill.rawValue] {
                if expiry > now {
                    superchargeExpiryBySkill[skill] = expiry
                    // Restore the boost that was locked in for this burst, if the save has one.
                    if let mult = saved.superchargeMultiplier?[skill.rawValue] {
                        superchargeMultiplierBySkill[skill] = mult
                    }
                }
            } else if let seconds = saved.supercharge[skill.rawValue], seconds > 0 {
                // Migrate a legacy save (remaining-seconds) to the wall-clock expiry model.
                superchargeExpiryBySkill[skill] = now.addingTimeInterval(seconds)
            }
        }
        slots = saved.slots.compactMap { SkillID(rawValue: $0) }
        hasSeenOnboarding = saved.hasSeenOnboarding
        soundEnabled = saved.soundEnabled
        hapticsEnabled = saved.hapticsEnabled
        lastActive = saved.lastActive
        doubleXPCoupons = saved.doubleXPCoupons ?? 0
        doubleXPExpiry = saved.doubleXPExpiry
        lastFreeCouponDay = saved.lastFreeCouponDay
        energyCells = saved.energyCells ?? 0
        if let expiry = doubleXPExpiry, expiry <= Date() { doubleXPExpiry = nil }
    }

    #if DEBUG
    /// Seeds representative demo state when launched with the `SEED_DEMO` env var
    /// (`ready` or `super`). Used for screenshots/UI verification; never runs in release.
    private func applyDemoSeedIfRequested() {
        guard let variant = ProcessInfo.processInfo.environment["SEED_DEMO"] else { return }
        let levels: [SkillID: Int] = [
            // Combat
            .attack: 34, .strength: 28, .defence: 22, .hitpoints: 25, .ranged: 15,
            .prayer: 11, .magic: 32,
            // Gathering
            .woodcutting: 55, .fishing: 35, .mining: 30, .farming: 12, .hunter: 16,
            // Artisan
            .cooking: 20, .firemaking: 18, .crafting: 15, .smithing: 24, .fletching: 13,
            .herblore: 9, .runecraft: 10, .construction: 8,
            // Support
            .agility: 16, .thieving: 14, .slayer: 11
        ]
        for (skill, lvl) in levels {
            let lo = XPTable.xp(toReach: lvl)
            let hi = XPTable.xp(toReach: lvl + 1)
            xpBySkill[skill] = Double(lo + (hi - lo) * 4 / 10)
        }
        slots = [.attack, .woodcutting, .fishing]
        energyBySkill = [.attack: 18, .woodcutting: 9, .fishing: 22]
        superchargeExpiryBySkill = [:]
        superchargeMultiplierBySkill = [:]
        doubleXPCoupons = 3
        energyCells = 2
        if variant == "super" {
            superchargeExpiryBySkill = [.attack: Date().addingTimeInterval(26)]
            superchargeMultiplierBySkill = [.attack: effectiveSuperchargeMultiplier]
            energyBySkill[.attack] = 0
            doubleXPExpiry = Date().addingTimeInterval(210) // 3:30 remaining
        }
        hasSeenOnboarding = true
        lastActive = Date()
        lastTick = Date()
        save()
    }

    /// Seeds a representative "welcome back" summary when launched with `OFFLINE_DEMO`, so the
    /// offline sheet can be screenshotted deterministically. Never runs in release.
    private func applyOfflineDemoIfRequested() {
        guard ProcessInfo.processInfo.environment["OFFLINE_DEMO"] != nil else { return }
        hasSeenOnboarding = true
        if slots.isEmpty { slots = [.woodcutting, .fishing, .attack] }
        let sampleXP: [SkillID: Int] = [.woodcutting: 8_640, .fishing: 5_180, .attack: 2_400]
        let entries: [OfflineProgress.Entry] = slots.map { skill in
            let from = level(for: skill)
            let xp = sampleXP[skill] ?? 3_000
            return .init(skill: skill, xpGained: xp,
                         fromLevel: from, toLevel: skill == .woodcutting ? from + 1 : from)
        }
        let away: TimeInterval = 8 * 3600 + 37 * 60
        offlineProgress = OfflineProgress(
            timeAway: away,
            creditedTime: min(away, offlineCapHours * 3600),
            wasCapped: false,
            entries: entries,
            totalXP: entries.reduce(0) { $0 + $1.xpGained }
        )
        // Stamp now so the real offline-accrual pass in `handleBecameActive` doesn't clobber
        // this deterministic demo summary.
        lastActive = Date()
        lastTick = Date()
    }
    #endif

    private func save() {
        let now = Date()
        // Persist Supercharge as absolute expiry dates (the new source of truth) and also as
        // remaining-seconds under the legacy `supercharge` key, so an older build could still read it.
        let futureExpiries = superchargeExpiryBySkill.filter { $0.value > now }
        let snapshot = SaveData(
            xp: Dictionary(uniqueKeysWithValues: xpBySkill.map { ($0.key.rawValue, $0.value) }),
            energy: Dictionary(uniqueKeysWithValues: energyBySkill.map { ($0.key.rawValue, $0.value) }),
            slots: slots.map(\.rawValue),
            supercharge: Dictionary(uniqueKeysWithValues: futureExpiries.map {
                ($0.key.rawValue, $0.value.timeIntervalSince(now))
            }),
            hasSeenOnboarding: hasSeenOnboarding,
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled,
            lastActive: lastActive,
            doubleXPCoupons: doubleXPCoupons,
            doubleXPExpiry: doubleXPExpiry,
            lastFreeCouponDay: lastFreeCouponDay,
            energyCells: energyCells,
            superchargeExpiry: Dictionary(uniqueKeysWithValues: futureExpiries.map {
                ($0.key.rawValue, $0.value)
            }),
            superchargeMultiplier: Dictionary(uniqueKeysWithValues: futureExpiries.compactMap { entry in
                superchargeMultiplierBySkill[entry.key].map { (entry.key.rawValue, $0) }
            })
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }
}

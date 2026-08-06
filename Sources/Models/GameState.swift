import SwiftUI

/// Fired when a skill gains a level, so the UI can celebrate it.
struct LevelUpEvent: Identifiable, Equatable {
    let id = UUID()
    let skill: SkillID
    let newLevel: Int
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
}

/// The single source of truth for all game state and rules.
@MainActor
final class GameState: ObservableObject {

    // MARK: Persisted state
    @Published private(set) var xpBySkill: [SkillID: Double] = [:]
    @Published private(set) var energyBySkill: [SkillID: Double] = [:]
    @Published private(set) var superchargeBySkill: [SkillID: Double] = [:]
    @Published private(set) var slots: [SkillID] = []
    @Published var hasSeenOnboarding: Bool = false
    @Published var soundEnabled: Bool = true
    @Published var hapticsEnabled: Bool = true

    /// Double XP coupons the player owns (free daily + in-app purchases).
    @Published private(set) var doubleXPCoupons: Int = 0
    /// When the current Double XP boost ends, or `nil` if no boost is active.
    @Published private(set) var doubleXPExpiry: Date?

    /// Most recent level-up, consumed by the UI for a celebratory toast.
    @Published var levelUpEvent: LevelUpEvent?

    /// Transient, user-facing message surfaced as a toast (daily reward, purchase, etc.).
    @Published var notice: String?

    // MARK: Runtime-only state
    private var isForeground: Bool = true
    private var lastTick: Date = Date()
    private var lastActive: Date = Date()
    private var lastFreeCouponDay: String?
    private var autosaveAccumulator: TimeInterval = 0

    private static let saveKey = "idleSkiller.save.v1"

    init() {
        load()
        lastTick = Date()
        if hasSeenOnboarding { grantDailyCouponIfNeeded() }
        #if DEBUG
        applyDemoSeedIfRequested()
        #endif
    }

    // MARK: - Derived values

    func xp(for skill: SkillID) -> Int { Int((xpBySkill[skill] ?? 0).rounded(.down)) }
    func level(for skill: SkillID) -> Int { XPTable.level(forXP: xp(for: skill)) }
    func energy(for skill: SkillID) -> Double { energyBySkill[skill] ?? 0 }
    func superchargeSeconds(for skill: SkillID) -> Double { superchargeBySkill[skill] ?? 0 }

    func isSupercharged(_ skill: SkillID) -> Bool { (superchargeBySkill[skill] ?? 0) > 0 }
    func isSlotted(_ skill: SkillID) -> Bool { slots.contains(skill) }
    func slotIndex(of skill: SkillID) -> Int? { slots.firstIndex(of: skill) }
    func isEligibleForSlot(_ skill: SkillID) -> Bool { level(for: skill) >= Balance.slotEligibilityLevel }
    func isMaxed(_ skill: SkillID) -> Bool { level(for: skill) >= XPTable.maxLevel }

    /// Progress (0...1) of banked Energy toward the 30s cap.
    func energyFraction(for skill: SkillID) -> Double {
        min(energy(for: skill) / Balance.maxEnergySeconds, 1.0)
    }

    func canSupercharge(_ skill: SkillID) -> Bool {
        !isSupercharged(skill) && energy(for: skill) >= Balance.minEnergyToSupercharge
    }

    var totalLevel: Int { SkillID.allCases.reduce(0) { $0 + level(for: $1) } }
    var totalXP: Int { SkillID.allCases.reduce(0) { $0 + xp(for: $1) } }
    var maxTotalLevel: Int { SkillID.allCases.count * XPTable.maxLevel }
    var maxSlots: Int { Balance.maxSlots(forTotalLevel: totalLevel) }
    var superchargeXPPerTap: Int { Balance.superchargeXPPerTap(forTotalLevel: totalLevel) }
    var maxedSkillCount: Int { SkillID.allCases.filter { isMaxed($0) }.count }
    var isFullyMaxed: Bool { maxedSkillCount == SkillID.allCases.count }
    var hasFreeSlot: Bool { slots.count < maxSlots }

    // MARK: Double XP

    /// Whether a Double XP boost is currently running.
    var isDoubleXPActive: Bool { (doubleXPExpiry ?? .distantPast) > Date() }

    /// Seconds left on the active Double XP boost (0 when inactive).
    var doubleXPRemaining: TimeInterval { max(0, (doubleXPExpiry ?? Date()).timeIntervalSinceNow) }

    /// The current global XP multiplier (2× while boosted, otherwise 1×).
    var xpMultiplier: Double { isDoubleXPActive ? Balance.doubleXPMultiplier : 1 }

    /// True when the player has a coupon to spend and no boost is already running.
    var canActivateDoubleXP: Bool { !isDoubleXPActive && doubleXPCoupons > 0 }

    /// Effective XP earned per tap on `skill`, folding in Supercharge and Double XP.
    func tapGain(for skill: SkillID) -> Int {
        let base = isSupercharged(skill) ? superchargeXPPerTap : 1
        return Int((Double(base) * xpMultiplier).rounded())
    }

    /// The next training-slot unlock as (slot number, required total level), or nil if all unlocked.
    var nextSlotUnlock: (slot: Int, totalLevel: Int)? {
        if maxSlots < 2 { return (2, Balance.slot2TotalLevel) }
        if maxSlots < 3 { return (3, Balance.slot3TotalLevel) }
        return nil
    }

    // MARK: - Player actions

    /// Register a tap on a skill's trainable object.
    func tap(_ skill: SkillID) {
        addXP(Double(tapGain(for: skill)), to: skill)
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

    /// Spend all banked Energy on a Supercharge. Returns true if one was triggered.
    @discardableResult
    func supercharge(_ skill: SkillID) -> Bool {
        let banked = energy(for: skill)
        guard banked >= Balance.minEnergyToSupercharge else { return false }
        superchargeBySkill[skill] = banked
        energyBySkill[skill] = 0
        save()
        return true
    }

    // MARK: - Double XP actions

    /// Spend one coupon to start a 10-minute, 2× XP boost across every skill.
    @discardableResult
    func activateDoubleXP() -> Bool {
        guard canActivateDoubleXP else { return false }
        doubleXPCoupons -= 1
        doubleXPExpiry = Date().addingTimeInterval(Balance.doubleXPDurationSeconds)
        save()
        return true
    }

    /// Add coupons to the player's balance (free daily grant or a completed purchase).
    func addCoupons(_ count: Int, announce: Bool = true) {
        guard count > 0 else { return }
        doubleXPCoupons += count
        if announce {
            notice = "🎟️ +\(count) Double XP coupon\(count == 1 ? "" : "s")"
        }
        save()
    }

    /// Grants the free daily coupon the first time the app is opened each calendar day.
    @discardableResult
    func grantDailyCouponIfNeeded() -> Bool {
        let today = Self.dayKey()
        guard lastFreeCouponDay != today else { return false }
        lastFreeCouponDay = today
        doubleXPCoupons += Balance.dailyFreeCoupons
        if hasSeenOnboarding {
            notice = "🎁 Daily reward: +\(Balance.dailyFreeCoupons) Double XP coupon\(Balance.dailyFreeCoupons == 1 ? "" : "s")"
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
        superchargeBySkill = [:]
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

    /// Called ~1x/second while in the foreground: credits passive XP + Energy and decays Supercharges.
    func foregroundTick() {
        guard isForeground else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastTick)
        lastTick = now
        guard dt > 0, dt < 3600 else { return } // ignore clock jumps
        for skill in slots {
            addXP(Balance.passiveXPPerSecond * dt * xpMultiplier, to: skill)
            addEnergy(dt, to: skill)
        }
        decaySupercharges(by: dt)
        expireDoubleXPIfNeeded()
        autosaveAccumulator += dt
        if autosaveAccumulator >= 15 {
            autosaveAccumulator = 0
            save()
        }
    }

    /// Called when the app returns to the foreground: credits *offline Energy only* (no passive XP).
    func handleBecameActive() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastActive)
        if elapsed > 0 {
            for skill in slots { addEnergy(elapsed, to: skill) }
            decaySupercharges(by: elapsed)
        }
        expireDoubleXPIfNeeded()
        grantDailyCouponIfNeeded()
        lastActive = now
        lastTick = now
        isForeground = true
    }

    /// Called when the app leaves the foreground: stamp the time and persist.
    func handleWillResignActive() {
        isForeground = false
        lastActive = Date()
        save()
    }

    // MARK: - Internal mutation

    private func addXP(_ amount: Double, to skill: SkillID) {
        guard amount > 0 else { return }
        let current = xpBySkill[skill] ?? 0
        guard current < Double(XPTable.maxXP) else { return }
        let oldLevel = XPTable.level(forXP: Int(current.rounded(.down)))
        let updated = min(current + amount, Double(XPTable.maxXP))
        xpBySkill[skill] = updated
        let newLevel = XPTable.level(forXP: Int(updated.rounded(.down)))
        if newLevel > oldLevel {
            levelUpEvent = LevelUpEvent(skill: skill, newLevel: newLevel)
        }
    }

    private func addEnergy(_ realSeconds: TimeInterval, to skill: SkillID) {
        let current = energyBySkill[skill] ?? 0
        let gained = realSeconds / Balance.realSecondsPerEnergySecond
        energyBySkill[skill] = min(current + gained, Balance.maxEnergySeconds)
    }

    private func decaySupercharges(by dt: TimeInterval) {
        for skill in SkillID.allCases {
            guard let remaining = superchargeBySkill[skill], remaining > 0 else { continue }
            let updated = remaining - dt
            superchargeBySkill[skill] = updated > 0 ? updated : nil
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
        for skill in SkillID.allCases {
            xpBySkill[skill] = saved.xp[skill.rawValue] ?? 0
            if let e = saved.energy[skill.rawValue] { energyBySkill[skill] = e }
            if let s = saved.supercharge[skill.rawValue] { superchargeBySkill[skill] = s }
        }
        slots = saved.slots.compactMap { SkillID(rawValue: $0) }
        hasSeenOnboarding = saved.hasSeenOnboarding
        soundEnabled = saved.soundEnabled
        hapticsEnabled = saved.hapticsEnabled
        lastActive = saved.lastActive
        doubleXPCoupons = saved.doubleXPCoupons ?? 0
        doubleXPExpiry = saved.doubleXPExpiry
        lastFreeCouponDay = saved.lastFreeCouponDay
        if let expiry = doubleXPExpiry, expiry <= Date() { doubleXPExpiry = nil }
    }

    #if DEBUG
    /// Seeds representative demo state when launched with the `SEED_DEMO` env var
    /// (`ready` or `super`). Used for screenshots/UI verification; never runs in release.
    private func applyDemoSeedIfRequested() {
        guard let variant = ProcessInfo.processInfo.environment["SEED_DEMO"] else { return }
        let levels: [SkillID: Int] = [
            .attack: 34, .strength: 28, .defence: 22, .hitpoints: 25, .ranged: 15,
            .magic: 13, .prayer: 11, .woodcutting: 30, .fishing: 20, .mining: 16
        ]
        for (skill, lvl) in levels {
            let lo = XPTable.xp(toReach: lvl)
            let hi = XPTable.xp(toReach: lvl + 1)
            xpBySkill[skill] = Double(lo + (hi - lo) * 4 / 10)
        }
        slots = [.attack, .woodcutting]
        energyBySkill = [.attack: 18, .woodcutting: 9]
        superchargeBySkill = [:]
        doubleXPCoupons = 3
        if variant == "super" {
            superchargeBySkill = [.attack: 26]
            energyBySkill[.attack] = 0
            doubleXPExpiry = Date().addingTimeInterval(423) // 7:03 remaining
        }
        hasSeenOnboarding = true
        lastActive = Date()
        lastTick = Date()
        save()
    }
    #endif

    private func save() {
        let snapshot = SaveData(
            xp: Dictionary(uniqueKeysWithValues: xpBySkill.map { ($0.key.rawValue, $0.value) }),
            energy: Dictionary(uniqueKeysWithValues: energyBySkill.map { ($0.key.rawValue, $0.value) }),
            slots: slots.map(\.rawValue),
            supercharge: Dictionary(uniqueKeysWithValues: superchargeBySkill.map { ($0.key.rawValue, $0.value) }),
            hasSeenOnboarding: hasSeenOnboarding,
            soundEnabled: soundEnabled,
            hapticsEnabled: hapticsEnabled,
            lastActive: lastActive,
            doubleXPCoupons: doubleXPCoupons,
            doubleXPExpiry: doubleXPExpiry,
            lastFreeCouponDay: lastFreeCouponDay
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.saveKey)
        }
    }
}

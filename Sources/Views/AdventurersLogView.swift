import SwiftUI

/// The Adventurer's Log — the player-facing home of the achievement/reward system. Two tabs:
/// an **Overview** (Reward Token balance, overall completion, and the Feats you're closest to
/// finishing) and **Feats** (drill into a Diary to see every Feat and its live progress).
///
/// Styled to match the app's dark translucent-card aesthetic and width-capped/centered so it
/// reads well on iPad as well as iPhone.
struct AdventurersLogView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab = .overview
    @State private var path: [FeatDiary] = []

    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case feats = "Feats"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                GameBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        TokenBalanceCard()
                        Picker("View", selection: $tab) {
                            ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch tab {
                        case .overview: LogOverview()
                        case .feats:    LogFeatList()
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Adventurer's Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: FeatDiary.self) { diary in
                FeatDiaryDetailView(diary: diary)
            }
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.environment["LOG_TAB"] == "feats" { tab = .feats }
                if let raw = ProcessInfo.processInfo.environment["OPEN_DIARY"],
                   let diary = FeatDiary(rawValue: raw) {
                    tab = .feats
                    path = [diary]
                }
                #endif
            }
        }
    }
}

// MARK: - Token balance hero

private struct TokenBalanceCard: View {
    @EnvironmentObject private var game: GameState
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.rewardToken.opacity(0.22)).frame(width: 52, height: 52)
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.rewardToken)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("REWARD TOKENS").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("\(game.tokens)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded)).monospacedDigit()
                Text("Earned by completing Feats").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .logCard()
    }
}

// MARK: - Overview tab

private struct LogOverview: View {
    @EnvironmentObject private var game: GameState

    /// Incomplete Feats you're closest to finishing — targets to chase.
    private var closest: [Feat] {
        FeatCatalog.all
            .filter { !game.isFeatComplete($0) }
            .sorted { game.featFraction($0) > game.featFraction($1) }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 16) {
            overallCard
            if !closest.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("CLOSEST FEATS", systemImage: "target")
                    VStack(spacing: 10) {
                        ForEach(closest) { FeatRow(feat: $0) }
                    }
                }
            }
        }
    }

    private var overallCard: some View {
        let done = game.totalFeatsCompleted
        let total = FeatCatalog.all.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("OVERALL", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(done) / \(total)")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
            }
            XPProgressBar(progress: total > 0 ? Double(done) / Double(total) : 0,
                          tint: .rewardToken, height: 8)
            Text(done == total ? "Every Feat complete — you legend."
                               : "Complete Feats to earn Reward Tokens.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .logCard()
    }
}

// MARK: - Feats tab (Diary list)

private struct LogFeatList: View {
    @EnvironmentObject private var game: GameState
    var body: some View {
        VStack(spacing: 12) {
            ForEach(FeatDiary.allCases) { diary in
                NavigationLink(value: diary) {
                    DiaryCard(diary: diary)
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
    }
}

private struct DiaryCard: View {
    @EnvironmentObject private var game: GameState
    let diary: FeatDiary

    var body: some View {
        let feats = FeatCatalog.feats(in: diary)
        let done = game.completedCount(in: diary)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(diary.tint.opacity(0.24)).frame(width: 44, height: 44)
                Image(systemName: diary.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(diary.tint)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(diary.title).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                    Spacer()
                    Text("\(done)/\(feats.count)")
                        .font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(done == feats.count ? .green : .secondary)
                }
                Text(diary.subtitle).font(.caption2).foregroundStyle(.secondary)
                XPProgressBar(progress: feats.isEmpty ? 0 : Double(done) / Double(feats.count),
                              tint: diary.tint, height: 5)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .contentShape(Rectangle())
        .logCard(cornerRadius: 14)
    }
}

// MARK: - Diary detail (all Feats in one Diary, grouped by tier)

struct FeatDiaryDetailView: View {
    @EnvironmentObject private var game: GameState
    let diary: FeatDiary

    private let tiers = FeatTier.allCases.sorted { $0.order < $1.order }

    var body: some View {
        ZStack {
            GameBackground()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    ForEach(tiers) { tier in
                        let feats = FeatCatalog.group(diary, tier)
                        if !feats.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                tierHeader(tier, feats: feats)
                                VStack(spacing: 10) {
                                    ForEach(feats) { FeatRow(feat: $0) }
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(diary.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        let feats = FeatCatalog.feats(in: diary)
        let done = game.completedCount(in: diary)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(diary.tint.opacity(0.24)).frame(width: 48, height: 48)
                Image(systemName: diary.icon).font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(diary.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(diary.subtitle).font(.subheadline.weight(.semibold))
                XPProgressBar(progress: feats.isEmpty ? 0 : Double(done) / Double(feats.count),
                              tint: diary.tint, height: 7)
                Text("\(done) / \(feats.count) Feats complete")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .logCard()
    }

    private func tierHeader(_ tier: FeatTier, feats: [Feat]) -> some View {
        let complete = game.isDiaryTierComplete(diary, tier)
        return HStack(spacing: 8) {
            Text(tier.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(tier.tint.opacity(0.22), in: Capsule())
                .overlay(Capsule().strokeBorder(tier.tint.opacity(0.5)))
                .foregroundStyle(tier.tint)
            Text("+\(Balance.Rewards.diaryTierBonus) bonus")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            if complete {
                Label("Cleared", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Shared Feat row

private struct FeatRow: View {
    @EnvironmentObject private var game: GameState
    let feat: Feat

    var body: some View {
        let done = game.isFeatComplete(feat)
        let progress = game.featProgress(feat)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill((done ? Color.green : feat.tier.tint).opacity(0.18))
                    .frame(width: 34, height: 34)
                Image(systemName: done ? "checkmark" : feat.diary.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(done ? .green : feat.tier.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(feat.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(done ? .secondary : .primary)
                    Spacer()
                    TokenTag(amount: feat.tokenReward, earned: done)
                }
                Text(feat.detail).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if feat.isCounter && !done {
                    XPProgressBar(progress: game.featFraction(feat), tint: feat.tier.tint, height: 5)
                    Text("\(progress) / \(feat.goal)")
                        .font(.caption2.weight(.medium)).monospacedDigit().foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .logCard(cornerRadius: 12)
    }
}

/// Small gold Token amount pill; dims to a check-style once earned.
private struct TokenTag: View {
    let amount: Int
    let earned: Bool
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.circle.fill").font(.caption2)
            Text("\(amount)").font(.caption2.weight(.bold)).monospacedDigit()
        }
        .foregroundStyle(earned ? Color.rewardToken : Color.rewardToken.opacity(0.65))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.rewardToken.opacity(earned ? 0.20 : 0.10), in: Capsule())
    }
}

// MARK: - Small helpers

private func sectionHeader(_ title: String, systemImage: String) -> some View {
    Label(title, systemImage: systemImage)
        .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
}

private extension View {
    /// The app's translucent card treatment used throughout the Log.
    func logCard(cornerRadius: CGFloat = 16) -> some View {
        background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.08)))
    }
}

import SwiftUI

/// Root switch between onboarding and the main game, plus the global game tick
/// and a shared level-up toast.
struct RootView: View {
    @EnvironmentObject private var game: GameState
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if game.hasSeenOnboarding {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .onReceive(ticker) { _ in game.foregroundTick() }
        .onChange(of: game.levelUpEvent) { _, event in
            if event != nil {
                SoundManager.shared.play(.levelUp, enabled: game.soundEnabled)
            }
        }
        .onChange(of: game.featEvent) { _, event in
            if event != nil {
                SoundManager.shared.play(.purchase, enabled: game.soundEnabled)
            }
        }
        .overlay(alignment: .top) {
            if let event = game.levelUpEvent {
                LevelUpToast(event: event)
                    .id(event.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: event.id) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        if game.levelUpEvent?.id == event.id {
                            withAnimation { game.levelUpEvent = nil }
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            if let notice = game.notice {
                NoticeToast(text: notice)
                    .id(notice)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: notice) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        if game.notice == notice {
                            withAnimation { game.notice = nil }
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            if let event = game.featEvent {
                FeatToast(event: event)
                    .id(event.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: event.id) {
                        try? await Task.sleep(nanoseconds: 2_600_000_000)
                        if game.featEvent?.id == event.id {
                            withAnimation { game.featEvent = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.levelUpEvent)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.notice)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.featEvent)
        .sheet(item: $game.offlineProgress) { progress in
            WelcomeBackView(progress: progress)
        }
    }
}

/// Transient banner shown whenever any skill levels up.
struct LevelUpToast: View {
    let event: LevelUpEvent

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(art: event.skill.art, size: 26, color: event.skill.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("LEVEL UP")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\(event.skill.displayName) reached level \(event.newLevel)")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(event.skill.tint.opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .padding(.top, 6)
    }
}

/// Transient banner for general notices (daily rewards, purchases).
struct NoticeToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.doubleXP.opacity(0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .padding(.top, 6)
    }
}

/// Celebratory banner shown when one or more Feats (or a whole Diary tier) complete, carrying the
/// Reward Tokens earned. Offset below the level-up/notice banners so they never overlap.
struct FeatToast: View {
    let event: FeatEvent

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(event.tint.opacity(0.25)).frame(width: 30, height: 30)
                Image(systemName: event.icon).font(.footnote.weight(.bold)).foregroundStyle(event.tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(event.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            if event.tokens > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "star.circle.fill").font(.caption2)
                    Text("+\(event.tokens)").font(.caption.weight(.bold)).monospacedDigit()
                }
                .foregroundStyle(Color.rewardToken)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.rewardToken.opacity(0.18), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.rewardToken.opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .padding(.top, 60)
    }
}

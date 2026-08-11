import SwiftUI

/// The two top-level destinations, shown via a shared segmented `TabSwitcher` in the nav bar
/// (identical placement on iPhone and iPad) rather than a platform tab bar.
enum AppTab: String, CaseIterable, Identifiable {
    case skills, raids
    var id: String { rawValue }
    var title: String {
        switch self {
        case .skills: return "Skills"
        case .raids: return "Raids"
        }
    }
}

/// Root switch between onboarding and the main game, plus the global game tick
/// and a shared level-up toast.
struct RootView: View {
    @EnvironmentObject private var game: GameState
    @State private var tab: AppTab = .skills
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if game.hasSeenOnboarding {
                Group {
                    switch tab {
                    case .skills: HomeView(tab: $tab)
                    case .raids: RaidsView(tab: $tab)
                    }
                }
                .onAppear {
                    #if DEBUG
                    let env = ProcessInfo.processInfo.environment
                    if env["OPEN_TAB"]?.lowercased() == "raids" || env["OPEN_RAID"] != nil || env["OPEN_APPLY"] != nil {
                        tab = .raids
                    }
                    #endif
                }
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

/// Compact segmented control that swaps between the Skills and Raids tabs. Rendered in each
/// screen's `.principal` toolbar slot so it centers in the nav bar on both iPhone and iPad.
struct TabSwitcher: View {
    @EnvironmentObject private var game: GameState
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let selected = tab == selection
                Button {
                    guard selection != tab else { return }
                    SoundManager.shared.play(.ui, enabled: game.soundEnabled)
                    withAnimation(.easeInOut(duration: 0.18)) { selection = tab }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                Capsule().fill(Color.accentColor.opacity(0.16))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.25), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
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

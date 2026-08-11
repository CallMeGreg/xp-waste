import SwiftUI

/// Root switch between onboarding and the main game, plus the global game tick
/// and a shared level-up toast.
struct RootView: View {
    @EnvironmentObject private var game: GameState
    @State private var tab = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if game.hasSeenOnboarding {
                TabView(selection: $tab) {
                    HomeView()
                        .tag(0)
                        .tabItem { Label("Skills", systemImage: "square.grid.2x2.fill") }
                    RaidsView()
                        .tag(1)
                        .tabItem { Label("Raids", systemImage: "flag.checkered") }
                }
                .onAppear {
                    #if DEBUG
                    let env = ProcessInfo.processInfo.environment
                    if env["OPEN_TAB"]?.lowercased() == "raids" || env["OPEN_RAID"] != nil || env["OPEN_APPLY"] != nil {
                        tab = 1
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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.levelUpEvent)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.notice)
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

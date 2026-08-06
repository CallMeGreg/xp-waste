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
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.levelUpEvent)
    }
}

/// Transient banner shown whenever any skill levels up.
struct LevelUpToast: View {
    let event: LevelUpEvent

    var body: some View {
        HStack(spacing: 10) {
            Text(event.skill.glyph).font(.title2)
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

import SwiftUI

/// First-launch, paged explainer of the core loop.
struct OnboardingView: View {
    @EnvironmentObject private var game: GameState
    @State private var page = 0

    private struct Card: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    private let cards: [Card] = [
        Card(icon: "🏆", title: "Train all 10 skills to 99",
             body: "Attack, Strength, Defence, Ranged, Magic, Hitpoints, Prayer, Woodcutting, Fishing and Mining — on the real Old School RuneScape XP curve."),
        Card(icon: "👆", title: "Tap to train",
             body: "Open a skill and tap its object to earn XP. Simple, satisfying, and always available."),
        Card(icon: "⚡️", title: "Slot skills & bank Energy",
             body: "Reach level 10 to slot a skill for passive XP. Slotted skills bank Energy in real time — even while the app is closed."),
        Card(icon: "🔥", title: "Supercharge for big bursts",
             body: "Spend banked Energy to Supercharge a skill: seconds of bonus XP per tap. Go away, come back, and unleash it.")
    ]

    var body: some View {
        ZStack {
            GameBackground()
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        cardView(card).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(action: advance) {
                    Text(page == cards.count - 1 ? "Begin training" : "Next")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Text(card.icon).font(.system(size: 92))
            Text(card.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(card.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func advance() {
        if page < cards.count - 1 {
            withAnimation { page += 1 }
        } else {
            game.completeOnboarding()
        }
    }
}

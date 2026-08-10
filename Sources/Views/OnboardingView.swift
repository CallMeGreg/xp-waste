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
        Card(icon: "🏆", title: "Train all 23 skills to 99",
             body: "Earn experience across 23 different skills — combat, gathering, artisan and support — to level each one up. The goal: reach level 99 in every skill and claim a max cape."),
        Card(icon: "👆", title: "Tap to train",
             body: "Open a skill and tap its object to earn XP. As you level up, that skill's training method improves into a faster, more rewarding one — and every tap earns more."),
        Card(icon: "⚡️", title: "AFK skills & bank charge",
             body: "Reach level 10 to put a skill in an AFK slot for passive XP. AFK skills bank Supercharge charge in real time — even while you're away."),
        Card(icon: "🔥", title: "Supercharge for big bursts",
             body: "Spend a skill's banked charge to Supercharge it — a timed burst of big bonus XP on every tap. The more charge you spend, the longer the burst. In a hurry? One Energy Cell fills charge on all your AFK skills at once."),
        Card(icon: "🎟️", title: "Daily Boost coupons",
             body: "Activate a coupon for a timed burst of multiplied XP across every skill — it even stacks with Supercharge. Claim a free one daily, or grab more anytime."),
        Card(icon: "🌟", title: "Every skill grants a perk",
             body: "Leveling any skill unlocks a permanent, account-wide perk — bigger Energy caps, stronger Supercharge, longer boosts, crit taps, richer daily rewards and more. The higher the level, the more powerful the perk.")
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
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
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
        .frame(maxWidth: 600)
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

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
        Card(icon: "trophy.fill", title: "Train all 23 skills to 99",
             body: "Earn experience across 23 different skills — combat, production, utility and gathering — to level each one up. The goal: reach level 99 in every skill and claim a max cape."),
        Card(icon: "hand.tap.fill", title: "Tap to train",
             body: "Open a skill and tap its object to earn XP. As you level up, that skill's training method improves into a faster, more rewarding one — and every tap earns more."),
        Card(icon: "bolt.fill", title: "AFK slots & Supercharge Energy",
             body: "Reach level 10 to put a skill in an AFK slot for passive XP. Tapping any skill has a small chance to build Supercharge Energy — Fishing's perk raises the odds."),
        Card(icon: "flame.fill", title: "Supercharge for big bursts",
             body: "Spend a skill's banked Energy to Supercharge it — a timed burst of big bonus XP on every tap. The more Energy you spend, the longer the burst. In a hurry? Use an Energy Cell to fill the skill you're training instantly."),
        Card(icon: "ticket.fill", title: "Boost Coupons",
             body: "Activate a coupon for a timed burst of multiplied XP across every skill — it even stacks with Supercharge. Claim a free one daily, or grab more anytime."),
        Card(icon: "sparkles", title: "Every skill grants a perk",
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
        .overlay(alignment: .topTrailing) {
            if page < cards.count - 1 {
                Button("Skip") { game.completeOnboarding() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20).padding(.vertical, 10)
            }
        }
    }

    private func cardView(_ card: Card) -> some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: card.icon)
                .font(.system(size: 68))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .frame(height: 96)
            Text(card.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(card.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
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

import SwiftUI

/// A single skill card on the Home grid.
struct SkillTileView: View {
    @EnvironmentObject private var game: GameState
    let skill: SkillID

    var body: some View {
        let level = game.level(for: skill)
        let slotted = game.isSlotted(skill)
        let supercharged = game.isSupercharged(skill)
        let ready = game.canSupercharge(skill)
        let method = game.currentMethod(for: skill)

        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(skill.tint.opacity(0.22))
                    .frame(width: 62, height: 62)
                ArtworkView(art: method.art, size: 30 * method.scale, color: method.tint ?? skill.tint)
                if slotted {
                    EnergyRing(fraction: game.energyFraction(for: skill), ready: ready)
                        .frame(width: 70, height: 70)
                }
            }
            .frame(width: 74, height: 74)

            Text(skill.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            HStack(spacing: 3) {
                Text("lv.").font(.caption2).foregroundStyle(.secondary)
                Text("\(level)").font(.caption.weight(.bold)).monospacedDigit()
            }

            XPProgressBar(progress: XPTable.progressToNextLevel(forXP: game.xp(for: skill)),
                          tint: skill.tint, height: 6)

            statusRow(slotted: slotted, supercharged: supercharged, ready: ready)
                .frame(height: 15)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor(supercharged: supercharged, ready: ready),
                              lineWidth: supercharged ? 2 : 1)
        )
    }

    @ViewBuilder
    private func statusRow(slotted: Bool, supercharged: Bool, ready: Bool) -> some View {
        HStack(spacing: 6) {
            if supercharged {
                Label("\(Int(game.superchargeSeconds(for: skill).rounded()))s",
                      systemImage: "flame.fill")
                    .font(.caption2.weight(.bold)).foregroundStyle(.orange)
            } else if ready {
                Label("Ready", systemImage: "flame")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.orange)
            } else if slotted, let idx = game.slotIndex(of: skill) {
                Label("AFK \(idx + 1)", systemImage: "bolt.fill")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.yellow)
            } else if game.isMaxed(skill) {
                Label("Maxed", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.green)
            } else {
                Text(" ").font(.caption2)
            }
        }
    }

    private func borderColor(supercharged: Bool, ready: Bool) -> Color {
        if supercharged { return .orange.opacity(0.85) }
        if ready { return .yellow.opacity(0.55) }
        return .white.opacity(0.07)
    }
}

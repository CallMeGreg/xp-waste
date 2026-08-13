import SwiftUI

/// "Welcome back" summary presented when the player returns and their slotted skills earned
/// XP while the app was closed. Shows time away, per-skill gains, and any level-ups.
struct WelcomeBackView: View {
    let progress: OfflineProgress
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    totalBanner
                    if progress.wasCapped { cappedNote }
                    VStack(spacing: 10) {
                        ForEach(progress.entries) { entry in
                            OfflineSkillRow(entry: entry)
                        }
                    }
                    collectButton
                }
                .padding(16)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(GameBackground())
            .navigationTitle("Welcome Back")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.yellow)
            Text("While you were away…")
                .font(.title3.weight(.bold))
            Text("Gone for \(Format.duration(progress.timeAway))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    private var totalBanner: some View {
        VStack(spacing: 4) {
            Text("+\(Format.abbrev(progress.totalXP)) XP")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .contentTransition(.numericText())
            Text("earned across \(progress.entries.count) slot\(progress.entries.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.yellow.opacity(0.25)))
    }

    private var cappedNote: some View {
        Label(
            "Offline training caps at \(hoursText) — only the first \(hoursText) counted.",
            systemImage: "hourglass"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var collectButton: some View {
        Button { dismiss() } label: {
            Text("Collect")
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.black)
        }
        .buttonStyle(PressableStyle())
        .padding(.top, 4)
    }

    private var hoursText: String {
        let h = Balance.maxOfflineHours
        let value = h == h.rounded() ? String(format: "%.0f", h) : String(format: "%.1f", h)
        return "\(value)h"
    }
}

/// A single skill's offline gain: emblem, XP earned, and a level badge (highlighted on level-up).
private struct OfflineSkillRow: View {
    let entry: OfflineProgress.Entry

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(art: entry.skill.art, size: 30, color: entry.skill.tint)
                .padding(8)
                .background(entry.skill.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.skill.displayName)
                    .font(.subheadline.weight(.semibold))
                Text("+\(Format.abbrev(entry.xpGained)) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            levelBadge
        }
        .padding(10)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.07)))
    }

    @ViewBuilder private var levelBadge: some View {
        if entry.leveledUp {
            HStack(spacing: 4) {
                Text("lv. \(entry.fromLevel)").foregroundStyle(.secondary)
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                Text("\(entry.toLevel)").fontWeight(.bold).foregroundStyle(.yellow)
            }
            .font(.caption.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.yellow.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.4)))
        } else {
            Text("lv. \(entry.toLevel)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: Capsule())
        }
    }
}

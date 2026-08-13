import SwiftUI

/// Settings: feedback toggles, a how-to recap, an at-a-glance progress summary, progress reset,
/// and about info.
struct SettingsView: View {
    @EnvironmentObject private var game: GameState
    @State private var showResetConfirm = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Feedback") {
                    Toggle("Haptics", isOn: $game.hapticsEnabled)
                        .onChange(of: game.hapticsEnabled) { _, _ in game.persist() }
                    Toggle("Sound effects", isOn: $game.soundEnabled)
                        .onChange(of: game.soundEnabled) { _, on in
                            game.persist()
                            if on { SoundManager.shared.play(.ui, enabled: true) }
                        }
                }

                Section("How to play") {
                    infoRow("hand.tap.fill", "Tap a skill's object to earn XP.")
                    infoRow("moon.zzz.fill", "Reach level 10 to put a skill in an AFK slot for passive XP.")
                    infoRow("bolt.fill", "Tapping a skill can spark Supercharge Energy — Fishing raises the odds.")
                    infoRow("flame.fill", "Supercharge to spend Energy for bonus XP per tap.")
                    infoRow("ticket.fill", "Activate a Boost Coupon for a timed XP boost on every skill — one free daily. Grows stronger and longer as you level Magic & Herblore.")
                }

                statsSection

                Section("Data") {
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("Reset all progress", systemImage: "trash")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version).foregroundStyle(.secondary)
                    }
                    Text("Inspired by Old School RuneScape. Not affiliated with or endorsed by Jagex.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Reset all progress?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) { game.resetProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases all levels, XP, slots and Energy.")
            }
        }
    }

    /// A compact account overview (moved here from the former Stats screen).
    private var statsSection: some View {
        Section("Stats") {
            statRow("Total level", "\(game.totalLevel) / \(game.maxTotalLevel)")
            statRow("Total XP", Format.abbrev(game.totalXP))
            statRow("Skills maxed", "\(game.maxedSkillCount) / \(SkillID.allCases.count)")
            statRow("AFK slots", "\(game.slots.count) / \(game.maxSlots)")
            statRow("Supercharge", "×\(game.effectiveSuperchargeMultiplier) tap XP")
            statRow("Boost Coupons", "\(game.doubleXPCoupons)")
            statRow("Energy Cells", "\(game.energyCells)")
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22, alignment: .center)
            Text(text).font(.subheadline)
        }
    }
}

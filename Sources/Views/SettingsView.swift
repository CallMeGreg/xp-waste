import SwiftUI

/// Settings: feedback toggles, a how-to recap, progress reset, and about info.
struct SettingsView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
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
                    infoRow("👆", "Tap a skill's object to earn XP.")
                    infoRow("⚡️", "Reach level 10 to put a skill in an AFK slot for passive XP.")
                    infoRow("🔋", "Tapping a skill can spark Supercharge charge — Fishing raises the odds.")
                    infoRow("🔥", "Supercharge to spend Energy for bonus XP per tap.")
                    infoRow("🎟️", "Activate a Daily Boost coupon for 5 min of 1.5× on every skill — one free daily.")
                }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset all progress?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) { game.resetProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases all levels, XP, slots and Energy.")
            }
        }
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(icon)
            Text(text).font(.subheadline)
        }
    }
}

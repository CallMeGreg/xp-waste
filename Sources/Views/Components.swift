import SwiftUI

/// Compact number formatting helpers (1,154 · 12.3K · 6.52M).
enum Format {
    static func abbrev(_ value: Int) -> String {
        switch abs(value) {
        case 1_000_000...:
            return String(format: "%.2fM", Double(value) / 1_000_000)
        case 100_000...:
            return String(format: "%.0fK", Double(value) / 1_000)
        case 10_000...:
            return String(format: "%.1fK", Double(value) / 1_000)
        default:
            return value.formatted()
        }
    }

    /// Formats a duration as `M:SS`, rounding up so a fresh boost reads its full length.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

extension Color {
    /// Accent used across the Double XP boost UI (a vivid violet, distinct from the
    /// yellow slot / orange Supercharge colors).
    static let doubleXP = Color(red: 0.60, green: 0.36, blue: 0.98)
}

/// App-wide dark background gradient.
struct GameBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.09, green: 0.11, blue: 0.10),
                     Color(red: 0.04, green: 0.05, blue: 0.06)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

/// A slim horizontal XP / progress bar.
struct XPProgressBar: View {
    var progress: Double
    var tint: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// A circular Energy meter drawn around a slotted skill's glyph.
struct EnergyRing: View {
    var fraction: Double
    var ready: Bool
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(ready ? Color.yellow : Color.orange,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ready ? .yellow.opacity(0.6) : .clear, radius: ready ? 4 : 0)
        }
    }
}

/// Button style that gives a springy press-down scale.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

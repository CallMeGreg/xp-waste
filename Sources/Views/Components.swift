import SwiftUI

/// Compact number formatting helpers (1,154 · 12.3K · 6.52M).
enum Format {
    static func abbrev(_ value: Int) -> String { formatAbbrev(value, compact: false) }

    /// Always-abbreviated form for tight, uniform columns (e.g. the lamp Apply sheet): values in the
    /// thousands render as K with extra precision (9,720 → "9.72K") so no row shows a bare 4–5 digit
    /// number beside abbreviated ones.
    static func abbrevCompact(_ value: Int) -> String { formatAbbrev(value, compact: true) }

    private static func formatAbbrev(_ value: Int, compact: Bool) -> String {
        let v = Double(value)
        let a = abs(v)
        // Round at the unit's display precision *first* so 999,950 rolls up to "1.00M", never "1000K".
        if a >= 1_000_000 || (a >= 100_000 && (a / 1_000).rounded() >= 1_000) {
            return String(format: "%.2fM", v / 1_000_000)
        }
        switch a {
        case 100_000...: return String(format: "%.0fK", v / 1_000)
        case 10_000...:  return String(format: "%.1fK", v / 1_000)
        case 1_000...:   return compact ? String(format: "%.2fK", v / 1_000) : value.formatted()
        default:         return value.formatted()
        }
    }

    /// Formats a duration as `M:SS`, rounding up so a fresh boost reads its full length.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Formats a multiplier as `×N` when whole (`×2` · `×5`) and `×N.N` otherwise (`×4.5`), so
    /// clean integer multipliers stay tidy while fractional ones (e.g. Prayer-scaled Supercharge)
    /// still read precisely.
    static func mult(_ v: Double) -> String {
        v == v.rounded() ? String(format: "×%.0f", v) : String(format: "×%.1f", v)
    }

    /// Formats a longer span in words (`2d 3h` · `8h 37m` · `45m` · `30s`) for the offline summary.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let secs = total % 60
        if days > 0 { return hours > 0 ? "\(days)d \(hours)h" : "\(days)d" }
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        if minutes > 0 { return secs > 0 ? "\(minutes)m \(secs)s" : "\(minutes)m" }
        return "\(secs)s"
    }
}

/// Responsive layout helpers so wide screens (iPad, landscape) use their full width while
/// iPhone (compact width) keeps its single-column look unchanged.
enum Layout {
    /// Content width cap for a scrolling column: narrow & centered on compact width, much wider on
    /// regular width so multi-column grids can fill an iPad screen without stretching edge-to-edge.
    static func maxWidth(_ hSize: UserInterfaceSizeClass?, compact: CGFloat, regular: CGFloat) -> CGFloat {
        hSize == .regular ? regular : compact
    }

    /// Grid columns that collapse to a single column on compact width (matching the iPhone list) and
    /// fan out to `count` flexible columns on regular width. Cells align to the top of their row so
    /// uneven-height cards (e.g. skill groups with different row counts) line up cleanly.
    static func columns(_ hSize: UserInterfaceSizeClass?, count: Int = 2, spacing: CGFloat = 14) -> [GridItem] {
        hSize == .regular
            ? Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: count)
            : [GridItem(.flexible(), alignment: .top)]
    }

    /// True on regular width (iPad / landscape) — a small readability shorthand at call sites.
    static func isWide(_ hSize: UserInterfaceSizeClass?) -> Bool { hSize == .regular }
}

extension Color {
    /// Accent used across the Daily Boost UI (a vivid violet, distinct from the
    /// yellow slot / orange Supercharge colors).
    static let doubleXP = Color(red: 0.60, green: 0.36, blue: 0.98)

    /// Gold accent for Reward Tokens and the Diary.
    static let rewardToken = Color(red: 0.95, green: 0.79, blue: 0.36)

    /// High-contrast label color for content drawn on top of the solid `rewardToken` gold — a deep
    /// espresso that stays legible where white would wash out on the light-gold fill.
    static let rewardTokenText = Color(red: 0.16, green: 0.11, blue: 0.02)
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

/// A circular Energy meter drawn around a slotted skill's icon.
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

import SwiftUI

/// The five top-level destinations, shown in a custom bottom tab bar (`AppTabBar`) with identical
/// placement on iPhone and iPad.
enum AppTab: String, CaseIterable, Identifiable {
    case skills, raids, shop, log, settings
    var id: String { rawValue }
    var title: String {
        switch self {
        case .skills:   return "Skills"
        case .raids:    return "Raids"
        case .shop:     return "Shop"
        case .log:      return "Log"
        case .settings: return "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .skills:   return "square.grid.2x2.fill"
        case .raids:    return "shield.fill"
        case .shop:     return "cart.fill"
        case .log:      return "book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Root switch between onboarding and the main game, plus the global game tick
/// and a shared level-up toast.
struct RootView: View {
    @EnvironmentObject private var game: GameState
    @State private var tab: AppTab = .skills
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if game.hasSeenOnboarding {
                mainInterface
            } else {
                OnboardingView()
            }
        }
        .onReceive(ticker) { _ in game.foregroundTick() }
        .onChange(of: game.levelUpEvent) { _, event in
            if event != nil {
                SoundManager.shared.play(.levelUp, enabled: game.soundEnabled)
            }
        }
        .onChange(of: game.featEvent) { _, event in
            if event != nil {
                SoundManager.shared.play(.purchase, enabled: game.soundEnabled)
            }
        }
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
        .overlay(alignment: .top) {
            if let notice = game.notice {
                NoticeToast(text: notice)
                    .id(notice)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: notice) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        if game.notice == notice {
                            withAnimation { game.notice = nil }
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            if let event = game.featEvent {
                FeatToast(event: event)
                    .id(event.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: event.id) {
                        try? await Task.sleep(nanoseconds: 2_600_000_000)
                        if game.featEvent?.id == event.id {
                            withAnimation { game.featEvent = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.levelUpEvent)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: game.notice)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: game.featEvent)
        .sheet(item: $game.offlineProgress) { progress in
            WelcomeBackView(progress: progress)
        }
    }

    /// The main game interface: the selected tab's content with a custom bottom tab bar pinned
    /// below it. All five destinations are kept alive so each keeps its own navigation and scroll
    /// state when switching tabs. A custom bar (rather than `TabView`) guarantees the tabs sit at
    /// the bottom identically on iPhone and iPad — iPadOS floats the native tab bar at the top.
    ///
    /// The bar is laid out in a `VStack` *below* the tab content (rather than as a
    /// `safeAreaInset` overlay) so it never covers the scrollable area. A safe-area inset applied
    /// out here wasn't reaching the scroll views inside each tab's own `NavigationStack`, which let
    /// the last rows scroll underneath the bar; bounding the content above the bar fixes every tab.
    private var mainInterface: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases) { item in
                    tabContent(item)
                        .opacity(tab == item ? 1 : 0)
                        .allowsHitTesting(tab == item)
                        .accessibilityHidden(tab != item)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppTabBar(selection: $tab)
        }
        .onAppear {
            #if DEBUG
            if let initial = Self.debugInitialTab() { tab = initial }
            #endif
        }
    }

    /// The root view for each bottom tab. Each destination owns its own `NavigationStack`.
    @ViewBuilder
    private func tabContent(_ tab: AppTab) -> some View {
        switch tab {
        case .skills:   HomeView()
        case .raids:    RaidsView()
        case .shop:     BoostsView()
        case .log:      AdventurersLogView()
        case .settings: SettingsView()
        }
    }

    #if DEBUG
    /// Maps the screenshot/deep-link env vars to the tab that should be selected on launch, so the
    /// existing debug hooks keep landing on the right destination now that they're tabs.
    private static func debugInitialTab() -> AppTab? {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["OPEN_TAB"]?.lowercased(),
           let tab = AppTab(rawValue: raw) { return tab }
        if env["OPEN_RAID"] != nil || env["OPEN_APPLY"] != nil { return .raids }
        switch env["OPEN_SHEET"] {
        case "doublexp": return .shop
        case "log":      return .log
        default:         break
        }
        if env["OPEN_DIARY"] != nil { return .log }
        if env["OPEN_SKILL"] != nil { return .skills }
        return nil
    }
    #endif
}

/// Custom bottom tab bar used in place of `TabView`, so the tabs sit at the bottom on both iPhone
/// and iPad (iPadOS floats the native tab bar at the top). Styled to match the app's dark theme and
/// gold accent, and extends its material under the home indicator via `safeAreaInset`.
struct AppTabBar: View {
    @EnvironmentObject private var game: GameState
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { item in
                let isSelected = selection == item
                Button {
                    if selection != item {
                        withAnimation(.easeInOut(duration: 0.15)) { selection = item }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .frame(height: 24)
                        Text(item.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
        .background {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .sensoryFeedback(trigger: selection) { _, _ in
            game.hapticsEnabled ? .selection : nil
        }
    }
}

struct LevelUpToast: View {
    let event: LevelUpEvent

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(art: event.skill.art, size: 26, color: event.skill.tint)
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

/// Transient banner for general notices (daily rewards, purchases).
struct NoticeToast: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.doubleXP.opacity(0.7), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .padding(.top, 6)
    }
}

/// Celebratory banner shown when one or more Feats (or a whole Diary tier) complete, carrying the
/// Reward Tokens earned. Offset below the level-up/notice banners so they never overlap.
struct FeatToast: View {
    let event: FeatEvent

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(event.tint.opacity(0.25)).frame(width: 30, height: 30)
                Image(systemName: event.icon).font(.footnote.weight(.bold)).foregroundStyle(event.tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title).font(.subheadline.weight(.bold)).lineLimit(1)
                Text(event.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            if event.tokens > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "star.circle.fill").font(.caption2)
                    Text("+\(event.tokens)").font(.caption.weight(.bold)).monospacedDigit()
                }
                .foregroundStyle(Color.rewardToken)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.rewardToken.opacity(0.18), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.rewardToken.opacity(0.7), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .padding(.top, 60)
    }
}

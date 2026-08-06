import SwiftUI

@main
struct XPWasteApp: App {
    @StateObject private var game = GameState()
    @StateObject private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
                .task {
                    store.onGrant = { [weak game] coupons in game?.addCoupons(coupons) }
                    store.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                game.handleBecameActive()
            case .inactive, .background:
                game.handleWillResignActive()
            @unknown default:
                break
            }
        }
    }
}

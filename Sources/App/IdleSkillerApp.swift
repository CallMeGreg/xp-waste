import SwiftUI

@main
struct IdleSkillerApp: App {
    @StateObject private var game = GameState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.dark)
                .tint(.accentColor)
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

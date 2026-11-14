import SwiftUI

@main
struct ColorFlowApp: App {
    private let model = Result { try GameModel() }

    var body: some Scene {
        WindowGroup {
            GameRootView(model: model)
        }
    }
}

private struct GameRootView: View {
    let model: Result<GameModel, Error>
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSplash = true

    var body: some View {
        ZStack {
            if showingSplash {
                SplashView()
            } else {
                switch model {
                case .success(let game): GameView(model: game)
                case .failure: ContentUnavailableView("Unable to Load Levels", systemImage: "exclamationmark.triangle",
                                                      description: Text("The game content is damaged. Please reinstall Color Flow."))
                }
            }
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, showingSplash else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                showingSplash = false
            } catch {
                // Only time spent in the foreground counts toward the splash.
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                if case .success(let game) = model { game.finishAnimation() }
                showingSplash = true
            }
        }
    }
}

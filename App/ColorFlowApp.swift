import SwiftUI

@main
struct ColorFlowApp: App {
    private let model = Result { try GameModel() }

    var body: some Scene {
        WindowGroup {
            switch model {
            case .success(let game): GameView(model: game)
            case .failure: ContentUnavailableView("Unable to Load Levels", systemImage: "exclamationmark.triangle",
                                                  description: Text("The game content is damaged. Please reinstall Color Flow."))
            }
        }
    }
}

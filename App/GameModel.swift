import ColorFlowCore
import Foundation
import Observation

struct PourPresentation {
    let slot: Int
    let color: PaintColor
    let initialUnits: Int
    let cells: [Cell]
    let before: GameState
}

@MainActor @Observable
final class GameModel {
    let levels: [LevelDefinition]
    let store: ProgressStore
    var progress: GameProgress
    var pour: PourPresentation?
    var clearedDuringPour = 0
    var pourDestination: Cell?
    var fillingCell: Cell?
    var saveError: String?
    private let engines: [PuzzleEngine]
    private var animation: Task<Void, Never>?

    var level: LevelDefinition { levels[progress.levelID - 1] }
    var engine: PuzzleEngine { engines[progress.levelID - 1] }
    var outcome: GameOutcome { engine.outcome(state: progress.state) }
    var busy: Bool { pour != nil }
    var finalLevel: Bool { level.id == levels.count }
    var presentationState: GameState { pour?.before ?? progress.state }

    init() throws {
        levels = try LevelCatalog.load()
        engines = try levels.map { try PuzzleEngine(level: $0) }
        let environment = ProcessInfo.processInfo.environment
        let testing = environment["COLOR_FLOW_UI_TEST"] == "1"
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let filename = testing ? "UI-Tests/\(environment["COLOR_FLOW_TEST_SESSION"] ?? "default").json" : "progress.json"
        store = ProgressStore(url: directory.appendingPathComponent("ColorFlow/\(filename)"))
        if testing && environment["COLOR_FLOW_RESET"] == "1" {
            try? FileManager.default.removeItem(at: store.url)
        }
        progress = store.load(levels: levels)
        if testing, environment["COLOR_FLOW_RESET"] == "1",
           let levelID = environment["COLOR_FLOW_TEST_LEVEL"].flatMap(Int.init),
           let level = levels.first(where: { $0.id == levelID }) {
            progress = GameProgress(level: level)
        }
    }

    func take(queue: Int) {
        guard !busy, let next = try? engine.applying(.take(queue: queue), to: progress.state) else { return }
        progress.state = next
        save()
    }

    func isCleared(_ cell: Cell) -> Bool {
        engine.isCleared(cell, state: presentationState) ||
            pour?.cells.prefix(clearedDuringPour).contains(cell) == true
    }

    func displayedBucket(slot: Int) -> PaintTin? {
        guard var bucket = presentationState.buckets[slot] else { return nil }
        if pour?.slot == slot { bucket.paintUnits -= clearedDuringPour }
        return bucket.paintUnits > 0 ? bucket : nil
    }

    func pour(slot: Int, reducedMotion: Bool) {
        guard !busy, let result = try? engine.pourResult(slot: slot, state: progress.state),
              let bucket = progress.state.buckets[slot] else { return }
        let presentation = PourPresentation(slot: slot, color: bucket.color, initialUnits: bucket.paintUnits,
                                            cells: result.cells, before: progress.state)
        progress.state = result.state
        save()
        pour = presentation
        animation = Task { [weak self] in
            await self?.animate(presentation, reducedMotion: reducedMotion)
        }
    }

    private func animate(_ presentation: PourPresentation, reducedMotion: Bool) async {
        let fastTests = ProcessInfo.processInfo.environment["COLOR_FLOW_FAST_ANIMATION"] == "1"
        let brief = reducedMotion || fastTests
        let fillDuration = brief ? 0.008 : 0.25
        let removalPause = brief ? 0.008 : 0.1
        let columnTravel = brief ? 0.008 : 0.25
        var previousColumn = presentation.cells[0].column
        do {
            try await Task.sleep(for: .seconds(brief ? 0.008 : 0.2))
            for (index, cell) in presentation.cells.enumerated() {
                pourDestination = cell
                if cell.column != previousColumn {
                    fillingCell = nil
                    try await Task.sleep(for: .seconds(columnTravel))
                }
                fillingCell = cell
                try await Task.sleep(for: .seconds(fillDuration))
                clearedDuringPour += 1
                let nextIndex = index + 1
                if nextIndex == presentation.cells.count || presentation.cells[nextIndex].column != cell.column {
                    fillingCell = nil
                }
                try await Task.sleep(for: .seconds(removalPause))
                previousColumn = cell.column
            }
            fillingCell = nil
            try await Task.sleep(for: .seconds(brief ? 0.008 : 0.15))
            finishAnimation()
        } catch {
            // The complete move is already saved; backgrounding ends presentation.
        }
    }

    func finishAnimation() {
        animation?.cancel()
        animation = nil
        pour = nil
        clearedDuringPour = 0
        pourDestination = nil
        fillingCell = nil
    }

    func restart() {
        guard !busy else { return }
        progress = GameProgress(level: level)
        save()
    }

    func advance() {
        guard !busy, outcome == .won else { return }
        progress = GameProgress(level: levels[finalLevel ? 0 : progress.levelID])
        save()
    }

    func save() {
        do {
            try store.save(progress)
            saveError = nil
        } catch {
            saveError = "Your progress could not be saved. Free some storage and try again."
        }
    }
}

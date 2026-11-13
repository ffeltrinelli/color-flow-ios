import ColorFlowCore
import Foundation
import Observation

struct PourPresentation {
    let column: Int
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
    var filledDuringPour = Set<Cell>()
    var tilted = false
    var streamEndRow: Int?
    var saveError: String?
    private var animation: Task<Void, Never>?

    var level: LevelDefinition { levels[progress.levelID - 1] }
    var engine: PuzzleEngine { try! PuzzleEngine(level: level) }
    var outcome: GameOutcome { engine.outcome(state: progress.state) }
    var busy: Bool { pour != nil }
    var finalLevel: Bool { level.id == levels.count }
    var presentationState: GameState { pour?.before ?? progress.state }

    init() throws {
        levels = try LevelCatalog.load()
        let environment = ProcessInfo.processInfo.environment
        let testing = environment["COLOR_FLOW_UI_TEST"] == "1"
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let filename = testing ? "UI-Tests/\(environment["COLOR_FLOW_TEST_SESSION"] ?? "default").json" : "progress.json"
        store = ProgressStore(url: directory.appendingPathComponent("ColorFlow/\(filename)"))
        if testing && environment["COLOR_FLOW_RESET"] == "1" {
            try? FileManager.default.removeItem(at: store.url)
        }
        progress = store.load(levels: levels)
    }

    func select(slot: Int) {
        guard !busy, outcome == .playing, progress.state.buckets[slot] != nil else { return }
        progress.state.selectedSlot = slot
        save()
    }

    func take(queue: Int) {
        guard !busy, let next = try? engine.applying(.take(queue: queue), to: progress.state) else { return }
        progress.state = next
        save()
    }

    func preview(column: Int) -> [Cell] {
        guard !busy, outcome == .playing, let slot = progress.state.selectedSlot else { return [] }
        return engine.pourTargets(slot: slot, column: column, state: progress.state)
    }

    func isPainted(_ cell: Cell) -> Bool {
        engine.isPainted(cell, state: presentationState) || filledDuringPour.contains(cell)
    }

    func pour(column: Int, reducedMotion: Bool) {
        guard !busy, let slot = progress.state.selectedSlot,
              let bucket = progress.state.buckets[slot] else { return }
        let cells = preview(column: column)
        guard !cells.isEmpty,
              let next = try? engine.applying(.pour(slot: slot, column: column), to: progress.state) else { return }
        let presentation = PourPresentation(column: column, color: bucket.color, initialUnits: bucket.paintUnits,
                                            cells: cells, before: progress.state)
        progress.state = next
        save()
        pour = presentation
        let fastTests = ProcessInfo.processInfo.environment["COLOR_FLOW_FAST_ANIMATION"] == "1"
        animation = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(for: .milliseconds(reducedMotion || fastTests ? 15 : 220))
                tilted = true
                try await Task.sleep(for: .milliseconds(reducedMotion || fastTests ? 15 : 280))
                for cell in cells {
                    streamEndRow = cell.row
                    try await Task.sleep(for: .milliseconds(reducedMotion || fastTests ? 15 : 260))
                    filledDuringPour.insert(cell)
                    try await Task.sleep(for: .milliseconds(reducedMotion || fastTests ? 15 : 210))
                }
                try await Task.sleep(for: .milliseconds(reducedMotion || fastTests ? 15 : 320))
                finishAnimation()
            } catch { /* Backgrounding commits the saved move without replaying its animation. */ }
        }
    }

    func finishAnimation() {
        animation?.cancel()
        animation = nil
        pour = nil
        filledDuringPour = []
        streamEndRow = nil
        tilted = false
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

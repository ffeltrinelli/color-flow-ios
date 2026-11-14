import ColorFlowCore
import Foundation
import Observation
import SwiftUI

struct PourPresentation {
    let slot: Int
    let color: PaintColor
    let initialUnits: Int
    let events: [PourEvent]
    let before: GameState
}

enum HintPresentation: Equatable {
    case idle
    case searching
    case finished(HintResult)
}

@MainActor @Observable
final class GameModel {
    let levels: [LevelDefinition]
    let store: ProgressStore
    var progress: GameProgress
    var pour: PourPresentation?
    var consumedDuringPour = 0
    var pourDestination: Cell?
    var fillingBoxID: Int?
    var animatedFillUnits: Double = 0
    private var displayedState: GameState?
    var saveError: String?
    private let engines: [PuzzleEngine]
    private let solutions: [[Move]]
    private var animation: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?
    var hintPresentation: HintPresentation = .idle
    private var playTimer = ActivePlayTimer()

    func setGameplayActive(_ active: Bool) {
        let seconds = playTimer.setRunning(active && (outcome == .playing || busy), at: ProcessInfo.processInfo.systemUptime)
        progress.addPlayTime(seconds)
        if !active { save() }
    }

    private func checkpointPlayTime() {
        progress.addPlayTime(playTimer.checkpoint(at: ProcessInfo.processInfo.systemUptime))
    }

    private func recordOutcome() {
        switch outcome {
        case .playing: break
        case .won: progress.resolveAttempt(.victory, difficulty: level.difficulty)
        case .lost: progress.resolveAttempt(.failure, difficulty: level.difficulty)
        }
    }

    func requestHint() {
        cancelHint()
        guard !busy, outcome == .playing else { return }
        let state = progress.state
        let levelID = progress.levelID
        let engine = engine
        let knownSolution = solutions.indices.contains(levelID - 1) ? solutions[levelID - 1] : nil
        let environment = ProcessInfo.processInfo.environment
        let slowHintTest = environment["COLOR_FLOW_UI_TEST"] == "1" && environment["COLOR_FLOW_SLOW_HINT"] == "1"
        // The regression holds the empty startup state before the worker begins.
        hintPresentation = slowHintTest ? .idle : .searching
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        hintTask = Task { [weak self] in
            if slowHintTest {
                do { try await Task.sleep(for: .seconds(4)) }
                catch { return }
                self?.hintPresentation = .searching
            }
            let worker = Task.detached(priority: .userInitiated) {
                return LevelHints.suggest(engine: engine, state: state, limit: .max, knownSolution: knownSolution,
                                          deadline: deadline, isCancelled: { Task.isCancelled })
            }
            let result = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled, let self,
                  self.progress.levelID == levelID, self.progress.state == state else { return }
            self.hintPresentation = .finished(result)
        }
    }

    func cancelHint() {
        hintTask?.cancel()
        hintTask = nil
        hintPresentation = .idle
    }

    var level: LevelDefinition { levels[progress.levelID - 1] }
    var engine: PuzzleEngine { engines[progress.levelID - 1] }
    var outcome: GameOutcome { engine.outcome(state: progress.state) }
    var busy: Bool { pour != nil }
    var finalLevel: Bool { level.id == levels.count }
    var presentationState: GameState { displayedState ?? progress.state }

    init() throws {
        levels = try LevelCatalog.load()
        solutions = (try? LevelCatalog.solutions()) ?? []
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
        cancelHint()
        checkpointPlayTime()
        progress.state = next
        recordOutcome()
        if outcome != .playing { setGameplayActive(false) }
        save()
    }

    func fillUnits(for box: BoxDefinition) -> Double {
        fillingBoxID == box.id ? animatedFillUnits : Double(engine.boxState(id: box.id, state: presentationState).filledUnits)
    }

    func boxSummary(_ box: BoxDefinition) -> String {
        let current = engine.boxState(id: box.id, state: presentationState)
        return "\(box.color.name), row \(current.row + 1), column \(box.column + 1), \(box.width) by \(box.height), \(current.filledUnits) of \(box.capacity) paint units"
    }

    func displayedBucket(slot: Int) -> PaintTin? {
        guard var bucket = (pour?.before ?? progress.state).buckets[slot] else { return nil }
        if pour?.slot == slot { bucket.paintUnits -= consumedDuringPour }
        return bucket.paintUnits > 0 ? bucket : nil
    }

    func pour(slot: Int, reducedMotion: Bool) {
        guard !busy, let result = try? engine.pourResult(slot: slot, state: progress.state),
              let bucket = progress.state.buckets[slot] else { return }
        let presentation = PourPresentation(slot: slot, color: bucket.color, initialUnits: bucket.paintUnits,
                                            events: result.events, before: progress.state)
        cancelHint()
        checkpointPlayTime()
        displayedState = progress.state
        progress.state = result.state
        recordOutcome()
        save()
        pour = presentation
        animation = Task { [weak self] in
            await self?.animate(presentation, reducedMotion: reducedMotion)
        }
    }

    private func animate(_ presentation: PourPresentation, reducedMotion: Bool) async {
        let brief = reducedMotion || ProcessInfo.processInfo.environment["COLOR_FLOW_FAST_ANIMATION"] == "1"
        do {
            try await Task.sleep(for: .seconds(brief ? 0.008 : 0.2))
            for event in presentation.events {
                try Task.checkCancellation()
                switch event {
                case .fill(let step):
                    try await animateFill(step, brief: brief)
                    displayedState = engine.presenting(event, in: presentationState)
                    fillingBoxID = nil
                case .remove:
                    try await Task.sleep(for: .seconds(brief ? 0.008 : 0.1))
                case .fall:
                    fillingBoxID = nil
                    withAnimation(.linear(duration: brief ? 0 : 0.1)) {
                        displayedState = engine.presenting(event, in: presentationState)
                    }
                    try await Task.sleep(for: .seconds(brief ? 0.008 : 0.1))
                }
            }
            finishAnimation()
        } catch {
            // The complete move is already saved; backgrounding ends presentation.
        }
    }

    private func animateFill(_ step: FillStep, brief: Bool) async throws {
        let previousColumn = pourDestination?.column
        pourDestination = step.entry
        if previousColumn != nil, previousColumn != step.entry.column {
            try await Task.sleep(for: .seconds(brief ? 0.008 : 0.25))
        }
        animatedFillUnits = Double(step.fromUnits)
        fillingBoxID = step.boxID
        for units in (step.fromUnits + 1)...step.toUnits {
            withAnimation(.linear(duration: brief ? 0 : 0.25)) {
                animatedFillUnits = Double(units)
            }
            try await Task.sleep(for: .seconds(brief ? 0.008 : 0.25))
            consumedDuringPour += 1
        }
    }

    func finishAnimation() {
        checkpointPlayTime()
        if outcome != .playing {
            _ = playTimer.setRunning(false, at: ProcessInfo.processInfo.systemUptime)
            progress.finalizeWinningTime(difficulty: level.difficulty)
        }
        animation?.cancel()
        animation = nil
        pour = nil
        displayedState = nil
        consumedDuringPour = 0
        pourDestination = nil
        fillingBoxID = nil
        animatedFillUnits = 0
        save()
    }

    func restart() {
        guard !busy else { return }
        cancelHint()
        checkpointPlayTime()
        progress.resolveAttempt(.restart, difficulty: level.difficulty)
        progress.startAttempt(level: level)
        save()
    }

    func advance() {
        guard !busy, outcome == .won else { return }
        cancelHint()
        progress.startAttempt(level: levels[finalLevel ? 0 : progress.levelID])
        save()
    }

    func clearStatistics() {
        progress.clearStatistics()
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

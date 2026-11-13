import Foundation
import Testing
@testable import ColorFlowCore

struct PuzzleTests {
    private func catalog() throws -> [LevelDefinition] { try LevelCatalog.load() }

    @Test func catalogHasFiveOrderedLevels() throws {
        let levels = try catalog()
        #expect(levels.map(\.id) == [1, 2, 3, 4, 5])
        #expect(levels.map(\.difficulty) == [.easy, .easy, .easy, .medium, .hard])
    }

    @Test func everyStoredSolutionWinsAndConservesPaint() throws {
        let levels = try catalog()
        let solutions = try LevelCatalog.solutions()
        #expect(solutions.count == levels.count)
        for (level, solution) in zip(levels, solutions) {
            let engine = try PuzzleEngine(level: level)
            var state = GameState(level: level)
            for move in solution {
                state = try engine.applying(move, to: state)
                #expect(engine.validate(state: state))
            }
            #expect(engine.outcome(state: state) == .won)
            #expect(throws: MoveError.self) { try engine.applying(.take(queue: 0), to: state) }
        }
    }

    @Test func retrievalAdvancesOnlyItsQueueAndSelectsBucket() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 1), to: GameState(level: level))
        #expect(state.queuePositions == [0, 1, 0, 0])
        #expect(state.selectedSlot == 0)
        #expect(state.buckets[0] == PaintTin(color: .yellow, paintUnits: 3))
    }

    @Test func previewsAndPoursStopAtColorBoundary() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        var state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        state = try engine.applying(.take(queue: 1), to: state)
        #expect(engine.pourTargets(slot: 0, column: 0, state: state).map(\.row) == [5, 4, 3])
        state = try engine.applying(.pour(slot: 0, column: 0), to: state)
        #expect(state.paintedCounts == [3, 0, 0, 0, 0, 0])
        #expect(state.buckets[0]?.paintUnits == 3)
        #expect(engine.pourTargets(slot: 0, column: 0, state: state).isEmpty)
        #expect(engine.isPainted(Cell(row: 3, column: 0), state: state))
        #expect(!engine.isPainted(Cell(row: 2, column: 0), state: state))
    }

    @Test func partialPourExhaustsAndReleasesSlot() throws {
        let level = LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 1, grid: ["B", "B", "B"],
                                    paintQueues: [[PaintTin(color: .blue, paintUnits: 1), PaintTin(color: .blue, paintUnits: 2)], [], [], []])
        let engine = try PuzzleEngine(level: level)
        var state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        #expect(engine.pourTargets(slot: 0, column: 0, state: state) == [Cell(row: 2, column: 0)])
        state = try engine.applying(.pour(slot: 0, column: 0), to: state)
        #expect(state.buckets == [nil])
        #expect(state.selectedSlot == nil)
        #expect(state.paintedCounts == [1])
    }

    @Test func fullSlotsAllowRechargeButRejectNewColor() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        for queue in [0, 2, 3] { state = try engine.applying(.take(queue: queue), to: state) }
        #expect(engine.canTake(queue: 1, state: state))
        #expect(!engine.canTake(queue: 0, state: state))
        #expect(throws: MoveError.self) { try engine.applying(.take(queue: 0), to: state) }
        state = try engine.applying(.take(queue: 1), to: state)
        #expect(state.buckets.compactMap { $0 }.count == 3)
        #expect(state.buckets[0]?.paintUnits == 6)
    }

    @Test func illegalColumnAndQueueAreRejected() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        let initial = GameState(level: level)
        #expect(throws: MoveError.self) { try engine.applying(.take(queue: 8), to: initial) }
        #expect(throws: MoveError.self) { try engine.applying(.pour(slot: 0, column: 0), to: initial) }
        let state = try engine.applying(.take(queue: 0), to: initial)
        #expect(throws: MoveError.self) { try engine.applying(.pour(slot: 0, column: 2), to: state) }
        #expect(throws: MoveError.self) { try engine.applying(.pour(slot: 0, column: -1), to: state) }
    }

    @Test func fullUnusableSlotsLoseEvenIfRechargeExists() throws {
        let level = LevelDefinition(id: 1, difficulty: .hard, bucketSlots: 1, grid: ["R", "R", "B"],
                                    paintQueues: [[PaintTin(color: .red, paintUnits: 1), PaintTin(color: .red, paintUnits: 1)],
                                                  [PaintTin(color: .blue, paintUnits: 1)], [], []])
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        #expect(engine.canTake(queue: 0, state: state))
        #expect(engine.outcome(state: state) == .lost)
    }

    @Test func otherwiseStuckStateLoses() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.queuePositions = level.paintQueues.map(\.count)
        #expect(engine.outcome(state: state) == .lost)
        #expect(!engine.validate(state: state))
    }

    @Test func invalidLevelDefinitionsAreRejected() throws {
        let definitions: [(LevelDefinition, LevelError)] = [
            (.init(id: 1, difficulty: .easy, bucketSlots: 3, grid: ["B", "BB"], paintQueues: [[], [], [], []]), .invalidGrid),
            (.init(id: 1, difficulty: .easy, bucketSlots: 3, grid: ["X"], paintQueues: [[], [], [], []]), .invalidGrid),
            (.init(id: 1, difficulty: .easy, bucketSlots: 0, grid: ["B"], paintQueues: [[], [], [], []]), .invalidSlots),
            (.init(id: 1, difficulty: .easy, bucketSlots: 1, grid: ["B"], paintQueues: [[], []]), .invalidQueues),
            (.init(id: 1, difficulty: .easy, bucketSlots: 1, grid: ["B"], paintQueues: [[.init(color: .blue, paintUnits: 0)], [], [], []]), .invalidQuantity),
            (.init(id: 1, difficulty: .easy, bucketSlots: 1, grid: ["B"], paintQueues: [[.init(color: .red, paintUnits: 1)], [], [], []]), .paintMismatch)
        ]
        for (level, error) in definitions {
            #expect(throws: error) { try LevelValidator.validate(level) }
        }
    }

    @Test func solverDistinguishesLimitFromUnsolvable() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        guard case .inconclusive = LevelSolver.solve(engine: engine, limit: 0) else {
            Issue.record("Expected an inconclusive search"); return
        }
        let impossible = LevelDefinition(id: 1, difficulty: .hard, bucketSlots: 1, grid: ["R", "B"],
                                        paintQueues: [[.init(color: .red, paintUnits: 1), .init(color: .blue, paintUnits: 1)], [], [], []])
        guard case .unsolvable = LevelSolver.solve(engine: try PuzzleEngine(level: impossible)) else {
            Issue.record("Expected an unsolvable level"); return
        }
    }

    @Test func hardLevelHasStoredLosingAlternative() throws {
        let level = try catalog()[4]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        for move in try LevelCatalog.hardLosingBranch() {
            #expect(engine.outcome(state: state) == .playing)
            state = try engine.applying(move, to: state)
            #expect(engine.validate(state: state))
        }
        #expect(engine.outcome(state: state) == .lost)
    }

    @Test func savedMoveRestoresExactly() throws {
        let levels = try catalog()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("progress.json"))
        let engine = try PuzzleEngine(level: levels[0])
        var progress = GameProgress(level: levels[0])
        progress.state = try engine.applying(.take(queue: 0), to: progress.state)
        progress.state = try engine.applying(.pour(slot: 0, column: 0), to: progress.state)
        try store.save(progress)
        #expect(store.load(levels: levels) == progress)
    }

    @Test func invalidSnapshotRestartsRecordedLevel() throws {
        let levels = try catalog()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("progress.json"))
        var progress = GameProgress(level: levels[3])
        progress.state.paintedCounts = [99]
        try store.save(progress)
        #expect(store.load(levels: levels) == GameProgress(level: levels[3]))
        try Data("broken".utf8).write(to: store.url)
        #expect(store.load(levels: levels) == GameProgress(level: levels[0]))
    }

    @Test func duplicateBucketsAndInvalidSelectionAreRejected() throws {
        let level = try catalog()[0]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.selectedSlot = 99
        #expect(!engine.validate(state: state))
        state.selectedSlot = nil
        state.buckets = [.init(color: .blue, paintUnits: 1), .init(color: .blue, paintUnits: 1), nil]
        #expect(!engine.validate(state: state))
    }
}

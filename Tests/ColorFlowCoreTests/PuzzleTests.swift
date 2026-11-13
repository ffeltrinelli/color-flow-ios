import Foundation
import Testing
@testable import ColorFlowCore

struct PuzzleTests {
    private func layeredLevel(slots: Int = 3) -> LevelDefinition {
        LevelDefinition(id: 1, difficulty: .easy, bucketSlots: slots, grid: ["RBR", "RGB", "BRG"],
                        paintQueues: [[.init(color: .red, paintUnits: 4)], [.init(color: .blue, paintUnits: 3)],
                                      [.init(color: .green, paintUnits: 2)], []])
    }

    private func replay(_ moves: [Move], level: LevelDefinition) throws -> GameState {
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        for move in moves {
            #expect(engine.outcome(state: state) == .playing)
            state = try engine.applying(move, to: state)
            #expect(engine.validate(state: state))
        }
        return state
    }

    @Test func catalogHasThreeLargerLevels() throws {
        let levels = try LevelCatalog.load()
        #expect(levels.map(\.id) == [1, 2, 3])
        #expect(levels.map(\.difficulty) == [.easy, .medium, .hard])
        #expect(levels.map(\.bucketSlots) == [3, 2, 2])
        #expect(levels.allSatisfy { $0.width == 10 && $0.height == 10 })
    }

    @Test func everyStoredSolutionWinsAndConservesPaint() throws {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        #expect(solutions.count == levels.count)
        for (level, moves) in zip(levels, solutions) {
            let engine = try PuzzleEngine(level: level)
            let state = try replay(moves, level: level)
            #expect(engine.outcome(state: state) == .won)
            #expect(state.clearedCounts.allSatisfy { $0 == 10 })
            #expect(state.buckets.allSatisfy { $0 == nil })
            #expect(state.queuePositions == level.paintQueues.map(\.count))
            #expect(throws: MoveError.self) { try engine.applying(.take(queue: 0), to: state) }
            #expect(throws: MoveError.self) { try engine.pourResult(slot: 0, state: state) }
        }
    }

    @Test func mediumAndHardHaveVerifiedLosingAlternatives() throws {
        let levels = try LevelCatalog.load()
        let branches = try LevelCatalog.losingBranches()
        #expect(Set(branches.keys) == [2, 3])
        for level in levels.dropFirst() {
            let moves = try #require(branches[level.id])
            #expect(moves.count > 10)
            let state = try replay(moves, level: level)
            #expect(try PuzzleEngine(level: level).outcome(state: state) == .lost)
        }
    }

    @Test func retrievalOnlyLoadsAndAdvancesItsQueue() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 1), to: GameState(level: level))
        #expect(state.queuePositions == [0, 1, 0, 0])
        #expect(state.clearedCounts == [0, 0, 0])
        #expect(state.buckets == [.init(color: .blue, paintUnits: 3), nil, nil])
    }

    @Test func automaticPourUsesTopBlocksAndLeftmostColumnAfterEveryRemoval() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        let before = try engine.applying(.take(queue: 0), to: GameState(level: level))
        let result = try engine.pourResult(slot: 0, state: before)
        #expect(result.cells == [Cell(row: 0, column: 0), Cell(row: 1, column: 0), Cell(row: 0, column: 2)])
        #expect(result.state == (try engine.applying(.pour(slot: 0), to: before)))
        #expect(result.state.clearedCounts == [2, 0, 1])
        #expect(result.state.buckets[0] == .init(color: .red, paintUnits: 1))
        #expect(!engine.canPour(slot: 0, state: result.state))
        #expect(engine.isCleared(Cell(row: 0, column: 0), state: result.state))
        #expect(!engine.isCleared(Cell(row: 2, column: 0), state: result.state))
        #expect(engine.remainingColors(column: 1, state: result.state) == [.blue, .green, .red])
        #expect(throws: MoveError.self) { try engine.pourResult(slot: 0, state: result.state) }
    }

    @Test func emptyColumnsAreSkippedAndBlockedBucketsRequireAnotherPour() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        var state = try replay([.take(queue: 0), .pour(slot: 0), .take(queue: 1), .pour(slot: 1)], level: level)
        #expect(state.clearedCounts == [3, 1, 2])
        #expect(state.buckets[1] == nil)
        state = try engine.applying(.take(queue: 2), to: state)
        let green = try engine.pourResult(slot: 1, state: state)
        #expect(green.cells == [Cell(row: 1, column: 1), Cell(row: 2, column: 2)])
        state = green.state
        #expect(state.clearedCounts == [3, 2, 3])
        #expect(engine.canPour(slot: 0, state: state))
        #expect(state.buckets[0]?.paintUnits == 1)
        #expect(engine.outcome(state: state) == .playing)
        state = try engine.applying(.pour(slot: 0), to: state)
        #expect(engine.outcome(state: state) == .won)
        #expect(engine.validate(state: state))
    }

    @Test func limitedPaintStopsWithinMatchingRunAndReleasesSlot() throws {
        let level = LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 1, grid: ["B", "B", "B"],
                                    paintQueues: [[.init(color: .blue, paintUnits: 1), .init(color: .blue, paintUnits: 2)], [], [], []])
        let state = try replay([.take(queue: 0), .pour(slot: 0)], level: level)
        #expect(state.clearedCounts == [1])
        #expect(state.buckets == [nil])
        #expect(try PuzzleEngine(level: level).remainingColors(column: 0, state: state) == [.blue, .blue])
    }

    @Test func fullSlotsAllowRechargeButRejectNewColor() throws {
        let level = LevelDefinition(id: 1, difficulty: .medium, bucketSlots: 2, grid: ["RBG", "RBG"],
                                    paintQueues: [[.init(color: .red, paintUnits: 1), .init(color: .green, paintUnits: 2)],
                                                  [.init(color: .blue, paintUnits: 2)], [.init(color: .red, paintUnits: 1)], []])
        let engine = try PuzzleEngine(level: level)
        var state = try replay([.take(queue: 0), .take(queue: 1)], level: level)
        #expect(engine.canTake(queue: 2, state: state))
        #expect(!engine.canTake(queue: 0, state: state))
        #expect(throws: MoveError.self) { try engine.applying(.take(queue: 0), to: state) }
        state = try engine.applying(.take(queue: 2), to: state)
        #expect(state.buckets == [.init(color: .red, paintUnits: 2), .init(color: .blue, paintUnits: 2)])
        #expect(engine.validate(state: state))
    }

    @Test func invalidMovesAndEmptySlotsAreRejected() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        let state = GameState(level: level)
        for queue in [-1, 4] {
            #expect(throws: MoveError.self) { try engine.applying(.take(queue: queue), to: state) }
        }
        for slot in [-1, 0, 3] {
            #expect(!engine.canPour(slot: slot, state: state))
            #expect(throws: MoveError.self) { try engine.applying(.pour(slot: slot), to: state) }
        }
    }

    @Test func fullBlockedSlotsLoseEvenWhenRechargeExists() throws {
        let level = LevelDefinition(id: 1, difficulty: .hard, bucketSlots: 1, grid: ["B", "R", "R"],
                                    paintQueues: [[.init(color: .red, paintUnits: 1), .init(color: .red, paintUnits: 1)],
                                                  [.init(color: .blue, paintUnits: 1)], [], []])
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        #expect(engine.canTake(queue: 0, state: state))
        #expect(engine.outcome(state: state) == .lost)
        #expect(engine.validate(state: state))
    }

    @Test func noLegalActionsLosesAndEmptyGridWins() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.queuePositions = level.paintQueues.map(\.count)
        #expect(engine.outcome(state: state) == .lost)
        state.clearedCounts = [3, 3, 3]
        #expect(engine.outcome(state: state) == .won)
        #expect(engine.validate(state: state))
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

    @Test func invalidSnapshotsAreRejected() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.clearedCounts = [4, 0, 0]
        #expect(!engine.validate(state: state))
        state = GameState(level: level)
        state.queuePositions = [0]
        #expect(!engine.validate(state: state))
        state = GameState(level: level)
        state.buckets = [.init(color: .red, paintUnits: 1), .init(color: .red, paintUnits: 1), nil]
        #expect(!engine.validate(state: state))
        state = GameState(level: level)
        state.buckets[0] = .init(color: .red, paintUnits: 0)
        #expect(!engine.validate(state: state))
        state = GameState(level: level)
        state.clearedCounts[0] = 1
        #expect(!engine.validate(state: state))
    }

    @Test func solverDistinguishesLimitFromUnsolvable() throws {
        let engine = try PuzzleEngine(level: layeredLevel())
        guard case .inconclusive = LevelSolver.solve(engine: engine, limit: 0) else {
            Issue.record("Expected an inconclusive search"); return
        }
        let impossible = LevelDefinition(id: 1, difficulty: .hard, bucketSlots: 1, grid: ["B", "R"],
                                        paintQueues: [[.init(color: .red, paintUnits: 1), .init(color: .blue, paintUnits: 1)], [], [], []])
        guard case .unsolvable = LevelSolver.solve(engine: try PuzzleEngine(level: impossible)) else {
            Issue.record("Expected an unsolvable level"); return
        }
    }

    private func withStore(_ test: (ProgressStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(ProgressStore(url: directory.appendingPathComponent("progress.json")))
    }

    @Test func completedAutomaticPourRestoresExactly() throws {
        let levels = try LevelCatalog.load()
        try withStore { store in
            var progress = GameProgress(level: levels[0])
            progress.state = try replay(Array(try LevelCatalog.solutions()[0].prefix(8)), level: levels[0])
            try store.save(progress)
            #expect(store.load(levels: levels) == progress)
        }
    }

    @Test func oldAndUnknownVersionsStartAtNewLevelOne() throws {
        let levels = try LevelCatalog.load()
        try withStore { store in
            for version in [1, 99] {
                var progress = GameProgress(level: levels[2])
                progress.version = version
                try store.save(progress)
                #expect(store.load(levels: levels) == GameProgress(level: levels[0]))
            }
            let oldSave = #"{"version":1,"levelID":3,"state":{"paintedCounts":[0,0,0,0,0,0],"queuePositions":[0,0,0,0],"buckets":[null,null,null],"selectedSlot":null}}"#
            try Data(oldSave.utf8).write(to: store.url)
            #expect(store.load(levels: levels) == GameProgress(level: levels[0]))
        }
    }

    @Test func completedAndLostResultsRestoreExactly() throws {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        let losingBranches = try LevelCatalog.losingBranches()
        try withStore { store in
            for level in levels {
                var progress = GameProgress(level: level)
                progress.state = try replay(solutions[level.id - 1], level: level)
                try store.save(progress)
                #expect(store.load(levels: levels) == progress)
                if let moves = losingBranches[level.id] {
                    progress.state = try replay(moves, level: level)
                    try store.save(progress)
                    #expect(store.load(levels: levels) == progress)
                }
            }
        }
    }

    @Test func invalidNewSnapshotRestartsRecordedLevelAndUnreadableSaveStartsAtOne() throws {
        let levels = try LevelCatalog.load()
        try withStore { store in
            var progress = GameProgress(level: levels[1])
            progress.state.clearedCounts = [99]
            try store.save(progress)
            #expect(store.load(levels: levels) == GameProgress(level: levels[1]))
            try Data("broken".utf8).write(to: store.url)
            #expect(store.load(levels: levels) == GameProgress(level: levels[0]))
        }
    }
}

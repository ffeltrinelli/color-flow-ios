import Foundation
import Testing
@testable import ColorFlowCore

struct PuzzleTests {
    private func level(rows: [String], slots: Int = 3, queues: [[PaintTin]]) -> LevelDefinition {
        let boxes = rows.enumerated().flatMap { row, colors in
            colors.enumerated().map { column, color in
                BoxDefinition(id: row * colors.count + column + 1, row: row, column: column,
                              color: PaintColor(rawValue: String(color))!)
            }
        }
        return LevelDefinition(id: 1, difficulty: .easy, bucketSlots: slots, width: rows[0].count,
                               height: rows.count, boxes: boxes, paintQueues: queues)
    }

    private func layeredLevel(slots: Int = 3) -> LevelDefinition {
        level(rows: ["RBR", "RGB", "BRG"], slots: slots,
              queues: [[.init(color: .red, paintUnits: 4)], [.init(color: .blue, paintUnits: 3)],
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

    private func fills(_ result: PourResult) -> [FillStep] {
        result.events.compactMap { if case .fill(let step) = $0 { step } else { nil } }
    }

    @Test func catalogHasAuthoredShapeProgressionAndAreaCoverage() throws {
        let levels = try LevelCatalog.load()
        #expect(levels.map(\.id) == [1, 2, 3])
        #expect(levels.map(\.difficulty) == [.easy, .medium, .hard])
        #expect(levels.map(\.bucketSlots) == [3, 2, 2])
        for (index, level) in levels.enumerated() {
            #expect(level.width == 10 && level.height == 10)
            #expect(level.boxes.reduce(0) { $0 + $1.capacity } == 100)
            #expect(level.boxes.filter { $0.capacity > 1 }.reduce(0) { $0 + $1.capacity } == (index + 1) * 20)
            let sizes = Set(level.boxes.map { "\($0.width)x\($0.height)" })
            let expected: Set<String> = switch index {
            case 0: ["1x1", "1x2", "2x1"]
            case 1: ["1x1", "1x2", "2x1", "1x3", "3x1", "2x2"]
            default: ["1x1", "1x2", "2x1", "1x3", "3x1", "2x2", "2x3", "3x2", "3x3"]
            }
            #expect(sizes == expected)
        }
    }

    @Test func everyStoredSolutionWinsAndConservesPaint() throws {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        #expect(solutions.count == levels.count)
        for (level, moves) in zip(levels, solutions) {
            let engine = try PuzzleEngine(level: level)
            let state = try replay(moves, level: level)
            #expect(engine.outcome(state: state) == .won)
            #expect(engine.remainingBoxes(state: state).isEmpty)
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

    @Test(arguments: [1, 2, 3], [1, 2, 3])
    func allRectangleSizesRetainPartialFillsAndRemoveAtCapacity(width: Int, height: Int) throws {
        let capacity = width * height
        let tins = [PaintTin(color: .red, paintUnits: 1)] + (capacity > 1 ? [.init(color: .red, paintUnits: capacity - 1)] : [])
        let box = BoxDefinition(id: 7, row: 0, column: 0, width: width, height: height, color: .red)
        let level = LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 1, width: width, height: height,
                                    boxes: [box], paintQueues: [tins, [], [], []])
        let engine = try PuzzleEngine(level: level)
        var state = try replay([.take(queue: 0), .pour(slot: 0)], level: level)
        #expect(engine.boxState(id: 7, state: state).filledUnits == 1)
        #expect(state.buckets == [nil])
        #expect(engine.isRemoved(box, state: state) == (capacity == 1))
        if capacity > 1 {
            state = try engine.applying(.take(queue: 0), to: state)
            let result = try engine.pourResult(slot: 0, state: state)
            #expect(fills(result).first?.fromUnits == 1)
            #expect(fills(result).first?.toUnits == capacity)
            #expect(result.events.contains(.remove(boxID: 7)))
            #expect(engine.outcome(state: result.state) == .won)
            #expect(engine.validate(state: result.state))
        }
    }

    @Test func retrievalOnlyLoadsAndAdvancesItsQueue() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 1), to: GameState(level: level))
        #expect(state.queuePositions == [0, 1, 0, 0])
        #expect(state.boxes.allSatisfy { $0.filledUnits == 0 })
        #expect(state.buckets == [.init(color: .blue, paintUnits: 3), nil, nil])
    }

    @Test func automaticPourUsesExposedBoxesAndRestartsFromLeftAfterRemoval() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        let before = try engine.applying(.take(queue: 0), to: GameState(level: level))
        let result = try engine.pourResult(slot: 0, state: before)
        #expect(fills(result).map(\.boxID) == [1, 4, 3])
        #expect(fills(result).map(\.entry.column) == [0, 0, 2])
        #expect(result.state == (try engine.applying(.pour(slot: 0), to: before)))
        #expect(result.state.buckets[0] == .init(color: .red, paintUnits: 1))
        #expect(!engine.canPour(slot: 0, state: result.state))
        #expect(throws: MoveError.self) { try engine.pourResult(slot: 0, state: result.state) }
    }

    @Test func wideBoxAcceptsPaintThroughItsUncoveredTopEdge() throws {
        let boxes = [
            BoxDefinition(id: 1, row: 0, column: 0, color: .blue),
            BoxDefinition(id: 2, row: 0, column: 1, color: .green),
            BoxDefinition(id: 3, row: 1, column: 0, width: 2, height: 2, color: .red)
        ]
        let level = LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 2, width: 2, height: 3, boxes: boxes,
                                    paintQueues: [[.init(color: .green, paintUnits: 1)], [.init(color: .red, paintUnits: 4)],
                                                  [.init(color: .blue, paintUnits: 1)], []])
        let engine = try PuzzleEngine(level: level)
        var state = try replay([.take(queue: 0), .pour(slot: 0), .take(queue: 1)], level: level)
        let result = try engine.pourResult(slot: 0, state: state)
        #expect(fills(result) == [FillStep(boxID: 3, entry: Cell(row: 1, column: 1), fromUnits: 0, toUnits: 4)])
        state = result.state
        #expect(engine.boxState(id: 1, state: state).row == 2)
        #expect(engine.validate(state: state))
    }

    private func bridgeLevel() -> LevelDefinition {
        let boxes = [
            BoxDefinition(id: 1, row: 0, column: 0, width: 2, color: .red),
            BoxDefinition(id: 2, row: 0, column: 2, color: .green),
            BoxDefinition(id: 3, row: 1, column: 0, color: .green),
            BoxDefinition(id: 4, row: 1, column: 1, width: 2, color: .blue),
            BoxDefinition(id: 5, row: 2, column: 0, width: 3, color: .yellow)
        ]
        return LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 3, width: 3, height: 3, boxes: boxes,
                               paintQueues: [[.init(color: .red, paintUnits: 1), .init(color: .red, paintUnits: 1)],
                                             [.init(color: .green, paintUnits: 1), .init(color: .green, paintUnits: 1)],
                                             [.init(color: .blue, paintUnits: 2)], [.init(color: .yellow, paintUnits: 3)]])
    }

    @Test func partialSupportBridgesGapThenCascadeRetainsLiquid() throws {
        let level = bridgeLevel()
        let engine = try PuzzleEngine(level: level)
        var state = try replay([.take(queue: 0), .pour(slot: 0), .take(queue: 1), .pour(slot: 0),
                                .take(queue: 2), .pour(slot: 0)], level: level)
        #expect(engine.boxState(id: 1, state: state) == BoxState(row: 0, filledUnits: 1))
        #expect(engine.boxState(id: 3, state: state).row == 1)
        state = try engine.applying(.take(queue: 3), to: state)
        let result = try engine.pourResult(slot: 0, state: state)
        let falls = result.events.compactMap { if case .fall(let step) = $0 { step } else { nil } }
        #expect(falls == [[BoxFall(boxID: 3, fromRow: 1, toRow: 2)], [BoxFall(boxID: 1, fromRow: 0, toRow: 1)]])
        #expect(engine.boxState(id: 1, state: result.state) == BoxState(row: 1, filledUnits: 1))
        #expect(engine.boxState(id: 3, state: result.state).row == 2)
        #expect(engine.validate(state: result.state))
    }

    @Test func singleCellRemovalLeavesSupportedBoxesInPlace() throws {
        let level = self.level(rows: ["RB", "BB"], slots: 2,
                               queues: [[.init(color: .red, paintUnits: 1)], [.init(color: .blue, paintUnits: 3)], [], []])
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 1), to: GameState(level: level))
        let result = try engine.pourResult(slot: 0, state: state)
        #expect(engine.boxState(id: 1, state: result.state).row == 0)
        #expect(result.events.allSatisfy { if case .fall = $0 { false } else { true } })
        #expect(engine.validate(state: result.state))
    }

    @Test func catalogPoursReplayFallsBeforeRetargeting() throws {
        var continuedAfterFall = false
        let solutions = try LevelCatalog.solutions()
        for level in try LevelCatalog.load() {
            let engine = try PuzzleEngine(level: level)
            var state = GameState(level: level)
            for move in solutions[level.id - 1] {
                if case .pour(let slot) = move {
                    let result = try engine.pourResult(slot: slot, state: state)
                    var presented = state
                    var hasFallen = false
                    for event in result.events {
                        if case .fall = event { hasFallen = true }
                        if case .fill(let step) = event {
                            continuedAfterFall = continuedAfterFall || hasFallen
                            #expect(step.entry.row == engine.boxState(id: step.boxID, state: presented).row)
                        }
                        presented = engine.presenting(event, in: presented)
                    }
                    #expect(presented.boxes == result.state.boxes)
                    state = result.state
                } else {
                    state = try engine.applying(move, to: state)
                }
            }
        }
        #expect(continuedAfterFall)
    }

    @Test func unsupportedBoxesFallSimultaneouslyThenUpperBoxesFollow() throws {
        let boxes = [
            BoxDefinition(id: 1, row: 0, column: 0, color: .red),
            BoxDefinition(id: 2, row: 0, column: 1, color: .blue),
            BoxDefinition(id: 3, row: 0, column: 2, color: .green),
            BoxDefinition(id: 4, row: 1, column: 0, color: .purple),
            BoxDefinition(id: 5, row: 1, column: 1, color: .purple),
            BoxDefinition(id: 6, row: 1, column: 2, color: .green),
            BoxDefinition(id: 7, row: 2, column: 0, width: 3, color: .yellow)
        ]
        let level = LevelDefinition(id: 1, difficulty: .hard, bucketSlots: 2, width: 3, height: 3, boxes: boxes,
                                    paintQueues: [[.init(color: .green, paintUnits: 2), .init(color: .red, paintUnits: 1)],
                                                  [.init(color: .yellow, paintUnits: 3), .init(color: .blue, paintUnits: 1)],
                                                  [.init(color: .purple, paintUnits: 2)], []])
        let engine = try PuzzleEngine(level: level)
        let before = try replay([.take(queue: 0), .pour(slot: 0), .take(queue: 1)], level: level)
        let result = try engine.pourResult(slot: 0, state: before)
        let falls = result.events.compactMap { if case .fall(let step) = $0 { step } else { nil } }
        #expect(falls == [
            [BoxFall(boxID: 4, fromRow: 1, toRow: 2), BoxFall(boxID: 5, fromRow: 1, toRow: 2)],
            [BoxFall(boxID: 1, fromRow: 0, toRow: 1), BoxFall(boxID: 2, fromRow: 0, toRow: 1)]
        ])
        #expect(engine.validate(state: result.state))
    }

    @Test func blockedLeftoversNeedAnotherTapAfterTheirColorBecomesExposed() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        var state = try replay([.take(queue: 0), .pour(slot: 0), .take(queue: 1), .pour(slot: 1),
                                .take(queue: 2), .pour(slot: 1)], level: level)
        #expect(state.buckets[0] == .init(color: .red, paintUnits: 1))
        #expect(engine.canPour(slot: 0, state: state))
        #expect(engine.outcome(state: state) == .playing)
        state = try engine.applying(.pour(slot: 0), to: state)
        #expect(engine.outcome(state: state) == .won)
        #expect(engine.validate(state: state))
    }

    @Test func engineEventsReplayExactSettledGeometryBeforeNextFill() throws {
        let level = bridgeLevel()
        let engine = try PuzzleEngine(level: level)
        let before = try replay([.take(queue: 1), .pour(slot: 0), .take(queue: 2)], level: level)
        let result = try engine.pourResult(slot: 0, state: before)
        let presented = result.events.reduce(before) { engine.presenting($1, in: $0) }
        #expect(presented.boxes == result.state.boxes)
        #expect(fills(result).map(\.boxID) == [4])
    }

    @Test func fullSlotsAllowRechargeButRejectNewColor() throws {
        let level = self.level(rows: ["RBG", "RBG"], slots: 2,
                               queues: [[.init(color: .red, paintUnits: 1), .init(color: .green, paintUnits: 2)],
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
        let level = self.level(rows: ["B", "R", "R"], slots: 1,
                               queues: [[.init(color: .red, paintUnits: 1), .init(color: .red, paintUnits: 1)],
                                        [.init(color: .blue, paintUnits: 1)], [], []])
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        #expect(engine.canTake(queue: 0, state: state))
        #expect(engine.outcome(state: state) == .lost)
        #expect(engine.validate(state: state))
    }

    @Test func noLegalActionsLosesAndEmptyBoardWins() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.queuePositions = level.paintQueues.map(\.count)
        #expect(engine.outcome(state: state) == .lost)
        state.boxes = level.boxes.map { BoxState(row: $0.row, filledUnits: $0.capacity) }
        #expect(engine.outcome(state: state) == .won)
        #expect(engine.validate(state: state))
    }

    @Test func invalidBoxLayoutsAreRejected() throws {
        func definition(_ boxes: [BoxDefinition]) -> LevelDefinition {
            LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 1, width: 2, height: 2,
                            boxes: boxes, paintQueues: [[.init(color: .red, paintUnits: 4)], [], [], []])
        }
        let valid = BoxDefinition(id: 1, row: 0, column: 0, width: 2, height: 2, color: .red)
        try LevelValidator.validate(definition([valid]))
        for box in [BoxDefinition(id: 1, row: 0, column: 0, width: 4, color: .red),
                    BoxDefinition(id: 1, row: -1, column: 0, width: 2, height: 2, color: .red),
                    BoxDefinition(id: 1, row: 1, column: 0, width: 2, height: 2, color: .red)] {
            #expect(throws: LevelError.invalidBoxes) { try LevelValidator.validate(definition([box])) }
        }
        #expect(throws: LevelError.invalidIDs) { try LevelValidator.validate(definition([valid, valid])) }
        #expect(throws: LevelError.invalidGrid) { try LevelValidator.validate(definition([])) }
        let overlapping = BoxDefinition(id: 2, row: 0, column: 0, color: .red)
        #expect(throws: LevelError.invalidBoxes) { try LevelValidator.validate(definition([valid, overlapping])) }
    }

    @Test func invalidSlotsQueuesQuantitiesAndPaintAreRejected() throws {
        let definitions: [(LevelDefinition, LevelError)] = [
            (level(rows: ["B"], slots: 0, queues: [[], [], [], []]), .invalidSlots),
            (level(rows: ["B"], slots: 1, queues: [[], []]), .invalidQueues),
            (level(rows: ["B"], slots: 1, queues: [[.init(color: .blue, paintUnits: 0)], [], [], []]), .invalidQuantity),
            (level(rows: ["B"], slots: 1, queues: [[.init(color: .red, paintUnits: 1)], [], [], []]), .paintMismatch)
        ]
        for (level, error) in definitions { #expect(throws: error) { try LevelValidator.validate(level) } }
    }

    @Test func invalidSnapshotsAreRejected() throws {
        let level = layeredLevel()
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.boxes.removeLast()
        #expect(!engine.validate(state: state))
        state = GameState(level: level)
        state.boxes[0].filledUnits = 2
        #expect(!engine.validate(state: state))
        state = GameState(level: level)
        state.boxes[0].row = 1
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
        state.boxes[0].filledUnits = 1
        #expect(!engine.validate(state: state))
    }

    @Test func floatingSnapshotIsRejectedEvenWhenPaintBalances() throws {
        let level = self.level(rows: ["R", "B"], queues: [[.init(color: .red, paintUnits: 1)], [.init(color: .blue, paintUnits: 1)], [], []])
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.boxes[1].filledUnits = 1
        state.queuePositions[1] = 1
        #expect(!engine.validate(state: state))
    }

    @Test func solverDistinguishesLimitFromUnsolvable() throws {
        let engine = try PuzzleEngine(level: layeredLevel())
        guard case .inconclusive = LevelSolver.solve(engine: engine, limit: 0) else {
            Issue.record("Expected an inconclusive search"); return
        }
        let impossible = level(rows: ["B", "R"], slots: 1,
                               queues: [[.init(color: .red, paintUnits: 1), .init(color: .blue, paintUnits: 1)], [], [], []])
        guard case .unsolvable = LevelSolver.solve(engine: try PuzzleEngine(level: impossible)) else {
            Issue.record("Expected an unsolvable level"); return
        }
    }

    private func withStore(_ test: (ProgressStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(ProgressStore(url: directory.appendingPathComponent("progress.json")))
    }

    @Test func partialFillsAndSettledPositionsRestoreExactly() throws {
        let levels = try LevelCatalog.load()
        try withStore { store in
            var progress = GameProgress(level: levels[0])
            progress.state = try replay([.take(queue: 0), .pour(slot: 0)], level: levels[0])
            #expect(progress.state.boxes[0].filledUnits == 1)
            try store.save(progress)
            #expect(store.load(levels: levels) == progress)
        }
        let level = bridgeLevel()
        try withStore { store in
            var progress = GameProgress(level: level)
            progress.state = try replay([.take(queue: 0), .pour(slot: 0), .take(queue: 1), .pour(slot: 0),
                                         .take(queue: 2), .pour(slot: 0), .take(queue: 3), .pour(slot: 0)], level: level)
            try store.save(progress)
            #expect(store.load(levels: [level]) == progress)
        }
    }

    @Test func oldAndUnknownVersionsStartAtNewLevelOne() throws {
        let levels = try LevelCatalog.load()
        try withStore { store in
            for version in [1, 2, 99] {
                var progress = GameProgress(level: levels[2])
                progress.version = version
                try store.save(progress)
                #expect(store.load(levels: levels) == GameProgress(level: levels[0]))
            }
            let oldSave = #"{"version":2,"levelID":3,"state":{"clearedCounts":[0,0,0],"queuePositions":[0,0,0,0],"buckets":[null,null]}}"#
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

    @Test func invalidCurrentSnapshotRestartsRecordedLevelAndUnreadableSaveStartsAtOne() throws {
        let levels = try LevelCatalog.load()
        try withStore { store in
            var progress = GameProgress(level: levels[1])
            progress.state.boxes = []
            try store.save(progress)
            #expect(store.load(levels: levels) == GameProgress(level: levels[1]))
            try Data("broken".utf8).write(to: store.url)
            #expect(store.load(levels: levels) == GameProgress(level: levels[0]))
        }
    }
}

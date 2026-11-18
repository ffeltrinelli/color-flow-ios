import Foundation
import Testing
@testable import ColorFlowCore

struct TargetingTests {
    private func layered(_ kind: BoardKind) -> LevelDefinition {
        let rows = ["RBR", "BRR", "RBB"]
        let boxes = rows.enumerated().flatMap { row, colors in
            colors.enumerated().map { column, color in
                BoxDefinition(id: row * 3 + column + 1, row: row, column: column,
                              color: PaintColor(rawValue: String(color))!)
            }
        }
        return LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 3, width: 3, height: 3,
            boxes: boxes, paintQueues: [[.init(color: .red, paintUnits: 5)],
                                      [.init(color: .blue, paintUnits: 4)], [], []], boardKind: kind)
    }

    private func entries(_ result: PourResult) -> [Int] {
        result.events.compactMap { if case .fill(let step) = $0 { step.entry.column } else { nil } }
    }

    @Test func circularSearchRestartsAtEverySelectedLaneAndWraps() throws {
        let level = layered(.circular)
        let engine = try PuzzleEngine(level: level)
        var state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        state.alignedLane = 1
        let before = state
        #expect(engine.canPour(slot: 0, state: state))
        _ = engine.legalMoves(state: state)
        _ = engine.outcome(state: state)
        #expect(state == before)
        let result = try engine.pourResult(slot: 0, state: state)
        #expect(entries(result) == [2, 2, 0])
        #expect(result.state.alignedLane == 0)
        #expect(result.state.buckets[0]?.paintUnits == 2)
        #expect(engine.validate(state: result.state))
        #expect(!engine.canPour(slot: 0, state: result.state))
        #expect(throws: MoveError.self) { try engine.pourResult(slot: 0, state: result.state) }
    }

    @Test func squareSearchStillRestartsAtTheFirstColumn() throws {
        let level = layered(.square)
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        let result = try engine.pourResult(slot: 0, state: state)
        #expect(entries(result) == [0, 2, 2])
        #expect(result.state.alignedLane == 0)
    }

    @Test func alignmentIsPartOfSearchIdentityAndRetrievalPreservesIt() throws {
        let level = layered(.circular)
        let engine = try PuzzleEngine(level: level)
        let initial = GameState(level: level)
        var rotated = initial
        rotated.alignedLane = 2
        #expect(Set([initial, rotated]).count == 2)
        #expect(try engine.applying(.take(queue: 0), to: rotated).alignedLane == 2)
        let a = try engine.pourResult(slot: 0, state: engine.applying(.take(queue: 0), to: initial))
        let b = try engine.pourResult(slot: 0, state: engine.applying(.take(queue: 0), to: rotated))
        #expect(entries(a).first == 0)
        #expect(entries(b).first == 2)
        rotated.alignedLane = 3
        #expect(!engine.validate(state: rotated))
    }

    @Test func partialArcFallsWithoutChangingPaintAndReceivesAGapPour() throws {
        let level = LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 3, width: 3, height: 2,
            boxes: [.init(id: 1, row: 0, column: 0, width: 2, color: .red),
                    .init(id: 2, row: 0, column: 2, color: .blue),
                    .init(id: 3, row: 1, column: 0, width: 3, color: .blue)],
            paintQueues: [[.init(color: .red, paintUnits: 1), .init(color: .red, paintUnits: 1)],
                          [.init(color: .blue, paintUnits: 4)], [], []], boardKind: .circular)
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        for move in [Move.take(queue: 0), .pour(slot: 0), .take(queue: 1)] {
            state = try engine.applying(move, to: state)
        }
        let fall = try engine.pourResult(slot: 0, state: state)
        #expect(fall.events.contains(.fall([.init(boxID: 1, fromRow: 0, toRow: 1)])))
        #expect(engine.boxState(id: 1, state: fall.state).filledUnits == 1)
        #expect(fall.state.alignedLane == 2)
        #expect(engine.validate(state: fall.state))
        state = try engine.applying(.take(queue: 0), to: fall.state)
        let final = try engine.pourResult(slot: 0, state: state)
        #expect(entries(final) == [0])
        #expect(engine.outcome(state: final.state) == .won)
        #expect(engine.validate(state: final.state))
    }

    @Test func circularHintsRespectAlignmentAndDoNotReuseAnUnmatchedCheckpoint() throws {
        let level = layered(.circular)
        let engine = try PuzzleEngine(level: level)
        guard case .solved(let known, _) = LevelSolver.solve(engine: engine) else {
            Issue.record("Expected a winning fixture"); return
        }
        var rotated = GameState(level: level)
        rotated.alignedLane = 2
        let before = rotated
        #expect(LevelHints.suggest(engine: engine, state: rotated, limit: 0, knownSolution: known) == .inconclusive)
        guard case .steps(let hints) = LevelHints.suggest(engine: engine, state: rotated, knownSolution: known) else {
            Issue.record("Expected hints from the rotated state"); return
        }
        #expect(!hints.isEmpty)
        #expect(rotated == before)
        for hint in hints { rotated = try engine.applying(hint.move, to: rotated) }
        guard case .solved(let continuation, _) = LevelSolver.solve(engine: engine, from: rotated) else {
            Issue.record("Hint prefix must retain a winning continuation"); return
        }
        for move in continuation { rotated = try engine.applying(move, to: rotated) }
        #expect(engine.outcome(state: rotated) == .won)
        #expect(before.alignedLane == 2 && before.boxes.allSatisfy { $0.filledUnits == 0 })
    }

    @Test func wideArcUsesTheAlignedEntryRatherThanItsFirstLane() throws {
        let level = LevelDefinition(id: 1, difficulty: .easy, bucketSlots: 1, width: 3, height: 1,
            boxes: [.init(id: 1, row: 0, column: 0, width: 3, color: .red)],
            paintQueues: [[.init(color: .red, paintUnits: 3)], [], [], []], boardKind: .circular)
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        state.alignedLane = 2
        state = try engine.applying(.take(queue: 0), to: state)
        let result = try engine.pourResult(slot: 0, state: state)
        #expect(entries(result) == [2])
        #expect(result.state.alignedLane == 2)
        #expect(engine.validate(state: result.state))
    }

    @Test func legacyOrientationMovesIntoEngineStateAndIsWrittenOnlyThere() throws {
        let level = layered(.circular)
        let progress = GameProgress(level: level)
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as! [String: Any]
        var state = json["state"] as! [String: Any]
        state.removeValue(forKey: "alignedLane")
        json["state"] = state
        json["version"] = 5
        json["circularEntryLane"] = 2
        let restored = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.state.alignedLane == 2)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as! [String: Any]
        #expect(encoded["circularEntryLane"] == nil)
        json.removeValue(forKey: "circularEntryLane")
        let missing = try JSONDecoder().decode(GameProgress.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(missing.state.alignedLane == 0)
    }
}

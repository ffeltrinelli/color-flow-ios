import Foundation

/// Gameplay witnesses obtained from the engine, not inferred from authored geometry.
public struct PathFeatures: Sendable {
    public private(set) var hasFall = false
    public private(set) var hasPartiallyFilledFall = false
    public private(set) var hasGapPour = false

    public init(level: LevelDefinition, moves: [Move]) throws {
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        for move in moves {
            if case .pour(let slot) = move {
                let result = try engine.pourResult(slot: slot, state: state)
                for event in result.events {
                    switch event {
                    case .fill(let step): hasGapPour = hasGapPour || step.entry.row > 0
                    case .fall(let falls):
                        hasFall = true
                        hasPartiallyFilledFall = hasPartiallyFilledFall || falls.contains {
                            engine.boxState(id: $0.boxID, state: state).filledUnits > 0
                        }
                    case .remove: break
                    }
                    state = engine.presenting(event, in: state)
                }
                state = result.state
            } else {
                state = try engine.applying(move, to: state)
            }
        }
    }
}

import Foundation
import ColorFlowCore

let levels = try LevelCatalog.load()
var solutions: [[Move]] = []
for level in levels {
    let engine = try PuzzleEngine(level: level)
    switch LevelSolver.solve(engine: engine) {
    case .solved(let moves, let visited):
        print("Level \(level.id) (\(level.difficulty.rawValue)): \(moves.count) moves, \(visited) states")
        solutions.append(moves)
    case .unsolvable(let visited): fatalError("Level \(level.id) is unsolvable (\(visited) states)")
    case .inconclusive(let visited): fatalError("Level \(level.id): search inconclusive (\(visited) states)")
    }
}
if CommandLine.arguments.contains("--write-solutions") {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(solutions).write(to: URL(fileURLWithPath: "Sources/ColorFlowCore/Resources/solutions.json"))
}

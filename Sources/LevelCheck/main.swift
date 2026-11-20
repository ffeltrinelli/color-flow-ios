import Foundation
import ColorFlowCore

private enum AuditError: Error {
    case missingSolutions, invalidWinningPath(Int), invalidLosingPath(Int), missingLosingPaths, invalidGenerationReport
}

private func replay(_ moves: [Move], engine: PuzzleEngine) throws -> GameOutcome {
    var state = GameState(level: engine.level)
    for move in moves {
        state = try engine.applying(move, to: state)
        guard engine.validate(state: state) else { throw AuditError.invalidWinningPath(engine.level.id) }
    }
    return engine.outcome(state: state)
}

private func audit() throws {
    let arguments = Set(CommandLine.arguments.dropFirst())
    let rewrite = arguments.contains("--write-solutions")
    let search = rewrite || arguments.contains("--solve")
    let levels = try LevelCatalog.load()
    let stored = rewrite ? [] : try LevelCatalog.solutions()
    guard rewrite || stored.count == levels.count else { throw AuditError.missingSolutions }
    var solutions: [[Move]] = []
    for (index, level) in levels.enumerated() {
        let engine = try PuzzleEngine(level: level)
        if !rewrite {
            guard try replay(stored[index], engine: engine) == .won else { throw AuditError.invalidWinningPath(level.id) }
        }
        if search {
            switch LevelSolver.solve(engine: engine) {
            case .solved(let moves, let visited):
                guard try replay(moves, engine: engine) == .won else { throw AuditError.invalidWinningPath(level.id) }
                solutions.append(moves)
                print("Level \(level.id) (\(level.difficulty.rawValue)): \(moves.count) moves, \(visited) search states")
            case .unsolvable(let visited):
                throw NSError(domain: "LevelCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: "Level \(level.id) is unsolvable (\(visited) states)"])
            case .inconclusive(let visited):
                throw NSError(domain: "LevelCheck", code: 2, userInfo: [NSLocalizedDescriptionKey: "Level \(level.id): search inconclusive (\(visited) states)"])
            }
        } else {
            print("Level \(level.id) (\(level.difficulty.rawValue)): verified \(stored[index].count) winning moves")
        }
    }
    let losing = try LevelCatalog.losingBranches()
    let expected = Set(levels.filter { $0.difficulty != .easy }.map(\.id))
    guard Set(losing.keys) == expected else { throw AuditError.missingLosingPaths }
    for level in levels where expected.contains(level.id) {
        guard let moves = losing[level.id],
              try replay(moves, engine: PuzzleEngine(level: level)) == .lost else {
            throw AuditError.invalidLosingPath(level.id)
        }
    }
    let report = try LevelCatalog.generationReport()
    try report.validate(levels: levels)
    guard report.batches.first?.order == .shuffledPairs,
          report.batches.first?.levelCount == 50,
          levels.prefix(50).filter({ $0.difficulty != .easy }).count == 30 else {
        throw AuditError.invalidGenerationReport
    }
    let features = try zip(levels, rewrite ? solutions : stored).filter { $0.0.boardKind == .circular }
        .map { try PathFeatures(level: $0.0, moves: $0.1) }
    guard features.allSatisfy(\.hasFall), features.contains(where: \.hasPartiallyFilledFall),
          features.contains(where: \.hasGapPour) else {
        throw AuditError.invalidGenerationReport
    }
    for (index, metric) in report.metrics.enumerated() {
        guard metric.solutionMoves == (rewrite ? solutions[index].count : stored[index].count) else {
            throw AuditError.invalidGenerationReport
        }
    }
    if rewrite {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(solutions).write(to: URL(fileURLWithPath: "Sources/ColorFlowCore/Resources/solutions.json"), options: .atomic)
    }
    print("Verified all \(levels.count) levels and \(losing.count) losing alternatives.")
}

do { try audit() }
catch {
    FileHandle.standardError.write(Data("Level audit failed: \(error)\n".utf8))
    exit(1)
}

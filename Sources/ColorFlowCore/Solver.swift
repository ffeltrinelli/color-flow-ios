public enum SearchResult: Sendable {
    case solved([Move], visited: Int)
    case unsolvable(visited: Int)
    case inconclusive(visited: Int)
}

public enum LevelSolver {
    public static func solve(engine: PuzzleEngine, from initial: GameState? = nil, limit: Int = 250_000,
                             knownSolution: [Move]? = nil,
                             isCancelled: @Sendable () -> Bool = { false }) -> SearchResult {
        let initial = initial ?? GameState(level: engine.level)
        if let knownSolution, let continuation = verifiedContinuation(engine: engine, state: initial,
                                                                      solution: knownSolution, isCancelled: isCancelled) {
            return .solved(continuation, visited: knownSolution.count)
        }
        var visited = Set<GameState>()
        var path: [Move] = []
        var exhausted = false
        func search(_ state: GameState) -> Bool {
            if isCancelled() { exhausted = true; return false }
            if engine.outcome(state: state) == .won { return true }
            guard !visited.contains(state) else { return false }
            guard visited.count < limit else { exhausted = true; return false }
            visited.insert(state)
            guard engine.outcome(state: state) == .playing else { return false }
            let legal = engine.legalMoves(state: state)
            let moves = legal.filter { if case .pour = $0 { true } else { false } } +
                legal.filter { if case .take = $0 { true } else { false } }
            for move in moves {
                guard let next = try? engine.applying(move, to: state) else { continue }
                path.append(move)
                if search(next) { return true }
                path.removeLast()
                if exhausted { return false }
            }
            return false
        }
        if search(initial) { return .solved(path, visited: visited.count) }
        return exhausted ? .inconclusive(visited: visited.count) : .unsolvable(visited: visited.count)
    }

    private static func verifiedContinuation(engine: PuzzleEngine, state: GameState, solution: [Move],
                                             isCancelled: @Sendable () -> Bool) -> [Move]? {
        var replay = GameState(level: engine.level)
        var continuation: [Move]? = replay == state ? [] : nil
        for move in solution {
            guard !isCancelled(), let next = try? engine.applying(move, to: replay) else { return nil }
            continuation?.append(move)
            replay = next
            if replay == state { continuation = [] }
        }
        guard !isCancelled(), engine.outcome(state: replay) == .won else { return nil }
        return continuation
    }

}

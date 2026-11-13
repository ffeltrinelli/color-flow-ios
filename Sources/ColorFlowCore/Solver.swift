public enum SearchResult: Sendable {
    case solved([Move], visited: Int)
    case unsolvable(visited: Int)
    case inconclusive(visited: Int)
}

public enum LevelSolver {
    public static func solve(engine: PuzzleEngine, from initial: GameState? = nil, limit: Int = 250_000) -> SearchResult {
        var visited = Set<GameState>()
        var path: [Move] = []
        var exhausted = false
        func search(_ state: GameState) -> Bool {
            if engine.outcome(state: state) == .won { return true }
            var key = state
            key.selectedSlot = nil
            guard !visited.contains(key) else { return false }
            guard visited.count < limit else { exhausted = true; return false }
            visited.insert(key)
            guard engine.outcome(state: state) == .playing else { return false }
            // Pour before retrieving more paint to find compact, readable solutions.
            let moves = engine.legalMoves(state: state).sorted { lhs, rhs in
                if case .pour = lhs, case .take = rhs { return true }
                return false
            }
            for move in moves {
                guard let next = try? engine.applying(move, to: state) else { continue }
                path.append(move)
                if search(next) { return true }
                path.removeLast()
                if exhausted { return false }
            }
            return false
        }
        if search(initial ?? GameState(level: engine.level)) { return .solved(path, visited: visited.count) }
        return exhausted ? .inconclusive(visited: visited.count) : .unsolvable(visited: visited.count)
    }
}

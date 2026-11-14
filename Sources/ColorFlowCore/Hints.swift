public struct HintStep: Equatable, Sendable, Identifiable {
    public let id: Int
    public let move: Move
    public let target: PaintTin
    public let controls: [PaintTin?]

    public var targetIndex: Int {
        switch move {
        case .take(let queue): queue
        case .pour(let slot): slot
        }
    }

    public var isRetrieval: Bool { if case .take = move { true } else { false } }
    public var instruction: String {
        "\(isRetrieval ? "Take" : "Pour") \(target.color.name.lowercased()) · \(isRetrieval ? "Queue" : "Bucket") \(targetIndex + 1)"
    }
}

public enum HintResult: Equatable, Sendable {
    case steps([HintStep])
    case unwinnable
    case inconclusive
}

public enum LevelHints {
    public static func suggest(engine: PuzzleEngine, state: GameState, limit: Int = 250_000,
                               knownSolution: [Move]? = nil,
                               deadline: ContinuousClock.Instant? = nil,
                               isCancelled: @Sendable () -> Bool = { false }) -> HintResult {
        let clock = ContinuousClock()
        switch LevelSolver.solve(engine: engine, from: state, limit: limit, knownSolution: knownSolution,
                                 isCancelled: { isCancelled() || deadline.map { clock.now >= $0 } == true }) {
        case .unsolvable: return .unwinnable
        case .inconclusive: return .inconclusive
        case .solved(let moves, _):
            var preview = state
            var steps: [HintStep] = []
            for move in moves.prefix(5) {
                let controls: [PaintTin?]
                let target: PaintTin?
                switch move {
                case .take(let queue):
                    controls = (0..<4).map { engine.frontTin(queue: $0, state: preview) }
                    target = controls[queue]
                case .pour(let slot):
                    controls = preview.buckets
                    target = controls[slot]
                }
                guard let target, let next = try? engine.applying(move, to: preview) else { return .inconclusive }
                steps.append(.init(id: steps.count + 1, move: move, target: target, controls: controls))
                preview = next
            }
            return .steps(steps)
        }
    }
}

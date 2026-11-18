/// Board-specific scan order; occupancy and exposed-block rules remain in the engine.
protocol TargetingPolicy: Sendable {
    func columns(width: Int, alignedLane: Int) -> [Int]
    func alignment(afterEntry column: Int) -> Int
    func validAlignment(_ lane: Int, width: Int) -> Bool
}

struct SquareTargeting: TargetingPolicy {
    func columns(width: Int, alignedLane: Int) -> [Int] { Array(0..<width) }
    func alignment(afterEntry column: Int) -> Int { 0 }
    func validAlignment(_ lane: Int, width: Int) -> Bool { lane == 0 }
}

struct CircularTargeting: TargetingPolicy {
    func columns(width: Int, alignedLane: Int) -> [Int] {
        (0..<width).map { (alignedLane + $0) % width }
    }
    func alignment(afterEntry column: Int) -> Int { column }
    func validAlignment(_ lane: Int, width: Int) -> Bool { (0..<width).contains(lane) }
}

extension BoardKind {
    var targetingPolicy: any TargetingPolicy {
        switch self {
        case .square: SquareTargeting()
        case .circular: CircularTargeting()
        }
    }
}

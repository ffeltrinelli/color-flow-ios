import Foundation

public struct Cell: Codable, Equatable, Hashable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

public enum Move: Codable, Equatable, Sendable {
    case take(queue: Int)
    case pour(slot: Int)
}

public enum GameOutcome: String, Codable, Sendable { case playing, won, lost }
public enum MoveError: Error { case illegalMove }

public struct PourResult: Sendable {
    public let cells: [Cell]
    public let state: GameState
}

public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var clearedCounts: [Int]
    public var queuePositions: [Int]
    public var buckets: [PaintTin?]

    public init(level: LevelDefinition) {
        clearedCounts = Array(repeating: 0, count: level.width)
        queuePositions = Array(repeating: 0, count: 4)
        buckets = Array(repeating: nil, count: level.bucketSlots)
    }
}

public struct PuzzleEngine: Sendable {
    public let level: LevelDefinition
    private let targets: [[PaintColor]]

    public init(level: LevelDefinition) throws {
        try LevelValidator.validate(level)
        self.level = level
        targets = level.colors
    }

    public func frontTin(queue: Int, state: GameState) -> PaintTin? {
        guard level.paintQueues.indices.contains(queue),
              level.paintQueues[queue].indices.contains(state.queuePositions[queue]) else { return nil }
        return level.paintQueues[queue][state.queuePositions[queue]]
    }

    public func canTake(queue: Int, state: GameState) -> Bool {
        guard let tin = frontTin(queue: queue, state: state) else { return false }
        return state.buckets.contains(nil) || state.buckets.contains { $0?.color == tin.color }
    }

    public func canPour(slot: Int, state: GameState) -> Bool {
        guard state.buckets.indices.contains(slot), let bucket = state.buckets[slot] else { return false }
        return firstTarget(color: bucket.color, state: state) != nil
    }

    public func isCleared(_ cell: Cell, state: GameState) -> Bool {
        cell.row < state.clearedCounts[cell.column]
    }

    public func remainingColors(column: Int, state: GameState) -> [PaintColor] {
        guard (0..<level.width).contains(column) else { return [] }
        return (state.clearedCounts[column]..<level.height).map { targets[$0][column] }
    }

    private func firstTarget(color: PaintColor, state: GameState) -> Cell? {
        for column in 0..<level.width {
            let row = state.clearedCounts[column]
            if row < level.height && targets[row][column] == color {
                return Cell(row: row, column: column)
            }
        }
        return nil
    }

    public func pourResult(slot: Int, state: GameState) throws -> PourResult {
        guard outcome(state: state) == .playing, canPour(slot: slot, state: state),
              var bucket = state.buckets[slot] else { throw MoveError.illegalMove }
        var next = state
        var cells: [Cell] = []
        while bucket.paintUnits > 0, let cell = firstTarget(color: bucket.color, state: next) {
            cells.append(cell)
            next.clearedCounts[cell.column] += 1
            bucket.paintUnits -= 1
        }
        next.buckets[slot] = bucket.paintUnits == 0 ? nil : bucket
        return PourResult(cells: cells, state: next)
    }

    public func legalMoves(state: GameState) -> [Move] {
        let retrievals = (0..<4).filter { canTake(queue: $0, state: state) }.map { Move.take(queue: $0) }
        let pours = state.buckets.indices.filter { canPour(slot: $0, state: state) }.map { Move.pour(slot: $0) }
        return retrievals + pours
    }

    public func outcome(state: GameState) -> GameOutcome {
        if state.clearedCounts.allSatisfy({ $0 == level.height }) { return .won }
        let hasPour = state.buckets.indices.contains { canPour(slot: $0, state: state) }
        if !hasPour && !state.buckets.contains(nil) { return .lost }
        return legalMoves(state: state).isEmpty ? .lost : .playing
    }

    public func applying(_ move: Move, to state: GameState) throws -> GameState {
        guard outcome(state: state) == .playing else { throw MoveError.illegalMove }
        switch move {
        case .take(let queue): return try taking(queue: queue, state: state)
        case .pour(let slot): return try pourResult(slot: slot, state: state).state
        }
    }

    private func taking(queue: Int, state: GameState) throws -> GameState {
        guard canTake(queue: queue, state: state), let tin = frontTin(queue: queue, state: state),
              let slot = state.buckets.firstIndex(where: { $0?.color == tin.color }) ?? state.buckets.firstIndex(of: nil)
        else { throw MoveError.illegalMove }
        var next = state
        next.buckets[slot] = PaintTin(color: tin.color, paintUnits: (next.buckets[slot]?.paintUnits ?? 0) + tin.paintUnits)
        next.queuePositions[queue] += 1
        return next
    }

    public func validate(state: GameState) -> Bool {
        guard state.clearedCounts.count == level.width, state.queuePositions.count == 4,
              state.buckets.count == level.bucketSlots,
              state.clearedCounts.allSatisfy({ (0...level.height).contains($0) }),
              (0..<4).allSatisfy({ (0...level.paintQueues[$0].count).contains(state.queuePositions[$0]) }),
              state.buckets.compactMap({ $0 }).allSatisfy({ $0.paintUnits > 0 && $0.paintUnits <= level.width * level.height })
        else { return false }
        let active = state.buckets.compactMap { $0 }
        guard Set(active.map(\.color)).count == active.count else { return false }
        for color in PaintColor.allCases {
            let remaining = (0..<level.width).reduce(0) { count, column in
                count + remainingColors(column: column, state: state).filter { $0 == color }.count
            }
            let reserved = (0..<4).reduce(0) { count, queue in
                count + level.paintQueues[queue].dropFirst(state.queuePositions[queue])
                    .filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            }
            let available = active.filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            guard remaining == reserved + available else { return false }
        }
        return true
    }
}

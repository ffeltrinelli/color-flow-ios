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
    case pour(slot: Int, column: Int)
}

public enum GameOutcome: String, Codable, Sendable { case playing, won, lost }
public enum MoveError: Error { case illegalMove }

public struct GameState: Codable, Equatable, Hashable, Sendable {
    public var paintedCounts: [Int]
    public var queuePositions: [Int]
    public var buckets: [PaintTin?]
    public var selectedSlot: Int?

    public init(level: LevelDefinition) {
        paintedCounts = Array(repeating: 0, count: level.width)
        queuePositions = Array(repeating: 0, count: 4)
        buckets = Array(repeating: nil, count: level.bucketSlots)
        selectedSlot = nil
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

    public func pourTargets(slot: Int, column: Int, state: GameState) -> [Cell] {
        guard state.buckets.indices.contains(slot), let bucket = state.buckets[slot],
              (0..<level.width).contains(column) else { return [] }
        var cells: [Cell] = []
        var row = level.height - state.paintedCounts[column] - 1
        while row >= 0 && cells.count < bucket.paintUnits && targets[row][column] == bucket.color {
            cells.append(Cell(row: row, column: column))
            row -= 1
        }
        return cells
    }

    public func isPainted(_ cell: Cell, state: GameState) -> Bool {
        cell.row >= level.height - state.paintedCounts[cell.column]
    }

    public func legalMoves(state: GameState) -> [Move] {
        let retrievals = (0..<4).filter { canTake(queue: $0, state: state) }.map { Move.take(queue: $0) }
        let pours = state.buckets.indices.flatMap { slot in
            (0..<level.width).compactMap { column -> Move? in
                pourTargets(slot: slot, column: column, state: state).isEmpty ? nil : .pour(slot: slot, column: column)
            }
        }
        return retrievals + pours
    }

    public func outcome(state: GameState) -> GameOutcome {
        if state.paintedCounts.allSatisfy({ $0 == level.height }), state.buckets.allSatisfy({ $0 == nil }),
           (0..<4).allSatisfy({ frontTin(queue: $0, state: state) == nil }) { return .won }
        let hasPour = state.buckets.indices.contains { slot in
            (0..<level.width).contains { !pourTargets(slot: slot, column: $0, state: state).isEmpty }
        }
        if !hasPour && !state.buckets.contains(nil) { return .lost }
        return legalMoves(state: state).isEmpty ? .lost : .playing
    }

    public func applying(_ move: Move, to state: GameState) throws -> GameState {
        guard outcome(state: state) == .playing else { throw MoveError.illegalMove }
        var next = state
        switch move {
        case .take(let queue):
            guard canTake(queue: queue, state: state), let tin = frontTin(queue: queue, state: state),
                  let slot = state.buckets.firstIndex(where: { $0?.color == tin.color }) ?? state.buckets.firstIndex(of: nil)
            else { throw MoveError.illegalMove }
            next.buckets[slot] = PaintTin(color: tin.color, paintUnits: (next.buckets[slot]?.paintUnits ?? 0) + tin.paintUnits)
            next.queuePositions[queue] += 1
            next.selectedSlot = slot
        case .pour(let slot, let column):
            let cells = pourTargets(slot: slot, column: column, state: state)
            guard !cells.isEmpty else { throw MoveError.illegalMove }
            next.paintedCounts[column] += cells.count
            next.buckets[slot]!.paintUnits -= cells.count
            if next.buckets[slot]!.paintUnits == 0 {
                next.buckets[slot] = nil
                next.selectedSlot = nil
            } else { next.selectedSlot = slot }
        }
        return next
    }

    public func validate(state: GameState) -> Bool {
        guard state.paintedCounts.count == level.width, state.queuePositions.count == 4,
              state.buckets.count == level.bucketSlots,
              state.paintedCounts.allSatisfy({ (0...level.height).contains($0) }),
              (0..<4).allSatisfy({ (0...level.paintQueues[$0].count).contains(state.queuePositions[$0]) }),
              state.buckets.compactMap({ $0 }).allSatisfy({ $0.paintUnits > 0 && $0.paintUnits <= level.width * level.height })
        else { return false }
        let active = state.buckets.compactMap { $0 }
        guard Set(active.map(\.color)).count == active.count else { return false }
        if let slot = state.selectedSlot {
            guard state.buckets.indices.contains(slot), state.buckets[slot] != nil else { return false }
        }
        for color in PaintColor.allCases {
            let remainingCells = (0..<level.width).reduce(0) { count, column in
                count + (0..<(level.height - state.paintedCounts[column])).filter { targets[$0][column] == color }.count
            }
            let reserved = (0..<4).reduce(0) { count, queue in
                count + level.paintQueues[queue].dropFirst(state.queuePositions[queue])
                    .filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            }
            let available = active.filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            guard remainingCells == reserved + available else { return false }
        }
        return true
    }
}

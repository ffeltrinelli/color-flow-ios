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

public struct BoxState: Codable, Equatable, Hashable, Sendable {
    public internal(set) var row: Int
    public internal(set) var filledUnits: Int
}

public struct FillStep: Equatable, Sendable {
    public let boxID: Int
    public let entry: Cell
    public let fromUnits: Int
    public let toUnits: Int
}

public struct BoxFall: Equatable, Sendable {
    public let boxID: Int
    public let fromRow: Int
    public let toRow: Int
}

public enum PourEvent: Equatable, Sendable {
    case fill(FillStep)
    case remove(boxID: Int)
    case fall([BoxFall])
}

public struct PourResult: Sendable {
    public let events: [PourEvent]
    public let state: GameState
}

public struct GameState: Codable, Equatable, Hashable, Sendable {
    public internal(set) var boxes: [BoxState]
    public internal(set) var queuePositions: [Int]
    public internal(set) var buckets: [PaintTin?]

    public init(level: LevelDefinition) {
        boxes = level.boxes.map { BoxState(row: $0.row, filledUnits: 0) }
        queuePositions = Array(repeating: 0, count: 4)
        buckets = Array(repeating: nil, count: level.bucketSlots)
    }
}

public struct PuzzleEngine: Sendable {
    public let level: LevelDefinition
    private let boxIndices: [Int: Int]

    public init(level: LevelDefinition) throws {
        try LevelValidator.validate(level)
        self.level = level
        boxIndices = Dictionary(uniqueKeysWithValues: level.boxes.enumerated().map { ($0.element.id, $0.offset) })
    }

    public func boxState(id: Int, state: GameState) -> BoxState {
        state.boxes[boxIndices[id]!]
    }

    public func isRemoved(_ box: BoxDefinition, state: GameState) -> Bool {
        boxState(id: box.id, state: state).filledUnits == box.capacity
    }

    public func remainingBoxes(state: GameState) -> [BoxDefinition] {
        level.boxes.filter { !isRemoved($0, state: state) }
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

    private func occupancy(state: GameState) -> [Int?] {
        var cells = Array<Int?>(repeating: nil, count: level.width * level.height)
        for (index, box) in level.boxes.enumerated() where state.boxes[index].filledUnits < box.capacity {
            for row in state.boxes[index].row..<(state.boxes[index].row + box.height) {
                for column in box.column..<(box.column + box.width) {
                    cells[row * level.width + column] = index
                }
            }
        }
        return cells
    }

    private func firstTarget(color: PaintColor, state: GameState) -> (index: Int, entry: Cell)? {
        let cells = occupancy(state: state)
        for column in 0..<level.width {
            for row in 0..<level.height {
                guard let index = cells[row * level.width + column] else { continue }
                if level.boxes[index].color == color { return (index, Cell(row: row, column: column)) }
                break
            }
        }
        return nil
    }

    private func fallingBoxes(state: GameState) -> [BoxFall] {
        let cells = occupancy(state: state)
        return level.boxes.enumerated().compactMap { index, box in
            let current = state.boxes[index]
            let bottom = current.row + box.height
            guard current.filledUnits < box.capacity, bottom < level.height,
                  (box.column..<(box.column + box.width)).allSatisfy({ cells[bottom * level.width + $0] == nil })
            else { return nil }
            return BoxFall(boxID: box.id, fromRow: current.row, toRow: current.row + 1)
        }
    }

    /// Replays engine events for presentation; does not perform targeting or gravity again.
    public func presenting(_ event: PourEvent, in state: GameState) -> GameState {
        var next = state
        switch event {
        case .fill(let step):
            let index = boxIndices[step.boxID]!
            next.boxes[index].filledUnits = step.toUnits
            if step.toUnits == level.boxes[index].capacity {
                // Removed positions are canonical so equivalent solver states hash equally.
                next.boxes[index].row = level.boxes[index].row
            }
        case .remove: break
        case .fall(let falls):
            for fall in falls { next.boxes[boxIndices[fall.boxID]!].row = fall.toRow }
        }
        return next
    }

    public func pourResult(slot: Int, state: GameState) throws -> PourResult {
        guard outcome(state: state) == .playing, canPour(slot: slot, state: state),
              var bucket = state.buckets[slot] else { throw MoveError.illegalMove }
        var next = state
        var events: [PourEvent] = []
        while bucket.paintUnits > 0, let target = firstTarget(color: bucket.color, state: next) {
            let box = level.boxes[target.index]
            let from = next.boxes[target.index].filledUnits
            let units = min(bucket.paintUnits, box.capacity - from)
            let fill = PourEvent.fill(FillStep(boxID: box.id, entry: target.entry, fromUnits: from, toUnits: from + units))
            events.append(fill)
            next = presenting(fill, in: next)
            bucket.paintUnits -= units
            if from + units == box.capacity {
                events.append(.remove(boxID: box.id))
                settle(state: &next, events: &events)
            }
        }
        next.buckets[slot] = bucket.paintUnits == 0 ? nil : bucket
        return PourResult(events: events, state: next)
    }

    private func settle(state: inout GameState, events: inout [PourEvent]) {
        var falls = fallingBoxes(state: state)
        while !falls.isEmpty {
            let event = PourEvent.fall(falls)
            events.append(event)
            state = presenting(event, in: state)
            falls = fallingBoxes(state: state)
        }
    }

    public func legalMoves(state: GameState) -> [Move] {
        let retrievals = (0..<4).filter { canTake(queue: $0, state: state) }.map { Move.take(queue: $0) }
        let pours = state.buckets.indices.filter { canPour(slot: $0, state: state) }.map { Move.pour(slot: $0) }
        return retrievals + pours
    }

    public func outcome(state: GameState) -> GameOutcome {
        if remainingBoxes(state: state).isEmpty { return .won }
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
        guard state.boxes.count == level.boxes.count, state.queuePositions.count == 4,
              state.buckets.count == level.bucketSlots,
              (0..<4).allSatisfy({ (0...level.paintQueues[$0].count).contains(state.queuePositions[$0]) }),
              state.buckets.compactMap({ $0 }).allSatisfy({ $0.paintUnits > 0 && $0.paintUnits <= level.width * level.height }),
              validGeometry(state: state) else { return false }
        let active = state.buckets.compactMap { $0 }
        guard Set(active.map(\.color)).count == active.count else { return false }
        for color in PaintColor.allCases {
            let remaining = level.boxes.enumerated().filter { $0.element.color == color }.reduce(0) {
                $0 + $1.element.capacity - state.boxes[$1.offset].filledUnits
            }
            let reserved = (0..<4).reduce(0) { count, queue in
                count + level.paintQueues[queue].dropFirst(state.queuePositions[queue])
                    .filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            }
            let available = active.filter { $0.color == color }.reduce(0) { $0 + $1.paintUnits }
            guard remaining == reserved + available else { return false }
        }
        return fallingBoxes(state: state).isEmpty
    }

    private func validGeometry(state: GameState) -> Bool {
        var occupied = Set<Cell>()
        for (index, box) in level.boxes.enumerated() {
            let current = state.boxes[index]
            guard (0...box.capacity).contains(current.filledUnits),
                  (box.row...(level.height - box.height)).contains(current.row) else { return false }
            if current.filledUnits == box.capacity {
                guard current.row == box.row else { return false }
                continue
            }
            for row in current.row..<(current.row + box.height) {
                for column in box.column..<(box.column + box.width) {
                    guard occupied.insert(Cell(row: row, column: column)).inserted else { return false }
                }
            }
        }
        return true
    }
}

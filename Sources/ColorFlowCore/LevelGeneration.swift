import Foundation

/// SplitMix64 keeps a recorded seed reproducible across Swift/toolchain versions.
struct LevelRandom {
    var seed: UInt64

    mutating func next() -> UInt64 {
        seed &+= 0x9e3779b97f4a7c15
        var value = seed
        value = (value ^ (value >> 30)) &* 0xbf58476d1ce4e5b9
        value = (value ^ (value >> 27)) &* 0x94d049bb133111eb
        return value ^ (value >> 31)
    }

    mutating func index(_ count: Int) -> Int { Int(next() % UInt64(count)) }

    mutating func shuffle<T>(_ values: [T]) -> [T] {
        var result = values
        for index in result.indices.dropFirst().reversed() {
            result.swapAt(index, self.index(index + 1))
        }
        return result
    }
}

public struct GenerationProfile: Codable, Equatable, Sendable {
    public let difficulty: Difficulty
    public let largeBoxArea: Int
    public var bucketSlots: Int { difficulty == .hard ? 2 : 3 }
    public var colorCount: Int { difficulty == .hard ? 5 : 4 }

    public init(difficulty: Difficulty, largeBoxArea: Int) {
        self.difficulty = difficulty
        self.largeBoxArea = largeBoxArea
    }

    public static let campaign: [GenerationProfile] = [
        .init(difficulty: .easy, largeBoxArea: 20),
        .init(difficulty: .easy, largeBoxArea: 24),
        .init(difficulty: .easy, largeBoxArea: 30),
        .init(difficulty: .medium, largeBoxArea: 35),
        .init(difficulty: .medium, largeBoxArea: 40),
        .init(difficulty: .medium, largeBoxArea: 45),
        .init(difficulty: .hard, largeBoxArea: 50),
        .init(difficulty: .hard, largeBoxArea: 55),
        .init(difficulty: .hard, largeBoxArea: 60)
    ]

    public static func balanced(count: Int) throws -> [GenerationProfile] {
        guard count > 0 else { throw GenerationError.invalidConfiguration }
        return (0..<count).map { index in
            let difficulty = Difficulty.allCases[index % Difficulty.allCases.count]
            let group = campaign.filter { $0.difficulty == difficulty }
            return group[(index / Difficulty.allCases.count) % group.count]
        }
    }

    public var sampledWinRange: ClosedRange<Int> {
        switch difficulty {
        case .easy:
            switch largeBoxArea { case ...20: 24...32; case ...24: 20...27; default: 16...23 }
        case .medium:
            switch largeBoxArea { case ...35: 12...19; case ...40: 8...15; default: 4...11 }
        case .hard: 0...4
        }
    }

    var shapes: [(Int, Int)] {
        switch difficulty {
        case .easy: [(1, 2), (2, 1)]
        case .medium: [(1, 2), (2, 1), (1, 3), (3, 1), (2, 2)]
        case .hard: [(1, 2), (2, 1), (1, 3), (3, 1), (2, 2), (2, 3), (3, 2), (3, 3)]
        }
    }
}

public struct GenerationMetrics: Codable, Equatable, Sendable {
    public let levelID: Int
    public let profile: GenerationProfile
    public let attempts: Int
    public let solutionMoves: Int
    public let visitedStates: Int
    public let sampledWins: Int
    public let sampledPlays: Int
}

public struct GeneratedCampaign: Sendable {
    public let seed: UInt64
    public let levels: [LevelDefinition]
    public let solutions: [[Move]]
    public let losingBranches: [Int: [Move]]
    public let metrics: [GenerationMetrics]
}

public enum GenerationError: Error, Equatable {
    case invalidConfiguration
    case attemptsExhausted(levelID: Int)
}

public enum LevelGenerator {
    public static func generate(seed: UInt64, profiles: [GenerationProfile] = GenerationProfile.campaign,
                                attemptLimit: Int = 200, searchLimit: Int = 25_000,
                                order: GenerationOrder = .progressive,
                                existingLevels: [LevelDefinition] = []) throws -> GeneratedCampaign {
        guard !profiles.isEmpty, attemptLimit > 0, searchLimit > 0,
              existingLevels.enumerated().allSatisfy({ $0.element.id == $0.offset + 1 }),
              profiles.allSatisfy({ profile in
                  let minimum = profile.shapes.reduce(0) { $0 + $1.0 * $1.1 }
                  return (minimum...80).contains(profile.largeBoxArea) &&
                      (profile.difficulty != .easy || profile.largeBoxArea.isMultiple(of: 2))
              }) else { throw GenerationError.invalidConfiguration }
        var random = LevelRandom(seed: seed)
        var levels: [LevelDefinition] = []
        var solutions: [[Move]] = []
        var losingBranches: [Int: [Move]] = [:]
        var metrics: [GenerationMetrics] = []
        try validateUnique(existingLevels)
        var fingerprints = try Set(existingLevels.map(fingerprint))
        let orderedProfiles = order == .shuffled ? random.shuffle(profiles) : profiles
        for profile in orderedProfiles {
            let id = existingLevels.count + levels.count + 1
            var accepted = false
            for attempt in 1...attemptLimit {
                guard let boxes = makeBoxes(profile: profile, random: &random) else { continue }
                let level = try makeLevel(id: id, profile: profile, boxes: boxes, random: &random)
                let fingerprint = try fingerprint(level)
                guard !fingerprints.contains(fingerprint) else { continue }
                let engine = try PuzzleEngine(level: level)
                guard case .solved(let moves, let visited) = LevelSolver.solve(engine: engine, limit: searchLimit),
                      try replay(moves, engine: engine) == .won else { continue }
                let samples = try samplePlay(engine: engine, random: &random)
                guard profile.sampledWinRange.contains(samples.wins),
                      (order == .shuffled || samples.wins <= (metrics.last?.sampledWins ?? 32)),
                      profile.difficulty == .easy || samples.loss != nil else { continue }
                fingerprints.insert(fingerprint)
                levels.append(level)
                solutions.append(moves)
                if profile.difficulty != .easy { losingBranches[id] = samples.loss }
                metrics.append(.init(levelID: id, profile: profile, attempts: attempt, solutionMoves: moves.count,
                                     visitedStates: visited, sampledWins: samples.wins, sampledPlays: 32))
                accepted = true
                break
            }
            guard accepted else { throw GenerationError.attemptsExhausted(levelID: id) }
        }
        return GeneratedCampaign(seed: seed, levels: levels, solutions: solutions,
                                 losingBranches: losingBranches, metrics: metrics)
    }

    public static func validateUnique(_ levels: [LevelDefinition]) throws {
        let fingerprints = try levels.map(fingerprint)
        guard Set(fingerprints).count == levels.count else { throw GenerationError.invalidConfiguration }
    }

    private static func fingerprint(_ level: LevelDefinition) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(LevelDefinition(id: 1, difficulty: level.difficulty,
            bucketSlots: level.bucketSlots, width: level.width, height: level.height,
            boxes: level.boxes, paintQueues: level.paintQueues))
    }

    private static func makeBoxes(profile: GenerationProfile, random: inout LevelRandom) -> [BoxDefinition]? {
        var occupied = Set<Int>()
        var geometry: [(row: Int, column: Int, width: Int, height: Int)] = []
        var shapes = random.shuffle(profile.shapes).sorted { $0.0 * $0.1 > $1.0 * $1.1 }
        var area = shapes.reduce(0) { $0 + $1.0 * $1.1 }
        while area < profile.largeBoxArea {
            let available = profile.shapes.filter { $0.0 * $0.1 <= profile.largeBoxArea - area }
            guard !available.isEmpty else { return nil }
            let shape = available[random.index(available.count)]
            shapes.append(shape)
            area += shape.0 * shape.1
        }
        for (width, height) in shapes {
            let positions = random.shuffle(Array(0..<100))
            guard let cell = positions.first(where: { cell in
                let row = cell / 10, column = cell % 10
                return row + height <= 10 && column + width <= 10 &&
                    (row..<(row + height)).allSatisfy { r in
                        (column..<(column + width)).allSatisfy { !occupied.contains(r * 10 + $0) }
                    }
            }) else { return nil }
            let row = cell / 10, column = cell % 10
            geometry.append((row, column, width, height))
            for r in row..<(row + height) {
                for c in column..<(column + width) { occupied.insert(r * 10 + c) }
            }
        }
        for cell in 0..<100 where !occupied.contains(cell) { geometry.append((cell / 10, cell % 10, 1, 1)) }
        geometry.sort { ($0.row, $0.column) < ($1.row, $1.column) }
        let colors = random.shuffle(Array(PaintColor.allCases.prefix(profile.colorCount)))
        let assignments = random.shuffle(geometry.indices.map { colors[$0 % colors.count] })
        return geometry.enumerated().map { index, box in
            BoxDefinition(id: index + 1, row: box.row, column: box.column, width: box.width,
                          height: box.height, color: assignments[index])
        }
    }

    private static func makeLevel(id: Int, profile: GenerationProfile, boxes: [BoxDefinition],
                                  random: inout LevelRandom) throws -> LevelDefinition {
        func definition(_ queues: [[PaintTin]]) -> LevelDefinition {
            LevelDefinition(id: id, difficulty: profile.difficulty, bucketSlots: profile.bucketSlots,
                            width: 10, height: 10, boxes: boxes, paintQueues: queues)
        }
        var supply = Array(repeating: [PaintTin](), count: 4)
        for (index, color) in PaintColor.allCases.prefix(profile.colorCount).enumerated() {
            supply[index % 4].append(.init(color: color, paintUnits: boxes.filter { $0.color == color }.reduce(0) { $0 + $1.capacity }))
        }
        let engine = try PuzzleEngine(level: definition(supply))
        var state = GameState(level: engine.level)
        var queues = Array(repeating: [PaintTin](), count: 4)
        // Derive a paint schedule using engine targeting/gravity. Queue assignment
        // preserves this chronological witness while introducing alternative choices.
        while !engine.remainingBoxes(state: state).isEmpty {
            let available = PaintColor.allCases.prefix(profile.colorCount).filter { color in
                var probe = state
                probe.buckets[0] = .init(color: color, paintUnits: 1)
                return engine.canPour(slot: 0, state: probe)
            }
            let color = available[random.index(available.count)]
            let units = 2 + random.index(profile.difficulty == .easy ? 5 : 8)
            state.buckets[0] = .init(color: color, paintUnits: units)
            let next = try engine.pourResult(slot: 0, state: state).state
            let consumed = units - (next.buckets[0]?.paintUnits ?? 0)
            queues[random.index(4)].append(.init(color: color, paintUnits: consumed))
            state = next
            state.buckets = Array(repeating: nil, count: profile.bucketSlots)
        }
        return definition(queues)
    }

    private static func replay(_ moves: [Move], engine: PuzzleEngine) throws -> GameOutcome {
        var state = GameState(level: engine.level)
        for move in moves {
            state = try engine.applying(move, to: state)
            guard engine.validate(state: state) else { throw GenerationError.invalidConfiguration }
        }
        return engine.outcome(state: state)
    }

    private static func samplePlay(engine: PuzzleEngine, random: inout LevelRandom) throws -> (wins: Int, loss: [Move]?) {
        var wins = 0
        var loss: [Move]?
        for _ in 0..<32 {
            var state = GameState(level: engine.level)
            var path: [Move] = []
            while engine.outcome(state: state) == .playing {
                let moves = engine.legalMoves(state: state)
                let move = moves[random.index(moves.count)]
                path.append(move)
                state = try engine.applying(move, to: state)
            }
            if engine.outcome(state: state) == .won { wins += 1 }
            else if loss == nil { loss = path }
        }
        return (wins, loss)
    }
}

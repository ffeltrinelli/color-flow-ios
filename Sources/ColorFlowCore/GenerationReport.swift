import Foundation

public enum GenerationOrder: String, Codable, Sendable {
    case progressive, shuffled
}

public struct GenerationBatch: Codable, Equatable, Sendable {
    public let seed: UInt64
    public let firstLevelID: Int
    public let levelCount: Int
    public let order: GenerationOrder

    public init(seed: UInt64, firstLevelID: Int, levelCount: Int, order: GenerationOrder) {
        self.seed = seed
        self.firstLevelID = firstLevelID
        self.levelCount = levelCount
        self.order = order
    }
}

public struct GenerationReport: Codable, Sendable {
    public let formatVersion: Int
    public var batches: [GenerationBatch]
    public var metrics: [GenerationMetrics]

    public init(batches: [GenerationBatch], metrics: [GenerationMetrics]) {
        formatVersion = 2
        self.batches = batches
        self.metrics = metrics
    }

    private enum CodingKeys: String, CodingKey { case formatVersion, seed, batches, metrics }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .formatVersion)
        guard version == 1 || version == 2 else { throw GenerationError.invalidConfiguration }
        metrics = try values.decode([GenerationMetrics].self, forKey: .metrics)
        if version == 1 {
            batches = [GenerationBatch(seed: try values.decode(UInt64.self, forKey: .seed),
                firstLevelID: 1, levelCount: metrics.count, order: .progressive)]
        } else {
            batches = try values.decode([GenerationBatch].self, forKey: .batches)
        }
        formatVersion = 2
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(formatVersion, forKey: .formatVersion)
        try values.encode(batches, forKey: .batches)
        try values.encode(metrics, forKey: .metrics)
    }

    public func validate(levels: [LevelDefinition]) throws {
        guard !levels.isEmpty, levels.map(\.id) == Array(1...levels.count),
              metrics.map(\.levelID) == levels.map(\.id), !batches.isEmpty else {
            throw GenerationError.invalidConfiguration
        }
        var nextID = 1
        for batch in batches {
            guard batch.firstLevelID == nextID, batch.levelCount > 0,
                  batch.levelCount <= levels.count - nextID + 1 else { throw GenerationError.invalidConfiguration }
            let group = metrics[(nextID - 1)..<(nextID - 1 + batch.levelCount)]
            if batch.order == .progressive {
                guard zip(group, group.dropFirst()).allSatisfy({ $0.sampledWins >= $1.sampledWins }) else {
                    throw GenerationError.invalidConfiguration
                }
            }
            nextID += batch.levelCount
        }
        guard nextID == levels.count + 1 else { throw GenerationError.invalidConfiguration }
        try LevelGenerator.validateUnique(levels)
        for (level, metric) in zip(levels, metrics) {
            guard metric.profile.difficulty == level.difficulty,
                  metric.profile.bucketSlots == level.bucketSlots,
                  metric.profile.colorCount == Set(level.boxes.map(\.color)).count,
                  metric.profile.largeBoxArea == level.boxes.filter({ $0.capacity > 1 }).reduce(0, { $0 + $1.capacity }),
                  metric.profile.sampledWinRange.contains(metric.sampledWins), metric.sampledPlays == 32,
                  metric.attempts > 0, metric.visitedStates > 0, metric.solutionMoves > 0 else {
                throw GenerationError.invalidConfiguration
            }
        }
    }
}

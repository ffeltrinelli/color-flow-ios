import Foundation

public struct GameProgress: Codable, Equatable, Sendable {
    public var version = 4
    public var levelID: Int
    public var state: GameState
    public private(set) var statistics = GameStatistics()
    public private(set) var attempt = AttemptProgress()

    private enum CodingKeys: String, CodingKey {
        case version, levelID, state, statistics, attempt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        levelID = try values.decode(Int.self, forKey: .levelID)
        state = try values.decode(GameState.self, forKey: .state)
        statistics = try values.decodeIfPresent(GameStatistics.self, forKey: .statistics) ?? GameStatistics()
        attempt = try values.decodeIfPresent(AttemptProgress.self, forKey: .attempt) ?? AttemptProgress(timingEligible: false)
    }

    public mutating func addPlayTime(_ seconds: TimeInterval) {
        attempt.addTime(seconds)
    }

    public mutating func resolveAttempt(_ result: AttemptResult, difficulty: Difficulty) {
        guard attempt.result == nil else { return }
        attempt.resolve(result)
        statistics.record(result, difficulty: difficulty)
    }

    public mutating func finalizeWinningTime(difficulty: Difficulty) {
        guard attempt.result == .victory, !attempt.winningTimeFinalized else { return }
        if attempt.timingEligible {
            statistics.recordWinningTime(attempt.elapsedSeconds, difficulty: difficulty)
        }
        attempt.finalizeWinningTime()
    }

    public mutating func clearStatistics() {
        statistics = GameStatistics()
        if attempt.result == .victory { attempt.finalizeWinningTime() }
    }

    public mutating func startAttempt(level: LevelDefinition) {
        levelID = level.id
        state = GameState(level: level)
        attempt = AttemptProgress()
    }

    mutating func restoreAttempt(outcome: GameOutcome, difficulty: Difficulty) {
        // Legacy result screens have no historical event to count.
        if !attempt.timingEligible, attempt.result == nil {
            switch outcome {
            case .won: attempt.resolve(.victory)
            case .lost: attempt.resolve(.failure)
            case .playing: break
            }
        }
        finalizeWinningTime(difficulty: difficulty)
    }

    public init(level: LevelDefinition) {
        levelID = level.id
        state = GameState(level: level)
    }
}

public struct ProgressStore: Sendable {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load(levels: [LevelDefinition]) -> GameProgress {
        guard let data = try? Data(contentsOf: url),
              var progress = try? JSONDecoder().decode(GameProgress.self, from: data),
              progress.version == 4,
              let level = levels.first(where: { $0.id == progress.levelID })
        else { return GameProgress(level: levels[0]) }
        guard let engine = try? PuzzleEngine(level: level), engine.validate(state: progress.state) else {
            progress.startAttempt(level: level)
            return progress
        }
        progress.restoreAttempt(outcome: engine.outcome(state: progress.state), difficulty: level.difficulty)
        return progress
    }

    public func save(_ progress: GameProgress) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(progress).write(to: url, options: .atomic)
    }
}

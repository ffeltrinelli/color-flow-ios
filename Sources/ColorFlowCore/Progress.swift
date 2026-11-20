import Foundation

public struct GameProgress: Codable, Equatable, Sendable {
    public var version = 7
    public var levelID: Int
    public var state: GameState
    public var aphorismID: String?
    public private(set) var statistics = GameStatistics()
    public private(set) var attempt = AttemptProgress()

    private enum CodingKeys: String, CodingKey {
        case version, levelID, state, statistics, attempt, circularEntryLane, aphorismID
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        levelID = try values.decode(Int.self, forKey: .levelID)
        state = try values.decode(GameState.self, forKey: .state)
        aphorismID = try values.decodeIfPresent(String.self, forKey: .aphorismID)
        if let legacyLane = try values.decodeIfPresent(Int.self, forKey: .circularEntryLane) {
            state.alignedLane = legacyLane
        }
        statistics = try values.decodeIfPresent(GameStatistics.self, forKey: .statistics) ?? GameStatistics()
        attempt = try values.decodeIfPresent(AttemptProgress.self, forKey: .attempt) ?? AttemptProgress(timingEligible: false)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(levelID, forKey: .levelID)
        try values.encode(state, forKey: .state)
        try values.encodeIfPresent(aphorismID, forKey: .aphorismID)
        try values.encode(statistics, forKey: .statistics)
        try values.encode(attempt, forKey: .attempt)
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
        aphorismID = nil
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
              var progress = try? JSONDecoder().decode(GameProgress.self, from: data)
        else { return GameProgress(level: levels[0]) }
        if (4...6).contains(progress.version) {
            progress.version = 7
            progress.startAttempt(level: levels[0])
            return progress
        }
        guard progress.version == 7,
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

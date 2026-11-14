import Foundation

public enum AttemptResult: String, Codable, Sendable {
    case victory, failure, restart
}

public struct DifficultyStatistics: Codable, Equatable, Sendable {
    public private(set) var victories = 0
    public private(set) var failures = 0
    public private(set) var restarts = 0
    public private(set) var timedVictories = 0
    public private(set) var winningSeconds: TimeInterval = 0

    public init() {}

    public var victoryPercentage: Double? {
        let attempts = victories + failures + restarts
        return attempts == 0 ? nil : Double(victories) / Double(attempts) * 100
    }

    public var averageWinningSeconds: TimeInterval? {
        timedVictories == 0 ? nil : winningSeconds / Double(timedVictories)
    }

    mutating func record(_ result: AttemptResult) {
        switch result {
        case .victory: victories += 1
        case .failure: failures += 1
        case .restart: restarts += 1
        }
    }

    mutating func recordWinningTime(_ seconds: TimeInterval) {
        timedVictories += 1
        winningSeconds += seconds
    }
}

public struct GameStatistics: Codable, Equatable, Sendable {
    private var difficulties: [Difficulty: DifficultyStatistics] = [:]

    public init() {}

    public subscript(_ difficulty: Difficulty) -> DifficultyStatistics {
        difficulties[difficulty] ?? DifficultyStatistics()
    }

    mutating func record(_ result: AttemptResult, difficulty: Difficulty) {
        difficulties[difficulty, default: DifficultyStatistics()].record(result)
    }

    mutating func recordWinningTime(_ seconds: TimeInterval, difficulty: Difficulty) {
        difficulties[difficulty, default: DifficultyStatistics()].recordWinningTime(seconds)
    }
}

public struct AttemptProgress: Codable, Equatable, Sendable {
    public private(set) var elapsedSeconds: TimeInterval = 0
    public private(set) var result: AttemptResult?
    public private(set) var winningTimeFinalized = false
    public let timingEligible: Bool

    public init(timingEligible: Bool = true) {
        self.timingEligible = timingEligible
    }

    mutating func addTime(_ seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0, !winningTimeFinalized,
              result == nil || result == .victory else { return }
        elapsedSeconds += seconds
    }

    mutating func resolve(_ result: AttemptResult) { self.result = result }
    mutating func finalizeWinningTime() { winningTimeFinalized = true }
}

/// Timestamps are monotonic and session-local; only measured durations are saved.
public struct ActivePlayTimer: Sendable {
    private var startedAt: TimeInterval?

    public init() {}

    public mutating func setRunning(_ running: Bool, at timestamp: TimeInterval) -> TimeInterval {
        let elapsed = checkpoint(at: timestamp)
        startedAt = running ? timestamp : nil
        return elapsed
    }

    public mutating func checkpoint(at timestamp: TimeInterval) -> TimeInterval {
        guard let start = startedAt else { return 0 }
        startedAt = timestamp
        return max(0, timestamp - start)
    }
}

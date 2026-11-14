import Foundation

public struct GameProgress: Codable, Equatable, Sendable {
    public var version = 4
    public var levelID: Int
    public var state: GameState

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
              let progress = try? JSONDecoder().decode(GameProgress.self, from: data),
              progress.version == 4,
              let level = levels.first(where: { $0.id == progress.levelID })
        else { return GameProgress(level: levels[0]) }
        guard let engine = try? PuzzleEngine(level: level), engine.validate(state: progress.state)
        else { return GameProgress(level: level) }
        return progress
    }

    public func save(_ progress: GameProgress) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(progress).write(to: url, options: .atomic)
    }
}

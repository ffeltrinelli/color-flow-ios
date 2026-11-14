import Foundation
import ColorFlowCore

struct Options {
    var seed = UInt64.random(in: .min ... .max)
    var difficulty: Difficulty?
    var count: Int?
    var output = "GeneratedLevels"

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            guard index + 1 < arguments.count else { throw GenerationError.invalidConfiguration }
            let value = arguments[index + 1]
            switch flag {
            case "--seed":
                guard let parsed = UInt64(value) else { throw GenerationError.invalidConfiguration }
                seed = parsed
            case "--difficulty":
                guard let parsed = Difficulty(rawValue: value) else { throw GenerationError.invalidConfiguration }
                difficulty = parsed
            case "--count":
                guard let parsed = Int(value), (1...99).contains(parsed) else { throw GenerationError.invalidConfiguration }
                count = parsed
            case "--output": output = value
            default: throw GenerationError.invalidConfiguration
            }
            index += 2
        }
        guard difficulty != nil || count == nil else { throw GenerationError.invalidConfiguration }
    }

    var profiles: [GenerationProfile] {
        guard let difficulty else { return GenerationProfile.campaign }
        let group = GenerationProfile.campaign.filter { $0.difficulty == difficulty }
        return (0..<(count ?? 3)).map { group[min($0, group.count - 1)] }
    }
}

struct Metadata: Encodable {
    let formatVersion = 1
    let seed: UInt64
    let metrics: [GenerationMetrics]
}

func run() throws {
    if CommandLine.arguments.contains("--help") {
        print("Usage: swift run LevelGenerate [--seed UINT64] [--difficulty easy|medium|hard --count 3] [--output DIRECTORY]")
        print("Default: a nine-level campaign. Output must be a new directory; copy verified files into Resources explicitly.")
        return
    }
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    let destination = URL(fileURLWithPath: options.output).standardizedFileURL
    guard !FileManager.default.fileExists(atPath: destination.path) else {
        throw CocoaError(.fileWriteFileExists)
    }
    print("Generating with seed \(options.seed)")
    let campaign = try LevelGenerator.generate(seed: options.seed, profiles: options.profiles)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let files = [
        "levels.json": try encoder.encode(campaign.levels),
        "solutions.json": try encoder.encode(campaign.solutions),
        "losing-branch.json": try encoder.encode(campaign.losingBranches),
        "generation.json": try encoder.encode(Metadata(seed: campaign.seed, metrics: campaign.metrics))
    ]
    let parent = destination.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let staging = parent.appendingPathComponent(".level-generation-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: staging) }
    for (name, data) in files { try data.write(to: staging.appendingPathComponent(name), options: .atomic) }
    try FileManager.default.moveItem(at: staging, to: destination)
    for metric in campaign.metrics {
        print("Level \(metric.levelID) \(metric.profile.difficulty.rawValue): \(metric.profile.largeBoxArea)% large boxes, \(metric.solutionMoves) moves, \(metric.visitedStates) states, random-play wins \(metric.sampledWins)/\(metric.sampledPlays), attempts \(metric.attempts)")
    }
    print("Verified campaign saved to \(destination.path)")
}

do { try run() }
catch {
    FileHandle.standardError.write(Data("Generation failed: \(error). Use --help for usage.\n".utf8))
    exit(1)
}

import Foundation
import ColorFlowCore

struct Options {
    var seed = UInt64.random(in: .min ... .max)
    var prototype = false
    var difficulty: Difficulty?
    var count: Int?
    var output = "GeneratedLevels"
    var appendFrom: String?
    var reviseFrom: String?
    var order: GenerationOrder = .progressive

    init(arguments: [String]) throws {
        var index = 0
        while index < arguments.count {
            let flag = arguments[index]
            if flag == "--prototype" {
                prototype = true
                order = .authored
                index += 1
                continue
            }
            if flag == "--shuffle" {
                order = .shuffled
                index += 1
                continue
            }
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
            case "--append-from": appendFrom = value
            case "--revise-prototype-from": reviseFrom = value
            default: throw GenerationError.invalidConfiguration
            }
            index += 2
        }
        guard reviseFrom == nil || (!prototype && appendFrom == nil && count == nil && difficulty == nil && order == .progressive),
              !prototype || (difficulty == nil && count == nil && appendFrom == nil && order == .authored),
              difficulty != nil || count == nil || appendFrom != nil,
              appendFrom == nil || (count != nil && difficulty == nil && order == .shuffled) else { throw GenerationError.invalidConfiguration }
    }

    func generationProfiles() throws -> [GenerationProfile] {
        if prototype { return GenerationProfile.prototype }
        if appendFrom != nil, let count { return try GenerationProfile.balanced(count: count) }
        guard let difficulty else { return GenerationProfile.campaign }
        let group = GenerationProfile.campaign.filter { $0.difficulty == difficulty }
        return (0..<(count ?? 3)).map { group[min($0, group.count - 1)] }
    }
}

struct ExistingCampaign {
    var levels: [LevelDefinition] = []
    var solutions: [[Move]] = []
    var losingBranches: [Int: [Move]] = [:]
    var report = GenerationReport(batches: [], metrics: [])

    init(directory: String?, verifyPaths: Bool = true) throws {
        guard let directory else { return }
        let root = URL(fileURLWithPath: directory)
        func read<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            try JSONDecoder().decode(type, from: Data(contentsOf: root.appendingPathComponent(name)))
        }
        levels = try read("levels.json", as: [LevelDefinition].self)
        solutions = try read("solutions.json", as: [[Move]].self)
        losingBranches = try read("losing-branch.json", as: [Int: [Move]].self)
        report = try read("generation.json", as: GenerationReport.self)
        try report.validate(levels: levels)
        guard solutions.count == levels.count,
              Set(losingBranches.keys) == Set(levels.filter { $0.difficulty != .easy }.map(\.id)) else {
            throw GenerationError.invalidConfiguration
        }
        guard verifyPaths else { return }
        for (level, moves) in zip(levels, solutions) {
            let engine = try PuzzleEngine(level: level)
            func verify(_ moves: [Move], outcome: GameOutcome) throws {
                var state = GameState(level: level)
                for move in moves {
                    state = try engine.applying(move, to: state)
                    guard engine.validate(state: state) else { throw GenerationError.invalidConfiguration }
                }
                guard engine.outcome(state: state) == outcome else { throw GenerationError.invalidConfiguration }
            }
            try verify(moves, outcome: .won)
            guard report.metrics[level.id - 1].solutionMoves == moves.count else {
                throw GenerationError.invalidConfiguration
            }
            if let losing = losingBranches[level.id] { try verify(losing, outcome: .lost) }
        }
    }
}

func run() throws {
    if CommandLine.arguments.contains("--help") {
        print("Usage: swift run LevelGenerate [--prototype | --revise-prototype-from DIRECTORY] [--seed UINT64] [--difficulty easy|medium|hard --count 3] [--append-from DIRECTORY --count N --shuffle] [--output DIRECTORY]")
        print("Default: a nine-level campaign. Output must be a new directory; copy verified files into Resources explicitly.")
        return
    }
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    let destination = URL(fileURLWithPath: options.output).standardizedFileURL
    guard !FileManager.default.fileExists(atPath: destination.path) else {
        throw CocoaError(.fileWriteFileExists)
    }
    print("Generating with seed \(options.seed)")
    var existing = try ExistingCampaign(directory: options.reviseFrom ?? options.appendFrom,
                                         verifyPaths: options.reviseFrom == nil)
    let profiles = try options.generationProfiles()
    let campaign: GeneratedCampaign
    if options.reviseFrom != nil {
        campaign = try LevelGenerator.revisePrototype(seed: options.seed, levels: existing.levels,
            solutions: existing.solutions, losingBranches: existing.losingBranches, metrics: existing.report.metrics)
        let replaced = campaign.levels.filter { updated in
            !existing.levels.contains { old in
                old.boardKind == updated.boardKind && old.difficulty == updated.difficulty &&
                old.boxes == updated.boxes && old.paintQueues == updated.paintQueues
            }
        }.map(\.id)
        existing.report.revisions.append(.init(seed: options.seed,
            levelIDs: campaign.levels.filter { $0.boardKind == .circular }.map(\.id), replacedLevelIDs: replaced))
        existing.levels = []
        existing.solutions = []
        existing.losingBranches = [:]
        existing.report.metrics = []
        print("Replaced circular definitions: \(replaced)")
    } else {
        campaign = try LevelGenerator.generate(seed: options.seed, profiles: profiles,
                                               order: options.order, existingLevels: existing.levels)
    }
    if options.prototype {
        let features = try zip(campaign.levels, campaign.solutions).filter { $0.0.boardKind == .circular }
            .map { try PathFeatures(level: $0.0, moves: $0.1) }
        guard features.allSatisfy(\.hasFall), features.contains(where: \.hasPartiallyFilledFall),
              features.contains(where: \.hasGapPour) else { throw GenerationError.invalidConfiguration }
    }
    if options.reviseFrom == nil {
        existing.report.batches.append(GenerationBatch(seed: options.seed, firstLevelID: existing.levels.count + 1,
                                                        levelCount: campaign.levels.count, order: options.order))
    }
    existing.levels += campaign.levels
    existing.solutions += campaign.solutions
    existing.losingBranches.merge(campaign.losingBranches) { _, new in new }
    existing.report.metrics += campaign.metrics
    try existing.report.validate(levels: existing.levels)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let files = [
        "levels.json": try encoder.encode(existing.levels),
        "solutions.json": try encoder.encode(existing.solutions),
        "losing-branch.json": try encoder.encode(existing.losingBranches),
        "generation.json": try encoder.encode(existing.report)
    ]
    let parent = destination.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    let staging = parent.appendingPathComponent(".level-generation-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: staging) }
    for (name, data) in files { try data.write(to: staging.appendingPathComponent(name), options: .atomic) }
    try FileManager.default.moveItem(at: staging, to: destination)
    for metric in campaign.metrics {
        print("Level \(metric.levelID) \(metric.profile.difficulty.rawValue): \(metric.profile.largeBoxArea) large-block cells, \(metric.solutionMoves) moves, \(metric.visitedStates) states, random-play wins \(metric.sampledWins)/\(metric.sampledPlays), attempts \(metric.attempts)")
    }
    print("Verified campaign saved to \(destination.path)")
}

do { try run() }
catch {
    FileHandle.standardError.write(Data("Generation failed: \(error). Use --help for usage.\n".utf8))
    exit(1)
}

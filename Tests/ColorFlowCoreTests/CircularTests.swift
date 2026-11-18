import Foundation
import Testing
@testable import ColorFlowCore

struct CircularTests {
    @Test func prototypeAlternatesCircularThenSquareWithExplicitPairProfiles() {
        let profiles = GenerationProfile.prototype
        #expect(profiles.count == 10)
        #expect(profiles.map(\.boardKind) == [.circular, .square, .circular, .square, .circular,
                                              .square, .circular, .square, .circular, .square])
        #expect(profiles.map(\.difficulty) == [.easy, .easy, .easy, .easy, .medium, .medium,
                                               .medium, .medium, .hard, .hard])
        #expect(profiles.map(\.largeBoxArea) == [10, 20, 12, 24, 18, 35, 20, 40, 25, 50])
        #expect(profiles.map(\.height) == [5, 10, 5, 10, 5, 10, 5, 10, 5, 10])
    }

    @Test func circularGenerationIsReproducibleAndRetainsItsConfiguration() throws {
        let profile = GenerationProfile(difficulty: .easy, largeBoxArea: 12, boardKind: .circular,
                                        height: 5, samplingArea: 24)
        let first = try LevelGenerator.generate(seed: 5, profiles: [profile], order: .authored)
        let repeated = try LevelGenerator.generate(seed: 5, profiles: [profile], order: .authored)
        #expect(first.levels == repeated.levels)
        #expect(first.solutions == repeated.solutions)
        #expect(first.metrics == repeated.metrics)
        let level = first.levels[0]
        #expect(level.width == 10 && level.height == 5 && level.boardKind == .circular)
        #expect(level.boxes.filter { $0.capacity > 1 }.reduce(0) { $0 + $1.capacity } == 12)
        #expect(try PathFeatures(level: level, moves: first.solutions[0]).hasFall)
        var report = GenerationReport(batches: [.init(seed: 5, firstLevelID: 1, levelCount: 1, order: .authored)],
                                      metrics: first.metrics)
        report.revisions = [.init(seed: 5, levelIDs: [1], replacedLevelIDs: [])]
        try report.validate(levels: first.levels)
        let decoded = try JSONDecoder().decode(GenerationReport.self, from: JSONEncoder().encode(report))
        #expect(decoded.metrics == report.metrics)
        #expect(decoded.revisions == report.revisions)
        report.revisions = [.init(seed: 5, levelIDs: [2], replacedLevelIDs: [])]
        #expect(throws: GenerationError.invalidConfiguration) { try report.validate(levels: first.levels) }
    }

    @Test func legacyLevelsDefaultToSquare() throws {
        let level = try TestCatalog.levels()[0]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(level)) as! [String: Any]
        json.removeValue(forKey: "boardKind")
        let decoded = try JSONDecoder().decode(LevelDefinition.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded == level)
        #expect(decoded.boardKind == .square)
    }

    @Test func inwardGeometryPreservesAngularSpanThicknessAndFillArea() {
        let geometry = CircularGeometry(lanes: 10, bands: 5, radius: 170)
        let inner = geometry.innerRadius(row: 0, height: 2)
        let outer = geometry.outerRadius(row: 0)
        let fallenInner = geometry.innerRadius(row: 1, height: 2)
        let fallenOuter = geometry.outerRadius(row: 1)
        #expect(geometry.hubRadius == 42.5)
        #expect(abs((outer - inner) - (fallenOuter - fallenInner)) < 0.0001)
        #expect(fallenOuter < outer && fallenInner < inner)
        for fraction in [0.0, 0.25, 0.5, 1.0] {
            for (inside, outside) in [(inner, outer), (fallenInner, fallenOuter)] {
                let fill = geometry.fillRadius(inner: inside, outer: outside, fraction: fraction)
                let areaRatio = (fill * fill - inside * inside) / (outside * outside - inside * inside)
                #expect(abs(areaRatio - fraction) < 0.0001)
            }
        }
        #expect(abs(geometry.innerRadius(row: 4, height: 1) - geometry.hubRadius) < 0.0001)
    }

    @Test func alignmentAlwaysTurnsCounterclockwiseAndUsesTheEntryLane() {
        let geometry = CircularGeometry(lanes: 10, bands: 5, radius: 1)
        var rotation = 0.0
        for lane in [8, 1, 1, 9, 0, 5, 2] {
            let next = geometry.rotation(from: rotation, to: lane)
            #expect(next <= rotation)
            #expect(rotation - next < 360)
            #expect(abs((next + Double(lane) * 36).truncatingRemainder(dividingBy: 360)) < 0.0001)
            rotation = next
        }
    }

    @Test(arguments: [4, 5]) func legacyCampaignRetainsStatisticsButStartsFresh(version: Int) throws {
        let levels = try TestCatalog.levels()
        var old = GameProgress(level: levels[2])
        old.version = version
        old.addPlayTime(12)
        old.resolveAttempt(.victory, difficulty: .hard)
        old.finalizeWinningTime(difficulty: .hard)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try store.save(old)
        let migrated = store.load(levels: levels)
        #expect(migrated.version == 6)
        #expect(migrated.levelID == 1)
        #expect(migrated.state == GameState(level: levels[0]))
        #expect(migrated.statistics == old.statistics)
        #expect(migrated.attempt.result == nil)
        #expect(migrated.attempt.elapsedSeconds == 0)
        #expect(migrated.state.alignedLane == 0)
    }

    @Test func circularSettledStateAndOrientationRestoreAfterInterruptedPresentation() throws {
        let profile = GenerationProfile(difficulty: .easy, largeBoxArea: 10, boardKind: .circular,
                                        height: 5, samplingArea: 20)
        let campaign = try LevelGenerator.generate(seed: 2026111701, profiles: [profile], order: .authored)
        let level = campaign.levels[0]
        let engine = try PuzzleEngine(level: level)
        var progress = GameProgress(level: level)
        for move in campaign.solutions[0] {
            if case .pour(let slot) = move {
                let result = try engine.pourResult(slot: slot, state: progress.state)
                progress.state = result.state
                break
            }
            progress.state = try engine.applying(move, to: progress.state)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProgressStore(url: directory.appendingPathComponent("save.json"))
        try store.save(progress)
        #expect(store.load(levels: [level]) == progress)
        progress.state.alignedLane = 10
        try store.save(progress)
        #expect(store.load(levels: [level]) == GameProgress(level: level))
    }
}

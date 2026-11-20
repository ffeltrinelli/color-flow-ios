import Foundation
import Testing
@testable import ColorFlowCore

struct GenerationReportTests {
    @Test func mixedCampaignShufflesMatchingPairsReproducibly() {
        let profiles = GenerationProfile.mixedCampaign(seed: 17)
        #expect(profiles == GenerationProfile.mixedCampaign(seed: 17))
        #expect(profiles != GenerationProfile.mixedCampaign(seed: 18))
        #expect(profiles.count == 50)
        #expect(profiles.filter { $0.difficulty == .easy }.count == 20)
        #expect(profiles.filter { $0.difficulty == .medium }.count == 20)
        #expect(profiles.filter { $0.difficulty == .hard }.count == 10)
        for index in stride(from: 0, to: profiles.count, by: 2) {
            let circular = profiles[index]
            let square = profiles[index + 1]
            #expect(circular.boardKind == .circular)
            #expect(square.boardKind == .square)
            #expect(circular.difficulty == square.difficulty)
            #expect(circular.samplingArea == square.samplingArea)
        }
    }

    @Test func reportAcceptsShuffledDifficultyAndValidatesBatchCoverage() throws {
        let profile = GenerationProfile(difficulty: .easy, largeBoxArea: 20)
        let campaign = try LevelGenerator.generate(seed: 8, profiles: [profile, profile], searchLimit: 500,
                                                   order: .shuffled)
        let metrics = campaign.metrics.enumerated().map { index, metric in
            GenerationMetrics(levelID: metric.levelID, profile: metric.profile, attempts: metric.attempts,
                solutionMoves: metric.solutionMoves, visitedStates: metric.visitedStates,
                sampledWins: index == 0 ? 24 : 32, sampledPlays: 32)
        }
        let batch = GenerationBatch(seed: 8, firstLevelID: 1, levelCount: 2, order: .shuffled)
        let report = GenerationReport(batches: [batch], metrics: metrics)
        try report.validate(levels: campaign.levels)
        let decoded = try JSONDecoder().decode(GenerationReport.self, from: JSONEncoder().encode(report))
        #expect(decoded.batches == report.batches)
        #expect(decoded.metrics == report.metrics)
        let progressive = GenerationReport(batches: [GenerationBatch(seed: 8, firstLevelID: 1,
            levelCount: 2, order: .progressive)], metrics: metrics)
        #expect(throws: GenerationError.invalidConfiguration) { try progressive.validate(levels: campaign.levels) }
        let gap = GenerationReport(batches: [GenerationBatch(seed: 8, firstLevelID: 2,
            levelCount: 2, order: .shuffled)], metrics: metrics)
        #expect(throws: GenerationError.invalidConfiguration) { try gap.validate(levels: campaign.levels) }
        let incomplete = GenerationReport(batches: [GenerationBatch(seed: 8, firstLevelID: 1,
            levelCount: 1, order: .shuffled)], metrics: metrics)
        #expect(throws: GenerationError.invalidConfiguration) { try incomplete.validate(levels: campaign.levels) }
    }

    @Test func legacyReportPreservesSeedAndMetrics() throws {
        let data = Data(#"{"formatVersion":1,"seed":20261114,"metrics":[]}"#.utf8)
        let report = try JSONDecoder().decode(GenerationReport.self, from: data)
        #expect(report.formatVersion == 2)
        #expect(report.batches == [GenerationBatch(seed: 20261114, firstLevelID: 1,
                                                   levelCount: 0, order: .progressive)])
        #expect(report.metrics.isEmpty)
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(GenerationReport.self, from: Data(#"{"formatVersion":99,"metrics":[]}"#.utf8))
        }
    }
}

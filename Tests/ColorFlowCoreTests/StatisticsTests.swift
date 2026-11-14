import Foundation
import Testing
@testable import ColorFlowCore

struct StatisticsTests {
    private func progress() throws -> GameProgress {
        GameProgress(level: try TestCatalog.levels()[0])
    }

    @Test func emptyStatisticsHaveNoPercentageOrAverage() throws {
        let saved = try progress()
        for difficulty in Difficulty.allCases {
            #expect(saved.statistics[difficulty].victoryPercentage == nil)
            #expect(saved.statistics[difficulty].averageWinningSeconds == nil)
        }
    }

    @Test func resultsCountOnceAndDifficultiesRemainIndependent() throws {
        var saved = try progress()
        let level = try TestCatalog.levels()[0]
        saved.addPlayTime(40)
        saved.resolveAttempt(.victory, difficulty: .easy)
        saved.resolveAttempt(.failure, difficulty: .easy)
        saved.finalizeWinningTime(difficulty: .easy)
        saved.finalizeWinningTime(difficulty: .easy)
        saved.startAttempt(level: level)
        saved.resolveAttempt(.failure, difficulty: .easy)
        saved.resolveAttempt(.restart, difficulty: .easy)
        saved.startAttempt(level: level)
        saved.resolveAttempt(.restart, difficulty: .easy)
        saved.startAttempt(level: level)
        saved.addPlayTime(80)
        saved.resolveAttempt(.victory, difficulty: .easy)
        saved.finalizeWinningTime(difficulty: .easy)
        let stats = saved.statistics[.easy]
        #expect(stats.victories == 2)
        #expect(stats.failures == 1)
        #expect(stats.restarts == 1)
        #expect(stats.victoryPercentage == 50)
        #expect(stats.averageWinningSeconds == 60)
        #expect(saved.statistics[.hard] == DifficultyStatistics())
    }

    @Test func timerCountsAnimationsButExcludesPausedIntervals() throws {
        var timer = ActivePlayTimer()
        var saved = try progress()
        #expect(timer.checkpoint(at: 10) == 0)
        saved.addPlayTime(timer.setRunning(true, at: 10))
        saved.addPlayTime(timer.checkpoint(at: 30))
        saved.resolveAttempt(.victory, difficulty: .easy)
        // The settled result is recorded before the last animation completes.
        #expect(saved.statistics[.easy].victories == 1)
        #expect(saved.statistics[.easy].averageWinningSeconds == nil)
        saved.addPlayTime(timer.setRunning(false, at: 35))
        saved.addPlayTime(timer.checkpoint(at: 100))
        saved.addPlayTime(timer.setRunning(true, at: 110))
        saved.addPlayTime(timer.setRunning(false, at: 115))
        saved.finalizeWinningTime(difficulty: .easy)
        saved.addPlayTime(100)
        #expect(saved.statistics[.easy].averageWinningSeconds == 30)
        #expect(saved.attempt.elapsedSeconds == 30)
    }

    @Test func failureAndRestartTimeDoNotEnterWinningAverage() throws {
        var saved = try progress()
        let level = try TestCatalog.levels()[0]
        saved.addPlayTime(500)
        saved.resolveAttempt(.failure, difficulty: .easy)
        saved.addPlayTime(20)
        saved.finalizeWinningTime(difficulty: .easy)
        #expect(saved.attempt.elapsedSeconds == 500)
        saved.startAttempt(level: level)
        saved.addPlayTime(200)
        saved.resolveAttempt(.restart, difficulty: .easy)
        saved.startAttempt(level: level)
        saved.addPlayTime(10)
        saved.resolveAttempt(.victory, difficulty: .easy)
        saved.finalizeWinningTime(difficulty: .easy)
        #expect(saved.statistics[.easy].averageWinningSeconds == 10)
    }

    private func legacyData(state: GameState, levelID: Int) throws -> Data {
        struct LegacyProgress: Encodable {
            let version = 4
            let levelID: Int
            let state: GameState
        }
        return try JSONEncoder().encode(LegacyProgress(levelID: levelID, state: state))
    }

    private func withStore(_ body: (ProgressStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(ProgressStore(url: directory.appendingPathComponent("progress.json")))
    }

    @Test func legacyPlayingSaveKeepsBoardAndCountsOnlyItsFutureResult() throws {
        let level = try TestCatalog.levels()[0]
        let engine = try PuzzleEngine(level: level)
        let state = try engine.applying(.take(queue: 0), to: GameState(level: level))
        try withStore { store in
            try legacyData(state: state, levelID: level.id).write(to: store.url)
            var saved = store.load(levels: [level])
            #expect(saved.version == 4)
            #expect(saved.state == state)
            #expect(!saved.attempt.timingEligible)
            saved.addPlayTime(50)
            saved.resolveAttempt(.victory, difficulty: .easy)
            saved.finalizeWinningTime(difficulty: .easy)
            #expect(saved.statistics[.easy].victories == 1)
            #expect(saved.statistics[.easy].averageWinningSeconds == nil)
            saved.startAttempt(level: level)
            #expect(saved.attempt.timingEligible)
            saved.addPlayTime(30)
            saved.resolveAttempt(.victory, difficulty: .easy)
            saved.finalizeWinningTime(difficulty: .easy)
            #expect(saved.statistics[.easy].victories == 2)
            #expect(saved.statistics[.easy].averageWinningSeconds == 30)
        }
    }

    @Test func legacyTerminalSaveDoesNotInventAResultOrCountRetryTwice() throws {
        let levels = try TestCatalog.levels()
        let solutions = try TestCatalog.solutions()
        let losing = try TestCatalog.losingBranches()
        try withStore { store in
            for level in levels {
                let engine = try PuzzleEngine(level: level)
                for moves in [solutions[level.id - 1], losing[level.id]].compactMap({ $0 }) {
                    let state = try moves.reduce(GameState(level: level)) { try engine.applying($1, to: $0) }
                    try legacyData(state: state, levelID: level.id).write(to: store.url)
                    var saved = store.load(levels: levels)
                    #expect(saved.state == state)
                    #expect(saved.attempt.result != nil)
                    saved.resolveAttempt(.restart, difficulty: level.difficulty)
                    #expect(saved.statistics[level.difficulty] == DifficultyStatistics())
                }
            }
        }
    }

    @Test func interruptedFinalAnimationRestoresCheckpointWithoutRecountingOrTimeAway() throws {
        let level = try TestCatalog.levels()[0]
        let engine = try PuzzleEngine(level: level)
        var saved = GameProgress(level: level)
        saved.state = try TestCatalog.solutions()[0].reduce(saved.state) { try engine.applying($1, to: $0) }
        saved.addPlayTime(23)
        saved.resolveAttempt(.victory, difficulty: level.difficulty)
        try withStore { store in
            try store.save(saved)
            let restored = store.load(levels: [level])
            #expect(restored.statistics[level.difficulty].victories == 1)
            #expect(restored.statistics[level.difficulty].averageWinningSeconds == 23)
            try store.save(restored)
            #expect(store.load(levels: [level]) == restored)
        }
    }

    @Test func clearingStatisticsPreservesTheCurrentBoardAndActiveAttempt() throws {
        let level = try TestCatalog.levels()[0]
        var saved = GameProgress(level: level)
        saved.resolveAttempt(.restart, difficulty: level.difficulty)
        saved.startAttempt(level: level)
        saved.state = try PuzzleEngine(level: level).applying(.take(queue: 0), to: saved.state)
        saved.addPlayTime(12)
        let state = saved.state
        let attempt = saved.attempt
        saved.clearStatistics()
        #expect(saved.statistics[level.difficulty] == DifficultyStatistics())
        #expect(saved.state == state)
        #expect(saved.levelID == level.id)
        #expect(saved.attempt == attempt)
        saved.resolveAttempt(.victory, difficulty: level.difficulty)
        saved.finalizeWinningTime(difficulty: level.difficulty)
        #expect(saved.statistics[level.difficulty].victories == 1)
        #expect(saved.statistics[level.difficulty].averageWinningSeconds == 12)
        try withStore { store in
            // Save a genuine playing state with cleared totals for exact restoration.
            saved.startAttempt(level: level)
            saved.clearStatistics()
            try store.save(saved)
            #expect(store.load(levels: [level]) == saved)
        }
    }

    @Test func clearingAPendingVictoryDoesNotResurrectItsTimeOrResult() throws {
        var saved = try progress()
        saved.addPlayTime(60)
        saved.resolveAttempt(.victory, difficulty: .easy)
        saved.clearStatistics()
        saved.finalizeWinningTime(difficulty: .easy)
        saved.resolveAttempt(.victory, difficulty: .easy)
        #expect(saved.statistics[.easy] == DifficultyStatistics())
    }

    @Test func invalidBoardRecoveryPreservesRecordedStatistics() throws {
        let level = try TestCatalog.levels()[0]
        var saved = GameProgress(level: level)
        saved.resolveAttempt(.restart, difficulty: level.difficulty)
        saved.startAttempt(level: level)
        saved.state.boxes = []
        try withStore { store in
            try store.save(saved)
            let restored = store.load(levels: [level])
            #expect(restored.state == GameState(level: level))
            #expect(restored.statistics[level.difficulty].restarts == 1)
            #expect(restored.attempt == AttemptProgress())
        }
    }

    @Test func newAttemptRetainsLifetimeTotalsAndRoundTrips() throws {
        let level = try TestCatalog.levels()[0]
        var saved = GameProgress(level: level)
        saved.resolveAttempt(.restart, difficulty: level.difficulty)
        saved.startAttempt(level: level)
        saved.addPlayTime(12)
        try withStore { store in
            try store.save(saved)
            #expect(store.load(levels: [level]) == saved)
            #expect(saved.statistics[level.difficulty].restarts == 1)
        }
    }
}

import Foundation
import Testing
@testable import ColorFlowCore

struct GenerationAndHintTests {
    private let profile = GenerationProfile(difficulty: .easy, largeBoxArea: 20)

    @Test func seedReproducesBoardsQueuesPathsAndMetrics() throws {
        let first = try LevelGenerator.generate(seed: 5, profiles: [profile], searchLimit: 500)
        let repeated = try LevelGenerator.generate(seed: 5, profiles: [profile], searchLimit: 500)
        let different = try LevelGenerator.generate(seed: 9, profiles: [profile], searchLimit: 500)
        #expect(first.levels == repeated.levels)
        #expect(first.solutions == repeated.solutions)
        #expect(first.metrics == repeated.metrics)
        #expect(first.levels != different.levels)
    }

    @Test func repeatedProfilesProduceDistinctBoardsAndVerifiedPaths() throws {
        let campaign = try LevelGenerator.generate(seed: 8, profiles: [profile, profile], searchLimit: 500)
        #expect(campaign.levels[0].boxes != campaign.levels[1].boxes)
        for (level, moves) in zip(campaign.levels, campaign.solutions) {
            try LevelValidator.validate(level)
            #expect(level.boxes.filter { $0.capacity > 1 }.reduce(0) { $0 + $1.capacity } == 20)
            let engine = try PuzzleEngine(level: level)
            let end = try moves.reduce(GameState(level: level)) { try engine.applying($1, to: $0) }
            #expect(engine.outcome(state: end) == .won)
        }
    }

    @Test func limitsAndImpossibleProfilesFailExplicitly() {
        #expect(throws: GenerationError.attemptsExhausted(levelID: 1)) {
            try LevelGenerator.generate(seed: 1, profiles: [profile], attemptLimit: 1, searchLimit: 1)
        }
        #expect(throws: GenerationError.invalidConfiguration) {
            try LevelGenerator.generate(seed: 1, profiles: [.init(difficulty: .easy, largeBoxArea: 25)])
        }
        #expect(throws: GenerationError.invalidConfiguration) {
            try LevelGenerator.generate(seed: 1, profiles: [], attemptLimit: 0)
        }
    }

    @Test func defaultProfilesIntroduceHardConstraintsGradually() {
        let profiles = GenerationProfile.campaign
        #expect(zip(profiles, profiles.dropFirst()).allSatisfy { $0.largeBoxArea <= $1.largeBoxArea })
        #expect(profiles.filter { $0.difficulty != .hard }.allSatisfy { $0.bucketSlots == 3 && $0.colorCount == 4 })
        #expect(profiles.filter { $0.difficulty == .hard }.allSatisfy { $0.bucketSlots == 2 && $0.colorCount == 5 })
    }

    @Test func hintsReplayTheirActualTargetsWithoutMutatingState() throws {
        let levels = try TestCatalog.levels()
        let solutions = try TestCatalog.solutions()
        for level in levels {
            let engine = try PuzzleEngine(level: level)
            let state = GameState(level: level)
            let result = LevelHints.suggest(engine: engine, state: state, knownSolution: solutions[level.id - 1])
            #expect(result == LevelHints.suggest(engine: engine, state: state, knownSolution: solutions[level.id - 1]))
            guard case .steps(let steps) = result else { Issue.record("Expected hints"); continue }
            #expect(steps.count == 5)
            var preview = state
            for step in steps {
                #expect(step.controls[step.targetIndex] == step.target)
                switch step.move {
                case .take(let queue): #expect(engine.frontTin(queue: queue, state: preview) == step.target)
                case .pour(let slot): #expect(preview.buckets[slot] == step.target)
                }
                preview = try engine.applying(step.move, to: preview)
            }
            #expect(state == GameState(level: level))
            guard case .solved = LevelSolver.solve(engine: engine, from: preview) else {
                Issue.record("Hints must remain on a winning path"); continue
            }
        }
    }

    @Test func hintsUseCurrentStateAndReturnOnlyRemainingMoves() throws {
        let level = try TestCatalog.levels()[0]
        let engine = try PuzzleEngine(level: level)
        let path = try TestCatalog.solutions()[0]
        let nearEnd = try path.dropLast(2).reduce(GameState(level: level)) { try engine.applying($1, to: $0) }
        guard case .steps(let steps) = LevelHints.suggest(engine: engine, state: nearEnd) else {
            Issue.record("Expected the last moves"); return
        }
        #expect(steps.count <= 2)
        let won = try steps.reduce(nearEnd) { try engine.applying($1.move, to: $0) }
        #expect(engine.outcome(state: won) == .won)
        #expect(LevelHints.suggest(engine: engine, state: won) == .steps([]))
    }

    @Test func verifiedSolutionsAccelerateHintsAndRejectInvalidWitnesses() throws {
        let level = try TestCatalog.levels()[0]
        let engine = try PuzzleEngine(level: level)
        let solution = try TestCatalog.solutions()[0]
        let initial = GameState(level: level)
        guard case .steps(let first) = LevelHints.suggest(engine: engine, state: initial, limit: 0, knownSolution: solution) else {
            Issue.record("A verified continuation needs no new search"); return
        }
        #expect(first.map(\.move) == Array(solution.prefix(5)))
        let changed = try solution.prefix(3).reduce(initial) { try engine.applying($1, to: $0) }
        guard case .steps(let next) = LevelHints.suggest(engine: engine, state: changed, limit: 0, knownSolution: solution) else {
            Issue.record("Expected a matching continuation"); return
        }
        #expect(next.map(\.move) == Array(solution.dropFirst(3).prefix(5)))
        #expect(LevelHints.suggest(engine: engine, state: initial, limit: 0, knownSolution: []) == .inconclusive)
        let alternative = try engine.applying(.take(queue: 2), to: initial)
        #expect(LevelHints.suggest(engine: engine, state: alternative, limit: 0, knownSolution: solution) == .inconclusive)
    }

    @Test func hintDeadlineStopsSearchWithoutClaimingADeadEnd() throws {
        let level = try TestCatalog.levels()[0]
        let engine = try PuzzleEngine(level: level)
        let state = GameState(level: level)
        #expect(LevelHints.suggest(engine: engine, state: state, limit: .max,
                                   deadline: ContinuousClock().now) == .inconclusive)
        guard case .steps = LevelHints.suggest(engine: engine, state: state, limit: .max,
                                               knownSolution: try TestCatalog.solutions()[0],
                                               deadline: ContinuousClock().now.advanced(by: .seconds(10))) else {
            Issue.record("A verified path should finish before its deadline"); return
        }
    }

    @Test func cancellationStopsAnInProgressSearch() throws {
        let level = try TestCatalog.levels()[0]
        let engine = try PuzzleEngine(level: level)
        let probe = CancellationProbe()
        let result = LevelHints.suggest(engine: engine, state: GameState(level: level), isCancelled: { probe.cancelAfterTenVisits() })
        #expect(result == .inconclusive)
    }

    @Test func hintDeadEndAndSearchLimitsAreDifferent() throws {
        let level = try TestCatalog.levels()[1]
        let engine = try PuzzleEngine(level: level)
        let branch = try #require(TestCatalog.losingBranches()[level.id])
        let lost = try branch.reduce(GameState(level: level)) { try engine.applying($1, to: $0) }
        #expect(LevelHints.suggest(engine: engine, state: lost) == .unwinnable)
        #expect(LevelHints.suggest(engine: engine, state: GameState(level: level), limit: 0) == .inconclusive)
        #expect(LevelHints.suggest(engine: engine, state: GameState(level: level), isCancelled: { true }) == .inconclusive)
    }
}

private final class CancellationProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var visits = 0

    func cancelAfterTenVisits() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        visits += 1
        return visits >= 10
    }
}

import ColorFlowCore
import XCTest

@MainActor
final class ColorFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment = [
            "COLOR_FLOW_UI_TEST": "1", "COLOR_FLOW_TEST_SESSION": UUID().uuidString,
            "COLOR_FLOW_RESET": "1", "COLOR_FLOW_FAST_ANIMATION": "1"
        ]
    }

    private func launch(level: Int = 1) {
        app.launchEnvironment["COLOR_FLOW_TEST_LEVEL"] = String(level)
        app.launch()
        let loaded = NSPredicate { [self] _, _ in
            app.staticTexts["level-number"].exists || app.buttons["advance"].exists || app.buttons["retry"].exists
        }
        expectation(for: loaded, evaluatedWith: app)
        waitForExpectations(timeout: 15)
    }

    private func waitUntilReady() {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(20))
        repeat {
            if app.otherElements["board"].value as? String == "Ready" ||
                app.buttons["advance"].exists || app.buttons["retry"].exists { return }
            Thread.sleep(forTimeInterval: 0.05)
        } while clock.now < deadline
        XCTFail("The board did not settle or show a result within 20 seconds")
    }

    @discardableResult
    private func play(_ moves: [Move], level: LevelDefinition) throws -> GameState {
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        for move in moves {
            let button: XCUIElement
            switch move {
            case .take(let queue): button = app.buttons["queue-\(queue)"]
            case .pour(let slot): button = app.buttons["slot-\(slot)"]
            }
            XCTAssertTrue(button.isEnabled)
            button.tap()
            if case .pour = move { waitUntilReady() }
            state = try engine.applying(move, to: state)
        }
        if engine.outcome(state: state) == .playing { assertBoxes(level: level, state: state) }
        return state
    }

    private func assertBoxes(level: LevelDefinition, state: GameState) {
        let engine = try! PuzzleEngine(level: level)
        if level.boardKind == .circular {
            XCTAssertEqual(app.otherElements["board"].label,
                           "Circular puzzle board, lane \(state.alignedLane + 1) beneath the pour pointer")
        }
        for box in level.boxes {
            let element = app.descendants(matching: .any).matching(identifier: "box-\(box.id)").firstMatch
            if engine.isRemoved(box, state: state) {
                XCTAssertFalse(element.exists)
            } else {
                let current = engine.boxState(id: box.id, state: state)
                let position = level.boardKind == .circular
                    ? "band \(current.row + 1), lane \(box.column + 1), \(box.width) lanes by \(box.height) bands"
                    : "row \(current.row + 1), column \(box.column + 1), \(box.width) by \(box.height)"
                let expected = "\(box.color.name), \(position), \(current.filledUnits) of \(box.capacity) paint units"
                XCTAssertEqual(element.label, expected)
            }
        }
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var firstTin: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'queue-'")).firstMatch
    }

    private struct PathCheckpoint {
        let level: LevelDefinition
        let path: [Move]
        let index: Int
        let before: GameState

        var move: Move { path[index] }
        var prefix: [Move] { Array(path.prefix(index)) }
        var throughMove: [Move] { Array(path.prefix(index + 1)) }
    }

    private func firstLevel(kind: BoardKind, difficulty: Difficulty) throws -> LevelDefinition {
        try XCTUnwrap(LevelCatalog.load().first { $0.boardKind == kind && $0.difficulty == difficulty })
    }

    private func checkpoint(kind: BoardKind, difficulty: Difficulty, outcome: GameOutcome = .won,
                            matching: (PuzzleEngine, GameState, Move, GameState) throws -> Bool) throws -> PathCheckpoint {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        let losses = try LevelCatalog.losingBranches()
        for level in levels where level.boardKind == kind && level.difficulty == difficulty {
            let path = outcome == .lost ? (losses[level.id] ?? []) : solutions[level.id - 1]
            let engine = try PuzzleEngine(level: level)
            var state = GameState(level: level)
            for (index, move) in path.enumerated() {
                let next = try engine.applying(move, to: state)
                if try matching(engine, state, move, next) {
                    return PathCheckpoint(level: level, path: path, index: index, before: state)
                }
                state = next
            }
        }
        throw NSError(domain: "Missing \(difficulty.rawValue) \(kind.rawValue) playback checkpoint", code: 1)
    }

    private func pourWithFall(engine: PuzzleEngine, state: GameState, move: Move) throws -> Bool {
        guard case .pour(let slot) = move else { return false }
        return try engine.pourResult(slot: slot, state: state).events.contains { event in
            if case .fall = event { return true }
            return false
        }
    }

    @discardableResult
    private func assertUnlockedQuote() throws -> Aphorism {
        let text = app.staticTexts["unlocked-aphorism"]
        XCTAssertTrue(text.exists)
        let aphorism = try XCTUnwrap(AphorismCatalog.load().entries.first { $0.text == text.label })
        XCTAssertTrue(app.staticTexts[aphorism.author].exists)
        XCTAssertTrue(app.staticTexts[aphorism.work].exists)
        XCTAssertTrue(app.buttons["advance"].isHittable)
        return aphorism
    }

    func testSplashOnLaunchAndReturnPreservesGame() {
        app.launch()
        let title = app.images["splash-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Color Flow")
        XCTAssertEqual(app.staticTexts["splash-subtitle"].label, "for Luisa")
        attachScreenshot("Splash — Color Flow for Luisa")
        XCTAssertTrue(app.staticTexts["level-number"].waitForExistence(timeout: 5))
        firstTin.tap()
        let bucket = app.buttons["slot-0"].value as? String

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["level-number"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["slot-0"].value as? String, bucket)
    }

    func testLevelCompletionAdvancesAndPersistsProgress() throws {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        launch()
        XCTAssertFalse(app.staticTexts["unlocked-aphorism"].exists)
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1 of \(levels.count)")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        assertBoxes(level: levels[0], state: GameState(level: levels[0]))
        try play(solutions[0], level: levels[0])
        XCTAssertTrue(app.staticTexts["Level Complete!"].exists)
        let quote = try assertUnlockedQuote()
        attachScreenshot("Centered level completion")
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(try assertUnlockedQuote(), quote)
        app.buttons["advance"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 2 of \(levels.count)")
        assertBoxes(level: levels[1], state: GameState(level: levels[1]))
        openStats()
        let difficulty = levels[0].difficulty.rawValue
        let victoryStats = statsRow(difficulty)
        XCTAssertTrue(victoryStats.label.contains("100%"), victoryStats.label)
        XCTAssertFalse(victoryStats.label.contains("—"), victoryStats.label)
        attachScreenshot("Stats — recorded victory")
        app.buttons["close-overlay"].tap()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 2 of \(levels.count)")
        assertBoxes(level: levels[1], state: GameState(level: levels[1]))
        openStats()
        XCTAssertTrue(statsRow(difficulty).label.contains("100%"))
        app.buttons["close-overlay"].tap()
    }

    func testSquareCompletionReturnsToCircle() throws {
        let levels = try LevelCatalog.load()
        launch(level: 2)
        XCTAssertEqual(app.otherElements["board"].label, "Puzzle grid")
        try play(LevelCatalog.solutions()[1], level: levels[1])
        try assertUnlockedQuote()
        attachScreenshot("Square level completion")
        app.buttons["advance"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 3 of \(levels.count)")
        XCTAssertEqual(app.otherElements["board"].label, "Circular puzzle board, lane 1 beneath the pour pointer")
        assertBoxes(level: levels[2], state: GameState(level: levels[2]))
    }

    func testCircularReducedMotionAndRestoration() throws {
        app.launchEnvironment["COLOR_FLOW_REDUCE_MOTION"] = "1"
        launch(level: 1)
        attachScreenshot("Circular initial board")
        let level = try LevelCatalog.load()[0]
        let moves = try LevelCatalog.solutions()[0]
        let end = try XCTUnwrap(moves.firstIndex { if case .pour = $0 { true } else { false } })
        try play(Array(moves.prefix(end + 1)), level: level)
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch(level: 1)
        XCTAssertEqual(snapshot(), before)
        attachScreenshot("Circular restored partial board")
    }

    func testSquareGameplayMedia() throws { try captureGameplay(kind: .square) }

    func testCircularGameplayMedia() throws { try captureGameplay(kind: .circular) }

    private func captureGameplay(kind: BoardKind) throws {
        let step = try checkpoint(kind: kind, difficulty: .medium) { engine, before, move, _ in
            let capacity = engine.level.width * engine.level.height
            let remaining = engine.remainingBoxes(state: before).reduce(0) { $0 + $1.capacity }
            guard (0.28...0.65).contains(1 - Double(remaining) / Double(capacity)) else { return false }
            return try pourWithFall(engine: engine, state: before, move: move)
        }
        let level = step.level
        let engine = try PuzzleEngine(level: level)
        // Use known sample quotes in the media so every capture uses the same layout.
        let examples = try AphorismCatalog.load().entries
        let text = kind == .circular ? "Act well your part—there all the honor lies."
                                     : "One touch of nature makes the whole world kin."
        app.launchEnvironment["COLOR_FLOW_TEST_APHORISM_ID"] = try XCTUnwrap(examples.first { $0.text == text }).id
        launch(level: level.id)
        XCTAssertFalse(app.staticTexts[text].exists)
        attachScreenshot("\(kind.rawValue.capitalized) opening board")
        let start = max(0, step.index - 2)
        var state = try play(Array(step.path.prefix(start)), level: level)
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch(level: level.id)
        FileHandle.standardError.write(Data("GAMEPLAY_CAPTURE_READY \(kind.rawValue)\n".utf8))
        Thread.sleep(forTimeInterval: 3)
        let clock = ContinuousClock()
        let began = clock.now
        var captured = false
        for (offset, move) in step.path.dropFirst(start).enumerated() {
            if clock.now - began >= .seconds(32) { break }
            let button: XCUIElement
            switch move {
            case .take(let queue): button = app.buttons["queue-\(queue)"]
            case .pour(let slot): button = app.buttons["slot-\(slot)"]
            }
            XCTAssertTrue(button.isEnabled)
            button.tap()
            if case .pour = move { waitUntilReady() }
            state = try engine.applying(move, to: state)
            if !captured, start + offset >= step.index, engine.outcome(state: state) == .playing {
                XCTAssertFalse(app.staticTexts[text].exists)
                attachScreenshot("README \(level.boardKind.rawValue) gameplay")
                captured = true
            }
            if engine.outcome(state: state) != .playing { break }
        }
        XCTAssertTrue(captured, "Capture must demonstrate a settled fall during gameplay")
        assertBoxes(level: level, state: state)
        if engine.outcome(state: state) == .playing {
            Thread.sleep(forTimeInterval: 3)
        }
    }

    func testFinalLevelCompletionStartsNewCampaign() throws {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        let longestQuote = try XCTUnwrap(AphorismCatalog.load().entries.max { $0.text.count < $1.text.count })
        app.launchEnvironment["COLOR_FLOW_TEST_APHORISM_ID"] = longestQuote.id
        launch(level: levels.count)
        try play(solutions[levels.count - 1], level: levels[levels.count - 1])
        XCTAssertTrue(app.staticTexts["Game Complete!"].exists)
        XCTAssertEqual(try assertUnlockedQuote(), longestQuote)
        attachScreenshot("Centered game completion")
        app.buttons["advance"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1 of \(levels.count)")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        assertBoxes(level: levels[0], state: GameState(level: levels[0]))
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1 of \(levels.count)")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        assertBoxes(level: levels[0], state: GameState(level: levels[0]))
    }

    func testRechargeAndExactRelaunchRestore() throws {
        let step = try checkpoint(kind: .circular, difficulty: .easy) { engine, before, move, _ in
            guard case .take(let queue) = move,
                  let tin = engine.frontTin(queue: queue, state: before) else { return false }
            return before.buckets.contains { $0?.color == tin.color }
        }
        launch(level: step.level.id)
        try play(step.throughMove, level: step.level)
        attachScreenshot("Recharged bucket")
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch(level: step.level.id)
        XCTAssertEqual(snapshot(), before)
    }

    func testPartialFillPersistsAcrossRelaunch() throws {
        let step = try checkpoint(kind: .circular, difficulty: .easy) { engine, _, _, after in
            zip(engine.level.boxes, after.boxes).contains { $1.filledUnits > 0 && $1.filledUnits < $0.capacity }
        }
        launch(level: step.level.id)
        try play(step.throughMove, level: step.level)
        attachScreenshot("Partially filled box")
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch(level: step.level.id)
        XCTAssertEqual(snapshot(), before)
    }

    func testGravityMatchesEnginePositions() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        let step = try checkpoint(kind: .square, difficulty: .easy) { engine, before, move, _ in
            try pourWithFall(engine: engine, state: before, move: move)
        }
        launch(level: step.level.id)
        try play(step.throughMove, level: step.level)
        attachScreenshot("Settled mixed-size boxes after gravity")
    }

    private func snapshot() -> [String] {
        let controls = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'slot-' OR identifier BEGINSWITH 'queue-'"))
            .allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.value ?? "")|\($0.isEnabled)" }
        let boxes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'box-'"))
            .allElementsBoundByIndex.map(\.label)
        return [app.otherElements["board"].label] + controls + boxes
    }

    func testBoardIsReadOnlyAndFitsScreen() throws {
        let levels = try Difficulty.allCases.flatMap { difficulty in
            try [BoardKind.circular, .square].map { try firstLevel(kind: $0, difficulty: difficulty) }
        }
        for level in levels {
            launch(level: level.id)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'box-' OR identifier == 'board'")).count, 0)
            let board = app.otherElements["board"].frame
            XCTAssertLessThanOrEqual(board.maxX, app.frame.maxX)
            XCTAssertLessThanOrEqual(board.width, 440)
            if app.frame.width == 375 {
                XCTAssertEqual(board.minX, 4, accuracy: 1)
                XCTAssertEqual(board.width, 367, accuracy: 1)
            }
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'slot-'")).count,
                           level.bucketSlots)
            for queue in level.paintQueues.indices where !level.paintQueues[queue].isEmpty {
                XCTAssertTrue(app.buttons["queue-\(queue)"].isHittable, app.debugDescription)
            }
            XCTAssertTrue(app.buttons["settings"].isHittable)
            XCTAssertGreaterThanOrEqual(app.buttons["settings"].frame.width, 44)
            XCTAssertGreaterThanOrEqual(app.buttons["settings"].frame.height, 44)
            attachScreenshot("Level \(level.id) — compact layout")
            app.terminate()
        }
    }

    private func openStats() {
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["stats"].isHittable)
        app.buttons["stats"].tap()
    }

    private func statsRow(_ difficulty: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "stats-\(difficulty)").firstMatch
    }

    func testStatsOverlayPreservesBoardAndRestartStatistics() throws {
        launch(level: try firstLevel(kind: .circular, difficulty: .easy).id)
        let before = snapshot()
        attachScreenshot("Paint badge header — compact")
        app.buttons["settings"].tap()
        attachScreenshot("Settings — Stats histogram entry")
        app.buttons["stats"].tap()
        for difficulty in ["easy", "medium", "hard"] {
            XCTAssertTrue(statsRow(difficulty).label.contains("Win percentage: —"))
        }
        XCTAssertFalse(firstTin.isHittable)
        let close = app.buttons["close-overlay"]
        XCTAssertTrue(close.isHittable)
        XCTAssertGreaterThanOrEqual(close.frame.width, 48)
        XCTAssertGreaterThanOrEqual(close.frame.height, 48)
        attachScreenshot("Stats — empty cartoon table")
        close.tap()
        XCTAssertEqual(snapshot(), before)

        app.buttons["settings"].tap()
        app.buttons["restart"].tap()
        app.buttons["Cancel"].tap()
        openStats()
        XCTAssertTrue(statsRow("easy").label.contains("Win percentage: —"))
        app.buttons["close-overlay"].tap()
        app.buttons["settings"].tap()
        app.buttons["restart"].tap()
        app.buttons["Restart Level"].tap()
        openStats()
        XCTAssertTrue(statsRow("easy").label.contains("Win percentage: 0%"))
        XCTAssertTrue(statsRow("easy").label.contains("Average win time: —"))
        attachScreenshot("Stats — recorded restart")
        app.buttons["close-overlay"].tap()
    }

    func testClearStatsRequiresConfirmationAndPreservesProgress() throws {
        launch(level: try firstLevel(kind: .circular, difficulty: .easy).id)
        app.buttons["settings"].tap()
        app.buttons["restart"].tap()
        app.buttons["Restart Level"].tap()
        firstTin.tap()
        let before = snapshot()
        openStats()
        XCTAssertTrue(statsRow("easy").label.contains("Win percentage: 0%"))
        app.buttons["clear-stats"].tap()
        let confirmation = app.alerts["Clear all stats?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        attachScreenshot("Clear stats — confirmation")
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(statsRow("easy").label.contains("Win percentage: 0%"))
        app.buttons["clear-stats"].tap()
        confirmation.buttons["Clear stats"].tap()
        for difficulty in ["easy", "medium", "hard"] {
            XCTAssertTrue(statsRow(difficulty).label.contains("Win percentage: —"))
            XCTAssertTrue(statsRow(difficulty).label.contains("Average win time: —"))
        }
        attachScreenshot("Stats — cleared totals")
        app.buttons["close-overlay"].tap()
        XCTAssertEqual(snapshot(), before)
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        XCTAssertEqual(snapshot(), before)
        openStats()
        XCTAssertTrue(statsRow("easy").label.contains("Win percentage: —"))
        app.buttons["close-overlay"].tap()
    }

    func testRestartRequiresConfirmation() {
        launch()
        firstTin.tap()
        let bucket = app.buttons["slot-0"].value as? String
        app.buttons["settings"].tap()
        app.buttons["restart"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, bucket)
        app.buttons["settings"].tap()
        app.buttons["restart"].tap()
        app.buttons["Restart Level"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }

    func testNormalPourLocksInputAndSurvivesTermination() throws {
        try verifyInterruptedPour(kind: .square)
    }

    func testCircularPourLocksInputAndSurvivesTermination() throws {
        try verifyInterruptedPour(kind: .circular)
    }

    private func verifyInterruptedPour(kind: BoardKind) throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        let preparation = try preparationForPour(minimumUnits: 4, kind: kind)
        let level = preparation.level
        launch(level: level.id)
        let engine = try PuzzleEngine(level: level)
        _ = try play(preparation.prefix, level: level)
        let expected = try engine.applying(.pour(slot: preparation.slot), to: preparation.before)
        app.buttons["slot-\(preparation.slot)"].tap()
        XCTAssertEqual(app.otherElements["board"].value as? String, "Pouring")
        XCTAssertFalse(app.buttons["settings"].isEnabled)
        for queue in app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'queue-'")).allElementsBoundByIndex {
            XCTAssertFalse(queue.isEnabled)
        }
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch(level: level.id)
        assertBoxes(level: level, state: expected)
        XCTAssertTrue(app.buttons["settings"].isEnabled)
        attachScreenshot("Restored complete move after interrupted animation")
    }

    func testReducedMotionPour() throws {
        app.launchEnvironment["COLOR_FLOW_REDUCE_MOTION"] = "1"
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        try play(Array(LevelCatalog.solutions()[0].prefix(2)), level: LevelCatalog.load()[0])
        attachScreenshot("Reduced motion cleared blocks")
    }

    func testNormalPourShowsSequentialFilling() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        let preparation = try preparationForPour(minimumUnits: 4, kind: .circular)
        let level = preparation.level
        launch(level: level.id)
        let engine = try PuzzleEngine(level: level)
        _ = try play(preparation.prefix, level: level)
        let expected = try engine.applying(.pour(slot: preparation.slot), to: preparation.before)
        let clock = ContinuousClock()
        let started = clock.now
        app.buttons["slot-\(preparation.slot)"].tap()
        waitUntilReady()
        XCTAssertGreaterThanOrEqual(started.duration(to: clock.now), .seconds(1))
        assertBoxes(level: level, state: expected)
        attachScreenshot("Normal pour fills and removes larger boxes")
    }

    private func preparationForPour(minimumUnits: Int, kind: BoardKind) throws
        -> (level: LevelDefinition, prefix: [Move], before: GameState, slot: Int) {
        let step = try checkpoint(kind: kind, difficulty: .easy) { engine, before, move, _ in
            guard case .pour(let slot) = move else { return false }
            let result = try engine.pourResult(slot: slot, state: before)
            let units = result.events.reduce(0) { total, event in
                if case .fill(let fill) = event { return total + fill.toUnits - fill.fromUnits }
                return total
            }
            return units >= minimumUnits
        }
        guard case .pour(let slot) = step.move else {
            throw NSError(domain: "Missing multi-unit pour fixture", code: 1)
        }
        return (step.level, step.prefix, step.before, slot)
    }

    func testHintsShowLoadingUntilResultIsReady() {
        app.launchEnvironment["COLOR_FLOW_SLOW_HINT"] = "1"
        launch()
        app.buttons["settings"].tap()
        app.buttons["hint"].tap()
        let loading = app.descendants(matching: .any).matching(identifier: "hint-loading").firstMatch
        XCTAssertTrue(loading.waitForExistence(timeout: 3), app.debugDescription)
        XCTAssertFalse(app.staticTexts["hint-inconclusive"].exists)
        attachScreenshot("Hint search — loading without a timeout message")
        let first = app.descendants(matching: .any).matching(identifier: "hint-step-1").firstMatch
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(10))
        while !first.exists && clock.now < deadline {
            XCTAssertFalse(app.staticTexts["hint-inconclusive"].exists)
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTAssertTrue(first.exists)
        XCTAssertFalse(app.staticTexts["hint-inconclusive"].exists)
        app.buttons["close-overlay"].tap()
    }

    func testSettingsAndPaintRiverHintsPreserveProgress() throws {
        launch()
        let before = snapshot()
        app.buttons["settings"].tap()
        XCTAssertTrue(app.buttons["restart"].isHittable)
        XCTAssertFalse(firstTin.isHittable)
        attachScreenshot("Cartoon game settings")
        app.buttons["hint"].tap()
        let first = app.descendants(matching: .any).matching(identifier: "hint-step-1").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        let engine = try PuzzleEngine(level: LevelCatalog.load()[0])
        guard case .steps(let steps) = LevelHints.suggest(engine: engine, state: GameState(level: engine.level),
                                                          knownSolution: try LevelCatalog.solutions()[0]) else {
            XCTFail("Expected hints"); return
        }
        XCTAssertTrue(first.label.contains(steps[0].instruction))
        attachScreenshot("Paint river — first hints")
        app.scrollViews["hint-route"].swipeUp()
        let fifth = app.descendants(matching: .any).matching(identifier: "hint-step-5").firstMatch
        XCTAssertTrue(fifth.isHittable)
        attachScreenshot("Paint river — fifth hint")
        app.buttons["close-overlay"].tap()
        XCTAssertEqual(snapshot(), before)
    }

    func testBlockedBucketRetainsQuantityAndNoTextCaption() throws {
        let step = try checkpoint(kind: .square, difficulty: .medium, outcome: .lost) { engine, _, _, after in
            engine.outcome(state: after) == .playing && after.buckets.indices.contains {
                after.buckets[$0] != nil && !engine.canPour(slot: $0, state: after)
            }
        }
        launch(level: step.level.id)
        let engine = try PuzzleEngine(level: step.level)
        let state = try play(step.throughMove, level: step.level)
        let slot = try XCTUnwrap(state.buckets.indices.first { state.buckets[$0] != nil && !engine.canPour(slot: $0, state: state) })
        XCTAssertEqual(app.buttons["slot-\(slot)"].value as? String, "\(state.buckets[slot]!.paintUnits) paint units, Blocked")
        XCTAssertFalse(app.staticTexts["Blocked"].exists)
        attachScreenshot("Cartoon lock above blocked bucket")
    }

    func testMediumLosingBranchAndRetry() throws {
        try verifyLosingBranch(levelID: firstLevel(kind: .circular, difficulty: .medium).id)
    }

    func testHardLosingBranchAndRetry() throws {
        try verifyLosingBranch(levelID: firstLevel(kind: .circular, difficulty: .hard).id)
    }

    private func verifyLosingBranch(levelID: Int) throws {
        launch(level: levelID)
        let level = try LevelCatalog.load()[levelID - 1]
        let moves = try XCTUnwrap(LevelCatalog.losingBranches()[levelID])
        try play(moves, level: level)
        XCTAssertTrue(app.buttons["retry"].waitForExistence(timeout: 5))
        attachScreenshot("Level \(levelID) — no moves left")
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch(level: levelID)
        XCTAssertTrue(app.buttons["retry"].exists)
        app.buttons["retry"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level \(levelID) of \(try LevelCatalog.load().count)")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }
}

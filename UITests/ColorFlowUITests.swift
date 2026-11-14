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
        for box in level.boxes {
            let element = app.descendants(matching: .any).matching(identifier: "box-\(box.id)").firstMatch
            if engine.isRemoved(box, state: state) {
                XCTAssertFalse(element.exists)
            } else {
                let current = engine.boxState(id: box.id, state: state)
                let expected = "\(box.color.name), row \(current.row + 1), column \(box.column + 1), \(box.width) by \(box.height), \(current.filledUnits) of \(box.capacity) paint units"
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

    func testSplashOnLaunchAndReturnPreservesGame() {
        app.launch()
        let title = app.images["splash-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Color Flow")
        XCTAssertEqual(app.staticTexts["splash-subtitle"].label, "for Luisa")
        attachScreenshot("Splash — Color Flow for Luisa")
        XCTAssertTrue(app.staticTexts["level-number"].waitForExistence(timeout: 5))
        app.buttons["queue-0"].tap()
        let bucket = app.buttons["slot-0"].value as? String

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["level-number"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["slot-0"].value as? String, bucket)
    }

    func testLevelTransitionAndFinalCompletion() throws {
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        launch()
        try play(solutions[0], level: levels[0])
        XCTAssertTrue(app.staticTexts["Level Complete!"].exists)
        attachScreenshot("Centered level completion")
        app.buttons["advance"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 2 of \(levels.count)")
        openStats()
        let easy = statsRow("easy")
        XCTAssertTrue(easy.label.contains("100%"), easy.label)
        XCTAssertFalse(easy.label.contains("—"), easy.label)
        attachScreenshot("Stats — recorded victory")
        app.buttons["close-overlay"].tap()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        app.launch()
        XCTAssertTrue(app.buttons["settings"].waitForExistence(timeout: 10))
        openStats()
        XCTAssertTrue(statsRow("easy").label.contains("100%"))
        app.buttons["close-overlay"].tap()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "1"
        app.terminate()
        launch(level: levels.count)
        try play(solutions[levels.count - 1], level: levels[levels.count - 1])
        XCTAssertTrue(app.staticTexts["Game Complete!"].exists)
        attachScreenshot("Centered game completion")
        app.buttons["advance"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1 of \(levels.count)")
    }

    func testFullCampaignJourneyAndStartAgain() throws {
        launch()
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        for (level, moves) in zip(levels, solutions) {
            XCTAssertEqual(app.staticTexts["level-number"].label, "Level \(level.id) of \(levels.count)")
            XCTAssertEqual(app.staticTexts["level-difficulty"].label, level.difficulty.rawValue.capitalized)
            attachScreenshot("Level \(level.id) — initial")
            try play(moves, level: level)
            XCTAssertTrue(app.buttons["advance"].waitForExistence(timeout: 5))
            attachScreenshot("Level \(level.id) — empty grid")
            app.buttons["advance"].tap()
        }
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1 of \(levels.count)")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }

    func testRechargeAndExactRelaunchRestore() throws {
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        var prefix: [Move] = []
        var foundRecharge = false
        for move in try LevelCatalog.solutions()[0] {
            if let queue = (0..<4).first(where: { queue in
                guard let tin = engine.frontTin(queue: queue, state: state) else { return false }
                return state.buckets.contains { $0?.color == tin.color }
            }) {
                prefix.append(.take(queue: queue))
                foundRecharge = true
                break
            }
            prefix.append(move)
            state = try engine.applying(move, to: state)
        }
        XCTAssertTrue(foundRecharge)
        _ = try play(prefix, level: level)
        attachScreenshot("Recharged bucket")
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(snapshot(), before)
    }

    func testPartialFillPersistsAcrossRelaunch() throws {
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        var prefix: [Move] = []
        for move in try LevelCatalog.solutions()[0] {
            prefix.append(move)
            state = try engine.applying(move, to: state)
            if zip(level.boxes, state.boxes).contains(where: { $1.filledUnits > 0 && $1.filledUnits < $0.capacity }) { break }
        }
        XCTAssertTrue(zip(level.boxes, state.boxes).contains { $1.filledUnits > 0 && $1.filledUnits < $0.capacity })
        try play(prefix, level: level)
        attachScreenshot("Partially filled box")
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(snapshot(), before)
    }

    func testGravityMatchesEnginePositions() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch(level: 3)
        let level = try LevelCatalog.load()[2]
        let engine = try PuzzleEngine(level: level)
        let solution = try LevelCatalog.solutions()[2]
        var state = GameState(level: level)
        var prefix: [Move] = []
        var observedFall = false
        for move in solution {
            prefix.append(move)
            if case .pour(let slot) = move {
                let result = try engine.pourResult(slot: slot, state: state)
                observedFall = result.events.contains { if case .fall = $0 { true } else { false } }
                state = result.state
            } else {
                state = try engine.applying(move, to: state)
            }
            if observedFall { break }
        }
        XCTAssertTrue(observedFall)
        try play(prefix, level: level)
        attachScreenshot("Settled mixed-size boxes after gravity")
    }

    private func snapshot() -> [String] {
        let controls = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'slot-' OR identifier BEGINSWITH 'queue-'"))
            .allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.value ?? "")|\($0.isEnabled)" }
        let boxes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'box-'"))
            .allElementsBoundByIndex.map(\.label)
        return controls + boxes
    }

    func testBoardIsReadOnlyAndFitsScreen() throws {
        let levels = try LevelCatalog.load()
        for levelID in [1, 4, 7] {
            launch(level: levelID)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'box-' OR identifier == 'board'")).count, 0)
            let board = app.otherElements["board"].frame
            XCTAssertLessThanOrEqual(board.maxX, app.frame.maxX)
            XCTAssertLessThanOrEqual(board.width, 440)
            if app.frame.width == 375 {
                XCTAssertEqual(board.minX, 4, accuracy: 1)
                XCTAssertEqual(board.width, 367, accuracy: 1)
            }
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'slot-'")).count,
                           levels[levelID - 1].bucketSlots)
            XCTAssertTrue(app.buttons["queue-0"].isHittable, app.debugDescription)
            XCTAssertTrue(app.buttons["settings"].isHittable)
            XCTAssertGreaterThanOrEqual(app.buttons["settings"].frame.width, 44)
            XCTAssertGreaterThanOrEqual(app.buttons["settings"].frame.height, 44)
            attachScreenshot("Level \(levelID) — compact layout")
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

    func testStatsOverlayPreservesBoardAndRestartStatistics() {
        launch()
        let before = snapshot()
        attachScreenshot("Paint badge header — compact")
        app.buttons["settings"].tap()
        attachScreenshot("Settings — Stats histogram entry")
        app.buttons["stats"].tap()
        for difficulty in ["easy", "medium", "hard"] {
            XCTAssertTrue(statsRow(difficulty).label.contains("Win percentage: —"))
        }
        XCTAssertFalse(app.buttons["queue-0"].isHittable)
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

    func testClearStatsRequiresConfirmationAndPreservesProgress() {
        launch()
        app.buttons["settings"].tap()
        app.buttons["restart"].tap()
        app.buttons["Restart Level"].tap()
        app.buttons["queue-0"].tap()
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
        app.buttons["queue-0"].tap()
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
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        let preparation = try preparationForPour(minimumUnits: 4)
        _ = try play(preparation.prefix, level: level)
        let expected = try engine.applying(.pour(slot: preparation.slot), to: preparation.state)
        app.buttons["slot-\(preparation.slot)"].tap()
        XCTAssertEqual(app.otherElements["board"].value as? String, "Pouring")
        XCTAssertFalse(app.buttons["settings"].isEnabled)
        XCTAssertFalse(app.buttons["queue-0"].isEnabled)
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
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
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        let preparation = try preparationForPour(minimumUnits: 4)
        _ = try play(preparation.prefix, level: level)
        let expected = try engine.applying(.pour(slot: preparation.slot), to: preparation.state)
        let clock = ContinuousClock()
        let started = clock.now
        app.buttons["slot-\(preparation.slot)"].tap()
        waitUntilReady()
        XCTAssertGreaterThanOrEqual(started.duration(to: clock.now), .seconds(1))
        assertBoxes(level: level, state: expected)
        attachScreenshot("Normal pour fills and removes larger boxes")
    }

    private func preparationForPour(minimumUnits: Int) throws -> (prefix: [Move], state: GameState, slot: Int) {
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        var state = GameState(level: level)
        var prefix: [Move] = []
        for move in try LevelCatalog.solutions()[0] {
            if case .pour(let slot) = move {
                let result = try engine.pourResult(slot: slot, state: state)
                let units = result.events.reduce(0) { total, event in
                    if case .fill(let step) = event { total + step.toUnits - step.fromUnits } else { total }
                }
                if units >= minimumUnits { return (prefix, state, slot) }
            }
            state = try engine.applying(move, to: state)
            prefix.append(move)
        }
        throw NSError(domain: "Missing multi-unit pour fixture", code: 1)
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
        XCTAssertFalse(app.buttons["queue-0"].isHittable)
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
        launch(level: 7)
        let level = try LevelCatalog.load()[6]
        let engine = try PuzzleEngine(level: level)
        let path = try XCTUnwrap(LevelCatalog.losingBranches()[7])
        var state = GameState(level: level)
        var prefix: [Move] = []
        for move in path {
            state = try engine.applying(move, to: state)
            prefix.append(move)
            if engine.outcome(state: state) == .playing && state.buckets.indices.contains(where: {
                state.buckets[$0] != nil && !engine.canPour(slot: $0, state: state)
            }) { break }
        }
        try play(prefix, level: level)
        let slot = try XCTUnwrap(state.buckets.indices.first { state.buckets[$0] != nil && !engine.canPour(slot: $0, state: state) })
        XCTAssertEqual(app.buttons["slot-\(slot)"].value as? String, "\(state.buckets[slot]!.paintUnits) paint units, Blocked")
        XCTAssertFalse(app.staticTexts["Blocked"].exists)
        attachScreenshot("Cartoon lock above blocked bucket")
    }

    func testMediumLosingBranchAndRetry() throws {
        try verifyLosingBranch(levelID: 4)
    }

    func testHardLosingBranchAndRetry() throws {
        try verifyLosingBranch(levelID: 7)
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

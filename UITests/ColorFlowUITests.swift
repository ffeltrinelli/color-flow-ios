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
        XCTAssertTrue(app.staticTexts["level-number"].waitForExistence(timeout: 15), app.debugDescription)
    }

    private func waitUntilReady() {
        let ready = NSPredicate(format: "value == %@", "Ready")
        expectation(for: ready, evaluatedWith: app.otherElements["board"])
        waitForExpectations(timeout: 15)
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
        assertBoxes(level: level, state: state)
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

    func testCompleteJourneyAndStartAgain() throws {
        launch()
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        for (level, moves) in zip(levels, solutions) {
            XCTAssertEqual(app.staticTexts["level-number"].label, "Level \(level.id)")
            XCTAssertEqual(app.staticTexts["level-difficulty"].label, level.difficulty.rawValue.capitalized)
            attachScreenshot("Level \(level.id) — initial")
            try play(moves, level: level)
            XCTAssertTrue(app.buttons["advance"].waitForExistence(timeout: 5))
            attachScreenshot("Level \(level.id) — empty grid")
            app.buttons["advance"].tap()
        }
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }

    func testRechargeAndExactRelaunchRestore() throws {
        launch()
        let level = try LevelCatalog.load()[0]
        let moves: [Move] = [.take(queue: 0), .take(queue: 2), .pour(slot: 0)]
        app.buttons["queue-0"].tap()
        app.buttons["queue-2"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "2 paint units, Ready to pour")
        app.buttons["slot-0"].tap()
        waitUntilReady()
        let engine = try PuzzleEngine(level: level)
        let expected = try moves.reduce(GameState(level: level)) { try engine.applying($1, to: $0) }
        assertBoxes(level: level, state: expected)
        attachScreenshot("Recharged bucket clears a larger box")
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(snapshot(), before)
    }

    func testPartialFillPersistsAcrossRelaunch() throws {
        launch()
        let level = try LevelCatalog.load()[0]
        try play([.take(queue: 0), .pour(slot: 0)], level: level)
        let box = app.descendants(matching: .any).matching(identifier: "box-1").firstMatch
        XCTAssertTrue(box.label.contains("1 of 2 paint units"))
        attachScreenshot("Partially filled two-cell box")
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
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'box-' OR identifier BEGINSWITH 'slot-' OR identifier BEGINSWITH 'queue-'"))
            .allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.value ?? "")|\($0.isEnabled)" }
    }

    func testBoardIsReadOnlyAndFitsScreen() {
        launch()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'box-' OR identifier == 'board'")).count, 0)
        let board = app.otherElements["board"].frame
        XCTAssertLessThanOrEqual(board.maxX, app.frame.maxX)
        XCTAssertLessThanOrEqual(board.width, 440)
        if app.frame.width == 375 {
            XCTAssertEqual(board.minX, 4, accuracy: 1)
            XCTAssertEqual(board.width, 367, accuracy: 1)
        }
        XCTAssertTrue(app.buttons["queue-0"].isHittable, app.debugDescription)
        XCTAssertTrue(app.buttons["restart"].isHittable)
        attachScreenshot("Read-only full-width grid")
    }

    func testRestartRequiresConfirmation() {
        launch()
        app.buttons["queue-0"].tap()
        let bucket = app.buttons["slot-0"].value as? String
        app.buttons["restart"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, bucket)
        app.buttons["restart"].tap()
        app.buttons["Restart Level"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }

    func testNormalPourLocksInputAndSurvivesTermination() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        let preparation: [Move] = [.take(queue: 0), .take(queue: 0), .take(queue: 1), .take(queue: 2)]
        var expected = GameState(level: level)
        for move in preparation {
            expected = try engine.applying(move, to: expected)
            if case .take(let queue) = move { app.buttons["queue-\(queue)"].tap() }
        }
        expected = try engine.applying(.pour(slot: 0), to: expected)
        app.buttons["slot-0"].tap()
        XCTAssertEqual(app.otherElements["board"].value as? String, "Pouring")
        XCTAssertFalse(app.buttons["restart"].isEnabled)
        XCTAssertFalse(app.buttons["queue-0"].isEnabled)
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        assertBoxes(level: level, state: expected)
        XCTAssertTrue(app.buttons["restart"].isEnabled)
        attachScreenshot("Restored complete move after interrupted animation")
    }

    func testReducedMotionPour() throws {
        app.launchEnvironment["COLOR_FLOW_REDUCE_MOTION"] = "1"
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        try play([.take(queue: 0), .pour(slot: 0)], level: LevelCatalog.load()[0])
        attachScreenshot("Reduced motion cleared blocks")
    }

    func testNormalPourShowsSequentialFilling() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        var expected = GameState(level: level)
        for queue in [0, 0, 1, 2] {
            expected = try engine.applying(.take(queue: queue), to: expected)
            app.buttons["queue-\(queue)"].tap()
        }
        expected = try engine.applying(.pour(slot: 0), to: expected)
        let clock = ContinuousClock()
        let started = clock.now
        app.buttons["slot-0"].tap()
        waitUntilReady()
        XCTAssertGreaterThanOrEqual(started.duration(to: clock.now), .seconds(1))
        assertBoxes(level: level, state: expected)
        attachScreenshot("Normal pour fills and removes larger boxes")
    }

    func testMediumLosingBranchAndRetry() throws {
        try verifyLosingBranch(levelID: 2)
    }

    func testHardLosingBranchAndRetry() throws {
        try verifyLosingBranch(levelID: 3)
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
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level \(levelID)")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }
}

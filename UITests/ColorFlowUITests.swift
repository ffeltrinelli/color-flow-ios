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
        assertColumns(level: level, state: state)
        return state
    }

    private func assertColumns(level: LevelDefinition, state: GameState) {
        let engine = try! PuzzleEngine(level: level)
        for column in 0..<level.width {
            let colors = engine.remainingColors(column: column, state: state)
            let expected = colors.isEmpty ? "Empty" : "Top to bottom: " + colors.map(\.name).joined(separator: ", ")
            XCTAssertEqual(app.otherElements["column-\(column)"].value as? String, expected)
        }
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    func testRechargeBlockedBucketAndExactRelaunchRestore() throws {
        launch()
        app.buttons["queue-2"].tap()
        app.buttons["queue-3"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "9 paint units, Ready to pour")
        app.buttons["queue-1"].tap()
        XCTAssertEqual(app.buttons["slot-1"].value as? String, "4 paint units, Blocked")
        XCTAssertFalse(app.buttons["slot-1"].isEnabled)
        app.buttons["queue-0"].tap()
        XCTAssertFalse(app.buttons["queue-3"].isEnabled)
        XCTAssertTrue(app.buttons["queue-2"].isEnabled)
        app.buttons["queue-2"].tap()
        XCTAssertEqual(app.buttons["slot-2"].value as? String, "11 paint units, Ready to pour")
        app.buttons["slot-0"].tap()
        waitUntilReady()
        attachScreenshot("Multi-column clearing before relaunch")
        let before = snapshot()
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(snapshot(), before)
    }

    private func snapshot() -> [String] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'column-' OR identifier BEGINSWITH 'slot-' OR identifier BEGINSWITH 'queue-'"))
            .allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.value ?? "")|\($0.isEnabled)" }
    }

    func testBoardIsReadOnlyAndFitsScreen() {
        launch()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' OR identifier BEGINSWITH 'column-' OR identifier == 'board'")).count, 0)
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

    func testNormalMultiColumnPourLocksInputAndSurvivesTermination() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        var expected = try engine.applying(.take(queue: 2), to: GameState(level: level))
        expected = try engine.applying(.take(queue: 3), to: expected)
        expected = try engine.applying(.pour(slot: 0), to: expected)
        app.buttons["queue-2"].tap()
        app.buttons["queue-3"].tap()
        app.buttons["slot-0"].tap()
        XCTAssertEqual(app.otherElements["board"].value as? String, "Pouring")
        XCTAssertFalse(app.buttons["restart"].isEnabled)
        XCTAssertFalse(app.buttons["queue-0"].isEnabled)
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        assertColumns(level: level, state: expected)
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        XCTAssertTrue(app.buttons["restart"].isEnabled)
        attachScreenshot("Restored complete automatic pour")
    }

    func testReducedMotionPour() throws {
        app.launchEnvironment["COLOR_FLOW_REDUCE_MOTION"] = "1"
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        try play([.take(queue: 0), .pour(slot: 0)], level: LevelCatalog.load()[0])
        attachScreenshot("Reduced motion cleared blocks")
    }

    func testNormalPourAcrossBoard() throws {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        let level = try LevelCatalog.load()[0]
        let engine = try PuzzleEngine(level: level)
        var expected = try engine.applying(.take(queue: 2), to: GameState(level: level))
        expected = try engine.applying(.take(queue: 3), to: expected)
        expected = try engine.applying(.pour(slot: 0), to: expected)
        app.buttons["queue-2"].tap()
        app.buttons["queue-3"].tap()
        let clock = ContinuousClock()
        let started = clock.now
        app.buttons["slot-0"].tap()
        waitUntilReady()
        XCTAssertGreaterThanOrEqual(started.duration(to: clock.now), .seconds(4))
        assertColumns(level: level, state: expected)
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        attachScreenshot("Normal pour cleared through rightmost column")
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

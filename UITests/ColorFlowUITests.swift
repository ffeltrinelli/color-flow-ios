import ColorFlowCore
import XCTest

@MainActor
final class ColorFlowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var session: String!

    override func setUp() async throws {
        continueAfterFailure = false
        session = UUID().uuidString
        app = XCUIApplication()
        app.launchEnvironment = [
            "COLOR_FLOW_UI_TEST": "1", "COLOR_FLOW_TEST_SESSION": session,
            "COLOR_FLOW_RESET": "1", "COLOR_FLOW_FAST_ANIMATION": "1"
        ]
    }

    private func launch() {
        app.launch()
        let loaded = app.staticTexts["level-number"].waitForExistence(timeout: 15)
        if !loaded { print(app.debugDescription) }
        XCTAssertTrue(loaded)
    }

    private func waitUntilReady() {
        let board = app.otherElements["board"]
        let ready = NSPredicate(format: "value == %@", "Ready")
        expectation(for: ready, evaluatedWith: board)
        waitForExpectations(timeout: 12)
    }

    private func play(_ moves: [Move], level: LevelDefinition, from initial: GameState? = nil) throws -> GameState {
        let engine = try PuzzleEngine(level: level)
        var state = initial ?? GameState(level: level)
        for move in moves {
            switch move {
            case .take(let queue):
                let button = app.buttons["queue-\(queue)"]
                XCTAssertTrue(button.isEnabled)
                button.tap()
            case .pour(let slot, let column):
                if state.selectedSlot != slot { app.buttons["slot-\(slot)"].tap() }
                let target = try XCTUnwrap(engine.pourTargets(slot: slot, column: column, state: state).last)
                let cell = app.buttons["cell-\(target.row)-\(column)"]
                XCTAssertEqual(cell.value as? String, "Ready to pour")
                cell.tap()
                waitUntilReady()
            }
            state = try engine.applying(move, to: state)
        }
        return state
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
            _ = try play(moves, level: level)
            XCTAssertTrue(app.buttons["advance"].waitForExistence(timeout: 5))
            attachScreenshot("Level \(level.id) — complete")
            app.buttons["advance"].tap()
        }
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }

    func testRechargePreviewsAndExactRelaunchRestore() throws {
        launch()
        app.buttons["queue-0"].tap()
        app.buttons["queue-2"].tap()
        app.buttons["queue-3"].tap()
        XCTAssertFalse(app.buttons["queue-0"].isEnabled)
        XCTAssertTrue(app.buttons["queue-1"].isEnabled)
        app.buttons["queue-1"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "6 paint units")
        // The uppermost highlighted cell must pour the same bottom-to-top run.
        app.buttons["cell-3-0"].tap()
        waitUntilReady()
        XCTAssertEqual(app.buttons["cell-5-0"].value as? String, "Painted")
        XCTAssertEqual(app.buttons["cell-2-0"].value as? String, "Unpainted")
        attachScreenshot("Partial board before relaunch")
        let before = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' OR identifier BEGINSWITH 'slot-' OR identifier BEGINSWITH 'queue-'"))
            .allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.value ?? "")|\($0.isEnabled)" }
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        let after = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-' OR identifier BEGINSWITH 'slot-' OR identifier BEGINSWITH 'queue-'"))
            .allElementsBoundByIndex.map { "\($0.identifier)|\($0.label)|\($0.value ?? "")|\($0.isEnabled)" }
        XCTAssertEqual(before, after)
    }

    func testRestartRequiresConfirmation() {
        launch()
        app.buttons["queue-0"].tap()
        app.buttons["restart"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "3 paint units")
        app.buttons["restart"].tap()
        app.buttons["Restart Level"].tap()
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 1")
    }

    func testNormalPourBlocksInputAndSurvivesTermination() {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        app.buttons["queue-0"].tap()
        app.buttons["cell-5-0"].tap()
        let pouring = NSPredicate(format: "value == %@", "Pouring")
        expectation(for: pouring, evaluatedWith: app.otherElements["board"])
        waitForExpectations(timeout: 3)
        XCTAssertFalse(app.buttons["restart"].isEnabled)
        XCTAssertFalse(app.buttons["queue-1"].isEnabled)
        attachScreenshot("Normal pour")
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertEqual(app.buttons["cell-3-0"].value as? String, "Painted")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
        XCTAssertTrue(app.buttons["restart"].isEnabled)
    }

    func testRightmostColumnPour() {
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        app.buttons["queue-3"].tap()
        app.buttons["cell-5-5"].tap()
        let pouring = NSPredicate(format: "value == %@", "Pouring")
        expectation(for: pouring, evaluatedWith: app.otherElements["board"])
        waitForExpectations(timeout: 3)
        attachScreenshot("Right edge pour")
        waitUntilReady()
        XCTAssertEqual(app.buttons["cell-0-5"].value as? String, "Painted")
    }

    func testReducedMotionPour() {
        app.launchEnvironment["COLOR_FLOW_REDUCE_MOTION"] = "1"
        app.launchEnvironment["COLOR_FLOW_FAST_ANIMATION"] = "0"
        launch()
        app.buttons["queue-0"].tap()
        app.buttons["cell-5-0"].tap()
        waitUntilReady()
        XCTAssertEqual(app.buttons["cell-3-0"].value as? String, "Painted")
        attachScreenshot("Reduced motion result")
    }

    func testHardLevelLosingBranchAndRetry() throws {
        launch()
        let levels = try LevelCatalog.load()
        let solutions = try LevelCatalog.solutions()
        for index in 0..<4 {
            _ = try play(solutions[index], level: levels[index])
            app.buttons["advance"].tap()
        }
        let path = try LevelCatalog.hardLosingBranch()
        _ = try play(path, level: levels[4])
        XCTAssertTrue(app.buttons["retry"].waitForExistence(timeout: 5))
        attachScreenshot("Hard level — no moves left")
        app.terminate()
        app.launchEnvironment["COLOR_FLOW_RESET"] = "0"
        launch()
        XCTAssertTrue(app.buttons["retry"].exists)
        app.buttons["retry"].tap()
        XCTAssertEqual(app.staticTexts["level-number"].label, "Level 5")
        XCTAssertEqual(app.buttons["slot-0"].value as? String, "Empty")
    }

}

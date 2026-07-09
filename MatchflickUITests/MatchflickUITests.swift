import XCTest

final class MatchflickUITests: XCTestCase {

    override func setUp() { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["MATCHFLICK_NO_SK"] = "1"
        app.launchEnvironment["MATCHFLICK_FORCE_PRO"] = "1"
        // Every test should start from a clean slate — otherwise a round left in progress by a
        // previous test (now correctly resumable) leaks into this one.
        app.launchEnvironment["MATCHFLICK_RESET_GAME"] = "1"
        app.launch()
        return app
    }

    func testFullSwipeFlowEndsInMatchAndLoops() {
        let app = launch()
        // The app opens straight into swiping using stored defaults — no setup screen.
        XCTAssertTrue(app.buttons["handoff-ready"].waitForExistence(timeout: 8))
        app.buttons["handoff-ready"].tap()

        // Swipe yes through however many cards player 1 sees, then repeat for remaining players,
        // looping until the match screen appears (handles the 2-round tiebreak case too).
        var guardCount = 0
        while !app.buttons["match-done"].exists {
            if app.buttons["swipe-yes"].waitForExistence(timeout: 3) {
                app.buttons["swipe-yes"].tap()
            } else if app.buttons["handoff-ready"].waitForExistence(timeout: 3) {
                app.buttons["handoff-ready"].tap()
            } else {
                break
            }
            guardCount += 1
            if guardCount > 40 { break }
        }
        XCTAssertTrue(app.buttons["match-done"].waitForExistence(timeout: 10))
        app.buttons["match-done"].tap()
        // Done loops straight into a fresh round instead of returning to a setup screen.
        // Generous timeout: the new round's deck is fetched live from TMDB.
        XCTAssertTrue(app.buttons["handoff-ready"].waitForExistence(timeout: 15))
    }

    func testWantToWatchTriageActuallyPersists() {
        let app = launch()
        XCTAssertTrue(app.buttons["handoff-ready"].waitForExistence(timeout: 8))
        app.buttons["handoff-ready"].tap()

        XCTAssertTrue(app.buttons["card-info"].waitForExistence(timeout: 8))
        app.buttons["card-info"].tap()

        XCTAssertTrue(app.buttons["triage-wantToWatch"].waitForExistence(timeout: 5))
        app.buttons["triage-wantToWatch"].tap()

        app.buttons["Done"].firstMatch.tap()

        // Confirm it actually persisted by showing up in the Want to Watch tab (not just a visual flash).
        app.tabBars.buttons["Want to Watch"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label != ''")).firstMatch.waitForExistence(timeout: 5))
    }

    func testRoundResumesAfterQuitAndReopen() {
        let app = launch()
        XCTAssertTrue(app.buttons["handoff-ready"].waitForExistence(timeout: 8))
        app.buttons["handoff-ready"].tap()

        // Swipe a couple cards in so cardIndex is nonzero, then quit mid-round.
        XCTAssertTrue(app.buttons["swipe-yes"].waitForExistence(timeout: 5))
        app.buttons["swipe-yes"].tap()
        XCTAssertTrue(app.buttons["swipe-yes"].waitForExistence(timeout: 5))
        app.buttons["swipe-yes"].tap()

        // Clear the reset flag before relaunching — activate() after terminate() reuses this
        // app instance's launchEnvironment, and leaving the flag on would wipe the very round
        // in progress we're trying to prove survives a relaunch.
        app.launchEnvironment["MATCHFLICK_RESET_GAME"] = "0"
        app.terminate()
        app.activate()

        // A working resume drops straight back into swiping (no handoff screen) — a fresh round
        // would show "handoff-ready" again since a new round always starts at player 0.
        XCTAssertFalse(app.buttons["handoff-ready"].waitForExistence(timeout: 5),
                        "Resume failed: app started a brand new round instead of continuing the one in progress")
        XCTAssertTrue(app.buttons["swipe-yes"].waitForExistence(timeout: 5))
    }
}

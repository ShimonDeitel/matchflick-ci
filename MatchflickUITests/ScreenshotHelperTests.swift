import XCTest

final class ScreenshotHelperTests: XCTestCase {
    func testCaptureScreens() {
        let app = XCUIApplication()
        app.launchEnvironment["MATCHFLICK_NO_SK"] = "1"
        app.launchEnvironment["MATCHFLICK_FORCE_PRO"] = "1"
        app.launch()
        _ = app.buttons["handoff-ready"].waitForExistence(timeout: 8)
        app.buttons["handoff-ready"].tap()
        _ = app.buttons["card-info"].waitForExistence(timeout: 8)
        sleep(1)
        let a1 = XCTAttachment(screenshot: app.screenshot())
        a1.name = "01-swipe"
        a1.lifetime = .keepAlways
        add(a1)

        // Save a couple of real titles to Want to Watch so that tab has content to show off.
        for _ in 0..<3 {
            if app.buttons["swipe-yes"].waitForExistence(timeout: 5) {
                app.buttons["swipe-yes"].tap()
                sleep(1)
            }
        }

        app.tabBars.buttons["Want to Watch"].tap()
        sleep(1)
        let a2 = XCTAttachment(screenshot: app.screenshot())
        a2.name = "02-wanttowatch"
        a2.lifetime = .keepAlways
        add(a2)

        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        let a3 = XCTAttachment(screenshot: app.screenshot())
        a3.name = "03-settings"
        a3.lifetime = .keepAlways
        add(a3)
    }

    /// Not forced-Pro, so the paywall is reachable — used for the subscription's required
    /// App Review screenshot.
    func testCapturePaywall() {
        let app = XCUIApplication()
        app.launchEnvironment["MATCHFLICK_NO_SK"] = "1"
        app.launch()
        _ = app.buttons["handoff-ready"].waitForExistence(timeout: 8)
        app.tabBars.buttons["Settings"].tap()
        sleep(1)
        // The Pro section is below the fold in this lazily-rendered Form — scroll until it exists.
        var attempts = 0
        while !app.buttons["unlock-pro-row"].exists && attempts < 10 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(app.buttons["unlock-pro-row"].waitForExistence(timeout: 5))
        app.buttons["unlock-pro-row"].tap()
        _ = app.buttons["paywall-unlock"].waitForExistence(timeout: 5)
        sleep(1)
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = "04-paywall"
        a.lifetime = .keepAlways
        add(a)
    }
}

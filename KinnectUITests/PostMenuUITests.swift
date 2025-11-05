// ABOUTME: UI tests for post menu actions including block
// ABOUTME: Validates block user option appears in post menu

import XCTest

final class PostMenuUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPostMenuHasBlockOption() throws {
        // Given: App is launched with posts in feed
        let app = XCUIApplication()
        app.launch()

        // When: User taps three-dot menu on first post
        let menuButton = app.buttons["post-menu"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        // Then: Block option should appear
        let blockButton = app.buttons["Block User"]
        XCTAssertTrue(blockButton.waitForExistence(timeout: 2), "Block user option should appear")

        // Cleanup
        app.tap() // Dismiss menu
    }
}

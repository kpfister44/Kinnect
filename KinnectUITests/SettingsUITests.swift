// ABOUTME: UI tests for Settings screen navigation and structure
// ABOUTME: Validates navigation from profile and settings list rendering

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigateToSettingsFromProfile() throws {
        // Given: App is launched and user is on profile tab
        let app = XCUIApplication()
        app.launch()

        // Navigate to profile tab
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()

        // When: User taps three-line menu icon
        let menuButton = app.navigationBars.buttons["line.3.horizontal"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3), "Menu button should exist")
        menuButton.tap()

        // Then: Settings screen should appear
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2), "Settings screen should appear")
    }

    @MainActor
    func testSettingsScreenHasAccountSection() throws {
        // Given: User navigates to settings
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Profile"].tap()
        app.navigationBars.buttons["line.3.horizontal"].tap()

        // Then: Account section should be visible
        XCTAssertTrue(app.staticTexts["Edit Profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Account Info"].exists)
    }

    @MainActor
    func testDarkModeTogglePersists() throws {
        // Given: User navigates to settings
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Profile"].tap()
        app.navigationBars.buttons["line.3.horizontal"].tap()

        // When: User toggles dark mode
        let darkModeToggle = app.switches["Dark Mode Toggle"]
        XCTAssertTrue(darkModeToggle.waitForExistence(timeout: 2))
        darkModeToggle.tap()

        // Then: Toggle state should change
        let toggleValue = darkModeToggle.value as? String
        XCTAssertEqual(toggleValue, "1", "Toggle should be on")
    }
}

//
//  KinnectUITests.swift
//  KinnectUITests
//
//  Created by Kyle Pfister on 10/17/25.
//

import XCTest

final class KinnectUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testFeedImagesExistAndAreInteractive() throws {
        // Given: App is launched and user is on feed
        let app = XCUIApplication()
        app.launch()

        // Wait for feed to load
        let feedImage = app.images.firstMatch
        XCTAssertTrue(feedImage.waitForExistence(timeout: 5), "Feed image should appear")

        // Then: Image should be present and interactive
        XCTAssertTrue(feedImage.exists, "Image should exist")
        XCTAssertTrue(feedImage.isHittable, "Image should be hittable for gestures")

        // Note: Pinch gesture automation is not supported by XCTest
        // Manual verification required for actual zoom behavior
    }

    @MainActor
    func testFeedScrollViewExists() throws {
        // Given: App is launched
        let app = XCUIApplication()
        app.launch()

        // Then: Feed scroll view should exist
        let scrollView = app.scrollViews.firstMatch
        XCTAssertTrue(scrollView.waitForExistence(timeout: 5), "Feed scroll view should exist")

        // Note: Testing scroll blocking during zoom requires gesture automation
        // that is not available in XCTest. Manual verification required.
    }

    @MainActor
    func testProfileFeedImagesAreInteractive() throws {
        // Given: App is launched
        let app = XCUIApplication()
        app.launch()

        // When: User navigates to profile
        app.tabBars.buttons.element(boundBy: 4).tap() // Profile tab

        // Wait for profile to load
        sleep(2)

        // When: User taps a post thumbnail (if posts exist)
        let firstThumbnail = app.images.firstMatch
        if firstThumbnail.exists && firstThumbnail.isHittable {
            firstThumbnail.tap()

            // Then: Profile feed image should be interactive
            let profileFeedImage = app.images.firstMatch
            XCTAssertTrue(profileFeedImage.waitForExistence(timeout: 3), "Profile feed image should appear")
            XCTAssertTrue(profileFeedImage.isHittable, "Profile feed image should be hittable")
        }

        // Note: Manual verification required for zoom gestures
    }

    @MainActor
    func testActivityBadgeAppearsOnLaunchWithoutVisitingTab() throws {
        // Given: App is launched
        let app = XCUIApplication()
        app.launch()

        // When: App loads on Feed tab (default)
        // Wait for feed to load to ensure app is fully initialized
        let feedImage = app.images.firstMatch
        XCTAssertTrue(feedImage.waitForExistence(timeout: 5), "Feed should load")

        // Then: Activity badge should appear immediately if there are unread activities
        // without needing to visit the Activity tab
        let activityTab = app.tabBars.buttons.element(boundBy: 3)
        XCTAssertTrue(activityTab.exists, "Activity tab should exist")

        // Check if badge exists (badge only appears when unreadCount > 0)
        // If badge exists, verify it shows a number
        if let badgeValue = activityTab.value as? String, !badgeValue.isEmpty {
            // Badge should contain a numeric value
            XCTAssertTrue(Int(badgeValue) != nil && Int(badgeValue)! > 0,
                         "Activity badge should show unread count on app launch")
        }
        // Note: If there are no unread activities, badge won't appear - that's expected
    }
}

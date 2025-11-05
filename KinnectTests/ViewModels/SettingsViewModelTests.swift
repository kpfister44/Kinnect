// ABOUTME: Tests for SettingsViewModel business logic
// ABOUTME: Validates fetching account info from auth session

import Testing
import Foundation
@testable import Kinnect

@MainActor
struct SettingsViewModelTests {

    @Test func fetchesAccountInfo() async throws {
        // Given: User is authenticated
        let viewModel = SettingsViewModel()

        // When: Fetching account info
        await viewModel.fetchAccountInfo()

        // Then: Account info should be populated
        #expect(viewModel.userEmail != nil)
        #expect(viewModel.userId != nil)
    }

    @Test func clearCachePostsNotification() async throws {
        // Given: SettingsViewModel with injected notification center
        let notificationCenter = NotificationCenter()
        let viewModel = SettingsViewModel(notificationCenter: notificationCenter)

        var notificationReceived = false
        let observer = notificationCenter.addObserver(forName: .clearAllCaches, object: nil, queue: nil) { _ in
            notificationReceived = true
        }
        defer { notificationCenter.removeObserver(observer) }

        // When: Clearing cache
        await viewModel.clearCache()

        // Then: Cache notification should be posted and success alert shown
        #expect(notificationReceived)
        #expect(viewModel.showCacheSuccessAlert)
    }

    @Test func exportUserDataStoresFileOnSuccess() async throws {
        // Given: SettingsViewModel with stubbed function invocation
        let exportedPayload = Data("{\"value\":1}".utf8)
        var invoked = false

        let viewModel = SettingsViewModel(
            notificationCenter: NotificationCenter(),
            invokeFunction: { functionName, _ in
                invoked = (functionName == "export-user-data")
                return exportedPayload
            },
            accessTokenProvider: { "token" }
        )

        viewModel.userId = UUID()

        // When: Exporting data
        await viewModel.exportUserData()

        // Then: A file should be written with the exported payload
        let url = try #require(viewModel.exportedDataURL)
        defer { try? FileManager.default.removeItem(at: url) }
        let storedData = try Data(contentsOf: url)
        #expect(invoked)
        #expect(storedData == exportedPayload)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func exportUserDataClearsStaleURLOnFailure() async throws {
        // Given: An existing export URL and a failing export
        let existingURL = FileManager.default.temporaryDirectory.appendingPathComponent("stale.json")
        try Data("old".utf8).write(to: existingURL)

        let viewModel = SettingsViewModel(
            notificationCenter: NotificationCenter(),
            invokeFunction: { _, _ in throw MockError.exportFailed },
            accessTokenProvider: { "token" }
        )

        viewModel.userId = UUID()
        viewModel.exportedDataURL = existingURL
        defer { try? FileManager.default.removeItem(at: existingURL) }

        // When: Export fails
        await viewModel.exportUserData()

        // Then: Exported data URL should reset and error should surface
        #expect(viewModel.exportedDataURL == nil)
        #expect(viewModel.errorMessage?.isEmpty == false)
    }
}

private enum MockError: Error {
    case exportFailed
}

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

    @Test func clearsCacheSuccessfully() async throws {
        // Given: SettingsViewModel
        let viewModel = SettingsViewModel()

        // When: Clearing cache
        await viewModel.clearCache()

        // Then: Should complete without error
        #expect(viewModel.errorMessage == nil)
    }

    @Test func exportsUserData() async throws {
        // Given: SettingsViewModel with a user identifier
        let viewModel = SettingsViewModel()
        viewModel.userId = UUID()

        // When: Exporting data
        await viewModel.exportUserData()

        // Then: Loading should stop even if export fails
        #expect(!viewModel.isLoading)
    }
}

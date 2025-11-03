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
}

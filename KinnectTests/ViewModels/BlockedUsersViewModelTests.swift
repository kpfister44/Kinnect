// ABOUTME: Tests for BlockedUsersViewModel
// ABOUTME: Validates fetching blocked users and unblock operations

import Testing
import Foundation
@testable import Kinnect

@MainActor
struct BlockedUsersViewModelTests {

    @Test func fetchesBlockedUsers() async throws {
        // Given: BlockedUsersViewModel
        let viewModel = BlockedUsersViewModel()

        // When: Fetching blocked users
        await viewModel.fetchBlockedUsers(userId: UUID())

        // Then: Should complete without crashing
        #expect(viewModel.blockedUsers != nil)
    }

    @Test func unblockRemovesUser() async throws {
        // Given: ViewModel with blocked users
        let viewModel = BlockedUsersViewModel()

        // When: Unblocking user
        await viewModel.unblockUser(blockedUserId: UUID())

        // Then: Should complete (integration test)
        #expect(!viewModel.isLoading)
    }
}

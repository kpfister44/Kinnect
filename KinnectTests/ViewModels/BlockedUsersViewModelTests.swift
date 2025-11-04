// ABOUTME: Tests for BlockedUsersViewModel
// ABOUTME: Integration tests - require real Supabase connection for meaningful validation

import Testing
import Foundation
@testable import Kinnect

@MainActor
struct BlockedUsersViewModelTests {

    @Test func initializesWithEmptyState() async throws {
        // Given/When: Creating new BlockedUsersViewModel
        let viewModel = BlockedUsersViewModel()

        // Then: Should initialize with empty state
        #expect(viewModel.blockedUsers.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func fetchBlockedUsersCompletesWithoutCrashing() async throws {
        // Given: BlockedUsersViewModel
        let viewModel = BlockedUsersViewModel()

        // When: Fetching blocked users (will fail without real auth)
        await viewModel.fetchBlockedUsers(userId: UUID())

        // Then: Should complete without crashing and reset loading state
        #expect(!viewModel.isLoading)
        // Note: blockedUsers will be empty without real database connection
        #expect(viewModel.blockedUsers.isEmpty)
    }

    @Test func unblockUserCompletesWithoutCrashing() async throws {
        // Given: ViewModel
        let viewModel = BlockedUsersViewModel()

        // When: Calling unblockUser (will fail without real auth)
        await viewModel.unblockUser(blockedUserId: UUID())

        // Then: Should complete without crashing and reset loading state
        #expect(!viewModel.isLoading)
    }

    @Test func unblockRequiresCurrentUserId() async throws {
        // Given: ViewModel without fetching (no currentUserId set)
        let viewModel = BlockedUsersViewModel()
        let testUserId = UUID()
        let mockProfile = Profile(
            id: testUserId,
            username: "testuser",
            avatarUrl: nil,
            fullName: nil,
            bio: nil,
            createdAt: Date()
        )

        // Manually add profile to simulate fetched state
        viewModel.blockedUsers = [mockProfile]
        #expect(viewModel.blockedUsers.count == 1)

        // When: Attempting to unblock without currentUserId set
        await viewModel.unblockUser(blockedUserId: testUserId)

        // Then: List should NOT be modified (defensive behavior)
        // Note: unblockUser guards against missing currentUserId
        #expect(viewModel.blockedUsers.count == 1)
        #expect(viewModel.errorMessage == nil) // No error, just early return
    }
}

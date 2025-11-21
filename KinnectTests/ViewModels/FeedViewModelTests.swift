// ABOUTME: Tests for FeedViewModel cache invalidation behavior
// ABOUTME: Ensures feed responds to notifications affecting cached posts

import Testing
import Foundation
@testable import Kinnect

@MainActor
struct FeedViewModelTests {

    @Test func blocksUpdateNotificationInvalidatesCache() async throws {
        // Given: FeedViewModel with stale cache flag
        let viewModel = FeedViewModel(currentUserId: UUID())
        viewModel.isCacheStale = true

        // When: Posting blocked users update notification
        NotificationCenter.default.post(name: .userDidUpdateBlockedUsers, object: nil)

        // Then: Cache should be invalidated
        #expect(viewModel.isCacheStale == false)
    }

    @Test func clearAllCachesNotificationInvalidatesFeedCache() async throws {
        // Given: FeedViewModel with cached state
        let viewModel = FeedViewModel(currentUserId: UUID())
        viewModel.isCacheStale = true

        // When: Triggering global cache clear
        NotificationCenter.default.post(name: .clearAllCaches, object: nil)

        // Then: Cache should be invalidated and marked not stale
        #expect(viewModel.isCacheStale == false)
    }
}

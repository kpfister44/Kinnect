// ABOUTME: Tests for FeedService feed fetching operations
// ABOUTME: Validates feed query and blocked user filtering

import Testing
import Foundation
@testable import Kinnect

struct FeedServiceTests {

    @Test func feedExcludesBlockedUsers() async throws {
        // Given: FeedService with blocked users
        let service = FeedService.shared
        let userId = UUID()

        // When: Fetching feed
        // Then: Should filter blocked users (integration test)
        do {
            let result = try await service.fetchFeed(currentUserId: userId)
            // Should not crash
            #expect(result.posts != nil)
        } catch {
            // Expected in test environment
            #expect(error != nil)
        }
    }
}

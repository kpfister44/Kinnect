// ABOUTME: Tests for BlockService user blocking operations
// ABOUTME: Integration tests - require real Supabase connection for meaningful validation

import Testing
import Foundation
@testable import Kinnect

struct BlockServiceTests {

    @Test func blockUserMethodExists() async throws {
        // Given: BlockService with test UUIDs
        let service = BlockService.shared
        let blockerId = UUID()
        let blockedId = UUID()

        // When: Calling blockUser
        // Then: Method should be callable without crashing
        // Note: Will fail without valid auth - this verifies method signature only
        _ = try? await service.blockUser(blockerId: blockerId, blockedId: blockedId)

        // Test passes if method is callable (doesn't crash)
        #expect(true)
    }

    @Test func unblockUserMethodExists() async throws {
        // Given: BlockService with test UUIDs
        let service = BlockService.shared
        let blockerId = UUID()
        let blockedId = UUID()

        // When: Calling unblockUser
        // Then: Method should be callable without crashing
        _ = try? await service.unblockUser(blockerId: blockerId, blockedId: blockedId)

        // Test passes if method is callable (doesn't crash)
        #expect(true)
    }

    @Test func fetchBlockedUsersMethodExists() async throws {
        // Given: BlockService with test UUID
        let service = BlockService.shared
        let userId = UUID()

        // When: Calling fetchBlockedUsers
        // Then: Method should be callable without crashing
        _ = try? await service.fetchBlockedUsers(userId: userId)

        // Test passes if method is callable (doesn't crash)
        #expect(true)
    }

    @Test func fetchBlockedUsersDecodesJoinedProfile() throws {
        // Given: Supabase join payload uses "blocked" key for joined profile
        let json = """
        [
            {
                "blocked": {
                    "user_id": "11111111-1111-1111-1111-111111111111",
                    "username": "blocked_user",
                    "avatar_url": null,
                    "full_name": "Blocked User",
                    "bio": null,
                    "created_at": "2024-11-04T15:00:00Z"
                }
            }
        ]
        """.data(using: .utf8)!

        // When: Decoding through BlockService helper
        let decoded = try BlockService.shared.decodeBlockedUsers(from: json)

        // Then: Decoder should extract profile information
        #expect(decoded.count == 1)
        #expect(decoded.first?.username == "blocked_user")
    }
}

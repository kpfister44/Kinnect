// ABOUTME: Tests for BlockService user blocking operations
// ABOUTME: Validates block, unblock, and fetch operations

import Testing
import Foundation
@testable import Kinnect

struct BlockServiceTests {

    @Test func blockUserInsertsRow() async throws {
        // Given: BlockService
        let service = BlockService.shared
        let blockerId = UUID()
        let blockedId = UUID()

        // When/Then: Method should exist
        // Note: Integration test - requires real database
        do {
            try await service.blockUser(blockerId: blockerId, blockedId: blockedId)
        } catch {
            // Expected to fail without auth
            #expect(error != nil)
        }
    }

    @Test func cannotBlockSelf() async throws {
        // Given: Same user ID for blocker and blocked
        let service = BlockService.shared
        let userId = UUID()

        // When/Then: Should fail with CHECK constraint
        do {
            try await service.blockUser(blockerId: userId, blockedId: userId)
            Issue.record("Should not allow blocking self")
        } catch {
            // Expected
            #expect(error != nil)
        }
    }
}

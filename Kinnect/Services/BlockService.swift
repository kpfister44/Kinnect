// ABOUTME: Service for user blocking and unblocking operations
// ABOUTME: Manages blocks table and provides filtering utilities

import Foundation
import Supabase

final class BlockService {
    static let shared = BlockService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Block Operations

    /// Block a user
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct BlockInsert: Encodable {
            let blockerId: String
            let blockedId: String

            enum CodingKeys: String, CodingKey {
                case blockerId = "blocker_id"
                case blockedId = "blocked_id"
            }
        }

        let insert = BlockInsert(
            blockerId: blockerId.uuidString,
            blockedId: blockedId.uuidString
        )

        try await client
            .from("blocks")
            .insert(insert)
            .execute()
    }

    /// Unblock a user
    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        try await client
            .from("blocks")
            .delete()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
    }

    /// Fetch list of blocked users
    func fetchBlockedUsers(userId: UUID) async throws -> [Profile] {
        struct BlockRow: Decodable {
            let blockedProfile: Profile

            enum CodingKeys: String, CodingKey {
                case blockedProfile = "blocked:profiles!blocked_id"
            }
        }

        let response = try await client
            .from("blocks")
            .select("blocked:profiles!blocked_id(*)")
            .eq("blocker_id", value: userId.uuidString)
            .execute()

        let rows = try JSONDecoder.supabase.decode([BlockRow].self, from: response.data)
        return rows.map { $0.blockedProfile }
    }

    /// Check if a user is blocked (either direction)
    func isBlocked(userId: UUID, targetUserId: UUID) async throws -> Bool {
        let response = try await client
            .from("blocks")
            .select("*", head: true, count: .exact)
            .or("and(blocker_id.eq.\(userId.uuidString),blocked_id.eq.\(targetUserId.uuidString)),and(blocker_id.eq.\(targetUserId.uuidString),blocked_id.eq.\(userId.uuidString))")
            .execute()

        return (response.count ?? 0) > 0
    }

    /// Get list of user IDs that are blocked bidirectionally (users I blocked OR users who blocked me)
    func getBlockedUserIds(userId: UUID) async throws -> [UUID] {
        struct BlockRow: Decodable {
            let blockerId: String
            let blockedId: String

            enum CodingKeys: String, CodingKey {
                case blockerId = "blocker_id"
                case blockedId = "blocked_id"
            }
        }

        // Fetch all blocks where I'm either the blocker or the blocked
        let response = try await client
            .from("blocks")
            .select("blocker_id, blocked_id")
            .or("blocker_id.eq.\(userId.uuidString),blocked_id.eq.\(userId.uuidString)")
            .execute()

        let rows = try JSONDecoder.supabase.decode([BlockRow].self, from: response.data)

        // Extract the "other" user ID from each block (not the current user)
        var blockedUserIds: Set<UUID> = []
        for row in rows {
            if let blockerId = UUID(uuidString: row.blockerId), blockerId != userId {
                blockedUserIds.insert(blockerId)
            }
            if let blockedId = UUID(uuidString: row.blockedId), blockedId != userId {
                blockedUserIds.insert(blockedId)
            }
        }

        return Array(blockedUserIds)
    }
}

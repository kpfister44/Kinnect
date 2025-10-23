//
//  LikeService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/23/25.
//

import Foundation
import Supabase

/// Service for managing likes on posts
final class LikeService {
    static let shared = LikeService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Like Operations

    /// Toggle like on a post. Returns true if now liked, false if now unliked.
    /// - Parameters:
    ///   - postId: The post to like/unlike
    ///   - userId: The user performing the action
    /// - Returns: Boolean indicating new state (true = liked, false = unliked)
    func toggleLike(postId: UUID, userId: UUID) async throws -> Bool {
        print("❤️ Toggling like on post \(postId) for user \(userId)")

        // Check if like already exists
        let existingLikes = try await checkLikeExists(postId: postId, userId: userId)

        if !existingLikes.isEmpty {
            // Like exists, so unlike (delete)
            print("💔 Unlike - removing like from database")
            try await deleteLike(postId: postId, userId: userId)
            return false
        } else {
            // Like doesn't exist, so like (insert)
            print("❤️ Like - adding like to database")
            try await insertLike(postId: postId, userId: userId)
            return true
        }
    }

    // MARK: - Private Methods

    /// Check if a like exists for a post by a user
    private func checkLikeExists(postId: UUID, userId: UUID) async throws -> [Like] {
        do {
            let response = try await client
                .from("likes")
                .select()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            let likes = try JSONDecoder.supabase.decode([Like].self, from: response.data)
            return likes
        } catch {
            print("❌ Failed to check like existence: \(error)")
            throw LikeServiceError.databaseError(error)
        }
    }

    /// Insert a new like
    private func insertLike(postId: UUID, userId: UUID) async throws {
        struct NewLike: Encodable {
            let postId: UUID
            let userId: UUID

            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case userId = "user_id"
            }
        }

        let newLike = NewLike(postId: postId, userId: userId)

        do {
            try await client
                .from("likes")
                .insert(newLike)
                .execute()
            print("✅ Like inserted successfully")
        } catch {
            print("❌ Failed to insert like: \(error)")
            throw LikeServiceError.databaseError(error)
        }
    }

    /// Delete an existing like
    private func deleteLike(postId: UUID, userId: UUID) async throws {
        do {
            try await client
                .from("likes")
                .delete()
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            print("✅ Like deleted successfully")
        } catch {
            print("❌ Failed to delete like: \(error)")
            throw LikeServiceError.databaseError(error)
        }
    }
}

// MARK: - Errors

enum LikeServiceError: LocalizedError {
    case databaseError(Error)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .databaseError(let error):
            return "Failed to update like: \(error.localizedDescription)"
        case .notAuthenticated:
            return "You must be signed in to like posts"
        }
    }
}

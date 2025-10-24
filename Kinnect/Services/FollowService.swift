//
//  FollowService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/24/25.
//

import Foundation
import Supabase

/// Service for managing follow relationships and user search
final class FollowService {
    static let shared = FollowService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Follow Operations

    /// Follow a user
    /// - Parameters:
    ///   - followerId: The user who is following
    ///   - followeeId: The user being followed
    func followUser(followerId: UUID, followeeId: UUID) async throws {
        print("👥 Following user: follower=\(followerId), followee=\(followeeId)")

        // Create follow relationship
        struct FollowInsert: Encodable {
            let follower: String
            let followee: String
        }

        let followData = FollowInsert(
            follower: followerId.uuidString,
            followee: followeeId.uuidString
        )

        try await client
            .from("follows")
            .insert(followData)
            .execute()

        print("✅ Follow successful")
    }

    /// Unfollow a user
    /// - Parameters:
    ///   - followerId: The user who is unfollowing
    ///   - followeeId: The user being unfollowed
    func unfollowUser(followerId: UUID, followeeId: UUID) async throws {
        print("👥 Unfollowing user: follower=\(followerId), followee=\(followeeId)")

        try await client
            .from("follows")
            .delete()
            .eq("follower", value: followerId.uuidString)
            .eq("followee", value: followeeId.uuidString)
            .execute()

        print("✅ Unfollow successful")
    }

    /// Check if a user is following another user
    /// - Parameters:
    ///   - followerId: The potential follower
    ///   - followeeId: The potential followee
    /// - Returns: True if followerId follows followeeId
    func checkFollowStatus(followerId: UUID, followeeId: UUID) async throws -> Bool {
        let response = try await client
            .from("follows")
            .select("*", head: true, count: .exact)
            .eq("follower", value: followerId.uuidString)
            .eq("followee", value: followeeId.uuidString)
            .execute()

        let isFollowing = (response.count ?? 0) > 0
        print("👥 Follow status check: \(isFollowing)")
        return isFollowing
    }

    // MARK: - Followers & Following Lists

    /// Get list of users following a specific user
    /// - Parameter userId: The user whose followers to fetch
    /// - Returns: Array of Profile objects
    func getFollowers(userId: UUID) async throws -> [Profile] {
        print("👥 Fetching followers for user: \(userId)")

        // Query follows table and join with profiles to get follower details
        let response = try await client
            .from("follows")
            .select("""
                follower,
                profiles!follows_follower_fkey(
                    user_id,
                    username,
                    avatar_url,
                    full_name,
                    bio,
                    created_at
                )
            """)
            .eq("followee", value: userId.uuidString)
            .execute()

        // Decode the response
        let followResponses = try JSONDecoder.supabase.decode([FollowerResponse].self, from: response.data)
        let profiles = followResponses.compactMap { $0.profiles }

        print("✅ Fetched \(profiles.count) followers")
        return profiles
    }

    /// Get list of users that a specific user is following
    /// - Parameter userId: The user whose following list to fetch
    /// - Returns: Array of Profile objects
    func getFollowing(userId: UUID) async throws -> [Profile] {
        print("👥 Fetching following for user: \(userId)")

        // Query follows table and join with profiles to get followee details
        let response = try await client
            .from("follows")
            .select("""
                followee,
                profiles!follows_followee_fkey(
                    user_id,
                    username,
                    avatar_url,
                    full_name,
                    bio,
                    created_at
                )
            """)
            .eq("follower", value: userId.uuidString)
            .execute()

        // Decode the response
        let followingResponses = try JSONDecoder.supabase.decode([FollowingResponse].self, from: response.data)
        let profiles = followingResponses.compactMap { $0.profiles }

        print("✅ Fetched \(profiles.count) following")
        return profiles
    }

    /// Get list of user IDs that a specific user is following
    /// - Parameter userId: The user whose following IDs to fetch
    /// - Returns: Array of user IDs
    func getFollowingIds(userId: UUID) async throws -> [UUID] {
        print("👥 Fetching following IDs for user: \(userId)")

        let response = try await client
            .from("follows")
            .select("followee")
            .eq("follower", value: userId.uuidString)
            .execute()

        struct FolloweeOnly: Decodable {
            let followee: UUID
        }

        let followees = try JSONDecoder.supabase.decode([FolloweeOnly].self, from: response.data)
        let ids = followees.map { $0.followee }

        print("✅ Fetched \(ids.count) following IDs")
        return ids
    }

    // MARK: - User Search

    /// Search for users by username (case-insensitive)
    /// - Parameter query: Search query string
    /// - Returns: Array of matching profiles (max 20)
    func searchUsers(query: String) async throws -> [Profile] {
        guard !query.isEmpty else {
            return []
        }

        print("🔍 Searching users with query: '\(query)'")

        // Use ilike for case-insensitive pattern matching
        // Pattern: %query% matches any username containing the query
        let pattern = "%\(query)%"

        let response = try await client
            .from("profiles")
            .select("user_id, username, avatar_url, full_name, bio, created_at")
            .ilike("username", pattern: pattern)
            .limit(20)
            .execute()

        let profiles = try JSONDecoder.supabase.decode([Profile].self, from: response.data)

        print("✅ Found \(profiles.count) users")
        return profiles
    }
}

// MARK: - Response Models

/// Response structure for followers query (joins follows with profiles)
private struct FollowerResponse: Decodable {
    let follower: UUID
    let profiles: Profile?
}

/// Response structure for following query (joins follows with profiles)
private struct FollowingResponse: Decodable {
    let followee: UUID
    let profiles: Profile?
}

// MARK: - Errors

enum FollowServiceError: LocalizedError {
    case alreadyFollowing
    case notFollowing
    case cannotFollowSelf
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .alreadyFollowing:
            return "You are already following this user"
        case .notFollowing:
            return "You are not following this user"
        case .cannotFollowSelf:
            return "You cannot follow yourself"
        case .userNotFound:
            return "User not found"
        }
    }
}

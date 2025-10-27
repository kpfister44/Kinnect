//
//  RealtimeService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/24/25.
//

import Foundation
import Supabase

/// Service for managing Supabase Realtime subscriptions for feed updates
final class RealtimeService {
    static let shared = RealtimeService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Channel Management

    /// Create and configure a Realtime channel for feed updates
    /// - Parameters:
    ///   - followedUserIds: List of user IDs that current user follows
    ///   - currentUserId: Current user's ID
    /// - Returns: Configured RealtimeChannelV2 (not yet subscribed)
    func createFeedChannel(
        followedUserIds: [UUID],
        currentUserId: UUID
    ) -> RealtimeChannelV2 {
        // Create unique channel name for this user's feed
        let channelName = "feed:\(currentUserId.uuidString)"

        print("📡 Creating Realtime channel: \(channelName)")

        let channel = client.realtimeV2.channel(channelName)

        return channel
    }

    // MARK: - Post Subscriptions

    /// Subscribe to new post insertions
    /// - Parameters:
    ///   - channel: The Realtime channel to subscribe on
    /// - Returns: Async stream of insert actions
    func subscribeToNewPosts(channel: RealtimeChannelV2) async -> some AsyncSequence {
        print("📡 Subscribing to posts INSERT events")
        return await channel.postgresChange(InsertAction.self, schema: "public", table: "posts")
    }

    // MARK: - Like Subscriptions

    /// Subscribe to like insertions
    /// - Parameters:
    ///   - channel: The Realtime channel to subscribe on
    /// - Returns: Async stream of insert actions
    func subscribeToLikeInserts(channel: RealtimeChannelV2) async -> some AsyncSequence {
        print("📡 Subscribing to likes INSERT events")
        return await channel.postgresChange(InsertAction.self, schema: "public", table: "likes")
    }

    /// Subscribe to like deletions
    /// - Parameters:
    ///   - channel: The Realtime channel to subscribe on
    /// - Returns: Async stream of delete actions
    func subscribeToLikeDeletes(channel: RealtimeChannelV2) async -> some AsyncSequence {
        print("📡 Subscribing to likes DELETE events")
        return await channel.postgresChange(DeleteAction.self, schema: "public", table: "likes")
    }

    // MARK: - Comment Subscriptions

    /// Subscribe to comment insertions
    /// - Parameters:
    ///   - channel: The Realtime channel to subscribe on
    /// - Returns: Async stream of insert actions
    func subscribeToCommentInserts(channel: RealtimeChannelV2) async -> some AsyncSequence {
        print("📡 Subscribing to comments INSERT events")
        return await channel.postgresChange(InsertAction.self, schema: "public", table: "comments")
    }

    /// Subscribe to comment deletions
    /// - Parameters:
    ///   - channel: The Realtime channel to subscribe on
    /// - Returns: Async stream of delete actions
    func subscribeToCommentDeletes(channel: RealtimeChannelV2) async -> some AsyncSequence {
        print("📡 Subscribing to comments DELETE events")
        return await channel.postgresChange(DeleteAction.self, schema: "public", table: "comments")
    }

    // MARK: - Activity Subscriptions

    /// Subscribe to new activity insertions
    /// - Parameters:
    ///   - channel: The Realtime channel to subscribe on
    /// - Returns: Async stream of insert actions
    func subscribeToActivityInserts(channel: RealtimeChannelV2) async -> some AsyncSequence {
        print("📡 Subscribing to activities INSERT events")
        return await channel.postgresChange(InsertAction.self, schema: "public", table: "activities")
    }

    /// Create and configure a Realtime channel for activity notifications
    /// - Parameter userId: Current user's ID
    /// - Returns: Configured RealtimeChannelV2 (not yet subscribed)
    func createActivityChannel(userId: UUID) -> RealtimeChannelV2 {
        let channelName = "activity:\(userId.uuidString)"
        print("📡 Creating Realtime channel: \(channelName)")
        return client.realtimeV2.channel(channelName)
    }

    // MARK: - Connection Management

    /// Subscribe to all configured callbacks and connect the channel
    /// - Parameter channel: The channel to subscribe
    func subscribe(channel: RealtimeChannelV2) async {
        print("📡 Subscribing to Realtime channel...")

        await channel.subscribe()

        print("✅ Realtime channel subscribed")
    }

    /// Unsubscribe and cleanup a channel
    /// - Parameter channel: The channel to cleanup
    func cleanup(channel: RealtimeChannelV2) async {
        print("📡 Cleaning up Realtime channel...")

        await channel.unsubscribe()

        print("✅ Realtime channel cleaned up")
    }
}

// MARK: - Realtime Event Models

/// Represents a post insert event from Realtime
struct RealtimePostInsert: Decodable {
    let id: UUID
    let author: UUID
    let caption: String?
    let mediaKey: String
    let mediaType: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case caption
        case mediaKey = "media_key"
        case mediaType = "media_type"
        case createdAt = "created_at"
    }
}

/// Represents a like event from Realtime (INSERT or DELETE)
struct RealtimeLikeEvent: Decodable {
    let postId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

/// Represents a comment event from Realtime (INSERT or DELETE)
struct RealtimeCommentEvent: Decodable {
    let id: UUID
    let postId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
    }
}

/// Represents an activity insert event from Realtime
struct RealtimeActivityInsert: Decodable {
    let id: UUID
    let userId: UUID
    let actorId: UUID
    let activityType: String
    let postId: UUID?
    let commentId: UUID?
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case activityType = "activity_type"
        case postId = "post_id"
        case commentId = "comment_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

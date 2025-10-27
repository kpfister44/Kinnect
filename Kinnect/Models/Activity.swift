//
//  Activity.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/26/25.
//

import Foundation

enum ActivityType: String, Codable {
    case like
    case comment
    case follow
}

struct Activity: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID           // recipient of the notification
    let actorId: UUID          // person who performed the action
    let activityType: ActivityType
    let postId: UUID?          // for likes and comments
    let commentId: UUID?       // for comments specifically
    let isRead: Bool
    let createdAt: Date

    // Relationships (not stored in DB, populated via joins)
    var actorProfile: Profile?  // actor's profile (username, avatar, etc.)

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

    // MARK: - Custom Initializer

    /// Create an Activity with optional actor profile
    init(
        id: UUID,
        userId: UUID,
        actorId: UUID,
        activityType: ActivityType,
        postId: UUID? = nil,
        commentId: UUID? = nil,
        isRead: Bool,
        createdAt: Date,
        actorProfile: Profile? = nil
    ) {
        self.id = id
        self.userId = userId
        self.actorId = actorId
        self.activityType = activityType
        self.postId = postId
        self.commentId = commentId
        self.isRead = isRead
        self.createdAt = createdAt
        self.actorProfile = actorProfile
    }

    // MARK: - Decodable

    /// Decode from database response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        actorId = try container.decode(UUID.self, forKey: .actorId)
        activityType = try container.decode(ActivityType.self, forKey: .activityType)
        postId = try container.decodeIfPresent(UUID.self, forKey: .postId)
        commentId = try container.decodeIfPresent(UUID.self, forKey: .commentId)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        actorProfile = nil // Will be populated separately from joins
    }
}

// MARK: - Grouped Activities

/// For grouping multiple likes on the same post
struct GroupedActivity: Identifiable, Equatable {
    let id: UUID                // Use first activity's ID as group ID
    let activityType: ActivityType
    let postId: UUID?
    let isRead: Bool
    let createdAt: Date         // Most recent activity time
    let actors: [Profile]       // All users who performed this action

    init(activities: [Activity]) {
        guard let first = activities.first else {
            fatalError("Cannot create GroupedActivity from empty array")
        }

        self.id = first.id
        self.activityType = first.activityType
        self.postId = first.postId
        self.isRead = activities.allSatisfy { $0.isRead }
        self.createdAt = activities.map { $0.createdAt }.max() ?? first.createdAt
        self.actors = activities.compactMap { $0.actorProfile }
    }
}

//
//  Comment.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation

struct Comment: Codable, Identifiable, Equatable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let body: String
    let createdAt: Date

    // Relationship (not stored in DB, populated via joins)
    var userProfile: Profile?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case body
        case createdAt = "created_at"
    }

    // MARK: - Custom Initializer

    /// Create a Comment with optional user profile
    init(id: UUID, postId: UUID, userId: UUID, body: String, createdAt: Date, userProfile: Profile? = nil) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.body = body
        self.createdAt = createdAt
        self.userProfile = userProfile
    }

    // MARK: - Decodable

    /// Decode from database response
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        postId = try container.decode(UUID.self, forKey: .postId)
        userId = try container.decode(UUID.self, forKey: .userId)
        body = try container.decode(String.self, forKey: .body)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        userProfile = nil // Will be populated separately from joins
    }
}

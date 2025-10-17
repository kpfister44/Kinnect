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
}

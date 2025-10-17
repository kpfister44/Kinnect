//
//  Like.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation

struct Like: Codable, Equatable {
    let postId: UUID
    let userId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

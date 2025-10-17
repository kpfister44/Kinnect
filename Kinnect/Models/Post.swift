//
//  Post.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation

struct Post: Codable, Identifiable, Equatable {
    let id: UUID
    let author: UUID
    var caption: String?
    let mediaKey: String
    let mediaType: MediaType
    let createdAt: Date

    // Relationships (not stored in DB, populated via joins)
    var authorProfile: Profile?
    var likeCount: Int = 0
    var commentCount: Int = 0
    var isLikedByCurrentUser: Bool = false

    enum MediaType: String, Codable {
        case photo
        case video
    }

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case caption
        case mediaKey = "media_key"
        case mediaType = "media_type"
        case createdAt = "created_at"
    }
}

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
    var likeCount: Int
    var commentCount: Int
    var isLikedByCurrentUser: Bool

    // Custom initializer to set default values for relationship properties
    init(
        id: UUID,
        author: UUID,
        caption: String? = nil,
        mediaKey: String,
        mediaType: MediaType,
        createdAt: Date,
        authorProfile: Profile? = nil,
        likeCount: Int = 0,
        commentCount: Int = 0,
        isLikedByCurrentUser: Bool = false
    ) {
        self.id = id
        self.author = author
        self.caption = caption
        self.mediaKey = mediaKey
        self.mediaType = mediaType
        self.createdAt = createdAt
        self.authorProfile = authorProfile
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
    }

    // Decodable initializer (required because we have a custom init)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        author = try container.decode(UUID.self, forKey: .author)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        mediaKey = try container.decode(String.self, forKey: .mediaKey)
        mediaType = try container.decode(MediaType.self, forKey: .mediaType)
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Relationship properties default to empty/zero
        authorProfile = nil
        likeCount = 0
        commentCount = 0
        isLikedByCurrentUser = false
    }

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

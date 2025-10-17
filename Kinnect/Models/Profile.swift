//
//  Profile.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    let username: String
    var avatarUrl: String?
    var fullName: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case fullName = "full_name"
        case createdAt = "created_at"
    }
}

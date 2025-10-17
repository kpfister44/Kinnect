//
//  Follow.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation

struct Follow: Codable, Equatable {
    let follower: UUID
    let followee: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case follower
        case followee
        case createdAt = "created_at"
    }
}

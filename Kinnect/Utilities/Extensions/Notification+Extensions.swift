//
//  Notification+Extensions.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/27/25.
//

import Foundation

extension Notification.Name {
    /// Posted when user logs out - used to clear caches
    static let userDidLogout = Notification.Name("userDidLogout")

    /// Posted when user creates a new post - used to invalidate feed cache
    static let userDidCreatePost = Notification.Name("userDidCreatePost")

    /// Posted when user updates their profile (avatar, etc.) - used to refresh feed cache
    static let userDidUpdateProfile = Notification.Name("userDidUpdateProfile")
}

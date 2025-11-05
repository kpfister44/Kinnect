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

    /// Posted when user follows or unfollows someone - used to invalidate feed cache
    static let userDidUpdateFollowing = Notification.Name("userDidUpdateFollowing")

    /// Posted when user updates blocked users list - used to invalidate feed cache
    static let userDidUpdateBlockedUsers = Notification.Name("userDidUpdateBlockedUsers")

    /// Posted when user deletes a post - used to sync deletion across ViewModels
    static let userDidDeletePost = Notification.Name("userDidDeletePost")

    /// Posted when user likes a post - used to sync like counts across ViewModels
    static let userDidLikePost = Notification.Name("userDidLikePost")

    /// Posted when user unlikes a post - used to sync like counts across ViewModels
    static let userDidUnlikePost = Notification.Name("userDidUnlikePost")

    /// Posted when user adds a comment - used to sync comment counts across ViewModels
    static let userDidCommentOnPost = Notification.Name("userDidCommentOnPost")

    /// Posted when user deletes a comment - used to sync comment counts across ViewModels
    static let userDidDeleteComment = Notification.Name("userDidDeleteComment")
}

// MARK: - Notification Payloads (Bug Fix #2: Prevent self-notification double-counting)

/// Payload for like/unlike notifications - includes source to prevent double-counting
struct LikeNotificationPayload {
    let postId: UUID
    let source: ViewModelSource
}

/// Payload for comment notifications - includes source to prevent double-counting
struct CommentNotificationPayload {
    let postId: UUID
    let source: ViewModelSource
}

/// Identifies which ViewModel posted the notification
enum ViewModelSource: String {
    case feedViewModel = "FeedViewModel"
    case profileFeedViewModel = "ProfileFeedViewModel"
}

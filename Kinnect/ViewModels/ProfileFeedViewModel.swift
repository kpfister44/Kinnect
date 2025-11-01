//
//  ProfileFeedViewModel.swift
//  Kinnect
//
//  Profile feed navigation feature - displays user's posts in feed format
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileFeedViewModel: ObservableObject, FeedInteractionViewModel {
    // MARK: - Published State
    @Published var posts: [Post] = []
    @Published var state: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - AsyncImage ID (for protocol conformance)
    /// Per-post reload tracking - only regenerate IDs for cancelled images
    var viewAppearanceID = UUID()

    /// Track reload counter per post - increment on cancellation to force new AsyncImage
    private var postReloadCounters: [UUID: Int] = [:]

    // MARK: - View Model Source (Bug Fix #2: Prevent self-notification double-counting)
    let viewModelSource: ViewModelSource = .profileFeedViewModel

    // MARK: - Dependencies
    private let profileService: ProfileService
    private let likeService: LikeService
    private let postService: PostService
    private let followService: FollowService
    let currentUserId: UUID

    // MARK: - Configuration
    private let userId: UUID // User whose posts we're displaying

    // MARK: - Loading State

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
    }

    // MARK: - Initialization

    init(
        userId: UUID,
        currentUserId: UUID,
        profileService: ProfileService? = nil,
        likeService: LikeService? = nil,
        postService: PostService? = nil,
        followService: FollowService? = nil
    ) {
        self.userId = userId
        self.currentUserId = currentUserId
        self.profileService = profileService ?? .shared
        self.likeService = likeService ?? .shared
        self.postService = postService ?? .shared
        self.followService = followService ?? .shared

        setupNotificationObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Listen for likes from other views (FeedView)
        NotificationCenter.default.addObserver(
            forName: .userDidLikePost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let payload = notification.object as? LikeNotificationPayload else { return }

            // Skip self-notifications (already handled optimistically)
            guard payload.source != .profileFeedViewModel else {
                print("⏭️ ProfileFeedViewModel skipping own like notification for post: \(payload.postId)")
                return
            }

            print("📡 ProfileFeedViewModel received like notification from \(payload.source.rawValue) for post: \(payload.postId)")

            // Update like count and liked state
            if let index = self.posts.firstIndex(where: { $0.id == payload.postId }) {
                self.posts[index].isLikedByCurrentUser = true
                self.posts[index].likeCount += 1
                print("✅ Updated like in ProfileFeedViewModel for post: \(payload.postId)")
            }
        }

        // Listen for unlikes from other views
        NotificationCenter.default.addObserver(
            forName: .userDidUnlikePost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let payload = notification.object as? LikeNotificationPayload else { return }

            // Skip self-notifications (already handled optimistically)
            guard payload.source != .profileFeedViewModel else {
                print("⏭️ ProfileFeedViewModel skipping own unlike notification for post: \(payload.postId)")
                return
            }

            print("📡 ProfileFeedViewModel received unlike notification from \(payload.source.rawValue) for post: \(payload.postId)")

            // Update like count and liked state
            if let index = self.posts.firstIndex(where: { $0.id == payload.postId }) {
                self.posts[index].isLikedByCurrentUser = false
                self.posts[index].likeCount = max(0, self.posts[index].likeCount - 1)
                print("✅ Updated unlike in ProfileFeedViewModel for post: \(payload.postId)")
            }
        }

        // Listen for comments from other views
        NotificationCenter.default.addObserver(
            forName: .userDidCommentOnPost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let payload = notification.object as? CommentNotificationPayload else { return }

            // Skip self-notifications (already handled optimistically)
            guard payload.source != .profileFeedViewModel else {
                print("⏭️ ProfileFeedViewModel skipping own comment notification for post: \(payload.postId)")
                return
            }

            print("📡 ProfileFeedViewModel received comment notification from \(payload.source.rawValue) for post: \(payload.postId)")

            // Update comment count
            if let index = self.posts.firstIndex(where: { $0.id == payload.postId }) {
                self.posts[index].commentCount += 1
                print("✅ Incremented comment count in ProfileFeedViewModel for post: \(payload.postId)")
            }
        }

        // Listen for comment deletions from other views
        NotificationCenter.default.addObserver(
            forName: .userDidDeleteComment,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let payload = notification.object as? CommentNotificationPayload else { return }

            // Skip self-notifications (already handled optimistically)
            guard payload.source != .profileFeedViewModel else {
                print("⏭️ ProfileFeedViewModel skipping own comment deletion notification for post: \(payload.postId)")
                return
            }

            print("📡 ProfileFeedViewModel received comment deletion notification from \(payload.source.rawValue) for post: \(payload.postId)")

            // Update comment count
            if let index = self.posts.firstIndex(where: { $0.id == payload.postId }) {
                self.posts[index].commentCount = max(0, self.posts[index].commentCount - 1)
                print("✅ Decremented comment count in ProfileFeedViewModel for post: \(payload.postId)")
            }
        }
    }

    // MARK: - Public Methods

    /// Load posts for the specific user
    func loadPosts() async {
        print("📱 Loading posts for user: \(userId)")

        state = .loading
        errorMessage = nil

        do {
            // Fetch all posts for this user (ProfileService handles signed URLs and like/comment counts)
            let fetchedPosts = try await profileService.fetchUserPosts(userId: userId, currentUserId: currentUserId)

            // Posts are already sorted newest-first by ProfileService
            posts = fetchedPosts

            state = .loaded
            print("✅ Loaded \(posts.count) posts for user \(userId)")

        } catch {
            print("❌ Failed to load posts: \(error)")
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    /// Get media URL for display (already in post)
    func getMediaURL(for post: Post) -> URL? {
        return post.mediaURL
    }

    // MARK: - Actions

    /// Toggle like with optimistic UI update
    func toggleLike(forPostID postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            return
        }

        // Store previous state for rollback if needed
        let previousLikedState = posts[index].isLikedByCurrentUser
        let previousLikeCount = posts[index].likeCount

        // Optimistic update (immediate UI feedback)
        posts[index].isLikedByCurrentUser.toggle()
        posts[index].likeCount += posts[index].isLikedByCurrentUser ? 1 : -1

        // Perform async like operation
        Task {
            do {
                let newLikedState = try await likeService.toggleLike(
                    postId: postID,
                    userId: currentUserId
                )

                // Verify optimistic update matches server response
                if posts[index].isLikedByCurrentUser != newLikedState {
                    print("⚠️ Optimistic update mismatch, correcting...")
                    posts[index].isLikedByCurrentUser = newLikedState
                    posts[index].likeCount = previousLikeCount + (newLikedState ? 1 : -1)
                }

                print("✅ Like toggled successfully: \(newLikedState ? "liked" : "unliked")")

                // Notify other ViewModels about like state change (with source to prevent self-notification)
                if newLikedState {
                    let payload = LikeNotificationPayload(postId: postID, source: .profileFeedViewModel)
                    NotificationCenter.default.post(name: .userDidLikePost, object: payload)
                    print("📡 Posted userDidLikePost notification for post: \(postID) from ProfileFeedViewModel")
                } else {
                    let payload = LikeNotificationPayload(postId: postID, source: .profileFeedViewModel)
                    NotificationCenter.default.post(name: .userDidUnlikePost, object: payload)
                    print("📡 Posted userDidUnlikePost notification for post: \(postID) from ProfileFeedViewModel")
                }
            } catch {
                print("❌ Failed to toggle like: \(error)")

                // Revert optimistic update on error
                posts[index].isLikedByCurrentUser = previousLikedState
                posts[index].likeCount = previousLikeCount

                // Show error to user
                errorMessage = "Failed to \(previousLikedState ? "unlike" : "like") post. Please try again."
            }
        }
    }

    /// Update comment count for a post (optimistic update from CommentViewModel)
    func updateCommentCount(for postId: UUID, newCount: Int) {
        // Update posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].commentCount = newCount
        }

        print("✅ Updated comment count to \(newCount) for post: \(postId)")
    }

    /// Delete a post (optimistic UI)
    /// Note: Caller should handle navigation/dismiss after successful deletion
    func deletePost(_ post: Post) async {
        print("🗑️ Initiating post deletion: \(post.id)")

        // Step 1: Store original state for rollback
        let originalPosts = posts

        // Step 2: Optimistic update - remove from UI immediately
        posts.removeAll(where: { $0.id == post.id })
        print("✅ Post removed from UI")

        // Step 3: Execute API call in background
        do {
            try await postService.deletePost(
                postId: post.id,
                userId: currentUserId,
                mediaKey: post.mediaKey
            )
            print("✅ Post deletion successful")

            // Step 4: Notify other ViewModels about deletion
            NotificationCenter.default.post(name: .userDidDeletePost, object: post.id)
            print("📡 Posted userDidDeletePost notification for post: \(post.id)")

            // Keep UI state (post already removed)

        } catch {
            print("❌ Post deletion failed: \(error)")

            // Step 4: Rollback on error
            posts = originalPosts
            errorMessage = error.localizedDescription
            print("🔄 Rolled back post deletion")
        }
    }

    /// Unfollow post author
    /// Note: Caller should handle navigation/dismiss after successful unfollow
    func unfollowPostAuthor(_ post: Post) async {
        let authorId = post.author

        guard let authorUsername = post.authorProfile?.username else {
            print("❌ Cannot unfollow: post has no author profile")
            return
        }

        print("👥 Unfollowing user: \(authorUsername)")

        // Step 1: Store original state for rollback
        let originalPosts = posts

        // Step 2: Optimistic update - remove all posts from this author
        posts.removeAll(where: { $0.author == authorId })
        print("✅ Removed \(authorUsername)'s posts from feed")

        // Step 3: Execute API call in background
        do {
            try await followService.unfollowUser(
                followerId: currentUserId,
                followeeId: authorId
            )
            print("✅ Unfollowed \(authorUsername)")
            // Keep UI state (posts already removed)

        } catch {
            print("❌ Unfollow failed: \(error)")

            // Step 4: Rollback on error
            posts = originalPosts
            errorMessage = error.localizedDescription
            print("🔄 Rolled back unfollow")
        }
    }

    /// Record image cancellation - increment reload counter to force AsyncImage recreation
    /// AsyncImage caches failure states, so we need new ID to bypass cache
    func recordImageCancellation(for postID: UUID) {
        let newCounter = (postReloadCounters[postID] ?? 0) + 1
        postReloadCounters[postID] = newCounter
        print("📝 Image cancelled for post: \(postID) - reload counter: \(newCounter)")

        // Trigger view update to force AsyncImage recreation with new ID
        objectWillChange.send()
    }

    /// Get unique AsyncImage ID for a post
    /// Uses counter that increments on cancellation to force new AsyncImage instances
    func getAsyncImageID(for postID: UUID) -> String {
        let counter = postReloadCounters[postID] ?? 0
        return "\(postID.uuidString)-\(counter)"
    }
}

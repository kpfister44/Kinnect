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
    }

    // MARK: - Public Methods

    /// Load posts for the specific user
    func loadPosts() async {
        print("📱 Loading posts for user: \(userId)")

        state = .loading
        errorMessage = nil

        do {
            // Fetch all posts for this user (ProfileService handles signed URLs)
            let fetchedPosts = try await profileService.fetchUserPosts(userId: userId)

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

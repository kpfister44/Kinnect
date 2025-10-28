//
//  FeedViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class FeedViewModel: ObservableObject {
    // MARK: - Published State
    @Published var posts: [Post] = []
    @Published var state: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Realtime State (Phase 9)
    @Published var pendingNewPostsCount: Int = 0
    @Published var showNewPostsBanner: Bool = false

    // MARK: - Cache State (Phase 10)
    @Published var isCacheStale: Bool = false
    private var cachedPosts: [Post] = []
    private var cacheTimestamp: Date?
    private let cacheTTL: TimeInterval = 45 * 60 // 45 minutes (under signed URL 1hr expiry)
    private let staleCacheThreshold: TimeInterval = 5 * 60 // 5 minutes

    // MARK: - Dependencies
    private let feedService: FeedService
    private let likeService: LikeService
    private let realtimeService: RealtimeService
    private let postService: PostService
    private let followService: FollowService
    let currentUserId: UUID // Exposed for comment sheet

    // MARK: - Pagination
    private var currentOffset = 0
    private let pageSize = 20
    private var canLoadMore = true

    // MARK: - Realtime (Phase 9)
    private var realtimeChannel: RealtimeChannelV2?
    private var followedUserIds: [UUID] = []

    // MARK: - Initialization

    init(
        feedService: FeedService? = nil,
        likeService: LikeService? = nil,
        realtimeService: RealtimeService? = nil,
        postService: PostService? = nil,
        followService: FollowService? = nil,
        currentUserId: UUID
    ) {
        self.feedService = feedService ?? .shared
        self.likeService = likeService ?? .shared
        self.realtimeService = realtimeService ?? .shared
        self.postService = postService ?? .shared
        self.followService = followService ?? .shared
        self.currentUserId = currentUserId

        // Observe logout notifications to clear cache (Phase 10)
        setupLogoutObserver()
    }

    deinit {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Logout Observer

    private func setupLogoutObserver() {
        NotificationCenter.default.addObserver(
            forName: .userDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
            print("🗑️ Cache cleared on logout")
        }
    }

    // MARK: - Loading State

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
    }

    // MARK: - Cache Helper Methods

    /// Check if cache is valid (not expired)
    private func isCacheValidCheck() -> Bool {
        guard let timestamp = cacheTimestamp else { return false }
        let age = Date().timeIntervalSince(timestamp)
        return age < cacheTTL
    }

    /// Check if cache is stale (old but still valid)
    private func isCacheStaleCheck() -> Bool {
        guard let timestamp = cacheTimestamp else { return false }
        let age = Date().timeIntervalSince(timestamp)
        return age >= staleCacheThreshold && age < cacheTTL
    }

    /// Calculate cache age in seconds
    private func cacheAge() -> Int {
        guard let timestamp = cacheTimestamp else { return 0 }
        return Int(Date().timeIntervalSince(timestamp))
    }

    /// Invalidate (clear) cache
    func invalidateCache() {
        cachedPosts = []
        cacheTimestamp = nil
        isCacheStale = false
        print("🗑️ Cache invalidated")
    }

    /// Update cache with fresh posts
    private func updateCache(with posts: [Post]) {
        cachedPosts = posts
        cacheTimestamp = Date()
        isCacheStale = false
        print("💾 Cache updated with \(posts.count) posts")
    }

    // MARK: - Public Methods

    /// Load the feed (called on view appear)
    func loadFeed(forceRefresh: Bool = false) async {
        // If force refresh requested, skip cache
        if forceRefresh {
            print("🔄 Force refresh - bypassing cache")
            currentOffset = 0
            canLoadMore = true
            await fetchPosts(isRefresh: true)
            return
        }

        // Check if cache is valid
        if isCacheValidCheck() {
            // Use cached data
            posts = cachedPosts
            state = .loaded
            isCacheStale = isCacheStaleCheck()

            print("✅ Loaded feed from cache (age: \(cacheAge())s, stale: \(isCacheStale))")

            // Restore pagination state based on cached posts
            currentOffset = cachedPosts.count
            canLoadMore = cachedPosts.count >= pageSize
            return
        }

        // Cache expired or empty - fetch fresh
        print("🌐 Cache miss - fetching fresh feed")
        currentOffset = 0
        canLoadMore = true
        await fetchPosts(isRefresh: true)
    }

    /// Load more posts (pagination)
    func loadMorePostsIfNeeded(currentPost: Post) async {
        // Check if we're near the end of the list
        guard let lastPost = posts.last,
              lastPost.id == currentPost.id,
              canLoadMore,
              state != .loading else {
            return
        }

        await fetchPosts(isRefresh: false)
    }

    /// Refresh the feed
    func refresh() async {
        await loadFeed()
    }

    // MARK: - Private Methods

    /// Fetch posts from Supabase
    private func fetchPosts(isRefresh: Bool) async {
        if isRefresh {
            state = .loading
            posts = []
        }

        do {
            let newPosts = try await feedService.fetchFeed(
                currentUserId: currentUserId,
                limit: pageSize,
                offset: currentOffset
            )

            if isRefresh {
                posts = newPosts
                // Update cache on initial refresh
                updateCache(with: newPosts)
            } else {
                posts.append(contentsOf: newPosts)
                // Update cache with full list after pagination
                updateCache(with: posts)
            }

            // Update pagination
            currentOffset += newPosts.count
            canLoadMore = newPosts.count >= pageSize

            state = .loaded
            errorMessage = nil

            print("✅ Feed loaded: \(posts.count) total posts")
        } catch {
            print("❌ Failed to load feed: \(error)")
            state = .error
            errorMessage = error.localizedDescription

            // If refresh failed, keep existing posts
            if !isRefresh {
                // Reset offset on error
                currentOffset = max(0, currentOffset - pageSize)
            }
        }
    }

    // MARK: - Media URLs

    /// Get media URL for display (already fetched in post)
    func getMediaURL(for post: Post) -> URL? {
        return post.mediaURL
    }

    // MARK: - Actions (Phase 7)

    /// Handle like action with optimistic update and error handling
    func toggleLike(forPostID postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else {
            return
        }

        // Find post in cache as well
        let cacheIndex = cachedPosts.firstIndex(where: { $0.id == postID })

        // Store previous state for rollback if needed
        let previousLikedState = posts[index].isLikedByCurrentUser
        let previousLikeCount = posts[index].likeCount

        // Optimistic update (immediate UI feedback)
        posts[index].isLikedByCurrentUser.toggle()
        posts[index].likeCount += posts[index].isLikedByCurrentUser ? 1 : -1

        // Also update cache optimistically
        if let cacheIndex = cacheIndex {
            cachedPosts[cacheIndex].isLikedByCurrentUser.toggle()
            cachedPosts[cacheIndex].likeCount += cachedPosts[cacheIndex].isLikedByCurrentUser ? 1 : -1
        }

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

                    // Correct cache as well
                    if let cacheIndex = cacheIndex {
                        cachedPosts[cacheIndex].isLikedByCurrentUser = newLikedState
                        cachedPosts[cacheIndex].likeCount = previousLikeCount + (newLikedState ? 1 : -1)
                    }
                }

                print("✅ Like toggled successfully: \(newLikedState ? "liked" : "unliked")")
            } catch {
                print("❌ Failed to toggle like: \(error)")

                // Revert optimistic update on error
                posts[index].isLikedByCurrentUser = previousLikedState
                posts[index].likeCount = previousLikeCount

                // Revert cache as well
                if let cacheIndex = cacheIndex {
                    cachedPosts[cacheIndex].isLikedByCurrentUser = previousLikedState
                    cachedPosts[cacheIndex].likeCount = previousLikeCount
                }

                // Show error to user
                errorMessage = "Failed to \(previousLikedState ? "unlike" : "like") post. Please try again."
            }
        }
    }

    // MARK: - Realtime Updates (Phase 9)

    /// Setup Realtime subscriptions for feed updates
    func setupRealtimeSubscriptions() async {
        // Get list of followed user IDs
        do {
            let followService = FollowService.shared
            followedUserIds = try await followService.getFollowingIds(userId: currentUserId)
            print("📡 Setting up Realtime for \(followedUserIds.count) followed users")
        } catch {
            print("❌ Failed to get following IDs for Realtime: \(error)")
            // Continue without Realtime - feed still works normally
            return
        }

        // Create Realtime channel
        let channel = realtimeService.createFeedChannel(
            followedUserIds: followedUserIds,
            currentUserId: currentUserId
        )

        // Subscribe to new posts
        let postInserts = await realtimeService.subscribeToNewPosts(channel: channel)

        // Subscribe to likes
        let likeInserts = await realtimeService.subscribeToLikeInserts(channel: channel)
        let likeDeletes = await realtimeService.subscribeToLikeDeletes(channel: channel)

        // Subscribe to comments
        let commentInserts = await realtimeService.subscribeToCommentInserts(channel: channel)
        let commentDeletes = await realtimeService.subscribeToCommentDeletes(channel: channel)

        // Connect to Realtime
        await realtimeService.subscribe(channel: channel)

        // Store channel reference for cleanup
        realtimeChannel = channel

        // Start listening to streams
        Task {
            do {
                for try await action in postInserts {
                    let insertAction = action as! InsertAction

                    // Extract values from dictionary
                    guard let idString = insertAction.record["id"]?.value as? String,
                          let id = UUID(uuidString: idString),
                          let authorString = insertAction.record["author"]?.value as? String,
                          let author = UUID(uuidString: authorString) else {
                        print("❌ Failed to parse post insert event")
                        continue
                    }

                    let post = RealtimePostInsert(
                        id: id,
                        author: author,
                        caption: insertAction.record["caption"]?.value as? String,
                        mediaKey: insertAction.record["media_key"]?.value as? String ?? "",
                        mediaType: insertAction.record["media_type"]?.value as? String ?? "photo",
                        createdAt: Date()
                    )

                    await handleNewPostEvent(post)
                }
            } catch {
                print("❌ Post subscription error: \(error)")
            }
        }

        Task {
            do {
                for try await action in likeInserts {
                    let insertAction = action as! InsertAction

                    // Extract values from dictionary
                    guard let postIdString = insertAction.record["post_id"]?.value as? String,
                          let postId = UUID(uuidString: postIdString),
                          let userIdString = insertAction.record["user_id"]?.value as? String,
                          let userId = UUID(uuidString: userIdString) else {
                        print("❌ Failed to parse like insert event")
                        continue
                    }

                    await handleLikeInsertEvent(postId: postId, userId: userId)
                }
            } catch {
                print("❌ Like insert subscription error: \(error)")
            }
        }

        Task {
            do {
                for try await action in likeDeletes {
                    let deleteAction = action as! DeleteAction

                    // Extract values from dictionary
                    guard let postIdString = deleteAction.oldRecord["post_id"]?.value as? String,
                          let postId = UUID(uuidString: postIdString),
                          let userIdString = deleteAction.oldRecord["user_id"]?.value as? String,
                          let userId = UUID(uuidString: userIdString) else {
                        print("❌ Failed to parse like delete event")
                        continue
                    }

                    await handleLikeDeleteEvent(postId: postId, userId: userId)
                }
            } catch {
                print("❌ Like delete subscription error: \(error)")
            }
        }

        Task {
            do {
                for try await action in commentInserts {
                    let insertAction = action as! InsertAction

                    // Extract values from dictionary
                    guard let postIdString = insertAction.record["post_id"]?.value as? String,
                          let postId = UUID(uuidString: postIdString) else {
                        print("❌ Failed to parse comment insert event")
                        continue
                    }

                    await handleCommentInsertEvent(postId: postId)
                }
            } catch {
                print("❌ Comment insert subscription error: \(error)")
            }
        }

        Task {
            do {
                for try await action in commentDeletes {
                    let deleteAction = action as! DeleteAction

                    // Extract values from dictionary
                    guard let postIdString = deleteAction.oldRecord["post_id"]?.value as? String,
                          let postId = UUID(uuidString: postIdString) else {
                        print("❌ Failed to parse comment delete event")
                        continue
                    }

                    await handleCommentDeleteEvent(postId: postId)
                }
            } catch {
                print("❌ Comment delete subscription error: \(error)")
            }
        }
    }

    /// Cleanup Realtime subscriptions
    func cleanupRealtimeSubscriptions() async {
        guard let channel = realtimeChannel else { return }

        await realtimeService.cleanup(channel: channel)
        realtimeChannel = nil

        print("📡 Realtime subscriptions cleaned up")
    }

    /// Handle new post insert event
    @MainActor
    private func handleNewPostEvent(_ insertedPost: RealtimePostInsert) async {
        // Filter: Only posts from followed users or self
        guard followedUserIds.contains(insertedPost.author) ||
              insertedPost.author == currentUserId else {
            print("📡 Ignoring post from unfollowed user")
            return
        }

        // Don't auto-insert - just increment counter and show banner
        pendingNewPostsCount += 1
        showNewPostsBanner = true

        print("📡 New post detected! Total pending: \(pendingNewPostsCount)")
    }

    /// Handle like insert event
    @MainActor
    private func handleLikeInsertEvent(postId: UUID, userId: UUID) async {
        // Skip if current user (already handled optimistically in toggleLike)
        guard userId != currentUserId else {
            print("📡 Ignoring own like event (handled optimistically)")
            return
        }

        // Update posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].likeCount += 1
        }

        // Update cache as well
        if let cacheIndex = cachedPosts.firstIndex(where: { $0.id == postId }) {
            cachedPosts[cacheIndex].likeCount += 1
        }

        print("📡 Like added to post \(postId) by user \(userId)")
    }

    /// Handle like delete event
    @MainActor
    private func handleLikeDeleteEvent(postId: UUID, userId: UUID) async {
        // Skip if current user (already handled optimistically in toggleLike)
        guard userId != currentUserId else {
            print("📡 Ignoring own unlike event (handled optimistically)")
            return
        }

        // Update posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].likeCount = max(0, posts[index].likeCount - 1)
        }

        // Update cache as well
        if let cacheIndex = cachedPosts.firstIndex(where: { $0.id == postId }) {
            cachedPosts[cacheIndex].likeCount = max(0, cachedPosts[cacheIndex].likeCount - 1)
        }

        print("📡 Like removed from post \(postId) by user \(userId)")
    }

    /// Handle comment insert event
    @MainActor
    private func handleCommentInsertEvent(postId: UUID) async {
        // Update posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].commentCount += 1
        }

        // Update cache as well
        if let cacheIndex = cachedPosts.firstIndex(where: { $0.id == postId }) {
            cachedPosts[cacheIndex].commentCount += 1
        }

        print("📡 Comment added to post \(postId)")
    }

    /// Handle comment delete event
    @MainActor
    private func handleCommentDeleteEvent(postId: UUID) async {
        // Update posts array
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].commentCount = max(0, posts[index].commentCount - 1)
        }

        // Update cache as well
        if let cacheIndex = cachedPosts.firstIndex(where: { $0.id == postId }) {
            cachedPosts[cacheIndex].commentCount = max(0, cachedPosts[cacheIndex].commentCount - 1)
        }

        print("📡 Comment removed from post \(postId)")
    }

    /// Scroll to top and load new posts (triggered by banner tap)
    func scrollToTopAndLoadNewPosts() async {
        // Reset banner state
        pendingNewPostsCount = 0
        showNewPostsBanner = false

        // Refresh feed
        await loadFeed(forceRefresh: true)

        print("📡 Loaded new posts and scrolled to top")
    }

    /// Refresh feed from stale cache banner (Phase 10)
    func refreshFeedFromBanner() async {
        print("🔄 User tapped stale cache banner - fetching fresh feed")

        // Hide stale banner
        isCacheStale = false

        // Force refresh to bypass cache
        await loadFeed(forceRefresh: true)

        print("✅ Feed refreshed from stale cache banner")
    }

    // MARK: - Post Actions

    /// Delete a post (optimistic UI)
    func deletePost(_ post: Post) async {
        print("🗑️ Initiating post deletion: \(post.id)")

        // Step 1: Store original state for rollback
        let originalPosts = posts
        let originalCachedPosts = cachedPosts

        // Step 2: Optimistic update - remove from UI immediately
        posts.removeAll(where: { $0.id == post.id })
        cachedPosts.removeAll(where: { $0.id == post.id })
        print("✅ Post removed from UI and cache")

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
            cachedPosts = originalCachedPosts
            errorMessage = error.localizedDescription
            print("🔄 Rolled back post deletion")
        }
    }

    /// Unfollow post author and remove their posts from feed
    func unfollowPostAuthor(_ post: Post) async {
        let authorId = post.author

        guard let authorUsername = post.authorProfile?.username else {
            print("❌ Cannot unfollow: post has no author profile")
            return
        }

        print("👥 Unfollowing user: \(authorUsername)")

        // Step 1: Store original state for rollback
        let originalPosts = posts
        let originalCachedPosts = cachedPosts

        // Step 2: Optimistic update - remove all posts from this author
        posts.removeAll(where: { $0.author == authorId })
        cachedPosts.removeAll(where: { $0.author == authorId })
        print("✅ Removed \(authorUsername)'s posts from feed and cache")

        // Step 3: Execute API call in background
        do {
            try await followService.unfollowUser(
                followerId: currentUserId,
                followeeId: authorId
            )
            print("✅ Unfollowed \(authorUsername)")
            // Keep UI state (posts already removed)

            // Step 4: Update followedUserIds for realtime filtering
            followedUserIds.removeAll(where: { $0 == authorId })

        } catch {
            print("❌ Unfollow failed: \(error)")

            // Step 5: Rollback on error
            posts = originalPosts
            cachedPosts = originalCachedPosts
            errorMessage = error.localizedDescription
            print("🔄 Rolled back unfollow")
        }
    }

}

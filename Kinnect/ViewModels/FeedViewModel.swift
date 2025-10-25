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

    // MARK: - Dependencies
    private let feedService: FeedService
    private let likeService: LikeService
    private let realtimeService: RealtimeService
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
        feedService: FeedService = .shared,
        likeService: LikeService = .shared,
        realtimeService: RealtimeService = .shared,
        currentUserId: UUID
    ) {
        self.feedService = feedService
        self.likeService = likeService
        self.realtimeService = realtimeService
        self.currentUserId = currentUserId
    }

    // MARK: - Loading State

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
    }

    // MARK: - Public Methods

    /// Load the feed (called on view appear)
    func loadFeed() async {
        // Reset pagination
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
            } else {
                posts.append(contentsOf: newPosts)
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

        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return // Post not in current feed
        }

        // Increment like count for other users only
        posts[index].likeCount += 1

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

        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return // Post not in current feed
        }

        // Decrement like count for other users only (ensure it doesn't go negative)
        posts[index].likeCount = max(0, posts[index].likeCount - 1)

        print("📡 Like removed from post \(postId) by user \(userId)")
    }

    /// Handle comment insert event
    @MainActor
    private func handleCommentInsertEvent(postId: UUID) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return // Post not in current feed
        }

        // Increment comment count
        posts[index].commentCount += 1

        print("📡 Comment added to post \(postId)")
    }

    /// Handle comment delete event
    @MainActor
    private func handleCommentDeleteEvent(postId: UUID) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else {
            return // Post not in current feed
        }

        // Decrement comment count (ensure it doesn't go negative)
        posts[index].commentCount = max(0, posts[index].commentCount - 1)

        print("📡 Comment removed from post \(postId)")
    }

    /// Scroll to top and load new posts (triggered by banner tap)
    func scrollToTopAndLoadNewPosts() async {
        // Reset banner state
        pendingNewPostsCount = 0
        showNewPostsBanner = false

        // Refresh feed
        await loadFeed()

        print("📡 Loaded new posts and scrolled to top")
    }

}

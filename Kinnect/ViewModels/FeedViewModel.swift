//
//  FeedViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class FeedViewModel: ObservableObject {
    // MARK: - Published State
    @Published var posts: [Post] = []
    @Published var state: LoadingState = .idle
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let feedService: FeedService
    private let likeService: LikeService
    let currentUserId: UUID // Exposed for comment sheet

    // MARK: - Pagination
    private var currentOffset = 0
    private let pageSize = 20
    private var canLoadMore = true

    // MARK: - Initialization

    init(feedService: FeedService = .shared, likeService: LikeService = .shared, currentUserId: UUID) {
        self.feedService = feedService
        self.likeService = likeService
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

}

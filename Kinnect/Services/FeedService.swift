//
//  FeedService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation
import Supabase

/// Service for fetching and managing the feed
struct FeedFetchResult {
    let posts: [Post]
    let requestedCount: Int
    let incompletePostIDs: [UUID]
}

final class FeedService {
    static let shared = FeedService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Feed Fetching

    /// Fetch posts from followed users (and own posts) with pagination
    /// - Parameters:
    ///   - currentUserId: The current user's ID
    ///   - limit: Number of posts to fetch (default: 20)
    ///   - offset: Offset for pagination (default: 0)
    /// - Returns: Array of fully-formed Post objects ready to display
    func fetchFeed(
        currentUserId: UUID,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> FeedFetchResult {
        print("📱 Fetching feed for user: \(currentUserId), limit: \(limit), offset: \(offset)")

        // Step 1: Get list of user IDs that current user follows
        let followService = FollowService.shared
        let followedUserIds = try await followService.getFollowingIds(userId: currentUserId)

        // Step 2: Build list of author IDs (followed users + current user)
        var authorIds = followedUserIds
        authorIds.append(currentUserId)

        print("📱 Fetching posts from \(authorIds.count) users (including self)")

        // Step 3: Fetch posts from these authors
        let response = try await client
            .from("posts")
            .select("""
                *,
                profiles!posts_author_fkey(
                    user_id,
                    username,
                    avatar_url,
                    full_name,
                    bio,
                    created_at
                )
            """)
            .in("author", values: authorIds.map { $0.uuidString })
            .order("created_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        // Decode posts with embedded profile data
        let postResponses = try JSONDecoder.supabase.decode([PostResponse].self, from: response.data)

        print("✅ Fetched \(postResponses.count) posts")

        // Transform responses into fully-formed Post objects
        // Use detached task so it completes even if view disappears (prevents partial cache)
        return try await Task.detached { [postResponses, currentUserId, client] in
            return try await withThrowingTaskGroup(of: (Int, Post).self) { group in
                // Pre-populate posts array in database order (preserves chronological ordering)
                var posts = postResponses.map { response in
                    var post = response.post
                    post.authorProfile = response.profiles
                    return post
                }

                // Add all posts to task group for concurrent processing
                // Return (index, post) tuples to preserve database ordering
                for (index, postResponse) in postResponses.enumerated() {
                    group.addTask {
                        do {
                            var post = postResponse.post

                            // Set author profile
                            post.authorProfile = postResponse.profiles

                            // Fetch all post data concurrently with timeout
                            try await withThrowingTaskGroup(of: Void.self) { dataGroup in
                                // Fetch signed URL with timeout
                                dataGroup.addTask {
                                    post.mediaURL = try await withTimeout(seconds: 10) {
                                        try await client.storage
                                            .from("posts")
                                            .createSignedURL(path: post.mediaKey, expiresIn: 3600)
                                    }
                                }

                                // Fetch like count with timeout
                                dataGroup.addTask {
                                    post.likeCount = try await withTimeout(seconds: 10) {
                                        let response = try await client
                                            .from("likes")
                                            .select("*", head: true, count: .exact)
                                            .eq("post_id", value: post.id.uuidString)
                                            .execute()
                                        return response.count ?? 0
                                    }
                                }

                                // Fetch comment count with timeout
                                dataGroup.addTask {
                                    post.commentCount = try await withTimeout(seconds: 10) {
                                        let response = try await client
                                            .from("comments")
                                            .select("*", head: true, count: .exact)
                                            .eq("post_id", value: post.id.uuidString)
                                            .execute()
                                        return response.count ?? 0
                                    }
                                }

                                // Check if liked by user with timeout
                                dataGroup.addTask {
                                    post.isLikedByCurrentUser = try await withTimeout(seconds: 10) {
                                        do {
                                            let response = try await client
                                                .from("likes")
                                                .select("*", head: true, count: .exact)
                                                .eq("post_id", value: post.id.uuidString)
                                                .eq("user_id", value: currentUserId.uuidString)
                                                .execute()
                                            return (response.count ?? 0) > 0
                                        } catch {
                                            print("⚠️ Failed to check like status: \(error)")
                                            return false
                                        }
                                    }
                                }

                                // Wait for all data to complete
                                try await dataGroup.waitForAll()
                            }

                            return (index, post)
                        } catch {
                            print("⚠️ Failed to process post \(postResponse.post.id): \(error)")
                            var fallback = postResponse.post
                            fallback.authorProfile = postResponse.profiles
                            return (index, fallback)
                        }
                    }
                }

                // Update posts at correct index (preserves database order)
                for try await (index, post) in group {
                    posts[index] = post
                }

                let incompleteIDs = posts.filter { $0.mediaURL == nil }.map { $0.id }
                let failedCount = incompleteIDs.count
                if failedCount > 0 {
                    print("⚠️ Processed \(posts.count)/\(postResponses.count) posts (\(failedCount) missing media URLs)")
                } else {
                    print("✅ Processed all \(posts.count) posts with full data")
                }

                return FeedFetchResult(
                    posts: posts,
                    requestedCount: postResponses.count,
                    incompletePostIDs: incompleteIDs
                )
            }
        }.value
    }

    /// Attempt to regenerate signed URLs for posts missing media URLs.
    func rehydrateMissingMedia(for posts: [Post]) async -> (posts: [Post], missingPostIDs: [UUID]) {
        let missing = posts.enumerated().filter { $0.element.mediaURL == nil }

        guard !missing.isEmpty else {
            return (posts, [])
        }

        var updatedPosts = posts

        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, post) in missing {
                group.addTask { [client] in
                    do {
                        let url = try await withTimeout(seconds: 10) {
                            try await client.storage
                                .from("posts")
                                .createSignedURL(path: post.mediaKey, expiresIn: 3600)
                        }
                        return (index, url)
                    } catch {
                        print("⚠️ Rehydrate failed for post \(post.id): \(error)")
                        return (index, nil)
                    }
                }
            }

            for await (index, url) in group {
                if let url {
                    updatedPosts[index].mediaURL = url
                }
            }
        }

        let stillMissing = updatedPosts
            .enumerated()
            .filter { $0.element.mediaURL == nil }
            .map { $0.element.id }

        let filtered = updatedPosts.filter { $0.mediaURL != nil }

        if !stillMissing.isEmpty {
            print("⚠️ Dropping \(stillMissing.count) posts with missing media after rehydrate attempt: \(stillMissing)")
        }

        return (filtered, stillMissing)
    }

    // MARK: - Media URLs

    /// Get signed URL for a post's media
    /// - Parameter mediaKey: The storage path (e.g., "userId/postId.jpg")
    /// - Returns: URL to display the media (signed URL valid for 1 hour)
    func getMediaURL(mediaKey: String) async throws -> URL {
        // Posts bucket is private, so we need signed URLs
        let signedURL = try await client.storage
            .from("posts")
            .createSignedURL(path: mediaKey, expiresIn: 3600) // 1 hour expiry

        return signedURL
    }

    // MARK: - Private Helper Methods

    /// Get like count for a post
    private func getLikeCount(postId: UUID) async throws -> Int {
        let response = try await client
            .from("likes")
            .select("*", head: true, count: .exact)
            .eq("post_id", value: postId.uuidString)
            .execute()

        return response.count ?? 0
    }

    /// Get comment count for a post
    private func getCommentCount(postId: UUID) async throws -> Int {
        let response = try await client
            .from("comments")
            .select("*", head: true, count: .exact)
            .eq("post_id", value: postId.uuidString)
            .execute()

        return response.count ?? 0
    }

    /// Check if a post is liked by a specific user
    private func isPostLikedByUser(postId: UUID, userId: UUID) async throws -> Bool {
        do {
            let response = try await client
                .from("likes")
                .select("*", head: true, count: .exact)
                .eq("post_id", value: postId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            return (response.count ?? 0) > 0
        } catch {
            // If error, assume not liked (don't fail the whole feed)
            print("⚠️ Failed to check like status: \(error)")
            return false
        }
    }
}

// MARK: - Response Models

/// Intermediate response structure for posts with embedded profiles
private struct PostResponse: Decodable {
    let post: Post
    let profiles: Profile?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode post fields directly from the container
        let id = try container.decode(UUID.self, forKey: .id)
        let author = try container.decode(UUID.self, forKey: .author)
        let caption = try container.decodeIfPresent(String.self, forKey: .caption)
        let mediaKey = try container.decode(String.self, forKey: .mediaKey)
        let mediaType = try container.decode(Post.MediaType.self, forKey: .mediaType)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)

        // Create post object
        self.post = Post(
            id: id,
            author: author,
            caption: caption,
            mediaKey: mediaKey,
            mediaType: mediaType,
            createdAt: createdAt
        )

        // Decode embedded profile
        self.profiles = try container.decodeIfPresent(Profile.self, forKey: .profiles)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case author
        case caption
        case mediaKey = "media_key"
        case mediaType = "media_type"
        case createdAt = "created_at"
        case profiles
    }
}

// MARK: - Timeout Helper

/// Execute async operation with timeout
/// - Parameters:
///   - seconds: Timeout duration in seconds
///   - operation: The async operation to execute
/// - Returns: The result of the operation
/// - Throws: TimeoutError if operation exceeds timeout
fileprivate func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Add the actual operation
        group.addTask {
            try await operation()
        }

        // Add timeout task
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw FeedServiceError.timeout
        }

        // Return first completed task (either result or timeout)
        let result = try await group.next()!

        // Cancel remaining tasks
        group.cancelAll()

        return result
    }
}

// MARK: - Errors

enum FeedServiceError: LocalizedError {
    case fetchFailed(Error)
    case noData
    case timeout

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to load feed: \(error.localizedDescription)"
        case .noData:
            return "No posts available"
        case .timeout:
            return "Request timed out. Please check your connection and try again."
        }
    }
}

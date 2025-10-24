//
//  FeedService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation
import Supabase

/// Service for fetching and managing the feed
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
    ) async throws -> [Post] {
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
        var posts: [Post] = []

        for postResponse in postResponses {
            do {
                var post = postResponse.post

                // Set author profile
                post.authorProfile = postResponse.profiles

                // Fetch signed URL for media
                post.mediaURL = try await getMediaURL(mediaKey: post.mediaKey)

                // Fetch like count
                post.likeCount = try await getLikeCount(postId: post.id)

                // Fetch comment count
                post.commentCount = try await getCommentCount(postId: post.id)

                // Check if current user liked this post
                post.isLikedByCurrentUser = try await isPostLikedByUser(
                    postId: post.id,
                    userId: currentUserId
                )

                posts.append(post)
            } catch {
                print("⚠️ Failed to process post \(postResponse.post.id): \(error)")
                // Continue with other posts even if one fails
                continue
            }
        }

        print("✅ Processed \(posts.count) posts with full data")
        return posts
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

// MARK: - Errors

enum FeedServiceError: LocalizedError {
    case fetchFailed(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to load feed: \(error.localizedDescription)"
        case .noData:
            return "No posts available"
        }
    }
}

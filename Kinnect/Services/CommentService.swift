//
//  CommentService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/23/25.
//

import Foundation
import Supabase

/// Service for managing comments on posts
final class CommentService {
    static let shared = CommentService()

    private let client: SupabaseClient

    // Instagram's comment character limit
    static let maxCommentLength = 2200

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Comment Operations

    /// Get comment count for a post
    func getCommentCount(postId: UUID) async throws -> Int {
        let response = try await client
            .from("comments")
            .select("*", head: true, count: .exact)
            .eq("post_id", value: postId.uuidString)
            .execute()

        return response.count ?? 0
    }

    /// Fetch all comments for a post (oldest first, Instagram-style)
    /// - Parameter postId: The post to fetch comments for
    /// - Returns: Array of comments with user profiles
    func fetchComments(postId: UUID) async throws -> [Comment] {
        print("💬 Fetching comments for post: \(postId)")

        do {
            // Fetch comments with author profiles via join
            let response = try await client
                .from("comments")
                .select("""
                    id,
                    post_id,
                    user_id,
                    body,
                    created_at,
                    profiles:user_id (
                        user_id,
                        username,
                        avatar_url,
                        full_name,
                        bio,
                        created_at
                    )
                """)
                .eq("post_id", value: postId.uuidString)
                .order("created_at", ascending: true) // Oldest first
                .execute()

            // Parse response manually to handle nested profile
            struct CommentResponse: Decodable {
                let id: UUID
                let postId: UUID
                let userId: UUID
                let body: String
                let createdAt: Date
                let profiles: Profile

                enum CodingKeys: String, CodingKey {
                    case id
                    case postId = "post_id"
                    case userId = "user_id"
                    case body
                    case createdAt = "created_at"
                    case profiles
                }
            }

            let commentResponses = try JSONDecoder.supabase.decode([CommentResponse].self, from: response.data)

            // Map to Comment models
            let comments = commentResponses.map { response in
                Comment(
                    id: response.id,
                    postId: response.postId,
                    userId: response.userId,
                    body: response.body,
                    createdAt: response.createdAt,
                    userProfile: response.profiles
                )
            }

            print("✅ Fetched \(comments.count) comments")
            return comments
        } catch {
            print("❌ Failed to fetch comments: \(error)")
            throw CommentServiceError.databaseError(error)
        }
    }

    /// Add a new comment to a post
    /// - Parameters:
    ///   - postId: The post to comment on
    ///   - userId: The user creating the comment
    ///   - body: The comment text (max 2,200 characters)
    /// - Returns: The created Comment object
    func addComment(postId: UUID, userId: UUID, body: String) async throws -> Comment {
        // Validate comment length
        guard body.count <= Self.maxCommentLength else {
            throw CommentServiceError.commentTooLong
        }

        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommentServiceError.emptyComment
        }

        print("💬 Adding comment to post \(postId)")

        struct NewComment: Encodable {
            let postId: UUID
            let userId: UUID
            let body: String

            enum CodingKeys: String, CodingKey {
                case postId = "post_id"
                case userId = "user_id"
                case body
            }
        }

        let newComment = NewComment(
            postId: postId,
            userId: userId,
            body: body
        )

        do {
            let response = try await client
                .from("comments")
                .insert(newComment)
                .select()
                .single()
                .execute()

            let comment = try JSONDecoder.supabase.decode(Comment.self, from: response.data)
            print("✅ Comment added successfully")
            return comment
        } catch {
            print("❌ Failed to add comment: \(error)")
            throw CommentServiceError.databaseError(error)
        }
    }

    /// Delete a comment (user can only delete their own comments)
    /// - Parameters:
    ///   - commentId: The comment to delete
    ///   - userId: The user performing the deletion (must match comment owner)
    func deleteComment(commentId: UUID, userId: UUID) async throws {
        print("💬 Deleting comment: \(commentId)")

        do {
            // RLS policy will ensure user can only delete their own comments
            try await client
                .from("comments")
                .delete()
                .eq("id", value: commentId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("✅ Comment deleted successfully")
        } catch {
            print("❌ Failed to delete comment: \(error)")
            throw CommentServiceError.databaseError(error)
        }
    }
}

// MARK: - Errors

enum CommentServiceError: LocalizedError {
    case databaseError(Error)
    case commentTooLong
    case emptyComment
    case notAuthenticated
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .databaseError(let error):
            return "Failed to process comment: \(error.localizedDescription)"
        case .commentTooLong:
            return "Comment is too long. Maximum \(CommentService.maxCommentLength) characters."
        case .emptyComment:
            return "Comment cannot be empty"
        case .notAuthenticated:
            return "You must be signed in to comment"
        case .unauthorized:
            return "You can only delete your own comments"
        }
    }
}

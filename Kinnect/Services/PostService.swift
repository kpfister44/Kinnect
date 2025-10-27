//
//  PostService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation
import Supabase
import UIKit

/// Service for managing posts and post-related operations
final class PostService {
    static let shared = PostService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Post Creation

    /// Create a new post with photo
    /// - Parameters:
    ///   - image: The photo to upload
    ///   - caption: Optional caption text
    ///   - userId: The author's user ID
    /// - Returns: The created Post object
    func createPost(image: UIImage, caption: String?, userId: UUID) async throws -> Post {
        print("📝 Creating new post for user: \(userId)")

        // Step 1: Compress image
        guard let imageData = ImageCompression.compressImage(image) else {
            print("❌ Image compression failed")
            throw PostServiceError.imageCompressionFailed
        }

        let fileSize = ImageCompression.formatFileSize(imageData.count)
        print("✅ Image compressed: \(fileSize)")

        // Step 2: Generate post ID (used for filename)
        let postId = UUID()

        // Step 3: Upload image to storage
        let mediaKey = try await uploadPhoto(imageData: imageData, userId: userId, postId: postId)
        print("✅ Photo uploaded: \(mediaKey)")

        // Step 4: Create post record in database
        let post = try await createPostRecord(
            postId: postId,
            userId: userId,
            caption: caption,
            mediaKey: mediaKey
        )

        print("✅ Post created successfully: \(post.id)")
        return post
    }

    // MARK: - Private Methods

    /// Upload photo data to Supabase Storage
    private func uploadPhoto(imageData: Data, userId: UUID, postId: UUID) async throws -> String {
        // File path: {userId}/{postId}.jpg
        let fileName = "\(postId.uuidString).jpg"
        let filePath = "\(userId.uuidString)/\(fileName)"

        print("📤 Uploading photo to: posts/\(filePath)")

        do {
            try await client.storage
                .from("posts")
                .upload(
                    path: filePath,
                    file: imageData,
                    options: FileOptions(
                        contentType: "image/jpeg",
                        upsert: false // Don't allow overwriting
                    )
                )
            print("✅ Upload successful")
        } catch {
            print("❌ Upload failed: \(error)")
            throw PostServiceError.uploadFailed(error)
        }

        return filePath
    }

    /// Create post record in database
    private func createPostRecord(
        postId: UUID,
        userId: UUID,
        caption: String?,
        mediaKey: String
    ) async throws -> Post {
        // Create encodable post struct for insert
        struct NewPost: Encodable {
            let id: UUID
            let author: UUID
            let caption: String?
            let mediaKey: String
            let mediaType: String

            enum CodingKeys: String, CodingKey {
                case id
                case author
                case caption
                case mediaKey = "media_key"
                case mediaType = "media_type"
            }
        }

        let newPost = NewPost(
            id: postId,
            author: userId,
            caption: caption,
            mediaKey: mediaKey,
            mediaType: "photo"
        )

        print("📝 Creating post record in database")

        do {
            let response = try await client
                .from("posts")
                .insert(newPost)
                .select()
                .single()
                .execute()

            let post = try JSONDecoder.supabase.decode(Post.self, from: response.data)

            return post
        } catch {
            print("❌ Database insert failed: \(error)")
            throw PostServiceError.databaseError(error)
        }
    }

    // MARK: - Post Fetching

    /// Fetch a single post by ID
    func fetchPost(postId: UUID) async throws -> Post {
        let response = try await client
            .from("posts")
            .select()
            .eq("id", value: postId.uuidString)
            .single()
            .execute()

        let post = try JSONDecoder.supabase.decode(Post.self, from: response.data)
        return post
    }

    /// Get signed URL for a post's media
    func getMediaURL(mediaKey: String) throws -> URL {
        let signedURL = try client.storage
            .from("posts")
            .getPublicURL(path: mediaKey)

        return signedURL
    }

    // MARK: - Post Deletion

    /// Delete a post (database record + storage file)
    /// - Parameters:
    ///   - postId: The post ID to delete
    ///   - userId: The current user's ID (for authorization check)
    ///   - mediaKey: The storage path for the media file
    /// - Throws: PostServiceError if deletion fails
    func deletePost(postId: UUID, userId: UUID, mediaKey: String) async throws {
        print("🗑️ Deleting post: \(postId)")

        // Step 1: Delete from database (also deletes likes/comments via CASCADE)
        try await deletePostRecord(postId: postId, userId: userId)
        print("✅ Post record deleted from database")

        // Step 2: Delete from storage bucket
        try await deletePostMedia(mediaKey: mediaKey)
        print("✅ Post media deleted from storage")

        print("✅ Post deleted successfully")
    }

    private func deletePostRecord(postId: UUID, userId: UUID) async throws {
        do {
            try await client
                .from("posts")
                .delete()
                .eq("id", value: postId.uuidString)
                .eq("author", value: userId.uuidString) // RLS check
                .execute()
        } catch {
            print("❌ Database delete failed: \(error)")
            throw PostServiceError.deleteFailed(error)
        }
    }

    private func deletePostMedia(mediaKey: String) async throws {
        do {
            try await client.storage
                .from("posts")
                .remove(paths: [mediaKey])
        } catch {
            print("❌ Storage delete failed: \(error)")
            // Non-fatal: database record is already deleted
            // Storage cleanup can be done later via admin tools
            print("⚠️ Continuing despite storage error")
        }
    }
}

// MARK: - Errors

enum PostServiceError: LocalizedError {
    case imageCompressionFailed
    case uploadFailed(Error)
    case databaseError(Error)
    case deleteFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different photo."
        case .uploadFailed(let error):
            return "Upload failed: \(error.localizedDescription)"
        case .databaseError(let error):
            return "Failed to create post: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete post: \(error.localizedDescription)"
        }
    }
}

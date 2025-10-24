//
//  ProfileService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/21/25.
//

import Foundation
import Supabase
import UIKit

/// Service for managing user profiles and profile-related operations
final class ProfileService {
    static let shared = ProfileService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Profile Operations

    /// Fetch a profile by user ID
    func fetchProfile(userId: UUID) async throws -> Profile {
        let response = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()

        let profile = try JSONDecoder.supabase.decode(Profile.self, from: response.data)
        return profile
    }

    /// Update profile information
    func updateProfile(
        userId: UUID,
        username: String? = nil,
        fullName: String? = nil,
        bio: String? = nil,
        avatarUrl: String? = nil
    ) async throws -> Profile {
        // Create encodable update struct
        struct ProfileUpdate: Encodable {
            let username: String?
            let fullName: String?
            let bio: String?
            let avatarUrl: String?

            enum CodingKeys: String, CodingKey {
                case username
                case fullName = "full_name"
                case bio
                case avatarUrl = "avatar_url"
            }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(username, forKey: .username)
                try container.encodeIfPresent(fullName, forKey: .fullName)
                try container.encodeIfPresent(bio, forKey: .bio)
                try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
            }
        }

        let updates = ProfileUpdate(
            username: username,
            fullName: fullName,
            bio: bio,
            avatarUrl: avatarUrl
        )

        let response = try await client
            .from("profiles")
            .update(updates)
            .eq("user_id", value: userId.uuidString)
            .select()
            .single()
            .execute()

        let profile = try JSONDecoder.supabase.decode(Profile.self, from: response.data)
        return profile
    }

    // MARK: - Avatar Upload

    /// Upload avatar image to Supabase Storage
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - userId: The user ID for naming the file
    /// - Returns: The public URL of the uploaded avatar
    func uploadAvatar(image: UIImage, userId: UUID) async throws -> String {
        print("📸 Starting avatar upload for user: \(userId)")

        // Step 1: Resize image to reasonable dimensions (avatars don't need to be huge)
        let maxDimension: CGFloat = 800 // Avatars only need 800x800 max
        let resizedImage = resizeImage(image, maxDimension: maxDimension)

        // Step 2: Compress with iterative quality reduction to meet 2MB limit
        let maxBytes = 2 * 1024 * 1024 // 2MB
        guard let finalData = compressToTarget(resizedImage, maxBytes: maxBytes) else {
            print("❌ Image compression failed")
            throw ProfileServiceError.imageCompressionFailed
        }

        let fileSize = ByteCountFormatter.string(fromByteCount: Int64(finalData.count), countStyle: .file)
        print("✅ Image compressed: \(fileSize)")

        // Store in user-specific folder: {userId}/{userId}.jpg
        let fileName = "\(userId.uuidString).jpg"
        let filePath = "\(userId.uuidString)/\(fileName)"

        print("📤 Uploading to path: \(filePath)")

        // Upload to avatars bucket
        do {
            try await client.storage
                .from("avatars")
                .upload(
                    path: filePath,
                    file: finalData,
                    options: FileOptions(
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )
            print("✅ Upload successful")
        } catch {
            print("❌ Upload failed: \(error)")
            throw error
        }

        // Get public URL with cache-busting parameter
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: filePath)

        // Add timestamp to bust cache
        let cacheBustedURL = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"

        print("✅ Public URL generated: \(cacheBustedURL)")

        return cacheBustedURL
    }

    // MARK: - Profile Stats

    /// Get profile statistics (posts count, followers count, following count)
    func getProfileStats(userId: UUID) async throws -> ProfileStats {
        // Get posts count
        let postsResponse = try await client
            .from("posts")
            .select("id", head: false, count: .exact)
            .eq("author", value: userId.uuidString)
            .execute()

        let postsCount = postsResponse.count ?? 0

        // Get followers count
        let followersResponse = try await client
            .from("follows")
            .select("follower", head: false, count: .exact)
            .eq("followee", value: userId.uuidString)
            .execute()

        let followersCount = followersResponse.count ?? 0

        // Get following count
        let followingResponse = try await client
            .from("follows")
            .select("followee", head: false, count: .exact)
            .eq("follower", value: userId.uuidString)
            .execute()

        let followingCount = followingResponse.count ?? 0

        return ProfileStats(
            postsCount: postsCount,
            followersCount: followersCount,
            followingCount: followingCount
        )
    }

    // MARK: - Image Compression Helpers

    /// Resizes an image to fit within max dimensions while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            // Landscape or square
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }

    /// Compresses image to JPEG, adjusting quality to meet size target
    private func compressToTarget(_ image: UIImage, maxBytes: Int) -> Data? {
        var compressionQuality: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compressionQuality)

        // Iteratively reduce quality if size is too large
        while let data = imageData, data.count > maxBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }

        return imageData
    }
}

// MARK: - Supporting Types

struct ProfileStats {
    var postsCount: Int
    var followersCount: Int
    var followingCount: Int
}

enum ProfileServiceError: LocalizedError {
    case imageCompressionFailed

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image. Please try a different photo."
        }
    }
}

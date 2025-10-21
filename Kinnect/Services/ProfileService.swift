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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(Profile.self, from: response.data)
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

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(Profile.self, from: response.data)
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

        // Compress image to JPEG (max 2MB as per bucket policy)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Image compression failed")
            throw ProfileServiceError.imageCompressionFailed
        }

        print("✅ Image compressed: \(imageData.count) bytes")

        // Ensure image is under 2MB
        let finalData: Data
        if imageData.count > 2 * 1024 * 1024 {
            print("⚠️ Image too large (\(imageData.count) bytes), recompressing...")
            // Try with lower quality
            guard let compressedData = image.jpegData(compressionQuality: 0.5),
                  compressedData.count <= 2 * 1024 * 1024 else {
                print("❌ Image still too large after recompression")
                throw ProfileServiceError.imageTooLarge
            }
            finalData = compressedData
            print("✅ Recompressed to: \(finalData.count) bytes")
        } else {
            finalData = imageData
        }

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
}

// MARK: - Supporting Types

struct ProfileStats {
    let postsCount: Int
    let followersCount: Int
    let followingCount: Int
}

enum ProfileServiceError: LocalizedError {
    case imageCompressionFailed
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image"
        case .imageTooLarge:
            return "Image is too large. Please select a smaller image."
        }
    }
}

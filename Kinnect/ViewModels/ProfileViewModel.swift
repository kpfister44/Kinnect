//
//  ProfileViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/21/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var profile: Profile?
    @Published var stats: ProfileStats?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFollowing: Bool = false
    @Published var isFollowOperationInProgress: Bool = false

    // MARK: - Private Properties

    private let profileService: ProfileService
    private let followService: FollowService

    // MARK: - Initialization

    init(profileService: ProfileService = ProfileService.shared, followService: FollowService = FollowService.shared) {
        self.profileService = profileService
        self.followService = followService
    }

    // MARK: - Profile Loading

    /// Load profile data and stats for a given user
    /// - Parameters:
    ///   - userId: The user ID to load
    ///   - currentUserId: The current user's ID (for checking follow status)
    func loadProfile(userId: UUID, currentUserId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch profile and stats in parallel
            async let profileData = profileService.fetchProfile(userId: userId)
            async let statsData = profileService.getProfileStats(userId: userId)

            let (fetchedProfile, fetchedStats) = try await (profileData, statsData)

            self.profile = fetchedProfile
            self.stats = fetchedStats

            // Check follow status if viewing someone else's profile
            if let currentUserId = currentUserId, currentUserId != userId {
                await checkFollowStatus(currentUserId: currentUserId, profileUserId: userId)
            }
        } catch {
            errorMessage = "Failed to load profile. Please try again."
            print("❌ Profile loading error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Profile Updates

    /// Update profile information
    func updateProfile(
        userId: UUID,
        username: String? = nil,
        fullName: String? = nil,
        bio: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil

        do {
            let updatedProfile = try await profileService.updateProfile(
                userId: userId,
                username: username,
                fullName: fullName,
                bio: bio
            )

            self.profile = updatedProfile
        } catch {
            // Check for username uniqueness error
            if error.localizedDescription.contains("duplicate") ||
               error.localizedDescription.contains("unique") {
                errorMessage = "Username is already taken. Please choose another."
            } else {
                errorMessage = "Failed to update profile. Please try again."
            }
            print("❌ Profile update error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Avatar Upload

    /// Upload avatar image and update profile
    func uploadAvatar(image: UIImage, userId: UUID) async {
        print("🖼️ ProfileViewModel: Starting avatar upload")
        isLoading = true
        errorMessage = nil

        do {
            // Upload image to storage
            print("🖼️ ProfileViewModel: Calling profileService.uploadAvatar")
            let avatarUrl = try await profileService.uploadAvatar(image: image, userId: userId)
            print("🖼️ ProfileViewModel: Got avatar URL: \(avatarUrl)")

            // Update profile with new avatar URL
            print("🖼️ ProfileViewModel: Updating profile with new avatar URL")
            let updatedProfile = try await profileService.updateProfile(
                userId: userId,
                avatarUrl: avatarUrl
            )

            self.profile = updatedProfile
            print("✅ ProfileViewModel: Avatar upload complete")
        } catch let error as ProfileServiceError {
            errorMessage = error.errorDescription
            print("❌ ProfileViewModel: ProfileServiceError: \(error)")
        } catch {
            errorMessage = "Failed to upload avatar. Please try again."
            print("❌ ProfileViewModel: Avatar upload error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Stats Refresh

    /// Refresh profile statistics
    func refreshStats(userId: UUID) async {
        do {
            let fetchedStats = try await profileService.getProfileStats(userId: userId)
            self.stats = fetchedStats
        } catch {
            print("❌ Stats refresh error: \(error)")
            // Don't show error to user for stats refresh - it's a background operation
        }
    }

    // MARK: - Follow Operations

    /// Check if current user is following the profile user
    private func checkFollowStatus(currentUserId: UUID, profileUserId: UUID) async {
        do {
            let status = try await followService.checkFollowStatus(
                followerId: currentUserId,
                followeeId: profileUserId
            )
            self.isFollowing = status
        } catch {
            print("❌ Follow status check error: \(error)")
            // Don't show error to user - default to not following
            self.isFollowing = false
        }
    }

    /// Toggle follow/unfollow with optimistic UI updates
    /// - Parameters:
    ///   - currentUserId: The current user's ID
    ///   - profileUserId: The profile user's ID
    func toggleFollow(currentUserId: UUID, profileUserId: UUID) async {
        // Store previous state for rollback
        let previousFollowState = isFollowing
        let previousStats = stats

        // Optimistic update - toggle immediately
        isFollowing.toggle()
        isFollowOperationInProgress = true

        // Update follower count optimistically
        if var currentStats = stats {
            if isFollowing {
                currentStats.followersCount += 1
            } else {
                currentStats.followersCount = max(0, currentStats.followersCount - 1)
            }
            stats = currentStats
        }

        do {
            // Perform API call
            if isFollowing {
                try await followService.followUser(followerId: currentUserId, followeeId: profileUserId)
                print("✅ Followed user successfully")
            } else {
                try await followService.unfollowUser(followerId: currentUserId, followeeId: profileUserId)
                print("✅ Unfollowed user successfully")
            }

            // Refresh stats to get accurate count from server
            await refreshStats(userId: profileUserId)
        } catch {
            // Revert on error
            print("❌ Follow toggle error: \(error)")
            isFollowing = previousFollowState
            stats = previousStats
            errorMessage = "Failed to update follow status. Please try again."
        }

        isFollowOperationInProgress = false
    }
}

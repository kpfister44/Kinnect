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
    @Published var posts: [Post] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isFollowing: Bool = false
    @Published var isFollowOperationInProgress: Bool = false

    // MARK: - Cache State (Phase 10)

    // Cache for multiple users' profiles
    private var profileCache: [UUID: CachedProfileData] = [:]
    private let cacheTTL: TimeInterval = 45 * 60 // 45 minutes (matches Feed TTL)

    // MARK: - Private Properties

    private let profileService: ProfileService
    private let followService: FollowService

    // MARK: - Cached Profile Data Structure

    struct CachedProfileData {
        let profile: Profile
        let posts: [Post]
        let stats: ProfileStats
        let timestamp: Date
    }

    // MARK: - Initialization

    init(profileService: ProfileService = ProfileService.shared, followService: FollowService = FollowService.shared) {
        self.profileService = profileService
        self.followService = followService

        // Observe logout notifications to clear cache (Phase 10)
        setupLogoutObserver()
    }

    deinit {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Cache Helper Methods

    /// Check if cached profile is valid (not expired)
    private func isCacheValid(for userId: UUID) -> Bool {
        guard let cached = profileCache[userId] else { return false }
        let age = Date().timeIntervalSince(cached.timestamp)
        return age < cacheTTL
    }

    /// Calculate cache age in seconds
    private func cacheAge(for userId: UUID) -> Int {
        guard let cached = profileCache[userId] else { return 0 }
        return Int(Date().timeIntervalSince(cached.timestamp))
    }

    /// Invalidate (clear) cache for specific user
    func invalidateCache(for userId: UUID) {
        profileCache.removeValue(forKey: userId)
        print("🗑️ Cache invalidated for user: \(userId)")
    }

    /// Invalidate all cached profiles
    func invalidateAllCaches() {
        profileCache.removeAll()
        print("🗑️ All profile caches cleared")
    }

    /// Update cache with fresh profile data
    private func updateCache(userId: UUID, profile: Profile, posts: [Post], stats: ProfileStats) {
        let cachedData = CachedProfileData(
            profile: profile,
            posts: posts,
            stats: stats,
            timestamp: Date()
        )
        profileCache[userId] = cachedData
        print("💾 Profile cache updated for user: \(userId)")
    }

    // MARK: - Logout Observer

    private func setupLogoutObserver() {
        NotificationCenter.default.addObserver(
            forName: .userDidLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateAllCaches()
            print("🗑️ All profile caches cleared on logout")
        }
    }

    // MARK: - Profile Loading

    /// Load profile data and stats for a given user
    /// - Parameters:
    ///   - userId: The user ID to load
    ///   - currentUserId: The current user's ID (for checking follow status)
    ///   - forceRefresh: Force refresh from API, bypassing cache
    func loadProfile(userId: UUID, currentUserId: UUID? = nil, forceRefresh: Bool = false) async {
        // If force refresh requested, skip cache
        if forceRefresh {
            print("🔄 Force refresh - bypassing cache for user: \(userId)")
            await fetchFreshProfile(userId: userId, currentUserId: currentUserId)
            return
        }

        // Check if cache is valid
        if isCacheValid(for: userId) {
            // Use cached data
            if let cached = profileCache[userId] {
                self.profile = cached.profile
                self.stats = cached.stats
                self.posts = cached.posts
                print("✅ Loaded profile from cache (age: \(cacheAge(for: userId))s)")

                // Still check follow status if viewing someone else's profile
                if let currentUserId = currentUserId, currentUserId != userId {
                    await checkFollowStatus(currentUserId: currentUserId, profileUserId: userId)
                }

                return
            }
        }

        // Cache expired or empty - fetch fresh
        print("🌐 Cache miss - fetching fresh profile for user: \(userId)")
        await fetchFreshProfile(userId: userId, currentUserId: currentUserId)
    }

    /// Fetch fresh profile data from API
    private func fetchFreshProfile(userId: UUID, currentUserId: UUID? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch profile, stats, and posts in parallel
            async let profileData = profileService.fetchProfile(userId: userId)
            async let statsData = profileService.getProfileStats(userId: userId)
            async let postsData = profileService.fetchUserPosts(userId: userId)

            let (fetchedProfile, fetchedStats, fetchedPosts) = try await (profileData, statsData, postsData)

            self.profile = fetchedProfile
            self.stats = fetchedStats

            // Attach author profile to each post
            self.posts = fetchedPosts.map { post in
                var updatedPost = post
                updatedPost.authorProfile = fetchedProfile
                return updatedPost
            }

            // Update cache with fresh data
            updateCache(userId: userId, profile: fetchedProfile, posts: self.posts, stats: fetchedStats)

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

            // Invalidate cache for this user since profile changed
            invalidateCache(for: userId)
            print("🔄 Profile updated - cache invalidated")
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

            // Invalidate cache for this user since avatar changed
            invalidateCache(for: userId)
            print("✅ ProfileViewModel: Avatar upload complete - cache invalidated")

            // Notify FeedViewModel to invalidate cache so updated avatar shows in feed
            NotificationCenter.default.post(name: .userDidUpdateProfile, object: nil)
            print("📢 Posted userDidUpdateProfile notification")
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

            // Also update cache optimistically
            if let cached = profileCache[profileUserId] {
                // Create new cache entry with updated stats
                let updatedCache = CachedProfileData(
                    profile: cached.profile,
                    posts: cached.posts,
                    stats: currentStats,
                    timestamp: cached.timestamp
                )
                profileCache[profileUserId] = updatedCache
            }
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

            // Update cache with fresh stats
            if let freshStats = stats, let cached = profileCache[profileUserId] {
                let updatedCache = CachedProfileData(
                    profile: cached.profile,
                    posts: cached.posts,
                    stats: freshStats,
                    timestamp: cached.timestamp
                )
                profileCache[profileUserId] = updatedCache
            }
        } catch {
            // Revert on error
            print("❌ Follow toggle error: \(error)")
            isFollowing = previousFollowState
            stats = previousStats

            // Revert cache as well
            if let previousStats = previousStats, let cached = profileCache[profileUserId] {
                let revertedCache = CachedProfileData(
                    profile: cached.profile,
                    posts: cached.posts,
                    stats: previousStats,
                    timestamp: cached.timestamp
                )
                profileCache[profileUserId] = revertedCache
            }

            errorMessage = "Failed to update follow status. Please try again."
        }

        isFollowOperationInProgress = false
    }
}

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

    // MARK: - AsyncImage Reload State (Bug Fix: TAB-SWITCH-001 - Iteration 6)
    /// Changes when view appears to force AsyncImage recreation and bypass cached failure states
    @Published var viewAppearanceID = UUID()

    /// Track if view is currently visible to avoid unnecessary AsyncImage reloads
    private var isViewVisible = false

    /// Track if a fetch is currently in progress
    private var isFetchInProgress = false

    /// Flag set when user switches away during an active fetch (AsyncImage reload needed)
    private var didSwitchAwayDuringFetch = false

    private var profileFetchTask: Task<Void, Never>?
    private var activeProfileRequestID: UUID?
    private var cancelledImagePostIDs: Set<UUID> = []

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
        profileFetchTask?.cancel()
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
    /// Only caches if ALL posts have valid mediaURLs (prevents partial cache)
    private func updateCache(userId: UUID, profile: Profile, posts: [Post], stats: ProfileStats) {
        // Validation: Ensure all posts have valid mediaURLs
        let postsWithoutURLs = posts.filter { $0.mediaURL == nil }

        guard postsWithoutURLs.isEmpty else {
            print("⚠️ Skipping profile cache update for \(userId): \(postsWithoutURLs.count)/\(posts.count) posts missing mediaURLs")
            print("⚠️ Posts without URLs: \(postsWithoutURLs.map { $0.id })")
            return
        }

        // All posts valid - safe to cache
        let cachedData = CachedProfileData(
            profile: profile,
            posts: posts,
            stats: stats,
            timestamp: Date()
        )
        profileCache[userId] = cachedData
        print("💾 Profile cache updated for user: \(userId) (all \(posts.count) posts have valid mediaURLs)")
    }

    // MARK: - View Lifecycle (Bug Fix: TAB-SWITCH-001)

    /// Call when view appears - regenerate AsyncImage IDs if user switched away during fetch
    func handleViewAppear() {
        let wasInvisible = !isViewVisible
        isViewVisible = true

        if wasInvisible && (didSwitchAwayDuringFetch || !cancelledImagePostIDs.isEmpty) {
            print("🔄 Profile view returning after switching away during fetch - regenerating AsyncImage IDs")
            viewAppearanceID = UUID()
            didSwitchAwayDuringFetch = false

            let failedIDs = cancelledImagePostIDs
            cancelledImagePostIDs.removeAll()

            Task { [weak self] in
                await self?.refreshCancelledImages(for: failedIDs)
            }
        } else if wasInvisible {
            print("✨ Profile view returning - no loads while away, keeping AsyncImage cache intact")
        }
    }

    /// Call when view disappears
    func handleViewDisappear() {
        isViewVisible = false

        if isFetchInProgress {
            print("🚨 Profile fetch in progress while view disappeared - will regenerate AsyncImages on return")
            didSwitchAwayDuringFetch = true
        } else {
            print("👋 Profile view disappeared - no active fetch")
        }
    }

    func recordImageCancellation(for postID: UUID) {
        cancelledImagePostIDs.insert(postID)

        if isViewVisible {
            let ids: Set<UUID> = [postID]
            Task { [weak self] in
                await self?.refreshCancelledImages(for: ids)
            }
        }
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

        // Listen for post deletions from other views (FeedView, ProfileFeedView)
        NotificationCenter.default.addObserver(
            forName: .userDidDeletePost,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let postId = notification.object as? UUID else { return }

            print("📡 ProfileViewModel received deletion notification for post: \(postId)")

            // Remove from current posts array
            let removedFromPosts = self.posts.contains(where: { $0.id == postId })
            self.posts.removeAll(where: { $0.id == postId })

            if removedFromPosts {
                print("✅ Removed post \(postId) from ProfileViewModel.posts array")
            }

            // Remove from all cached profiles (since we cache multiple users)
            for (userId, cached) in self.profileCache {
                let hadPost = cached.posts.contains(where: { $0.id == postId })
                if hadPost {
                    var updatedPosts = cached.posts
                    updatedPosts.removeAll(where: { $0.id == postId })

                    let updatedCache = CachedProfileData(
                        profile: cached.profile,
                        posts: updatedPosts,
                        stats: cached.stats,
                        timestamp: cached.timestamp
                    )
                    self.profileCache[userId] = updatedCache
                    print("✅ Removed post \(postId) from cache for user: \(userId)")
                }
            }
        }
    }

    // MARK: - Profile Loading

    /// Load profile data and stats for a given user
    /// - Parameters:
    ///   - userId: The user ID to load
    ///   - currentUserId: The current user's ID (for checking follow status)
    ///   - forceRefresh: Force refresh from API, bypassing cache
    func loadProfile(userId: UUID, currentUserId: UUID? = nil, forceRefresh: Bool = false) async {
        if forceRefresh {
            print("🔄 Force refresh - bypassing cache for user: \(userId)")
            invalidateCache(for: userId)
        } else if isCacheValid(for: userId) {
            if let cached = profileCache[userId] {
                profile = cached.profile
                stats = cached.stats
                posts = cached.posts
                print("✅ Loaded profile from cache (age: \(cacheAge(for: userId))s)")

                if let currentUserId = currentUserId, currentUserId != userId {
                    await checkFollowStatus(currentUserId: currentUserId, profileUserId: userId)
                }

                return
            }
        }

        print("🌐 Fetching profile from Supabase for user: \(userId)")
        scheduleProfileFetch(userId: userId, currentUserId: currentUserId)
    }

    private func scheduleProfileFetch(userId: UUID, currentUserId: UUID?) {
        if isFetchInProgress {
            profileFetchTask?.cancel()
        }

        isLoading = true
        errorMessage = nil

        let requestID = UUID()
        activeProfileRequestID = requestID

        let profileService = self.profileService

        isFetchInProgress = true

        if !isViewVisible {
            print("🚨 Profile fetch starting while view invisible - will regenerate AsyncImages on return")
            didSwitchAwayDuringFetch = true
        }

        profileFetchTask?.cancel()
        profileFetchTask = Task.detached { [weak self] in
            do {
                async let profileData = profileService.fetchProfile(userId: userId)
                async let statsData = profileService.getProfileStats(userId: userId)
                async let postsData = profileService.fetchUserPosts(userId: userId)

                let (fetchedProfile, fetchedStats, fetchedPosts) = try await (profileData, statsData, postsData)
                let (hydratedPosts, droppedIDs) = await profileService.rehydrateMissingMedia(for: fetchedPosts)

                await MainActor.run {
                    guard let self = self, self.activeProfileRequestID == requestID else { return }
                    self.handleProfileFetchSuccess(
                        userId: userId,
                        profile: fetchedProfile,
                        stats: fetchedStats,
                        posts: hydratedPosts,
                        droppedPostIDs: droppedIDs,
                        currentUserId: currentUserId
                    )
                }
            } catch {
                await MainActor.run {
                    guard let self = self, self.activeProfileRequestID == requestID else { return }
                    self.handleProfileFetchFailure(error: error)
                }
            }
        }
    }

    private func handleProfileFetchSuccess(
        userId: UUID,
        profile: Profile,
        stats: ProfileStats,
        posts: [Post],
        droppedPostIDs: [UUID],
        currentUserId: UUID?
    ) {
        defer {
            isLoading = false
            isFetchInProgress = false
            profileFetchTask = nil
            activeProfileRequestID = nil
        }

        self.profile = profile
        self.stats = stats

        self.posts = posts.map { post in
            var updated = post
            updated.authorProfile = profile
            return updated
        }

        updateCache(userId: userId, profile: profile, posts: self.posts, stats: stats)

        if !droppedPostIDs.isEmpty {
            print("⚠️ Dropped profile posts with missing media: \(droppedPostIDs)")
        }

        errorMessage = nil

        if let currentUserId = currentUserId, currentUserId != userId {
            Task { await self.checkFollowStatus(currentUserId: currentUserId, profileUserId: userId) }
        }
    }

    private func handleProfileFetchFailure(error: Error) {
        defer {
            isLoading = false
            isFetchInProgress = false
            profileFetchTask = nil
            activeProfileRequestID = nil
        }

        if error is CancellationError {
            print("⚠️ Profile fetch task cancelled (request superseded)")
            return
        }

        errorMessage = "Failed to load profile. Please try again."
        print("❌ Profile loading error: \(error)")
    }

    private func refreshCancelledImages(for ids: Set<UUID>) async {
        guard !ids.isEmpty else { return }

        cancelledImagePostIDs.subtract(ids)

        let postsToRefresh = posts.filter { ids.contains($0.id) }
        guard !postsToRefresh.isEmpty else { return }

        print("🔄 Profile: refreshing signed URLs for cancelled images: \(ids)")
        let (rehydratedPosts, stillMissing) = await profileService.rehydrateMissingMedia(for: postsToRefresh)

        guard !rehydratedPosts.isEmpty else {
            if !stillMissing.isEmpty {
                print("⚠️ Profile: unable to refresh media for posts: \(stillMissing)")
            }
            return
        }

        for updatedPost in rehydratedPosts {
            if let index = posts.firstIndex(where: { $0.id == updatedPost.id }) {
                posts[index].mediaURL = updatedPost.mediaURL
            }

            if let profileId = profile?.id, var cached = profileCache[profileId] {
                if let cachedIndex = cached.posts.firstIndex(where: { $0.id == updatedPost.id }) {
                    var updatedCachedPosts = cached.posts
                    updatedCachedPosts[cachedIndex].mediaURL = updatedPost.mediaURL
                    profileCache[profileId] = CachedProfileData(
                        profile: cached.profile,
                        posts: updatedCachedPosts,
                        stats: cached.stats,
                        timestamp: cached.timestamp
                    )
                }
            }
        }

        if !stillMissing.isEmpty {
            print("⚠️ Profile posts still missing media after refresh: \(stillMissing)")
        }
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

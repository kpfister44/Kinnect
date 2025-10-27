//
//  ActivityViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/26/25.
//

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class ActivityViewModel: ObservableObject {
    // MARK: - Published State
    @Published var activities: [Activity] = []
    @Published var groupedActivities: [GroupedActivityItem] = []
    @Published var state: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var unreadCount: Int = 0

    // MARK: - Dependencies
    private let activityService: ActivityService
    private let realtimeService: RealtimeService
    private let currentUserId: UUID

    // Realtime channel
    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Initialization

    init(
        currentUserId: UUID,
        activityService: ActivityService? = nil,
        realtimeService: RealtimeService? = nil
    ) {
        self.currentUserId = currentUserId
        self.activityService = activityService ?? .shared
        self.realtimeService = realtimeService ?? .shared
    }

    // MARK: - Loading State

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
    }

    // MARK: - Public Methods

    /// Load activities for the current user
    func loadActivities() async {
        state = .loading

        do {
            let fetchedActivities = try await activityService.fetchActivities(userId: currentUserId)
            activities = fetchedActivities
            groupedActivities = groupActivities(fetchedActivities)
            state = .loaded
            errorMessage = nil

            print("✅ Loaded \(activities.count) activities, grouped into \(groupedActivities.count) items")

            // Update unread count
            await updateUnreadCount()
        } catch {
            print("❌ Failed to load activities: \(error)")
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh activities (for pull-to-refresh)
    func refreshActivities() async {
        await loadActivities()
    }

    /// Update unread count badge
    func updateUnreadCount() async {
        do {
            let count = try await activityService.getUnreadCount(userId: currentUserId)
            unreadCount = count
            print("🔔 Unread count: \(count)")
        } catch {
            print("❌ Failed to update unread count: \(error)")
        }
    }

    /// Mark a single activity as read
    func markAsRead(_ activity: Activity) async {
        guard !activity.isRead else { return }

        // Optimistically update local state
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = Activity(
                id: activity.id,
                userId: activity.userId,
                actorId: activity.actorId,
                activityType: activity.activityType,
                postId: activity.postId,
                commentId: activity.commentId,
                isRead: true,
                createdAt: activity.createdAt,
                actorProfile: activity.actorProfile
            )
        }

        // Regroup activities
        groupedActivities = groupActivities(activities)

        // Decrement unread count
        unreadCount = max(0, unreadCount - 1)

        do {
            try await activityService.markAsRead(activityId: activity.id)
            print("✅ Activity marked as read")
        } catch {
            print("❌ Failed to mark activity as read: \(error)")
            // On error, reload to sync state
            await loadActivities()
        }
    }

    /// Mark all activities in a grouped item as read
    func markGroupedActivityAsRead(_ groupedItem: GroupedActivityItem) async {
        let unreadActivities = groupedItem.activities.filter { !$0.isRead }
        guard !unreadActivities.isEmpty else { return }

        // Optimistically update all activities in the group
        for activity in unreadActivities {
            if let index = activities.firstIndex(where: { $0.id == activity.id }) {
                activities[index] = Activity(
                    id: activity.id,
                    userId: activity.userId,
                    actorId: activity.actorId,
                    activityType: activity.activityType,
                    postId: activity.postId,
                    commentId: activity.commentId,
                    isRead: true,
                    createdAt: activity.createdAt,
                    actorProfile: activity.actorProfile
                )
            }
        }

        // Regroup activities
        groupedActivities = groupActivities(activities)

        // Decrement unread count
        unreadCount = max(0, unreadCount - unreadActivities.count)

        // Mark all as read in database
        do {
            for activity in unreadActivities {
                try await activityService.markAsRead(activityId: activity.id)
            }
            print("✅ Marked \(unreadActivities.count) activities as read")
        } catch {
            print("❌ Failed to mark activities as read: \(error)")
            // On error, reload to sync state
            await loadActivities()
        }
    }

    /// Mark all activities as read
    func markAllAsRead() async {
        guard unreadCount > 0 else { return }

        // Optimistically update all to read
        activities = activities.map { activity in
            Activity(
                id: activity.id,
                userId: activity.userId,
                actorId: activity.actorId,
                activityType: activity.activityType,
                postId: activity.postId,
                commentId: activity.commentId,
                isRead: true,
                createdAt: activity.createdAt,
                actorProfile: activity.actorProfile
            )
        }

        // Regroup
        groupedActivities = groupActivities(activities)

        // Reset count
        unreadCount = 0

        do {
            try await activityService.markAllAsRead(userId: currentUserId)
            print("✅ All activities marked as read")
        } catch {
            print("❌ Failed to mark all as read: \(error)")
            errorMessage = error.localizedDescription
            // Reload to sync state
            await loadActivities()
        }
    }

    /// Delete a single activity
    func deleteActivity(_ groupedItem: GroupedActivityItem) async {
        // Optimistically remove from UI
        let originalGroupedActivities = groupedActivities
        groupedActivities.removeAll { $0.id == groupedItem.id }

        // Remove underlying activities
        let activityIdsToRemove = groupedItem.activities.map { $0.id }
        activities.removeAll { activityIdsToRemove.contains($0.id) }

        // Update unread count if any were unread
        let unreadRemoved = groupedItem.activities.filter { !$0.isRead }.count
        unreadCount = max(0, unreadCount - unreadRemoved)

        do {
            // Delete all activities in the group
            for activity in groupedItem.activities {
                try await activityService.deleteActivity(activityId: activity.id, userId: currentUserId)
            }

            print("✅ Activity deleted")
        } catch {
            print("❌ Failed to delete activity: \(error)")

            // Restore on error
            groupedActivities = originalGroupedActivities
            errorMessage = error.localizedDescription

            // Reload to sync state
            await loadActivities()
        }
    }

    /// Clear all activities
    func clearAllActivities() async {
        // Optimistically clear
        let originalActivities = activities
        let originalGroupedActivities = groupedActivities
        let originalUnreadCount = unreadCount

        activities = []
        groupedActivities = []
        unreadCount = 0

        do {
            try await activityService.clearAllActivities(userId: currentUserId)
            print("✅ All activities cleared")
        } catch {
            print("❌ Failed to clear activities: \(error)")

            // Restore on error
            activities = originalActivities
            groupedActivities = originalGroupedActivities
            unreadCount = originalUnreadCount
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Realtime Updates

    /// Setup realtime subscriptions for new activities
    func setupRealtimeSubscriptions() async {
        print("🔔 Setting up Realtime subscriptions for activities")

        // Create channel
        let channel = realtimeService.createActivityChannel(userId: currentUserId)
        realtimeChannel = channel

        // Subscribe to new activities
        let activityInserts = await realtimeService.subscribeToActivityInserts(channel: channel)

        // Subscribe to channel
        await realtimeService.subscribe(channel: channel)

        // Start listening for activity insertions
        Task {
            do {
                for try await action in activityInserts {
                    let insertAction = action as! InsertAction

                    // Parse activity using direct dictionary access
                    guard let activityIdString = insertAction.record["id"]?.value as? String,
                          let activityId = UUID(uuidString: activityIdString),
                          let userIdString = insertAction.record["user_id"]?.value as? String,
                          let userId = UUID(uuidString: userIdString),
                          let actorIdString = insertAction.record["actor_id"]?.value as? String,
                          let actorId = UUID(uuidString: actorIdString),
                          let activityTypeString = insertAction.record["activity_type"]?.value as? String else {
                        print("❌ Failed to parse activity insert")
                        continue
                    }

                    // Only process if it's for current user
                    guard userId == currentUserId else {
                        continue
                    }

                    print("🔔 New activity received: \(activityTypeString)")

                    // Increment unread count
                    await incrementUnreadCount()

                    // Optional: Refresh activities list to show new notification
                    // await loadActivities()
                }
            } catch {
                print("❌ Activity subscription error: \(error)")
            }
        }
    }

    /// Clean up realtime subscriptions
    func cleanupRealtimeSubscriptions() async {
        guard let channel = realtimeChannel else {
            return
        }

        await realtimeService.cleanup(channel: channel)
        realtimeChannel = nil
    }

    /// Increment unread count (for realtime updates)
    private func incrementUnreadCount() async {
        unreadCount += 1
        print("🔔 Unread count: \(unreadCount)")
    }

    // MARK: - Grouping Logic

    /// Group activities by type and post
    /// - Likes on the same post get grouped together
    /// - Comments and follows remain individual
    private func groupActivities(_ activities: [Activity]) -> [GroupedActivityItem] {
        var grouped: [GroupedActivityItem] = []
        var processedLikes: Set<UUID> = []

        for activity in activities {
            switch activity.activityType {
            case .like:
                // Skip if already processed in a group
                guard let postId = activity.postId, !processedLikes.contains(postId) else {
                    continue
                }

                // Find all likes on this post
                let likesOnPost = activities.filter {
                    $0.activityType == .like && $0.postId == postId
                }

                // Mark as processed
                processedLikes.insert(postId)

                // Create grouped item
                grouped.append(GroupedActivityItem(activities: likesOnPost))

            case .comment, .follow:
                // Comments and follows are always individual
                grouped.append(GroupedActivityItem(activities: [activity]))
            }
        }

        return grouped
    }
}

// MARK: - GroupedActivityItem

/// Represents a single row in the activity feed
/// Can contain multiple activities (for grouped likes) or a single activity (comments, follows)
struct GroupedActivityItem: Identifiable, Equatable {
    let id: UUID
    let activityType: ActivityType
    let postId: UUID?
    let commentId: UUID?
    let isRead: Bool
    let createdAt: Date
    let activities: [Activity]  // Underlying activities (1 for individual, multiple for grouped likes)

    init(activities: [Activity]) {
        guard let first = activities.first else {
            fatalError("Cannot create GroupedActivityItem from empty array")
        }

        self.id = first.id
        self.activityType = first.activityType
        self.postId = first.postId
        self.commentId = first.commentId
        self.isRead = activities.allSatisfy { $0.isRead }
        self.createdAt = activities.map { $0.createdAt }.max() ?? first.createdAt
        self.activities = activities
    }

    /// Get actor profiles for display
    var actors: [Profile] {
        activities.compactMap { $0.actorProfile }
    }

    /// Get first actor for single activities
    var primaryActor: Profile? {
        activities.first?.actorProfile
    }

    /// Check if this is a grouped item (multiple activities)
    var isGrouped: Bool {
        activities.count > 1
    }
}

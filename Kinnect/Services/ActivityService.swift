//
//  ActivityService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/26/25.
//

import Foundation
import Supabase

/// Service for managing user activity notifications
final class ActivityService {
    static let shared = ActivityService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Activity Operations

    /// Fetch activities for the current user (last 30 days)
    /// - Parameter userId: The user to fetch activities for
    /// - Returns: Array of activities with actor profiles
    func fetchActivities(userId: UUID) async throws -> [Activity] {
        print("🔔 Fetching activities for user: \(userId)")

        do {
            // Fetch activities from last 30 days with actor profiles
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()

            let response = try await client
                .from("activities")
                .select("""
                    id,
                    user_id,
                    actor_id,
                    activity_type,
                    post_id,
                    comment_id,
                    is_read,
                    created_at,
                    profiles:actor_id (
                        user_id,
                        username,
                        avatar_url,
                        full_name,
                        bio,
                        created_at
                    )
                """)
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: thirtyDaysAgo.ISO8601Format())
                .order("created_at", ascending: false) // Newest first
                .execute()

            // Parse response with nested profile
            struct ActivityResponse: Decodable {
                let id: UUID
                let userId: UUID
                let actorId: UUID
                let activityType: ActivityType
                let postId: UUID?
                let commentId: UUID?
                let isRead: Bool
                let createdAt: Date
                let profiles: Profile

                enum CodingKeys: String, CodingKey {
                    case id
                    case userId = "user_id"
                    case actorId = "actor_id"
                    case activityType = "activity_type"
                    case postId = "post_id"
                    case commentId = "comment_id"
                    case isRead = "is_read"
                    case createdAt = "created_at"
                    case profiles
                }
            }

            let activityResponses = try JSONDecoder.supabase.decode([ActivityResponse].self, from: response.data)

            // Map to Activity models
            let activities = activityResponses.map { response in
                Activity(
                    id: response.id,
                    userId: response.userId,
                    actorId: response.actorId,
                    activityType: response.activityType,
                    postId: response.postId,
                    commentId: response.commentId,
                    isRead: response.isRead,
                    createdAt: response.createdAt,
                    actorProfile: response.profiles
                )
            }

            print("✅ Fetched \(activities.count) activities")
            return activities
        } catch {
            print("❌ Failed to fetch activities: \(error)")
            throw ActivityServiceError.databaseError(error)
        }
    }

    /// Get count of unread activities
    /// - Parameter userId: The user to get unread count for
    /// - Returns: Number of unread activities
    func getUnreadCount(userId: UUID) async throws -> Int {
        do {
            let response = try await client
                .from("activities")
                .select("*", head: true, count: .exact)
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()

            return response.count ?? 0
        } catch {
            print("❌ Failed to get unread count: \(error)")
            throw ActivityServiceError.databaseError(error)
        }
    }

    /// Mark a single activity as read
    /// - Parameter activityId: The activity to mark as read
    func markAsRead(activityId: UUID) async throws {
        print("🔔 Marking activity as read: \(activityId)")

        do {
            struct UpdatePayload: Encodable {
                let isRead: Bool

                enum CodingKeys: String, CodingKey {
                    case isRead = "is_read"
                }
            }

            try await client
                .from("activities")
                .update(UpdatePayload(isRead: true))
                .eq("id", value: activityId.uuidString)
                .execute()

            print("✅ Activity marked as read")
        } catch {
            print("❌ Failed to mark activity as read: \(error)")
            throw ActivityServiceError.databaseError(error)
        }
    }

    /// Mark all activities as read for a user
    /// - Parameter userId: The user to mark all activities as read for
    func markAllAsRead(userId: UUID) async throws {
        print("🔔 Marking all activities as read for user: \(userId)")

        do {
            struct UpdatePayload: Encodable {
                let isRead: Bool

                enum CodingKeys: String, CodingKey {
                    case isRead = "is_read"
                }
            }

            try await client
                .from("activities")
                .update(UpdatePayload(isRead: true))
                .eq("user_id", value: userId.uuidString)
                .eq("is_read", value: false)
                .execute()

            print("✅ All activities marked as read")
        } catch {
            print("❌ Failed to mark all activities as read: \(error)")
            throw ActivityServiceError.databaseError(error)
        }
    }

    /// Delete a single activity
    /// - Parameters:
    ///   - activityId: The activity to delete
    ///   - userId: The user performing the deletion (must match activity owner)
    func deleteActivity(activityId: UUID, userId: UUID) async throws {
        print("🔔 Deleting activity: \(activityId)")

        do {
            // RLS policy ensures user can only delete their own activities
            try await client
                .from("activities")
                .delete()
                .eq("id", value: activityId.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("✅ Activity deleted")
        } catch {
            print("❌ Failed to delete activity: \(error)")
            throw ActivityServiceError.databaseError(error)
        }
    }

    /// Clear all activities for a user (delete all)
    /// - Parameter userId: The user to clear activities for
    func clearAllActivities(userId: UUID) async throws {
        print("🔔 Clearing all activities for user: \(userId)")

        do {
            try await client
                .from("activities")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            print("✅ All activities cleared")
        } catch {
            print("❌ Failed to clear activities: \(error)")
            throw ActivityServiceError.databaseError(error)
        }
    }
}

// MARK: - Errors

enum ActivityServiceError: LocalizedError {
    case databaseError(Error)
    case notAuthenticated

    var errorDescription: String? {
        switch self {
        case .databaseError(let error):
            return "Failed to process activity: \(error.localizedDescription)"
        case .notAuthenticated:
            return "You must be signed in to view activities"
        }
    }
}

//
//  ActivityRowView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/26/25.
//

import SwiftUI

struct ActivityRowView: View {
    let groupedActivity: GroupedActivityItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                // Avatar(s)
                avatarView

                // Content (text + timestamp)
                VStack(alignment: .leading, spacing: 4) {
                    activityText
                        .font(.system(size: 14))
                        .foregroundColor(.igTextPrimary)
                        .lineLimit(3)

                    Text(timeAgo)
                        .font(.system(size: 12))
                        .foregroundColor(.igTextSecondary)
                }

                Spacer()

                // Unread indicator
                if !groupedActivity.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.igBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Avatar View

    @ViewBuilder
    private var avatarView: some View {
        if groupedActivity.isGrouped && groupedActivity.actors.count > 1 {
            // Stacked avatars for grouped likes (show first 3)
            ZStack(alignment: .leading) {
                ForEach(Array(groupedActivity.actors.prefix(3).enumerated()), id: \.offset) { index, actor in
                    AsyncImage(url: avatarURL(for: actor)) { phase in
                        switch phase {
                        case .empty, .failure:
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 16))
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(Color.igBackground, lineWidth: 2)
                    )
                    .offset(x: CGFloat(index * 16), y: 0)
                }
            }
            .frame(width: 72, height: 40)
        } else {
            // Single avatar for individual activities
            AsyncImage(url: primaryAvatarURL) { phase in
                switch phase {
                case .empty, .failure:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Activity Text

    @ViewBuilder
    private var activityText: some View {
        switch groupedActivity.activityType {
        case .like:
            if groupedActivity.isGrouped {
                groupedLikeText
            } else {
                singleLikeText
            }
        case .comment:
            commentText
        case .follow:
            followText
        }
    }

    private var singleLikeText: some View {
        Text(username(for: 0))
            .fontWeight(.semibold)
        +
        Text(" liked your photo.")
    }

    private var groupedLikeText: some View {
        let actors = groupedActivity.actors
        let count = actors.count

        if count == 2 {
            return Text(username(for: 0))
                .fontWeight(.semibold)
            +
            Text(" and ")
            +
            Text(username(for: 1))
                .fontWeight(.semibold)
            +
            Text(" liked your photo.")
        } else if count > 2 {
            let othersCount = count - 1
            return Text(username(for: 0))
                .fontWeight(.semibold)
            +
            Text(" and ")
            +
            Text("\(othersCount) others")
                .fontWeight(.semibold)
            +
            Text(" liked your photo.")
        } else {
            // Fallback (shouldn't happen for grouped)
            return Text(username(for: 0))
                .fontWeight(.semibold)
            +
            Text(" liked your photo.")
        }
    }

    private var commentText: some View {
        Text(username(for: 0))
            .fontWeight(.semibold)
        +
        Text(" commented: ")
        +
        Text(commentBody)
            .foregroundColor(.igTextSecondary)
    }

    private var followText: some View {
        Text(username(for: 0))
            .fontWeight(.semibold)
        +
        Text(" started following you.")
    }

    // MARK: - Computed Properties

    private func username(for index: Int) -> String {
        guard index < groupedActivity.actors.count else {
            return "unknown"
        }
        return groupedActivity.actors[index].username
    }

    private func avatarURL(for actor: Profile) -> URL? {
        guard let avatarUrlString = actor.avatarUrl else {
            return nil
        }
        return URL(string: avatarUrlString)
    }

    private var primaryAvatarURL: URL? {
        guard let actor = groupedActivity.primaryActor else {
            return nil
        }
        return avatarURL(for: actor)
    }

    private var commentBody: String {
        // For comments, try to get the comment body
        // This would need to be fetched or included in the activity data
        // For now, we'll use a placeholder
        "..." // In production, you'd fetch this or include it in the activity model
    }

    private var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(groupedActivity.createdAt)

        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else if interval < 604800 {
            return "\(Int(interval / 86400))d"
        } else {
            return "\(Int(interval / 604800))w"
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // Single like
        ActivityRowView(
            groupedActivity: GroupedActivityItem(activities: [
                Activity(
                    id: UUID(),
                    userId: UUID(),
                    actorId: UUID(),
                    activityType: .like,
                    postId: UUID(),
                    isRead: false,
                    createdAt: Date().addingTimeInterval(-3600),
                    actorProfile: Profile(
                        id: UUID(),
                        username: "johndoe",
                        avatarUrl: nil,
                        fullName: "John Doe",
                        bio: nil,
                        createdAt: Date()
                    )
                )
            ]),
            onTap: {}
        )

        Divider()

        // Grouped likes
        ActivityRowView(
            groupedActivity: GroupedActivityItem(activities: [
                Activity(
                    id: UUID(),
                    userId: UUID(),
                    actorId: UUID(),
                    activityType: .like,
                    postId: UUID(),
                    isRead: true,
                    createdAt: Date().addingTimeInterval(-7200),
                    actorProfile: Profile(
                        id: UUID(),
                        username: "janedoe",
                        avatarUrl: nil,
                        fullName: "Jane Doe",
                        bio: nil,
                        createdAt: Date()
                    )
                ),
                Activity(
                    id: UUID(),
                    userId: UUID(),
                    actorId: UUID(),
                    activityType: .like,
                    postId: UUID(),
                    isRead: true,
                    createdAt: Date().addingTimeInterval(-7300),
                    actorProfile: Profile(
                        id: UUID(),
                        username: "bobsmith",
                        avatarUrl: nil,
                        fullName: "Bob Smith",
                        bio: nil,
                        createdAt: Date()
                    )
                )
            ]),
            onTap: {}
        )

        Divider()

        // Comment
        ActivityRowView(
            groupedActivity: GroupedActivityItem(activities: [
                Activity(
                    id: UUID(),
                    userId: UUID(),
                    actorId: UUID(),
                    activityType: .comment,
                    postId: UUID(),
                    commentId: UUID(),
                    isRead: false,
                    createdAt: Date().addingTimeInterval(-300),
                    actorProfile: Profile(
                        id: UUID(),
                        username: "alicewonder",
                        avatarUrl: nil,
                        fullName: "Alice Wonder",
                        bio: nil,
                        createdAt: Date()
                    )
                )
            ]),
            onTap: {}
        )

        Divider()

        // Follow
        ActivityRowView(
            groupedActivity: GroupedActivityItem(activities: [
                Activity(
                    id: UUID(),
                    userId: UUID(),
                    actorId: UUID(),
                    activityType: .follow,
                    isRead: true,
                    createdAt: Date().addingTimeInterval(-86400),
                    actorProfile: Profile(
                        id: UUID(),
                        username: "charlie",
                        avatarUrl: nil,
                        fullName: "Charlie Brown",
                        bio: nil,
                        createdAt: Date()
                    )
                )
            ]),
            onTap: {}
        )

        Spacer()
    }
}

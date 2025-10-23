//
//  CommentCellView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/23/25.
//

import SwiftUI

struct CommentCellView: View {
    let comment: Comment
    let currentUserId: UUID
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .empty:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                case .failure:
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                        )
                @unknown default:
                    EmptyView()
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Username + Comment Text
                Text(username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.igTextPrimary)
                +
                Text(" ")
                +
                Text(comment.body)
                    .font(.system(size: 14))
                    .foregroundColor(.igTextPrimary)

                // Timestamp
                Text(timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(.igTextSecondary)
            }

            Spacer()

            // Delete button (only for own comments)
            if isOwnComment {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties

    private var username: String {
        comment.userProfile?.username ?? "unknown"
    }

    private var avatarURL: URL? {
        guard let avatarUrlString = comment.userProfile?.avatarUrl else {
            return nil
        }
        return URL(string: avatarUrlString)
    }

    private var isOwnComment: Bool {
        comment.userId == currentUserId
    }

    private var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(comment.createdAt)

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

#Preview {
    VStack(spacing: 0) {
        CommentCellView(
            comment: Comment(
                id: UUID(),
                postId: UUID(),
                userId: UUID(),
                body: "This is a great photo! 🔥",
                createdAt: Date().addingTimeInterval(-3600),
                userProfile: Profile(
                    id: UUID(),
                    username: "johndoe",
                    avatarUrl: nil,
                    fullName: "John Doe",
                    bio: nil,
                    createdAt: Date()
                )
            ),
            currentUserId: UUID(),
            onDelete: {}
        )

        Divider()

        CommentCellView(
            comment: Comment(
                id: UUID(),
                postId: UUID(),
                userId: UUID(),
                body: "Beautiful shot! Where was this taken?",
                createdAt: Date().addingTimeInterval(-7200),
                userProfile: Profile(
                    id: UUID(),
                    username: "janedoe",
                    avatarUrl: nil,
                    fullName: "Jane Doe",
                    bio: nil,
                    createdAt: Date()
                )
            ),
            currentUserId: UUID(),
            onDelete: {}
        )
    }
}

//
//  UserRowView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/24/25.
//

import SwiftUI

/// Reusable component for displaying a user in a list
/// Used in: SearchView, FollowersListView, FollowingListView
struct UserRowView: View {
    let profile: Profile
    let showFollowButton: Bool
    let isFollowing: Bool
    let onFollowToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())
                    case .failure, .empty:
                        defaultAvatar
                    @unknown default:
                        defaultAvatar
                    }
                }
            } else {
                defaultAvatar
            }

            // Username and Full Name
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.username)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.igTextPrimary)

                if let fullName = profile.fullName, !fullName.isEmpty {
                    Text(fullName)
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                }
            }

            Spacer()

            // Follow Button (if enabled)
            if showFollowButton {
                Button(action: onFollowToggle) {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isFollowing ? .igTextPrimary : .white)
                        .frame(width: 90, height: 32)
                        .background(isFollowing ? Color.igBackgroundGray : Color.igBlue)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isFollowing ? Color.igBorderGray : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle()) // Prevent row tap from triggering button
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 44, height: 44)
            .foregroundColor(.igTextSecondary)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        UserRowView(
            profile: Profile(
                id: UUID(),
                username: "johndoe",
                avatarUrl: nil,
                fullName: "John Doe",
                bio: "Living life",
                createdAt: Date()
            ),
            showFollowButton: true,
            isFollowing: false,
            onFollowToggle: {}
        )

        Divider()

        UserRowView(
            profile: Profile(
                id: UUID(),
                username: "janedoe",
                avatarUrl: nil,
                fullName: "Jane Doe",
                bio: nil,
                createdAt: Date()
            ),
            showFollowButton: true,
            isFollowing: true,
            onFollowToggle: {}
        )

        Divider()

        UserRowView(
            profile: Profile(
                id: UUID(),
                username: "bobsmith",
                avatarUrl: nil,
                fullName: nil,
                bio: nil,
                createdAt: Date()
            ),
            showFollowButton: false,
            isFollowing: false,
            onFollowToggle: {}
        )
    }
    .background(Color.igBackground)
}

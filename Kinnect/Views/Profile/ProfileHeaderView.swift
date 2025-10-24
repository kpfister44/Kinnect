//
//  ProfileHeaderView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/21/25.
//

import SwiftUI

struct ProfileHeaderView: View {
    let profile: Profile
    let stats: ProfileStats
    let isCurrentUser: Bool
    let isFollowing: Bool
    let isFollowOperationInProgress: Bool
    let onEditProfile: () -> Void
    let onFollowToggle: () -> Void
    let onFollowersTap: () -> Void
    let onFollowingTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Avatar and Stats Row
            HStack(spacing: 20) {
                // Avatar
                if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 90)
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

                Spacer()

                // Stats
                HStack(spacing: 32) {
                    StatView(count: stats.postsCount, label: "Posts")

                    // Tappable Followers
                    Button(action: onFollowersTap) {
                        StatView(count: stats.followersCount, label: "Followers")
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Tappable Following
                    Button(action: onFollowingTap) {
                        StatView(count: stats.followingCount, label: "Following")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.trailing, 8)
            }
            .padding(.horizontal, 16)

            // Username and Bio
            VStack(alignment: .leading, spacing: 4) {
                if let fullName = profile.fullName, !fullName.isEmpty {
                    Text(fullName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.igTextPrimary)
                }

                if let bio = profile.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.system(size: 14))
                        .foregroundColor(.igTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            // Action Button (Edit Profile or Follow)
            if isCurrentUser {
                Button(action: onEditProfile) {
                    Text("Edit Profile")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.igTextPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(Color.igBackgroundGray)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.igBorderGray, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
            } else {
                // Follow button (Instagram-style)
                Button(action: onFollowToggle) {
                    HStack(spacing: 4) {
                        if isFollowOperationInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: isFollowing ? .igTextPrimary : .white))
                                .scaleEffect(0.8)
                        }
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isFollowing ? .igTextPrimary : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                    .background(isFollowing ? Color.igBackgroundGray : Color.igBlue)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFollowing ? Color.igBorderGray : Color.clear, lineWidth: 1)
                    )
                }
                .disabled(isFollowOperationInProgress)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 16)
    }

    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 90, height: 90)
            .foregroundColor(.igTextSecondary)
    }
}

// MARK: - Stat View Component

struct StatView: View {
    let count: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.igTextPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleProfile = Profile(
        id: UUID(),
        username: "johndoe",
        avatarUrl: nil,
        fullName: "John Doe",
        bio: "Living life one day at a time 🌟",
        createdAt: Date()
    )

    let sampleStats = ProfileStats(
        postsCount: 42,
        followersCount: 150,
        followingCount: 200
    )

    return VStack {
        ProfileHeaderView(
            profile: sampleProfile,
            stats: sampleStats,
            isCurrentUser: true,
            isFollowing: false,
            isFollowOperationInProgress: false,
            onEditProfile: {},
            onFollowToggle: {},
            onFollowersTap: {},
            onFollowingTap: {}
        )

        Spacer()
    }
    .background(Color.igBackground)
}

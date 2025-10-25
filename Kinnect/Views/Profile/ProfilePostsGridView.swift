//
//  ProfilePostsGridView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/21/25.
//

import SwiftUI

struct ProfilePostsGridView: View {
    let posts: [Post]
    let isCurrentUser: Bool
    let currentUserId: UUID

    // Grid layout: 3 columns with 1pt spacing (Instagram style)
    private let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color.igBorderGray)
                .frame(height: 0.5)

            if posts.isEmpty {
                // Empty State
                emptyState
            } else {
                // Posts Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 1) {
                        ForEach(posts) { post in
                            NavigationLink {
                                PostDetailView(post: post, currentUserId: currentUserId)
                            } label: {
                                PostGridCell(post: post)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "camera")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.igTextSecondary)

            VStack(spacing: 4) {
                Text(isCurrentUser ? "No Posts Yet" : "No Posts")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.igTextPrimary)

                if isCurrentUser {
                    Text("Share your first photo or video")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - Post Grid Cell

struct PostGridCell: View {
    let post: Post

    var body: some View {
        // Load actual image from signed URL
        if let mediaURL = post.mediaURL {
            AsyncImage(url: mediaURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.igBackgroundGray)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .igTextSecondary))
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(alignment: .topTrailing) {
                            // Show video icon for video posts
                            if post.mediaType == .video {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                                    .padding(8)
                            }
                        }
                case .failure:
                    Rectangle()
                        .fill(Color.igBackgroundGray)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay(
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.igTextSecondary)
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.igBackgroundGray)
                        .aspectRatio(1, contentMode: .fill)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
        } else {
            // Fallback if no URL
            Rectangle()
                .fill(Color.igBackgroundGray)
                .aspectRatio(1, contentMode: .fill)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.igTextSecondary)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VStack(spacing: 0) {
            // Empty State Preview
            ProfilePostsGridView(
                posts: [],
                isCurrentUser: true,
                currentUserId: UUID()
            )
            .frame(height: 300)

            Divider()

            // With Posts Preview
            ProfilePostsGridView(
                posts: [
                    Post(
                        id: UUID(),
                        author: UUID(),
                        caption: "Test post 1",
                        mediaKey: "test1.jpg",
                        mediaType: .photo,
                        createdAt: Date(),
                        mediaURL: URL(string: "https://picsum.photos/600/600")
                    ),
                    Post(
                        id: UUID(),
                        author: UUID(),
                        caption: "Test post 2",
                        mediaKey: "test2.jpg",
                        mediaType: .video,
                        createdAt: Date(),
                        mediaURL: URL(string: "https://picsum.photos/600/600?random=2")
                    )
                ],
                isCurrentUser: true,
                currentUserId: UUID()
            )
            .frame(height: 300)
        }
        .background(Color.igBackground)
    }
}

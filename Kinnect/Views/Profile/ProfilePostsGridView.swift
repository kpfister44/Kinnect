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
                            PostGridCell(post: post)
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
        GeometryReader { geometry in
            // Placeholder for post thumbnail
            // In Phase 6, this will load the actual image from Supabase Storage
            Rectangle()
                .fill(Color.igBackgroundGray)
                .aspectRatio(1, contentMode: .fill)
                .overlay(
                    Image(systemName: post.mediaType == .video ? "play.circle.fill" : "photo")
                        .foregroundColor(.igTextSecondary)
                )
        }
        .aspectRatio(1, contentMode: .fill)
        .clipped()
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        // Empty State Preview
        ProfilePostsGridView(posts: [], isCurrentUser: true)
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
                    createdAt: Date()
                ),
                Post(
                    id: UUID(),
                    author: UUID(),
                    caption: "Test post 2",
                    mediaKey: "test2.jpg",
                    mediaType: .video,
                    createdAt: Date()
                )
            ],
            isCurrentUser: true
        )
        .frame(height: 300)
    }
    .background(Color.igBackground)
}

//
//  FeedView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct FeedView: View {
    // MARK: - State
    @State private var posts: [Post] = []

    var body: some View {
        NavigationStack {
            Group {
                if posts.isEmpty {
                    emptyStateView
                } else {
                    feedScrollView
                }
            }
            .navigationTitle("Kinnect")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.igBackground)
            .onAppear {
                loadMockData()
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.igTextSecondary)

                Text("No posts yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.igTextPrimary)

                Text("Follow people to see their posts")
                    .font(.system(size: 16))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Feed Scroll View
    private var feedScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(posts) { post in
                    PostCellView(
                        post: post,
                        onLikeTapped: {
                            handleLike(post: post)
                        },
                        onCommentTapped: {
                            handleComment(post: post)
                        }
                    )

                    Divider()
                        .background(Color.igSeparator)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Actions
    private func handleLike(post: Post) {
        // TODO: Implement like functionality in Phase 7
        if let index = posts.firstIndex(where: { $0.id == post.id }) {
            posts[index].isLikedByCurrentUser.toggle()
            posts[index].likeCount += posts[index].isLikedByCurrentUser ? 1 : -1
        }
    }

    private func handleComment(post: Post) {
        // TODO: Implement comment functionality in Phase 7
        print("Comment tapped for post: \(post.id)")
    }

    // MARK: - Mock Data (Phase 4 only)
    private func loadMockData() {
        // Create mock profiles
        let profile1 = Profile(
            id: UUID(),
            username: "alex_wanderlust",
            avatarUrl: "https://i.pravatar.cc/150?img=12",
            fullName: "Alex Johnson",
            bio: "Adventure seeker 🌍",
            createdAt: Date().addingTimeInterval(-86400 * 30)
        )

        let profile2 = Profile(
            id: UUID(),
            username: "sarah.codes",
            avatarUrl: "https://i.pravatar.cc/150?img=45",
            fullName: "Sarah Martinez",
            bio: "iOS Developer • Coffee enthusiast ☕️",
            createdAt: Date().addingTimeInterval(-86400 * 60)
        )

        // Create mock posts
        posts = [
            Post(
                id: UUID(),
                author: profile1.id,
                caption: "Just finished an amazing hike in the mountains! The views were absolutely breathtaking and totally worth the early morning start. Can't wait to come back here again. 🏔️✨",
                mediaKey: "mock_post_1",
                mediaType: .photo,
                createdAt: Date().addingTimeInterval(-3600 * 2),
                authorProfile: profile1,
                likeCount: 124,
                commentCount: 15,
                isLikedByCurrentUser: false
            ),
            Post(
                id: UUID(),
                author: profile2.id,
                caption: "New coffee spot in town ☕️",
                mediaKey: "mock_post_2",
                mediaType: .photo,
                createdAt: Date().addingTimeInterval(-3600 * 8),
                authorProfile: profile2,
                likeCount: 67,
                commentCount: 8,
                isLikedByCurrentUser: true
            )
        ]
    }
}

#Preview {
    FeedView()
}

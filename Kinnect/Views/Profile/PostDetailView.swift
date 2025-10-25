//
//  PostDetailView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/25/25.
//

import SwiftUI

struct PostDetailView: View {
    let initialPost: Post
    let currentUserId: UUID

    @State private var post: Post
    @State private var showingComments = false
    @State private var isExpanded = false
    @State private var isLoadingDetails = true
    @Environment(\.dismiss) private var dismiss

    private let likeService = LikeService.shared
    private let commentService = CommentService.shared

    init(post: Post, currentUserId: UUID) {
        self.initialPost = post
        self.currentUserId = currentUserId
        _post = State(initialValue: post)
    }

    private var shouldTruncate: Bool {
        guard let caption = post.caption else { return false }
        return caption.count > 100
    }

    private var displayCaption: String {
        guard let caption = post.caption else { return "" }
        if !isExpanded && shouldTruncate {
            let index = caption.index(caption.startIndex, offsetBy: 100, limitedBy: caption.endIndex) ?? caption.endIndex
            return String(caption[..<index])
        }
        return caption
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Post Header
                headerView

                // Post Image
                imageView

                // Action Buttons
                actionButtonsView

                // Like Count
                if post.likeCount > 0 {
                    Text("\(post.likeCount) \(post.likeCount == 1 ? "like" : "likes")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.igTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 4)
                }

                // Caption
                if let caption = post.caption, !caption.isEmpty {
                    CaptionView(
                        username: post.authorProfile?.username ?? "Unknown",
                        caption: displayCaption,
                        shouldShowMore: shouldTruncate && !isExpanded,
                        isExpanded: $isExpanded,
                        shouldTruncate: shouldTruncate
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

                // View Comments
                if post.commentCount > 0 {
                    Button {
                        showingComments = true
                    } label: {
                        Text("View all \(post.commentCount) comments")
                            .font(.system(size: 14))
                            .foregroundColor(.igTextSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }

                // Timestamp
                Text(post.createdAt.timeAgoDisplay())
                    .font(.system(size: 12))
                    .foregroundColor(.igTextSecondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)

                Spacer()
            }
        }
        .background(Color.igBackground)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPostDetails()
        }
        .sheet(isPresented: $showingComments) {
            CommentsView(
                postId: post.id,
                currentUserId: currentUserId,
                onCommentCountChanged: { newCount in
                    post.commentCount = newCount
                }
            )
        }
    }

    // MARK: - View Components

    private var headerView: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = post.authorProfile?.avatarUrl {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.igSeparator)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.igSeparator)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.igTextSecondary)
                    )
            }

            // Username
            Text(post.authorProfile?.username ?? "Unknown")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Spacer()

            // Three-dot menu
            Button {
                // TODO: Show post options menu
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.igTextPrimary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var imageView: some View {
        AsyncImage(url: post.mediaURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.igSeparator)
                    .overlay(ProgressView().tint(.igTextSecondary))
                    .aspectRatio(1, contentMode: .fit)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
            case .failure:
                Rectangle()
                    .fill(Color.igSeparator)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.igTextSecondary)
                            Text("Failed to load")
                                .font(.system(size: 12))
                                .foregroundColor(.igTextSecondary)
                        }
                    )
                    .aspectRatio(1, contentMode: .fit)
            @unknown default:
                Rectangle()
                    .fill(Color.igSeparator)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            // Like Button
            Button {
                Task {
                    await toggleLike()
                }
            } label: {
                Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(post.isLikedByCurrentUser ? .igRed : .igTextPrimary)
            }

            // Comment Button
            Button {
                showingComments = true
            } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 24))
                    .foregroundColor(.igTextPrimary)
            }

            // Share Button
            Button {
                // TODO: Share action
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 24))
                    .foregroundColor(.igTextPrimary)
            }

            Spacer()

            // Bookmark Button
            Button {
                // TODO: Bookmark action
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 24))
                    .foregroundColor(.igTextPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func loadPostDetails() async {
        isLoadingDetails = true

        do {
            // Fetch like count, comment count, and like status in parallel
            async let likeCount = fetchLikeCount()
            async let commentCount = fetchCommentCount()
            async let isLiked = fetchIsLikedByCurrentUser()

            let (likes, comments, liked) = try await (likeCount, commentCount, isLiked)

            post.likeCount = likes
            post.commentCount = comments
            post.isLikedByCurrentUser = liked
        } catch {
            print("⚠️ Failed to load post details: \(error)")
        }

        isLoadingDetails = false
    }

    private func fetchLikeCount() async throws -> Int {
        return try await likeService.getLikeCount(postId: post.id)
    }

    private func fetchCommentCount() async throws -> Int {
        return try await commentService.getCommentCount(postId: post.id)
    }

    private func fetchIsLikedByCurrentUser() async throws -> Bool {
        return try await likeService.isPostLikedByUser(postId: post.id, userId: currentUserId)
    }

    private func toggleLike() async {
        // Optimistic update
        let wasLiked = post.isLikedByCurrentUser
        post.isLikedByCurrentUser.toggle()

        if post.isLikedByCurrentUser {
            post.likeCount += 1
        } else {
            post.likeCount = max(0, post.likeCount - 1)
        }

        do {
            if wasLiked {
                // Unlike
                try await likeService.unlikePost(postId: post.id, userId: currentUserId)
                print("✅ Unliked post")
            } else {
                // Like
                try await likeService.likePost(postId: post.id, userId: currentUserId)
                print("✅ Liked post")
            }
        } catch {
            // Revert on error
            print("❌ Failed to toggle like: \(error)")
            post.isLikedByCurrentUser = wasLiked
            if wasLiked {
                post.likeCount += 1
            } else {
                post.likeCount = max(0, post.likeCount - 1)
            }
        }
    }
}

#Preview {
    NavigationStack {
        PostDetailView(
            post: Post(
                id: UUID(),
                author: UUID(),
                caption: "This is a sample post caption for testing the detail view. It should show how captions are displayed with proper formatting.",
                mediaKey: "sample1",
                mediaType: .photo,
                createdAt: Date().addingTimeInterval(-3600),
                authorProfile: Profile(
                    id: UUID(),
                    username: "johndoe",
                    avatarUrl: "https://i.pravatar.cc/150?img=1",
                    fullName: "John Doe",
                    bio: nil,
                    createdAt: Date()
                ),
                likeCount: 42,
                commentCount: 8,
                isLikedByCurrentUser: false,
                mediaURL: URL(string: "https://picsum.photos/600/600")
            ),
            currentUserId: UUID()
        )
    }
}

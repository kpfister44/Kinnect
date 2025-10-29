//
//  PostCellView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import SwiftUI

struct PostCellView: View {
    let post: Post
    var mediaURL: URL? // Real Supabase URL
    @EnvironmentObject var feedViewModel: FeedViewModel

    @State private var isExpanded = false
    @State private var showingComments = false
    @State private var showDeleteConfirmation = false
    @State private var showUnfollowConfirmation = false

    init(post: Post, mediaURL: URL?) {
        self.post = post
        self.mediaURL = mediaURL
    }

    private var shouldTruncate: Bool {
        guard let caption = post.caption else { return false }
        return caption.count > 100 // Roughly 3 lines
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
        VStack(alignment: .leading, spacing: 0) {
            headerView
            imageView
            actionButtonsView

            // MARK: - Like Count
            if post.likeCount > 0 {
                Text("\(post.likeCount) \(post.likeCount == 1 ? "like" : "likes")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.igTextPrimary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }

            // MARK: - Caption
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

            // MARK: - View Comments (if comments exist)
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

            // MARK: - Timestamp
            Text(post.createdAt.timeAgoDisplay())
                .font(.system(size: 12))
                .foregroundColor(.igTextSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
        }
        .background(Color.igBackground)
        .sheet(isPresented: $showingComments) {
            CommentsView(
                postId: post.id,
                currentUserId: feedViewModel.currentUserId,
                onCommentCountChanged: { _ in
                    // Comment count updates handled by realtime in FeedViewModel
                }
            )
        }
        .alert("Delete Post?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await feedViewModel.deletePost(post)
                }
            }
        } message: {
            Text("This post will be permanently deleted.")
        }
        .alert("Unfollow \(post.authorProfile?.username ?? "User")?", isPresented: $showUnfollowConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Unfollow", role: .destructive) {
                Task {
                    await feedViewModel.unfollowPostAuthor(post)
                }
            }
        } message: {
            Text("Their posts will no longer appear in your feed.")
        }
    }

    // MARK: - View Components

    private var imageView: some View {
        AsyncImage(url: mediaURL) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.igSeparator)
                    .overlay(ProgressView().tint(.igTextSecondary))
                    .aspectRatio(1, contentMode: .fit)
                    .onAppear {
                        print("🖼️ AsyncImage EMPTY for post \(post.id)")
                        print("🖼️ mediaURL provided: \(mediaURL?.absoluteString ?? "nil")")
                    }
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .onAppear {
                        print("✅ AsyncImage SUCCESS for post \(post.id)")
                    }
            case .failure(let error):
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
                    .onAppear {
                        print("❌ AsyncImage FAILURE for post \(post.id)")
                        print("❌ Error: \(error)")
                        print("❌ mediaURL provided: \(mediaURL?.absoluteString ?? "nil")")

                        if let urlError = error as? URLError, urlError.code == .cancelled {
                            feedViewModel.recordImageCancellation(for: post.id)
                        }
                    }
            @unknown default:
                Rectangle()
                    .fill(Color.igSeparator)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .id("\(post.id)-\(feedViewModel.viewAppearanceID)")
    }

    private var actionButtonsView: some View {
        HStack(spacing: 16) {
            Button {
                feedViewModel.toggleLike(forPostID: post.id)
            } label: {
                Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                    .font(.system(size: 24))
                    .foregroundColor(post.isLikedByCurrentUser ? .igRed : .igTextPrimary)
            }

            Button {
                showingComments = true
            } label: {
                Image(systemName: "bubble.right")
                    .font(.system(size: 24))
                    .foregroundColor(.igTextPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

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
                .id("\(post.author)-avatar-\(feedViewModel.viewAppearanceID)")
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
                handleThreeDotMenuTap()
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

    // MARK: - Actions

    private func handleThreeDotMenuTap() {
        // Check if this is the current user's post
        let isOwnPost = post.author == feedViewModel.currentUserId

        if isOwnPost {
            showDeleteConfirmation = true
        } else {
            showUnfollowConfirmation = true
        }
    }
}

// MARK: - Caption View Component
struct CaptionView: View {
    let username: String
    let caption: String
    let shouldShowMore: Bool
    @Binding var isExpanded: Bool
    let shouldTruncate: Bool

    var body: some View {
        Group {
            Text(username)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.igTextPrimary)
            +
            Text(" ")
                .font(.system(size: 14))
            +
            Text(caption)
                .font(.system(size: 14))
                .foregroundColor(.igTextPrimary)
            +
            (shouldShowMore ? moreText : Text(""))
        }
        .onTapGesture {
            if shouldTruncate {
                isExpanded.toggle()
            }
        }
    }

    private var moreText: Text {
        Text("... ")
            .font(.system(size: 14))
            .foregroundColor(.igTextSecondary)
        +
        Text("more")
            .font(.system(size: 14))
            .foregroundColor(.igTextSecondary)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        PostCellView(
            post: Post(
                id: UUID(),
                author: UUID(),
                caption: "This is a sample post caption for testing the UI layout. It should show how captions are displayed with proper formatting and the 'more' button when the text is too long to fit in the initial view.",
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
                isLikedByCurrentUser: false
            ),
            mediaURL: URL(string: "https://picsum.photos/600/600")
        )
        .environmentObject(FeedViewModel(currentUserId: UUID()))

        Divider()

        PostCellView(
            post: Post(
                id: UUID(),
                author: UUID(),
                caption: "Short caption",
                mediaKey: "sample2",
                mediaType: .photo,
                createdAt: Date().addingTimeInterval(-86400),
                authorProfile: Profile(
                    id: UUID(),
                    username: "janedoe",
                    avatarUrl: "https://i.pravatar.cc/150?img=2",
                    fullName: "Jane Doe",
                    bio: nil,
                    createdAt: Date()
                ),
                likeCount: 15,
                commentCount: 0,
                isLikedByCurrentUser: true
            ),
            mediaURL: URL(string: "https://picsum.photos/600/600?random=2")
        )
        .environmentObject(FeedViewModel(currentUserId: UUID()))
    }
}

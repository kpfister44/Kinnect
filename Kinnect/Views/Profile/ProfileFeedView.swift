//
//  ProfileFeedView.swift
//  Kinnect
//
//  Profile feed navigation - shows user's posts in feed format with scroll-to-post
//

import SwiftUI

struct ProfileFeedView: View {
    let userId: UUID
    let initialPostId: UUID
    let currentUserId: UUID

    @StateObject private var viewModel: ProfileFeedViewModel
    @Environment(\.dismiss) private var dismiss

    init(userId: UUID, initialPostId: UUID, currentUserId: UUID) {
        self.userId = userId
        self.initialPostId = initialPostId
        self.currentUserId = currentUserId

        // Create view model
        _viewModel = StateObject(wrappedValue: ProfileFeedViewModel(
            userId: userId,
            currentUserId: currentUserId
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground.ignoresSafeArea()

                switch viewModel.state {
                case .idle, .loading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .igTextSecondary))

                case .loaded:
                    if viewModel.posts.isEmpty {
                        emptyState
                    } else {
                        feedContent
                    }

                case .error:
                    errorState
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Posts")
                            .font(.system(size: 12))
                            .foregroundColor(.igTextSecondary)

                        Text(viewModel.posts.first?.authorProfile?.username ?? "")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.igTextPrimary)
                    }
                }
            }
            .task {
                // Load posts when view appears
                await viewModel.loadPosts()
            }
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        PostCellView(
                            post: post,
                            mediaURL: viewModel.getMediaURL(for: post),
                            viewModel: viewModel
                        )
                        .id(post.id)

                        // Divider between posts
                        Rectangle()
                            .fill(Color.igBorderGray)
                            .frame(height: 0.5)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // Scroll to initial post after layout completes
                // Delay allows AsyncImages to start downloading before scroll
                // This prevents cancellation of images that scroll out of view
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Check if initial post exists in the list
                    if viewModel.posts.contains(where: { $0.id == initialPostId }) {
                        proxy.scrollTo(initialPostId, anchor: .top)
                        print("✅ Scrolled to post: \(initialPostId)")
                    } else if let firstPost = viewModel.posts.first {
                        // Fallback: scroll to first post if initial post not found
                        proxy.scrollTo(firstPost.id, anchor: .top)
                        print("⚠️ Initial post not found, scrolled to first post")
                    } else {
                        print("⚠️ No posts to scroll to")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.igTextSecondary)

            Text("No posts")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.igTextPrimary)
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.igTextSecondary)

            Text("Failed to load posts")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                Task {
                    await viewModel.loadPosts()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color.igBlue)
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileFeedView(
            userId: UUID(),
            initialPostId: UUID(),
            currentUserId: UUID()
        )
    }
}

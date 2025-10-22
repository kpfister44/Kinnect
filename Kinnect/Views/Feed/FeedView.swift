//
//  FeedView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct FeedView: View {
    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel

    // MARK: - State
    @StateObject private var viewModel: FeedViewModel

    // MARK: - Initialization
    init(currentUserId: UUID) {
        _viewModel = StateObject(wrappedValue: FeedViewModel(currentUserId: currentUserId))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle, .loading:
                    loadingView
                case .loaded:
                    if viewModel.posts.isEmpty {
                        emptyStateView
                    } else {
                        feedScrollView
                    }
                case .error:
                    errorView
                }
            }
            .navigationTitle("Kinnect")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.igBackground)
            .task {
                await viewModel.loadFeed()
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.igBlue)

                Text("Loading feed...")
                    .font(.system(size: 16))
                    .foregroundColor(.igTextSecondary)
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

                Text("Upload a photo to get started!")
                    .font(.system(size: 16))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: - Error View
    private var errorView: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.igRed)

                Text("Couldn't load feed")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.igTextPrimary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.igBlue)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    // MARK: - Feed Scroll View
    private var feedScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.posts, id: \.id) { post in
                    PostCellView(
                        post: post,
                        mediaURL: viewModel.getMediaURL(for: post)
                    )
                    .environmentObject(viewModel)
                    .id(post.id) // Ensure SwiftUI tracks each cell by post ID
                    .task {
                        // Pagination: load more when reaching last post
                        await viewModel.loadMorePostsIfNeeded(currentPost: post)
                    }

                    Divider()
                        .background(Color.igSeparator)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    FeedView(currentUserId: UUID())
        .environmentObject(AuthViewModel())
}

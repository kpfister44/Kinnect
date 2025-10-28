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
            ZStack {
                Group {
                    switch viewModel.state {
                    case .idle, .loading:
                        loadingView
                    case .loaded:
                        if viewModel.posts.isEmpty {
                            emptyStateView
                        } else {
                            feedScrollViewWithBanner
                        }
                    case .error:
                        errorView
                    }
                }
                .navigationTitle("Kinnect")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.igBackground)

                // Error toast (for like/action errors)
                if let errorMessage = viewModel.errorMessage, viewModel.state == .loaded {
                    VStack {
                        Spacer()

                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.white)

                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()

                            Button {
                                viewModel.errorMessage = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundColor(.white)
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .padding()
                        .background(Color.igBlack.opacity(0.9))
                        .cornerRadius(8)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .animation(.spring(), value: viewModel.errorMessage)
                }
            }
            .task {
                await viewModel.loadFeed()
                await viewModel.setupRealtimeSubscriptions()
            }
            .onDisappear {
                Task {
                    await viewModel.cleanupRealtimeSubscriptions()
                }
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
                Image(systemName: "person.2.slash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.igTextSecondary)

                Text("Welcome to Kinnect")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.igTextPrimary)

                Text("Follow people to see their posts in your feed")
                    .font(.system(size: 16))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Tap the search tab to find friends")
                    .font(.system(size: 14))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
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

    // MARK: - Feed Scroll View with Banner (Phase 9)
    private var feedScrollViewWithBanner: some View {
        ZStack(alignment: .top) {
            // Main feed content
            ScrollViewReader { proxy in
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
                .onChange(of: viewModel.pendingNewPostsCount) { oldValue, newValue in
                    // When user taps banner, scroll to top
                    if newValue == 0, oldValue > 0, let firstPost = viewModel.posts.first {
                        withAnimation {
                            proxy.scrollTo(firstPost.id, anchor: .top)
                        }
                    }
                }
            }

            // New posts banner overlay (Phase 9)
            // Only banner shown - appears when real-time detects new posts
            if viewModel.showNewPostsBanner {
                VStack {
                    NewPostsBanner(count: viewModel.pendingNewPostsCount) {
                        Task {
                            await viewModel.scrollToTopAndLoadNewPosts()
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .zIndex(1) // Ensure banner stays on top
            }
        }
    }
}

#Preview {
    FeedView(currentUserId: UUID())
        .environmentObject(AuthViewModel())
}

//
//  CommentsView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/23/25.
//

import SwiftUI

struct CommentsView: View {
    @StateObject private var viewModel: CommentViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool

    init(postId: UUID, currentUserId: UUID, onCommentCountChanged: @escaping (Int) -> Void) {
        _viewModel = StateObject(
            wrappedValue: CommentViewModel(
                postId: postId,
                currentUserId: currentUserId,
                onCommentCountChanged: onCommentCountChanged
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Content area
                Group {
                    switch viewModel.state {
                    case .idle, .loading:
                        loadingView
                    case .loaded, .posting:
                        if viewModel.comments.isEmpty {
                            emptyStateView
                        } else {
                            commentsScrollView
                        }
                    case .error:
                        errorView
                    }
                }

                Divider()
                    .background(Color.igSeparator)

                // Input area (always visible)
                commentInputArea
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.igTextPrimary)
                    }
                }
            }
            .background(Color.igBackground)
            .task {
                await viewModel.loadComments()
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.2)
                .tint(.igBlue)

            Text("Loading comments...")
                .font(.system(size: 14))
                .foregroundColor(.igTextSecondary)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.igTextSecondary)

            Text("No comments yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Text("Be the first to comment!")
                .font(.system(size: 14))
                .foregroundColor(.igTextSecondary)

            Spacer()
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(.igRed)

            Text("Couldn't load comments")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Button {
                Task {
                    await viewModel.loadComments()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.igBlue)
                    .cornerRadius(6)
            }

            Spacer()
        }
    }

    // MARK: - Comments Scroll View

    private var commentsScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.comments) { comment in
                    CommentCellView(
                        comment: comment,
                        currentUserId: viewModel.currentUserId,
                        onDelete: {
                            Task {
                                await viewModel.deleteComment(comment)
                            }
                        }
                    )

                    Divider()
                        .background(Color.igSeparator)
                        .padding(.leading, 60) // Align with comment text
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Comment Input Area

    private var commentInputArea: some View {
        HStack(spacing: 12) {
            // Text field
            TextField("Add a comment...", text: $viewModel.commentText, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(1...6)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    Task {
                        await viewModel.postComment()
                    }
                }

            // Character count (when typing)
            if viewModel.characterCount > 0 {
                Text("\(viewModel.characterCount)")
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.isAtCharacterLimit ? .igRed : .igTextSecondary)
            }

            // Post button
            Button {
                Task {
                    await viewModel.postComment()
                    isInputFocused = false
                }
            } label: {
                if viewModel.state == .posting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Post")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(viewModel.canPost ? .igBlue : .igTextSecondary)
                }
            }
            .disabled(!viewModel.canPost || viewModel.state == .posting)
        }
        .padding()
        .background(Color.igBackground)
    }
}

#Preview {
    CommentsView(
        postId: UUID(),
        currentUserId: UUID(),
        onCommentCountChanged: { _ in }
    )
}

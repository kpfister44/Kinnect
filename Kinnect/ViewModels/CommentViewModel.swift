//
//  CommentViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/23/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class CommentViewModel: ObservableObject {
    // MARK: - Published State
    @Published var comments: [Comment] = []
    @Published var state: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var commentText: String = ""

    // MARK: - Dependencies
    private let commentService: CommentService
    private let postId: UUID
    let currentUserId: UUID // Exposed for CommentCellView
    private let onCommentCountChanged: (Int) -> Void

    // MARK: - Initialization

    init(
        postId: UUID,
        currentUserId: UUID,
        commentService: CommentService? = nil,
        onCommentCountChanged: @escaping (Int) -> Void
    ) {
        self.postId = postId
        self.currentUserId = currentUserId
        self.commentService = commentService ?? .shared
        self.onCommentCountChanged = onCommentCountChanged
    }

    // MARK: - Loading State

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
        case posting
    }

    // MARK: - Public Methods

    /// Load comments for the post
    func loadComments() async {
        state = .loading

        do {
            let fetchedComments = try await commentService.fetchComments(postId: postId)
            comments = fetchedComments
            state = .loaded
            errorMessage = nil

            print("✅ Loaded \(comments.count) comments")
        } catch {
            print("❌ Failed to load comments: \(error)")
            state = .error
            errorMessage = error.localizedDescription
        }
    }

    /// Add a new comment
    func postComment() async {
        let trimmedText = commentText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            return
        }

        guard trimmedText.count <= CommentService.maxCommentLength else {
            errorMessage = "Comment is too long"
            return
        }

        // Store text for potential retry
        let textToPost = trimmedText

        // Clear input immediately (optimistic)
        commentText = ""

        // Set posting state
        let previousState = state
        state = .posting

        do {
            // Add comment to database
            var newComment = try await commentService.addComment(
                postId: postId,
                userId: currentUserId,
                body: textToPost
            )

            // Fetch current user's profile for display
            // (In production, you'd cache this or pass it in)
            // For now, we'll create a minimal profile
            // This will be populated by the next loadComments call

            // Optimistically add to local array
            comments.append(newComment)

            // Notify parent of count change
            onCommentCountChanged(comments.count)

            // Refresh to get full profile data
            await loadComments()

            print("✅ Comment posted successfully")
        } catch {
            print("❌ Failed to post comment: \(error)")

            // Restore text on error
            commentText = textToPost

            // Restore state
            state = previousState

            // Show error
            errorMessage = error.localizedDescription
        }
    }

    /// Delete a comment
    func deleteComment(_ comment: Comment) async {
        // Optimistically remove from UI
        let originalComments = comments
        comments.removeAll { $0.id == comment.id }

        // Notify parent of count change
        onCommentCountChanged(comments.count)

        do {
            try await commentService.deleteComment(
                commentId: comment.id,
                userId: currentUserId
            )

            print("✅ Comment deleted successfully")
        } catch {
            print("❌ Failed to delete comment: \(error)")

            // Restore on error
            comments = originalComments

            // Restore count
            onCommentCountChanged(comments.count)

            // Show error
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    var characterCount: Int {
        commentText.count
    }

    var isAtCharacterLimit: Bool {
        characterCount >= CommentService.maxCommentLength
    }

    var canPost: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        characterCount <= CommentService.maxCommentLength
    }
}

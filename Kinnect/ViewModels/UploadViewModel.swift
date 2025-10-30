//
//  UploadViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class UploadViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isUploading = false
    @Published var uploadSuccess = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let userId: UUID
    private let postService: PostService

    // MARK: - Initialization

    init(userId: UUID, postService: PostService = .shared) {
        self.userId = userId
        self.postService = postService
    }

    // MARK: - Public Methods

    /// Upload a post with image and optional caption
    func uploadPost(image: UIImage, caption: String?) async {
        print("🚀 Starting upload process...")

        // Reset state
        isUploading = true
        uploadSuccess = false
        errorMessage = nil

        do {
            // Create post (uploads image + creates database record)
            let post = try await postService.createPost(
                image: image,
                caption: caption,
                userId: userId
            )

            print("✅ Post created successfully: \(post.id)")

            // Update UI
            isUploading = false
            uploadSuccess = true

            // Notify other ViewModels to invalidate cache so new post appears when switching tabs
            NotificationCenter.default.post(name: .userDidCreatePost, object: userId)
            print("📢 Posted userDidCreatePost notification for user: \(userId)")

        } catch let error as PostServiceError {
            // Handle known errors
            print("❌ Upload failed: \(error.localizedDescription)")
            isUploading = false
            errorMessage = error.localizedDescription

        } catch {
            // Handle unknown errors
            print("❌ Upload failed: \(error.localizedDescription)")
            isUploading = false
            errorMessage = "An unexpected error occurred. Please try again."
        }
    }

    /// Reset upload state
    func reset() {
        isUploading = false
        uploadSuccess = false
        errorMessage = nil
    }
}

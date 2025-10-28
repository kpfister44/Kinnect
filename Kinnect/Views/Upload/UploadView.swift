//
//  UploadView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI
import PhotosUI

// MARK: - Identifiable Image Wrapper
/// Wrapper to make UIImage identifiable for sheet presentation
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct UploadView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageWrapper: IdentifiableImage? // Changed: use wrapper instead of UIImage
    @State private var isProcessingImage = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Camera icon
                    Image(systemName: "camera.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.igTextSecondary)

                    // Title and description
                    VStack(spacing: 8) {
                        Text("Share a moment")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.igTextPrimary)

                        Text("Select a photo from your library")
                            .font(.system(size: 16))
                            .foregroundColor(.igTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Photo picker button
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 18, weight: .medium))

                            Text("Select Photo")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.igBlue)
                        .cornerRadius(8)
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.igRed)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 8)
                    }
                }
                .padding()
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedItem) { _, newItem in
                guard newItem != nil, !isProcessingImage else {
                    return
                }

                isProcessingImage = true

                Task {
                    do {
                        guard let data = try await newItem?.loadTransferable(type: Data.self) else {
                            await MainActor.run {
                                errorMessage = "Failed to load selected photo. Try selecting a different photo."
                                isProcessingImage = false
                                selectedItem = nil
                            }
                            return
                        }

                        guard let uiImage = UIImage(data: data) else {
                            await MainActor.run {
                                errorMessage = "Failed to process selected photo. Try selecting a different photo."
                                isProcessingImage = false
                                selectedItem = nil
                            }
                            return
                        }

                        // Wait for PhotosPicker to fully dismiss before presenting sheet
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                        // Set image wrapper on main thread - this triggers sheet presentation
                        await MainActor.run {
                            selectedImageWrapper = IdentifiableImage(image: uiImage)
                            errorMessage = nil // Clear any previous errors
                            isProcessingImage = false
                        }
                    } catch {
                        print("❌ Failed to load image: \(error)")

                        // Provide user-friendly error message
                        await MainActor.run {
                            // Check if it's an iCloud-related error (common in simulator)
                            if error.localizedDescription.contains("CloudPhotoLibrary") ||
                               error.localizedDescription.contains("PHAssetExportRequest") ||
                               error.localizedDescription.contains("helper application") {
                                errorMessage = "Cannot access iCloud photos in simulator. Try using a local photo or test on a physical device."
                            } else {
                                errorMessage = "Failed to load selected photo. Please try again or choose a different photo."
                            }

                            // Reset state
                            isProcessingImage = false
                            selectedItem = nil
                        }
                    }
                }
            }
            .sheet(item: $selectedImageWrapper, onDismiss: {
                // Reset state when sheet is dismissed
                selectedItem = nil
                selectedImageWrapper = nil
                isProcessingImage = false
                errorMessage = nil
            }) { imageWrapper in
                // Sheet content - only presents when imageWrapper is non-nil
                if let userId = currentUserId {
                    NewPostView(selectedImage: imageWrapper.image, userId: userId)
                }
            }
        }
    }

    // MARK: - Helper

    private var currentUserId: UUID? {
        if case .authenticated(let userId) = authViewModel.authState {
            return userId
        }
        return nil
    }
}

#Preview {
    UploadView()
        .environmentObject(AuthViewModel())
}

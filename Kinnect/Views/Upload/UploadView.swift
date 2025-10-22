//
//  UploadView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI
import PhotosUI

struct UploadView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showNewPostView = false
    @State private var isProcessingImage = false

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
                    guard let data = try await newItem?.loadTransferable(type: Data.self) else {
                        await MainActor.run { isProcessingImage = false }
                        return
                    }

                    guard let uiImage = UIImage(data: data) else {
                        await MainActor.run { isProcessingImage = false }
                        return
                    }

                    // Ensure UI updates happen on main thread
                    await MainActor.run {
                        selectedImage = uiImage
                    }

                    // Wait for PhotosPicker to fully dismiss (prevents first-launch glitch)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                    await MainActor.run {
                        showNewPostView = true
                        isProcessingImage = false
                    }
                }
            }
            .sheet(isPresented: $showNewPostView) {
                // Reset selection when sheet is dismissed
                selectedItem = nil
                selectedImage = nil
                isProcessingImage = false
            } content: {
                if let image = selectedImage, let userId = currentUserId {
                    NewPostView(selectedImage: image, userId: userId)
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

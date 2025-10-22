//
//  NewPostView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import SwiftUI

struct NewPostView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: UploadViewModel

    let selectedImage: UIImage

    @State private var caption: String = ""
    @FocusState private var isCaptionFocused: Bool

    // Instagram's caption limit is 2,200 characters
    private let maxCaptionLength = 2200

    init(selectedImage: UIImage, userId: UUID) {
        self.selectedImage = selectedImage
        self._viewModel = StateObject(wrappedValue: UploadViewModel(userId: userId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                if viewModel.isUploading {
                    uploadingOverlay
                } else {
                    mainContent
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isUploading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        sharePost()
                    }
                    .bold()
                    .disabled(viewModel.isUploading)
                }
            }
            .alert("Upload Failed", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onChange(of: viewModel.uploadSuccess) { _, success in
                if success {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Image Preview
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)

                // Caption Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        // Small thumbnail
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        // Caption text editor
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Write a caption...", text: $caption, axis: .vertical)
                                .font(.system(size: 16))
                                .foregroundColor(.igTextPrimary)
                                .lineLimit(10)
                                .focused($isCaptionFocused)
                                .onChange(of: caption) { _, newValue in
                                    // Enforce character limit
                                    if newValue.count > maxCaptionLength {
                                        caption = String(newValue.prefix(maxCaptionLength))
                                    }
                                }

                            // Character count
                            if !caption.isEmpty {
                                Text("\(caption.count)/\(maxCaptionLength)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.igTextSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .background(Color.igSeparator)
                }
                .background(Color.igBackground)

                Spacer()
            }
        }
        .onAppear {
            // Auto-focus caption field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCaptionFocused = true
            }
        }
    }

    // MARK: - Uploading Overlay

    private var uploadingOverlay: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.igBlue)

            Text("Posting...")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.igTextPrimary)

            Text("Please wait while we upload your post")
                .font(.system(size: 14))
                .foregroundColor(.igTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.igBackground)
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(40)
    }

    // MARK: - Actions

    private func sharePost() {
        Task {
            await viewModel.uploadPost(image: selectedImage, caption: caption.isEmpty ? nil : caption)
        }
    }
}

#Preview {
    NewPostView(
        selectedImage: UIImage(systemName: "photo")!,
        userId: UUID()
    )
}

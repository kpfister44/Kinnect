//
//  EditProfileView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/21/25.
//

import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    let profile: Profile

    @State private var username: String
    @State private var fullName: String
    @State private var bio: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showPhotoPicker = false

    @FocusState private var focusedField: Field?

    enum Field {
        case username
        case fullName
        case bio
    }

    init(viewModel: ProfileViewModel, profile: Profile) {
        self.viewModel = viewModel
        self.profile = profile
        _username = State(initialValue: profile.username)
        _fullName = State(initialValue: profile.fullName ?? "")
        _bio = State(initialValue: profile.bio ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Section
                        VStack(spacing: 12) {
                            // Avatar Preview
                            ZStack(alignment: .bottomTrailing) {
                                if let selectedImage = selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                } else if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        case .failure, .empty:
                                            defaultAvatar
                                        @unknown default:
                                            defaultAvatar
                                        }
                                    }
                                } else {
                                    defaultAvatar
                                }

                                // Edit Icon
                                Image(systemName: "camera.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.igBlue)
                                    .background(Color.igBackground)
                                    .clipShape(Circle())
                            }
                            .onTapGesture {
                                showPhotoPicker = true
                            }

                            Button(action: {
                                showPhotoPicker = true
                            }) {
                                Text("Change Profile Photo")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.igBlue)
                            }
                        }
                        .padding(.top, 20)

                        // Form Fields
                        VStack(spacing: 16) {
                            // Username Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.igTextPrimary)

                                TextField("username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .focused($focusedField, equals: .username)
                                    .font(.system(size: 16))
                                    .padding(12)
                                    .background(Color.igBackgroundGray)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(focusedField == .username ? Color.igBlack : Color.igBorderGray, lineWidth: 1)
                                    )

                                if !isUsernameValid(username) && !username.isEmpty {
                                    Text("Username must be 3-20 characters (letters, numbers, underscore, or period)")
                                        .font(.system(size: 12))
                                        .foregroundColor(.igRed)
                                }
                            }

                            // Full Name Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Name")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.igTextPrimary)

                                TextField("John Doe", text: $fullName)
                                    .focused($focusedField, equals: .fullName)
                                    .font(.system(size: 16))
                                    .padding(12)
                                    .background(Color.igBackgroundGray)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(focusedField == .fullName ? Color.igBlack : Color.igBorderGray, lineWidth: 1)
                                    )
                            }

                            // Bio Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bio")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.igTextPrimary)

                                TextEditor(text: $bio)
                                    .focused($focusedField, equals: .bio)
                                    .font(.system(size: 16))
                                    .frame(height: 100)
                                    .padding(8)
                                    .background(Color.igBackgroundGray)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(focusedField == .bio ? Color.igBlack : Color.igBorderGray, lineWidth: 1)
                                    )

                                Text("\(bio.count)/150")
                                    .font(.system(size: 12))
                                    .foregroundColor(.igTextSecondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 16)

                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.igRed)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.igTextPrimary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(hasChanges ? .igBlue : .igTextSecondary)
                    .disabled(!hasChanges || viewModel.isLoading)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { oldValue, newValue in
                Task {
                    await loadSelectedImage()
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)
                    }
                }
            }
        }
    }

    // MARK: - Views

    private var defaultAvatar: some View {
        Image(systemName: "person.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 100, height: 100)
            .foregroundColor(.igTextSecondary)
    }

    // MARK: - Validation

    private var hasChanges: Bool {
        username != profile.username ||
        fullName != (profile.fullName ?? "") ||
        bio != (profile.bio ?? "") ||
        selectedImage != nil
    }

    private func isUsernameValid(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_.]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }

    // MARK: - Actions

    private func loadSelectedImage() async {
        guard let photoItem = selectedPhotoItem else { return }

        do {
            if let data = try await photoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                    viewModel.errorMessage = nil // Clear any previous errors
                }
            } else {
                // Failed to load image data
                await MainActor.run {
                    viewModel.errorMessage = "Failed to load selected photo. Try selecting a different photo."
                }
            }
        } catch {
            print("❌ Failed to load image: \(error)")

            // Provide user-friendly error message
            await MainActor.run {
                // Check if it's an iCloud-related error (common in simulator)
                if error.localizedDescription.contains("CloudPhotoLibrary") ||
                   error.localizedDescription.contains("PHAssetExportRequest") ||
                   error.localizedDescription.contains("helper application") {
                    viewModel.errorMessage = "Cannot access iCloud photos in simulator. Try using a local photo or test on a physical device."
                } else {
                    viewModel.errorMessage = "Failed to load selected photo. Please try again or choose a different photo."
                }

                // Reset the picker selection
                selectedPhotoItem = nil
            }
        }
    }

    private func saveProfile() async {
        guard case .authenticated(let userId) = authViewModel.authState else {
            return
        }

        // Limit bio to 150 characters
        let trimmedBio = String(bio.prefix(150))

        // Upload avatar if changed
        if let newImage = selectedImage {
            await viewModel.uploadAvatar(image: newImage, userId: userId)
        }

        // Update profile fields
        if username != profile.username || fullName != profile.fullName || trimmedBio != profile.bio {
            await viewModel.updateProfile(
                userId: userId,
                username: username != profile.username ? username.lowercased() : nil,
                fullName: fullName != profile.fullName ? fullName : nil,
                bio: trimmedBio != profile.bio ? trimmedBio : nil
            )
        }

        // Dismiss if no errors
        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleProfile = Profile(
        id: UUID(),
        username: "johndoe",
        avatarUrl: nil,
        fullName: "John Doe",
        bio: "Living life one day at a time",
        createdAt: Date()
    )

    return EditProfileView(
        viewModel: ProfileViewModel(),
        profile: sampleProfile
    )
    .environmentObject(AuthViewModel())
}

//
//  UsernameCreationView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct UsernameCreationView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var username: String = ""
    @State private var fullName: String = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case username
        case fullName
    }

    var body: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.igTextSecondary)
                        .padding(.top, 60)

                    Text("Create your profile")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.igTextPrimary)
                        .padding(.top, 16)

                    Text("Choose a username to get started")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 40)

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
                }
                .padding(.horizontal, 32)

                Spacer()

                // Create Account Button
                Button(action: {
                    Task {
                        await viewModel.createProfile(username: username, fullName: fullName)
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        Text("Create Account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                }
                .background(isFormValid ? Color.igBlue : Color.igTextSecondary)
                .cornerRadius(8)
                .disabled(!isFormValid || viewModel.isLoading)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.igRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            focusedField = .username
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        isUsernameValid(username) && !fullName.isEmpty
    }

    private func isUsernameValid(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_.]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
}

#Preview {
    UsernameCreationView()
        .environmentObject(AuthViewModel())
}

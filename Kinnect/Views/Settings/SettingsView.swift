// ABOUTME: Main settings screen with grouped list of configuration options
// ABOUTME: Instagram-style layout with account, privacy, data, preferences, and about sections

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = ProfileViewModel()
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showLogoutAlert = false
    @State private var showDeleteAlert1 = false
    @State private var showDeleteAlert2 = false
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        List {
            // MARK: - Account Section
            Section(header: Text("Account").textCase(.uppercase)) {
                NavigationLink {
                    if let profile = profileViewModel.profile {
                        EditProfileView(
                            viewModel: profileViewModel,
                            profile: profile
                        )
                    } else {
                        ProgressView()
                            .onAppear {
                                Task {
                                    guard case .authenticated(let userId) = authViewModel.authState else { return }
                                    await profileViewModel.loadProfile(userId: userId, currentUserId: userId)
                                }
                            }
                    }
                } label: {
                    SettingsRowView(
                        icon: "person.circle",
                        title: "Edit Profile",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    if let email = viewModel.userEmail,
                       let userId = viewModel.userId,
                       let createdAt = viewModel.accountCreatedAt {
                        AccountInfoView(
                            email: email,
                            userId: userId,
                            createdAt: createdAt
                        )
                    } else {
                        ProgressView()
                            .onAppear {
                                Task {
                                    await viewModel.fetchAccountInfo()
                                }
                            }
                    }
                } label: {
                    SettingsRowView(
                        icon: "info.circle",
                        title: "Account Info",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    ChangePasswordView()
                } label: {
                    SettingsRowView(
                        icon: "key",
                        title: "Change Password",
                        iconColor: .igTextSecondary
                    )
                }

                Button {
                    showDeleteAlert1 = true
                } label: {
                    SettingsRowView(
                        icon: "trash",
                        title: "Delete Account",
                        iconColor: .igRed
                    )
                }
            }

            // MARK: - Privacy Section
            Section(header: Text("Privacy").textCase(.uppercase)) {
                NavigationLink {
                    BlockedUsersView()
                        .environmentObject(authViewModel)
                } label: {
                    SettingsRowView(
                        icon: "hand.raised",
                        title: "Blocked Users",
                        iconColor: .igTextSecondary
                    )
                }
            }

            // MARK: - Data & Storage Section
            Section(header: Text("Data & Storage").textCase(.uppercase)) {
                Button {
                    Task {
                        await viewModel.clearCache()
                    }
                } label: {
                    SettingsRowView(
                        icon: "trash.circle",
                        title: "Clear Cache",
                        iconColor: .igTextSecondary
                    )
                }
                .disabled(viewModel.isLoading)

                NavigationLink {
                    Text("Download My Data") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "arrow.down.circle",
                        title: "Download My Data",
                        iconColor: .igTextSecondary
                    )
                }
            }

            // MARK: - Preferences Section
            Section(header: Text("Preferences").textCase(.uppercase)) {
                HStack(spacing: 12) {
                    SettingsRowView(
                        icon: "moon.fill",
                        title: "Dark Mode",
                        iconColor: .igTextSecondary
                    )

                    Toggle("", isOn: $isDarkMode)
                        .labelsHidden()
                        .accessibilityLabel("Dark Mode Toggle")
                }
            }

            // MARK: - About Section
            Section(header: Text("About").textCase(.uppercase)) {
                HStack {
                    SettingsRowView(
                        icon: "app.badge",
                        title: "App Version",
                        iconColor: .igTextSecondary
                    )

                    Text("1.0.0 (1)")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                }

                NavigationLink {
                    Text("Terms of Service") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "doc.text",
                        title: "Terms of Service",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    Text("Privacy Policy") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "hand.raised.shield",
                        title: "Privacy Policy",
                        iconColor: .igTextSecondary
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
        .safeAreaInset(edge: .bottom) {
            // MARK: - Log Out Button (Footer)
            Button {
                showLogoutAlert = true
            } label: {
                Text("Log Out")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.igRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.igBackground)
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAlert1) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) {
                showDeleteAlert2 = true
            }
        } message: {
            Text("Are you sure you want to delete your account?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert2) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAccount()
                    // Sign out on success
                    if viewModel.errorMessage == nil {
                        await authViewModel.signOut()
                    }
                }
            }
        } message: {
            Text("This action is permanent and cannot be undone. All your posts, comments, and data will be deleted.")
        }
        .alert("Cache Cleared", isPresented: $viewModel.showCacheSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("All cached data has been cleared.")
        }
        .onAppear {
            Task {
                await viewModel.fetchAccountInfo()
            }
        }
    }
}

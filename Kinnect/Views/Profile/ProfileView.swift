//
//  ProfileView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                if viewModel.isLoading && viewModel.profile == nil {
                    // Loading State
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .igTextSecondary))
                } else if let profile = viewModel.profile, let stats = viewModel.stats {
                    // Profile Content
                    VStack(spacing: 0) {
                        // Profile Header
                        ProfileHeaderView(
                            profile: profile,
                            stats: stats,
                            isCurrentUser: true,
                            onEditProfile: {
                                showEditProfile = true
                            },
                            onFollowToggle: {
                                // Non-functional for Phase 3
                            }
                        )

                        // Posts Grid
                        ProfilePostsGridView(
                            posts: [], // Empty for now - will be populated in Phase 6
                            isCurrentUser: true
                        )
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    // Error State
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.igRed)

                        Text(errorMessage)
                            .font(.system(size: 16))
                            .foregroundColor(.igTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            Task {
                                await loadProfile()
                            }
                        }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 40)
                                .background(Color.igBlue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.profile?.username ?? "Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            Task {
                                await authViewModel.signOut()
                            }
                        }) {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.igTextPrimary)
                    }
                }
            }
            .sheet(isPresented: $showEditProfile) {
                if let profile = viewModel.profile {
                    EditProfileView(
                        viewModel: viewModel,
                        profile: profile
                    )
                }
            }
            .task {
                await loadProfile()
            }
            .refreshable {
                await loadProfile()
            }
        }
    }

    private func loadProfile() async {
        guard case .authenticated(let userId) = authViewModel.authState else {
            return
        }

        await viewModel.loadProfile(userId: userId)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

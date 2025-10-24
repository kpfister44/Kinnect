//
//  ProfileView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct ProfileView: View {
    /// Optional user ID - if nil, displays current user's profile
    let userId: UUID?

    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showFollowersList = false
    @State private var showFollowingList = false

    init(userId: UUID? = nil) {
        self.userId = userId
    }

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
                            isCurrentUser: isCurrentUser,
                            isFollowing: viewModel.isFollowing,
                            isFollowOperationInProgress: viewModel.isFollowOperationInProgress,
                            onEditProfile: {
                                showEditProfile = true
                            },
                            onFollowToggle: {
                                Task {
                                    await handleFollowToggle()
                                }
                            },
                            onFollowersTap: {
                                showFollowersList = true
                            },
                            onFollowingTap: {
                                showFollowingList = true
                            }
                        )

                        // Posts Grid
                        ProfilePostsGridView(
                            posts: [], // Empty for now - will be populated in Phase 6
                            isCurrentUser: isCurrentUser
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
            .sheet(isPresented: $showFollowersList) {
                if let profile = viewModel.profile {
                    FollowersListView(userId: profile.id)
                }
            }
            .sheet(isPresented: $showFollowingList) {
                if let profile = viewModel.profile {
                    FollowingListView(userId: profile.id)
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

    // MARK: - Computed Properties

    /// Check if viewing current user's profile
    private var isCurrentUser: Bool {
        guard case .authenticated(let currentUserId) = authViewModel.authState else {
            return false
        }
        // If userId is nil, we're viewing current user. Otherwise, check if it matches
        return userId == nil || userId == currentUserId
    }

    /// Get the profile user ID to load
    private var profileUserId: UUID? {
        // If userId provided, use it. Otherwise use current user's ID
        if let userId = userId {
            return userId
        }
        guard case .authenticated(let currentUserId) = authViewModel.authState else {
            return nil
        }
        return currentUserId
    }

    /// Get current user's ID
    private var currentUserId: UUID? {
        guard case .authenticated(let userId) = authViewModel.authState else {
            return nil
        }
        return userId
    }

    // MARK: - Helper Methods

    private func loadProfile() async {
        guard let profileId = profileUserId else {
            return
        }

        await viewModel.loadProfile(userId: profileId, currentUserId: currentUserId)
    }

    private func handleFollowToggle() async {
        guard let currentId = currentUserId,
              let profileId = profileUserId else {
            return
        }

        await viewModel.toggleFollow(currentUserId: currentId, profileUserId: profileId)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
